// ARMOR-IOS-CONTROL - the security of the account: the second factor (an authenticator app), the open sessions, and how the server sees this phone.
// The way in from outside the house (the VPN and the dynamic address) is set up in Studio, where its keys are shown once; the lock of the phone is in its own screen.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

@MainActor
final class SecurityState: ObservableObject {
    @Published var totp: TotpInfo?
    @Published var sessions: [SessionInfo] = []
    @Published var remote: RemoteInfo?
    @Published var setup: TotpSetup?
    @Published var recoveryCodes: [String] = []
    @Published var busy = false
    @Published var message: String?

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        if let value = try? await model.controller.api.totpState(origin) { totp = value }
        if let value = try? await model.controller.api.mySessions(origin) { sessions = value }
        remote = try? await model.controller.api.remoteCheck(origin)
    }

    /// Runs one change; a refusal is told in words and nothing else moves.
    private func run(_ model: AppModel, _ action: (String) async throws -> Void) async {
        guard let origin = model.activeOrigin else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await action(origin); await load(model: model) }
        catch { message = SecurityText.errorText(error, model.translator) }
    }

    func start(model: AppModel, password: String) async {
        await run(model) { origin in self.setup = try await model.controller.api.totpSetup(origin, password: password) }
    }

    func enable(model: AppModel, code: String) async {
        await run(model) { origin in
            self.recoveryCodes = try await model.controller.api.totpEnable(origin, code: code)
            self.setup = nil
        }
    }

    func disable(model: AppModel, password: String) async {
        await run(model) { origin in
            try await model.controller.api.totpDisable(origin, password: password)
            self.recoveryCodes = []; self.setup = nil
        }
    }

    func end(model: AppModel, _ session: SessionInfo) async { await run(model) { origin in try await model.controller.api.endSession(origin, id: session.id) } }
    func endOthers(model: AppModel) async { await run(model) { origin in try await model.controller.api.endOtherSessions(origin) } }
}

