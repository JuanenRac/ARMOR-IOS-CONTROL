// ARMOR-IOS-CONTROL - More: the server and its two addresses, the lock of the phone, the language, the help, and signing out.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct MoreView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(model.tr("Servidor")) { ServerSettings() }
                    NavigationLink(model.tr("Bloqueo con el teléfono")) { LockSettingsView() }
                    NavigationLink(model.tr("Idioma")) { LanguageView() }
                    NavigationLink(model.tr("Qué avisos quiero")) { NoticeSettingsView() }
                    NavigationLink(model.tr("Sonido de cada aviso")) { SoundSettingsView() }
                    NavigationLink(model.tr("Voz de las alarmas")) { VoiceSettingsView() }
                    NavigationLink(model.tr("Ayuda")) { HelpView() }
                    NavigationLink(model.tr("Dispositivos")) { DevicesView() }
                }.listRowBackground(Theme.surface)
                Section {
                    LabeledContent(model.tr("Usuario"), value: model.state.facts.role)
                    LabeledContent(model.tr("Servidor"), value: model.activeOrigin ?? "-")
                    LabeledContent(model.tr("Versión"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                    Button(model.tr("Cerrar sesión"), role: .destructive) { confirmSignOut = true }
                }.listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle(model.tr("Más"))
            .confirmationDialog(model.tr("¿Cerrar sesión?"), isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button(model.tr("Cerrar sesión"), role: .destructive) { Task { await model.signOut() } }
                Button(model.tr("Cancelar"), role: .cancel) {}
            } message: { Text(model.tr("Dejarás de recibir avisos en este móvil hasta que vuelvas a entrar.")) }
        }
    }
}

struct ServerSettings: View {
    @EnvironmentObject var model: AppModel
    @State private var draft = SavedInstallation()
    @State private var qr = ""

    var body: some View {
        Form {
            Section(header: Text(model.tr("Servidor"))) { AddressFields(draft: $draft) }
            Section {
                Button(model.tr("Guardar y volver a conectar")) {
                    model.saveInstallation(draft)
                    Task { await model.connect(); await model.refresh() }
                }
                if let problem = model.problem { Text(problem.message(model.translator)).foregroundColor(Theme.amber) }
            }
            Section(header: Text(model.tr("Certificado del servidor")), footer: Text(model.tr("La primera vez que se conecta por https, la app recuerda la clave del certificado de tu instalación. Si cambia, no se conecta y te lo dice. También puedes emparejarla pegando el texto del código QR que muestra Studio (armor-pin:…)."))) {
                TextField("armor-pin:…", text: $qr).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(model.tr("Emparejar")) {
                    if model.pair(qr: qr) { model.show(model.tr("Servidor emparejado."), error: false); qr = "" } else { model.show(model.tr("Ese código no es correcto."), error: true) }
                }.disabled(qr.isEmpty)
                Button(model.tr("Olvidar los certificados guardados"), role: .destructive) { model.forgetPins() }
            }
        }
        .navigationTitle(model.tr("Servidor"))
        .onAppear { draft = model.installation }
    }
}

