// ARMOR-IOS-CONTROL - Security, for an administrator: the VPN into the house (devices that can connect, with their configuration) and the name that follows the house (dynamic DNS).
// The same two cards as Studio's Security tab. The work is done by the maintenance helper of the machine. The configuration of a device holds its PRIVATE KEY: it is shown once with a warning, it is
// kept only in memory (never on disk, never in a log), it closes by itself after the time in Resources/security.json, when the screen goes away and when the app leaves the screen, and copying it to the
// clipboard is off unless that file allows it.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import UIKit
import ArmorCore

@MainActor
final class RemoteSetupState: ObservableObject {
    @Published var setup: RemoteSetup?
    @Published var config: PeerConfig?
    @Published var busy = false
    @Published var message: String?
    private var closer: Task<Void, Never>?
    let policy = PeerConfigPolicy.bundled()

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        do { setup = try await model.controller.api.remoteSetup(origin) } catch { message = SecurityText.errorText(error, model.translator) }
    }

    private func run(_ model: AppModel, _ action: (String) async throws -> Void) async {
        guard let origin = model.activeOrigin else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await action(origin) } catch { message = SecurityText.errorText(error, model.translator) }
    }

    func vpnSetup(model: AppModel, endpoint: String, port: Int, lan: String, route: String) async {
        await run(model) { origin in self.setup = try await model.controller.api.vpnSetup(origin, endpoint: endpoint, port: port, lan: lan, routeLan: route) }
    }

    func show(model: AppModel, peer: VpnPeer) async {
        await run(model) { origin in self.keep(try await model.controller.api.vpnShowPeer(origin, name: peer.name)) }
    }

    func add(model: AppModel, name: String, full: Bool) async {
        await run(model) { origin in
            self.keep(try await model.controller.api.vpnAddPeer(origin, name: name, fullTunnel: full))
            self.setup = try await model.controller.api.remoteSetup(origin)
        }
    }

    func remove(model: AppModel, peer: VpnPeer) async {
        await run(model) { origin in
            try await model.controller.api.vpnRemovePeer(origin, name: peer.name)
            self.close()
            self.setup = try await model.controller.api.remoteSetup(origin)
        }
    }

    func ddnsSetup(model: AppModel, provider: String, domain: String, token: String, zone: String, record: String, url: String) async {
        await run(model) { origin in self.setup = try await model.controller.api.ddnsSetup(origin, provider: provider, domain: domain, token: token, zone: zone, record: record, url: url) }
    }

    func ddnsUpdate(model: AppModel) async { await run(model) { origin in self.setup = try await model.controller.api.ddnsUpdate(origin) } }
    func ddnsStop(model: AppModel) async { await run(model) { origin in self.setup = try await model.controller.api.ddnsRemove(origin) } }

    /// Shows the configuration of a device and closes it by itself after the time the settings give.
    private func keep(_ shown: PeerConfig) {
        config = shown
        closer?.cancel()
        let seconds = policy.visibleSeconds
        closer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled { self?.close() }
        }
    }

    /// Forgets the configuration (and with it the private key).
    func close() {
        closer?.cancel(); closer = nil
        config = nil
    }
}