struct SecurityView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openURL) private var openURL
    @StateObject private var security = SecurityState()
    @State private var password = ""
    @State private var code = ""

    private func when(_ ms: Int) -> String {
        if ms <= 0 { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    var body: some View {
        List {
            if let message = security.message { Section { Text(message).foregroundColor(Theme.danger) }.listRowBackground(Theme.surface) }
            totpSection
            sessionsSection
            remoteSection
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Seguridad"))
        .task { await security.load(model: model) }
        .refreshable { await security.load(model: model) }
    }

    @ViewBuilder private var totpSection: some View {
        Section(header: Text(model.tr("Segundo factor (aplicación autenticadora)")),
                footer: Text(model.tr("Con él, una contraseña robada no basta para entrar: la aplicación del móvil da un código de seis cifras que cambia cada treinta segundos. Sirve Google Authenticator, Aegis, Authy o cualquier similar."))) {
            if let totp = security.totp {
                Text(totp.enabled ? model.tr("El segundo factor está ACTIVADO en tu cuenta.") + " " + String(totp.recoveryLeft) + " " + model.tr("códigos de recuperación restantes") : model.tr("El segundo factor está desactivado."))
                    .font(.subheadline.weight(.bold)).foregroundColor(totp.enabled ? Theme.accent : Theme.muted)
            }
            if security.setup == nil && security.totp?.enabled == false {
                SecureField(model.tr("Tu contraseña (para confirmar que eres tú)"), text: $password)
                Button(model.tr("Configurarlo")) { let typed = password; password = ""; Task { await security.start(model: model, password: typed) } }.disabled(password.isEmpty || security.busy)
            }
            if let setup = security.setup {
                Text(model.tr("Añade esta clave a tu aplicación: abre el enlace en el móvil que tiene la aplicación, o escribe la clave a mano (el tipo es «basado en tiempo»).")).font(.footnote)
                Text(model.tr("Clave")).font(.footnote.weight(.bold))
                Text(SecurityParser.grouped(setup.secret)).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                if let link = URL(string: setup.uri), link.scheme == "otpauth" { Button(model.tr("Abrir en la aplicación")) { openURL(link) } }
                TextField(model.tr("Código de la aplicación (6 cifras)"), text: $code).keyboardType(.numberPad)
                    .onChange(of: code) { value in code = String(value.filter(\.isNumber).prefix(6)) }
                Button(model.tr("Activarlo")) { let typed = code; code = ""; Task { await security.enable(model: model, code: typed) } }.disabled(code.count != 6 || security.busy)
            }
            if !security.recoveryCodes.isEmpty {
                Text(model.tr("Tus códigos de recuperación: guárdalos ahora")).font(.subheadline.weight(.bold)).foregroundColor(Theme.amber)
                Text(model.tr("Cada uno vale una vez, si pierdes el móvil. Solo se muestran ahora y el servidor guarda solo una huella de ellos. Guárdalos en un lugar seguro, no en el mismo móvil.")).font(.footnote)
                Text(security.recoveryCodes.joined(separator: "\n")).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            }
            if security.totp?.enabled == true {
                SecureField(model.tr("Tu contraseña (para confirmar que eres tú)"), text: $password)
                Button(model.tr("Desactivarlo"), role: .destructive) { let typed = password; password = ""; Task { await security.disable(model: model, password: typed) } }.disabled(password.isEmpty || security.busy)
            }
        }.listRowBackground(Theme.surface)
    }

    @ViewBuilder private var sessionsSection: some View {
        Section(header: Text(model.tr("Tus sesiones abiertas")),
                footer: Text(model.tr("Cada navegador o móvil con la sesión abierta. Si no reconoces alguno, ciérralo: necesitará tu contraseña de nuevo."))) {
            if security.sessions.isEmpty { Text(model.tr("No hay sesiones que mostrar.")).foregroundColor(Theme.muted) }
            ForEach(security.sessions) { session in
                let origin = session.remote ? model.tr("desde fuera") : model.tr("desde casa")
                let line = origin + " · " + (session.ip.isEmpty ? "-" : session.ip) + " · " + model.tr("último uso") + " " + when(session.lastSeenMs)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.current ? model.tr("esta sesión") : (session.agent.isEmpty ? "-" : session.agent)).font(.subheadline.weight(.bold)).lineLimit(2)
                        Text(line).font(.caption).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    if !session.current { Button(model.tr("Cerrarla"), role: .destructive) { Task { await security.end(model: model, session) } }.disabled(security.busy) }
                }
            }
            if security.sessions.count > 1 {
                Button(model.tr("Cerrar todas las demás"), role: .destructive) { Task { await security.endOthers(model: model) } }.disabled(security.busy)
            }
        }.listRowBackground(Theme.surface)
    }

    @ViewBuilder private var remoteSection: some View {
        Section(header: Text(model.tr("Usar el servidor desde fuera de casa")),
                footer: Text(model.tr("Abre el servidor a Internet solo por una puerta: un proxy inverso con certificado válido (el perfil TLS). El broker y los nodos nunca se publican. Pulsa el botón desde un móvil con datos para ver cómo te ve el servidor."))) {
            Button(model.tr("Comprobar cómo me ve el servidor")) { Task { await security.load(model: model) } }.disabled(security.busy)
            if let remote = security.remote {
                Text(model.tr("Dirección que ve el servidor") + ": " + remote.ip)
                Text(model.tr("Cuenta como") + ": " + (remote.remote ? model.tr("desde fuera") : model.tr("desde casa")))
                Text(model.tr("Cookie segura") + ": " + (remote.cookieSecure ? model.tr("sí") : model.tr("no")))
                Text(model.tr("Proxy de confianza") + ": " + remote.trustProxy)
                Text(model.tr("Política del segundo factor") + ": " + remote.policy)
                if !remote.remote {
                    Text(model.tr("El servidor te ve dentro de casa. Si estás con datos móviles, el proxy no está pasando tu dirección: indica abajo el proxy de confianza.")).font(.footnote).foregroundColor(Theme.amber)
                }
            }
        }.listRowBackground(Theme.surface)
    }
}