struct LockSettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let status = model.lockStatus
        Form {
            Section(footer: Text(availabilityText(status))) {
                Toggle(model.tr("Pedirlo para armar, desarmar, silenciar y desbloquear"), isOn: Binding(get: { status.sensitiveOn }, set: { on in Task { await model.setSensitiveLock(on) } }))
                    .disabled(status.sensitiveForced)
                if status.sensitiveForced { Text(model.tr("Tu administrador lo exige en este servidor.")).font(.caption).foregroundColor(Theme.amber) }
                Toggle(model.tr("Pedirlo también para abrir la aplicación"), isOn: Binding(get: { status.openOn }, set: { on in Task { await model.setOpenLock(on) } }))
                    .disabled(status.openForced)
                Text(model.tr("Desactivado por defecto. Siempre queda la salida de entrar con la contraseña.")).font(.caption).foregroundColor(Theme.muted)
                Picker(model.tr("Una comprobación vale durante"), selection: Binding(get: { status.graceSeconds }, set: { model.setGrace($0) })) {
                    ForEach(LockSettings.graceChoices, id: \.self) { seconds in Text(graceText(seconds)).tag(seconds) }
                }
            }
            if status.unmet {
                Section { Text(model.tr("Lo pide el servidor o lo has pedido tú, pero este teléfono no tiene código de acceso: de momento no se pedirá nada. Pon un código en Ajustes del iPhone.")).foregroundColor(Theme.amber) }
            }
            Section(footer: Text(model.tr("Desactivado por defecto. La sesión guardada y el acceso recordado solo se pueden leer con el teléfono desbloqueado."))) {
                Toggle(model.tr("Atar la clave de la sesión al desbloqueo del teléfono"), isOn: Binding(get: { model.tiedToUnlock }, set: { on in Task { await model.setTiedToUnlock(on) } }))
                if model.tiedToUnlock {
                    Text(model.tr("Aviso: con esto, tras reiniciar el teléfono, las alarmas no llegarán hasta que lo desbloquees por primera vez.")).font(.caption).foregroundColor(Theme.amber)
                }
            }
        }
        .navigationTitle(model.tr("Bloqueo con el teléfono"))
    }

    private func availabilityText(_ status: LockStatus) -> String {
        switch status.availability {
        case .biometric: return model.tr("Este teléfono tiene Face ID o Touch ID, y su código como alternativa.")
        case .deviceCredential: return model.tr("Este teléfono solo tiene código de acceso: se pedirá eso.")
        case .none: return model.tr("Este teléfono no tiene código de acceso: sin él no se puede pedir nada.")
        }
    }

    private func graceText(_ seconds: Int) -> String {
        switch seconds {
        case 0: return model.tr("Cada vez")
        case 30: return model.trf("%d segundos", 30)
        default: return model.trf("%d minutos", seconds / 60)
        }
    }
}

struct LanguageView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        List {
            Section(footer: Text(model.tr("El idioma de la app. Si no eliges uno, usa el del móvil cuando es uno de estos ocho."))) {
                ForEach(Translator.languages, id: \.code) { language in
                    Button { model.chooseLanguage(language.code) } label: {
                        HStack { Text(language.name).foregroundColor(.white); Spacer(); if model.language == language.code { Image(systemName: "checkmark").foregroundColor(Theme.accent) } }
                    }
                }
            }
        }
        .navigationTitle(model.tr("Idioma"))
    }
}

struct DevicesView: View {
    @EnvironmentObject var model: AppModel
    @State private var devices: [SiteDevice] = []
    @State private var confirm: (SiteDevice, String)?

    var body: some View {
        List {
            if devices.isEmpty { Text(model.tr("Sin dispositivos")).foregroundColor(Theme.muted) }
            ForEach(devices) { device in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(device.name); Spacer(); Pill(text: device.online ? model.tr("en línea") : model.tr("fuera de línea"), color: device.online ? Theme.ok : Theme.amber) }
                    if device.canCommand, model.state.facts.canChange {
                        HStack {
                            Button(model.tr("Encender")) { run(device, "on") }
                            Button(model.tr("Apagar")) { run(device, "off") }
                        }.buttonStyle(.bordered).tint(Theme.accent)
                    }
                }.listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Dispositivos"))
        .task { await load() }
        .refreshable { await load() }
        .alert(model.tr("Confirmar"), isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
            Button(model.tr("Confirmar"), role: .destructive) { if let (device, command) = confirm { confirm = nil; Task { await send(device, command, true) } } }
            Button(model.tr("Cancelar"), role: .cancel) { confirm = nil }
        } message: { Text(confirm.map { question($0.0, $0.1) } ?? "") }
    }

    private func load() async {
        guard let origin = model.activeOrigin else { return }
        devices = (try? await model.controller.api.devices(origin)) ?? devices
    }

    private func run(_ device: SiteDevice, _ command: String) {
        if device.risk == "circuit" || device.risk == "critical" { confirm = (device, command) } else { Task { await send(device, command, false) } }
    }

    private func question(_ device: SiteDevice, _ command: String) -> String {
        let verb = command == "on" ? model.tr("conectar") : model.tr("cortar")
        if device.risk == "circuit" { return model.trf("«%s» es un circuito del cuadro eléctrico. ¿Seguro que quieres %s su alimentación?", device.name, verb) }
        return model.trf("«%s» es crítico (un congelador, una bomba, la alarma...). Solo un administrador puede ordenarlo. ¿Seguro que quieres %s su alimentación?", device.name, verb)
    }

    private func send(_ device: SiteDevice, _ command: String, _ confirmed: Bool) async {
        await model.order { asker in try await model.controller.command(device: device, command: command, confirmed: confirmed, asker: asker) }
        await load()
    }
}