struct RemoteSetupView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var remote = RemoteSetupState()
    @State private var endpoint = ""
    @State private var port = "51820"
    @State private var lan = "192.168.0.0/24"
    @State private var route = ""
    @State private var peerName = ""
    @State private var fullTunnel = false
    @State private var removing: VpnPeer?
    @State private var copied = false
    @State private var provider = "duckdns"
    @State private var domain = ""
    @State private var token = ""
    @State private var zone = ""
    @State private var record = ""
    @State private var url = ""

    var body: some View {
        List {
            if let message = remote.message { Section { Text(message).foregroundColor(Theme.danger) }.listRowBackground(Theme.surface) }
            if !model.state.facts.isAdmin {
                Section { Text(model.tr("Solo un administrador puede usar esta pantalla.")).foregroundColor(Theme.danger) }.listRowBackground(Theme.surface)
            } else if let setup = remote.setup {
                vpnSection(setup)
                ddnsSection(setup)
                Section(header: Text(model.tr("Paneles de los nodos a través del servidor")),
                        footer: Text(model.tr("Para abrir el panel de un nodo desde fuera de casa, usa Studio (Configuración > Seguridad): ahí se registran los nodos y se comprueba y se confía en su certificado."))) { EmptyView() }
                    .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Acceso desde fuera de casa"))
        .task { if model.state.facts.isAdmin { await remote.load(model: model) } }
        .onDisappear { remote.close() }
        .onChange(of: scenePhase) { phase in if phase != .active { remote.close() } }
        .alert(removing?.name ?? "", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button(model.tr("Quitar"), role: .destructive) { if let peer = removing { removing = nil; Task { await remote.remove(model: model, peer: peer) } } }
            Button(model.tr("Cancelar"), role: .cancel) { removing = nil }
        } message: { Text(model.tr("¿Quitar este dispositivo? Ya no podrá conectarse.")) }
    }

    @ViewBuilder private func vpnSection(_ setup: RemoteSetup) -> some View {
        Section(header: Text(model.tr("VPN (WireGuard)"))) {
            if !setup.vpnScript {
                Text(model.tr("El ayudante de mantenimiento no está instalado en la máquina, así que esto no se puede hacer desde aquí. Instálalo con: install_cm5.sh --with-maintenance.")).font(.footnote).foregroundColor(Theme.muted)
            } else if !setup.vpnTool {
                Text(model.tr("WireGuard no está instalado en la máquina. Instálalo con «sudo apt install wireguard-tools» y vuelve.")).font(.footnote).foregroundColor(Theme.amber)
            } else if !setup.vpnConfigured {
                TextField(model.tr("Nombre o dirección a la que se conectará el móvil (por ejemplo casa.duckdns.org)"), text: $endpoint).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(model.tr("Puerto de la VPN (UDP)"), text: $port).keyboardType(.numberPad).onChange(of: port) { value in port = String(value.filter(\.isNumber).prefix(5)) }
                TextField(model.tr("Red de la casa"), text: $lan).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(model.tr("Que el móvil llegue también a los nodos de la casa (nombre de la interfaz de red, por ejemplo eth0)"), text: $route).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(model.tr("Configurar la VPN")) {
                    let number = Int(port) ?? 51820
                    Task { await remote.vpnSetup(model: model, endpoint: endpoint.trimmingCharacters(in: .whitespaces), port: number, lan: lan.trimmingCharacters(in: .whitespaces), route: route.trimmingCharacters(in: .whitespaces)) }
                }.disabled(endpoint.trimmingCharacters(in: .whitespaces).isEmpty || remote.busy)
            } else {
                Text((setup.vpnRunning ? model.tr("La VPN está funcionando.") : model.tr("La VPN está configurada pero parada.")) + " " + setup.vpnEndpoint + " · " + setup.vpnSubnet)
                    .font(.subheadline.weight(.bold)).foregroundColor(setup.vpnRunning ? Theme.accent : Theme.amber)
                Text(model.tr("En tu router, redirige el puerto UDP {0} a esta máquina. No hace falta abrir nada más.").replacingOccurrences(of: "{0}", with: SecurityParser.forwardedPort(setup))).font(.footnote).foregroundColor(Theme.muted)
                Text(model.tr("Dispositivos que pueden conectarse")).font(.subheadline.weight(.bold))
                if setup.peers.isEmpty { Text(model.tr("Todavía no hay dispositivos.")).foregroundColor(Theme.muted) }
                ForEach(setup.peers, id: \.name) { peer in
                    HStack {
                        VStack(alignment: .leading) { Text(peer.name).font(.subheadline.weight(.bold)); Text(peer.address).font(.caption).foregroundColor(Theme.muted) }
                        Spacer()
                        Button(model.tr("Ver configuración")) { copied = false; Task { await remote.show(model: model, peer: peer) } }.disabled(remote.busy).buttonStyle(.borderless)
                        Button(model.tr("Quitar"), role: .destructive) { removing = peer }.disabled(remote.busy).buttonStyle(.borderless)
                    }
                }
                Text(model.tr("Añadir un dispositivo")).font(.subheadline.weight(.bold))
                TextField(model.tr("Nombre del dispositivo (letras, cifras, - y _; por ejemplo movil-ana)"), text: $peerName).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: peerName) { value in peerName = SecurityParser.cleanPeerName(value) }
                Toggle(model.tr("Enviar todo el tráfico de este dispositivo por la casa"), isOn: $fullTunnel)
                Button(model.tr("Crear")) { let name = peerName; peerName = ""; copied = false; Task { await remote.add(model: model, name: name, full: fullTunnel) } }.disabled(peerName.isEmpty || remote.busy)
                if let shown = remote.config { configBlock(shown) }
            }
        }.listRowBackground(Theme.surface)
    }

    @ViewBuilder private func configBlock(_ shown: PeerConfig) -> some View {
        Text(model.tr("Configuración de este dispositivo") + ": " + shown.name).font(.subheadline.weight(.bold)).foregroundColor(Theme.amber)
        Text(model.tr("Contiene la clave privada del dispositivo. Escanea el código con la app WireGuard (o importa el texto), cierra esta ventana y no se lo des a nadie más.")).font(.footnote)
        Text(model.trf("Se cierra sola en %s s y no se guarda en el teléfono.", Int(remote.policy.visibleSeconds))).font(.caption).foregroundColor(Theme.muted)
        Text(shown.config).font(.system(size: 12, design: .monospaced)).privacySensitive()
        HStack {
            if remote.policy.allowCopy {
                Button(copied ? model.tr("Copiado") : model.tr("Copiar")) {
                    UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: shown.config]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
                    copied = true
                }.buttonStyle(.bordered)
            }
            Button(model.tr("Cerrar")) { copied = false; remote.close() }.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder private func ddnsSection(_ setup: RemoteSetup) -> some View {
        Section(header: Text(model.tr("Nombre que sigue a tu casa (DNS dinámico)")),
                footer: Text(model.tr("Tu operador cambia de vez en cuando la dirección pública de tu casa. Esto mantiene un nombre apuntando siempre a ella, y el móvil nunca necesita saber la dirección."))) {
            if !setup.ddnsScript {
                Text(model.tr("El ayudante de mantenimiento no está instalado en la máquina, así que esto no se puede hacer desde aquí. Instálalo con: install_cm5.sh --with-maintenance.")).font(.footnote).foregroundColor(Theme.muted)
            } else if setup.ddnsConfigured {
                Text(model.tr("Manteniendo {0} al día mediante {1}. Última dirección comunicada: {2}.")
                    .replacingOccurrences(of: "{0}", with: setup.ddnsName.isEmpty ? "-" : setup.ddnsName).replacingOccurrences(of: "{1}", with: setup.ddnsProvider)
                    .replacingOccurrences(of: "{2}", with: setup.ddnsLast.isEmpty ? "-" : setup.ddnsLast))
                HStack {
                    Button(model.tr("Actualizar ahora")) { Task { await remote.ddnsUpdate(model: model) } }.buttonStyle(.bordered).disabled(remote.busy)
                    Button(model.tr("Dejar de actualizar")) { Task { await remote.ddnsStop(model: model) } }.buttonStyle(.bordered).disabled(remote.busy)
                }
            } else {
                Text(model.tr("Sin configurar.")).foregroundColor(Theme.muted)
                Picker(model.tr("Servicio"), selection: $provider) {
                    ForEach(["duckdns", "cloudflare", "url"], id: \.self) { id in Text(SecurityText.ddnsProviderName(id, model.translator)).tag(id) }
                }
                if provider == "duckdns" { TextField(model.tr("Nombre (sin .duckdns.org)"), text: $domain).textInputAutocapitalization(.never).autocorrectionDisabled() }
                if provider == "cloudflare" {
                    TextField(model.tr("ID de la zona (Cloudflare)"), text: $zone).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField(model.tr("Nombre que mantener al día"), text: $record).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                if provider == "url" { TextField(model.tr("Dirección a la que llamar, con {ip} donde va la dirección"), text: $url).textInputAutocapitalization(.never).autocorrectionDisabled() }
                else { SecureField(model.tr("Token del servicio"), text: $token) }
                Button(model.tr("Guardar y comprobar ahora")) {
                    let sent = (provider, domain.lowercased(), token, zone, record, url)
                    token = ""
                    Task { await remote.ddnsSetup(model: model, provider: sent.0, domain: sent.1.trimmingCharacters(in: .whitespaces), token: sent.2.trimmingCharacters(in: .whitespaces), zone: sent.3.trimmingCharacters(in: .whitespaces), record: sent.4.trimmingCharacters(in: .whitespaces), url: sent.5.trimmingCharacters(in: .whitespaces)) }
                }.disabled(!ddnsReady || remote.busy)
            }
        }.listRowBackground(Theme.surface)
    }

    private var ddnsReady: Bool {
        switch provider {
        case "duckdns": return !domain.isEmpty && !token.isEmpty
        case "cloudflare": return !zone.isEmpty && !record.isEmpty && !token.isEmpty
        default: return !url.isEmpty
        }
    }
}
