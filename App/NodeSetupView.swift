// ARMOR-IOS-CONTROL - configure a field node over Bluetooth: find it, sign in (or create its administrator), and set its name, Wi-Fi, address and broker; and show or scan the pairing QR code
// of a node. The same flow as the Android app. For a node that has no Ethernet cable or no address yet. The protocol is ARMOR-NODE-RADAR's docs/BLE_PROVISIONING.md; the rules are in ArmorCore.
// Written without a Mac: it is built by the CI but has not been run against a node or an iPhone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import CoreBluetooth
import CoreImage.CIFilterBuiltins
import AVFoundation
import ArmorCore

enum NodeStep { case search, connecting, signIn, configure, verify }

@MainActor
final class NodeSetupModel: ObservableObject {
    @Published var step = NodeStep.search
    @Published var scanning = false
    @Published var found: [FoundNode] = []
    @Published var hello: NodeHello?
    @Published var busy = false
    @Published var message = ""
    @Published var admin = false
    @Published var networks: [WifiNetwork] = []
    @Published var problems: [String] = []
    @Published var saved = false
    @Published var name = ""
    /// The node being configured: it is looked for again after it restarts.
    @Published var target: FoundNode?
    /// The app is reading what the node did with its connection.
    @Published var checking = false
    @Published var outcome: NodeOutcome?

    var t = Translator()
    private let client = NodeBleClient()
    private var scanTimeout: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?

    // MARK: the radio

    private func ask(_ op: String, _ args: JSON? = nil, timeout: TimeInterval = 30) async -> NodeReply {
        await withCheckedContinuation { continuation in client.request(op, args: args, timeout: timeout) { continuation.resume(returning: $0) } }
    }

    private func link(_ node: FoundNode) async -> Bool {
        await withCheckedContinuation { continuation in client.connect(node) { continuation.resume(returning: $0) } }
    }

    // MARK: finding nodes

    func scan() {
        message = ""
        client.whenReady { [weak self] state in
            guard let self else { return }
            switch state {
            case .poweredOn: self.beginScan()
            case .unauthorized: self.message = self.t.tr("La app no tiene permiso de Bluetooth: concédelo en Ajustes del iPhone.")
            case .poweredOff: self.message = self.t.tr("El Bluetooth del teléfono está apagado.")
            case .unsupported: self.message = self.t.tr("Este teléfono no tiene Bluetooth de bajo consumo.")
            default: self.message = self.t.tr("No se pudo empezar la búsqueda.")
            }
        }
    }

    private func beginScan() {
        scanning = true
        found = []
        // A search does not go on for ever (it uses the battery): after half a minute it stops by itself.
        scanTimeout?.cancel()
        scanTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !Task.isCancelled { self?.stopScan() }
        }
        let started = client.startScan { [weak self] node in
            guard let self else { return }
            self.found = (self.found.filter { $0.id != node.id } + [node]).sorted { $0.rssi > $1.rssi }
        }
        if !started { scanning = false; message = t.tr("No se pudo empezar la búsqueda.") }
    }

    func stopScan() {
        scanTimeout?.cancel()
        client.stopScan()
        scanning = false
    }

    func connect(_ node: FoundNode) {
        stopScan()
        step = .connecting
        message = t.trf("Conectando con %s… (iOS puede pedir emparejar)", node.name)
        Task {
            if !(await link(node)) { step = .search; message = t.trf("No se pudo conectar con %s.", node.name); return }
            let reply = await ask("hello")
            if !reply.ok { client.disconnect(); step = .search; message = NodeProtocol.errorText(reply.error, t); return }
            let hello = NodeHello(reply.data)
            self.hello = hello; name = hello.name; target = node; message = ""; step = .signIn
        }
    }

    // MARK: signing in and configuring

    /// Creates the administrator of a new node with its set-up code, or signs in to a node that has users.
    func signIn(code: String, secret: String, user: String, password: String) {
        guard let hello else { return }
        busy = true; message = ""
        Task {
            var args: JSON = ["user": user, "password": password]
            let reply: NodeReply
            if hello.setup {
                let effective = code.isEmpty ? (SetupCode.derive(secret: secret, mac: hello.mac) ?? "") : code
                args["code"] = effective.trimmingCharacters(in: .whitespaces).uppercased()
                reply = await ask("setup", args)
            } else { reply = await ask("login", args) }
            busy = false
            if reply.ok { admin = hello.setup || (reply.data["role"] as? String) == "admin"; message = ""; step = .configure }
            else { message = NodeProtocol.errorText(reply.error, t) }
        }
    }

    func searchNetworks() {
        busy = true; message = t.tr("Buscando redes Wi-Fi… (unos segundos)")
        Task {
            let reply = await ask("wifi.scan", timeout: 40)
            busy = false
            if reply.ok { networks = WifiNetwork.list(reply.data); message = networks.isEmpty ? t.tr("No se oyó ninguna red.") : "" }
            else { message = NodeProtocol.errorText(reply.error, t) }
        }
    }

    func apply(_ form: NodeSettingsPatch.Form) {
        let wrong = NodeSettingsPatch.problems(form, t)
        if !wrong.isEmpty { message = ""; problems = wrong; saved = false; return }
        busy = true; message = ""; problems = []; saved = false
        Task {
            let reply = await ask("config.put", ["config": NodeSettingsPatch.build(form)])
            busy = false
            if reply.ok { saved = true; message = t.tr("Guardado. Reinicia el nodo para aplicarlo.") }
            else { message = NodeProtocol.errorText(reply.error, t); problems = reply.problems(t) }
        }
    }

    func reboot() {
        busy = true
        Task {
            let reply = await ask("reboot")
            client.disconnect()
            if !reply.ok { busy = false; message = NodeProtocol.errorText(reply.error, t); return }
            check(firstWait: 15)
        }
    }

    /// Looks for the node again over Bluetooth (it keeps advertising while it has no address) and reads what it did with its connection.
    func check(firstWait: TimeInterval = 0) {
        guard let target else { return }
        step = .verify; busy = true; checking = true; outcome = nil; saved = false
        message = t.tr("El nodo se reinicia. Comprobando su conexión…")
        checkTask?.cancel()
        checkTask = Task {
            if firstWait > 0 { try? await Task.sleep(nanoseconds: UInt64(firstWait * 1_000_000_000)) }
            var last = NodeOutcome.waiting
            var seen = false
            var failures = 0
            for attempt in 1...12 {
                if Task.isCancelled { return }
                if let node = await findAgain(target), await link(node) {
                    let reply = await ask("hello", timeout: 10)
                    client.disconnect()
                    if reply.ok {
                        seen = true
                        let hello = NodeHello(reply.data)
                        last = NodeOutcome.of(hello, t)
                        self.hello = hello
                        if case .online = last { break }
                        if case .failed = last { failures += 1; if failures >= 2 { break } }   // the second time the same reason is not a coincidence
                    }
                }
                message = t.trf("Comprobando la conexión… (intento %s de 12)", attempt)
                try? await Task.sleep(nanoseconds: 6_000_000_000)
            }
            if Task.isCancelled { return }
            busy = false; checking = false; outcome = last
            message = seen ? "" : t.tr("No se volvió a ver el nodo por Bluetooth. Con cable Ethernet, búscalo en tu red o en Studio. Sin cable y sin Wi-Fi guardado, a los 90 s de arrancar abre su Wi-Fi ARMOR-SETUP-… (la contraseña es su código de configuración).")
        }
    }

    private func findAgain(_ target: FoundNode, timeout: TimeInterval = 8) async -> FoundNode? {
        var heard: FoundNode?
        guard client.startScan({ node in if node.id == target.id || node.name == target.name { heard = node } }) else { return nil }
        let end = Date().addingTimeInterval(timeout)
        while heard == nil && Date() < end { try? await Task.sleep(nanoseconds: 300_000_000) }
        client.stopScan()
        return heard
    }

    /// Leaves the set-up: a check that was still running is stopped too (it would otherwise put the screen back on "Verify" after it was closed).
    func close() {
        checkTask?.cancel(); scanTimeout?.cancel()
        client.stopScan(); client.disconnect()
        step = .search; scanning = false; found = []; hello = nil; busy = false; message = ""; admin = false; networks = []; problems = []; saved = false; name = ""; target = nil; checking = false; outcome = nil
    }
}

struct NodeSetupView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var setup = NodeSetupModel()
    @State private var paired: Pairing?

    var body: some View {
        List {
            if !setup.message.isEmpty {
                Section { Text(setup.message).foregroundColor(setup.saved ? Theme.ok : Theme.danger) }.listRowBackground(Theme.surface)
            }
            switch setup.step {
            case .search: SearchStep(setup: setup, paired: $paired)
            case .connecting:
                Section { Text(model.tr("Conectando… Si iOS pregunta por emparejar, acepta y escribe el PIN que muestra el nodo en su consola USB.")) }.listRowBackground(Theme.surface)
            case .signIn: SignInStep(setup: setup)
            case .configure: ConfigureStep(setup: setup)
            case .verify: VerifyStep(setup: setup, onDone: { setup.close(); dismiss() })
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Configurar nodo por Bluetooth"))
        .onAppear { setup.t = model.translator }
        .onDisappear { setup.close() }
    }
}

private struct SearchStep: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var setup: NodeSetupModel
    @Binding var paired: Pairing?

    var body: some View {
        Section {
            Text(model.tr("Para un nodo sin cable Ethernet o sin dirección todavía. El nodo tiene que estar encendido y con el Bluetooth activo (un nodo nuevo lo tiene mientras no tenga usuarios).")).font(.footnote).foregroundColor(Theme.muted)
            Button(setup.scanning ? model.tr("Parar la búsqueda") : model.tr("Buscar nodos")) { setup.scanning ? setup.stopScan() : setup.scan() }
            if setup.scanning && setup.found.isEmpty { Text(model.tr("Buscando…")).foregroundColor(Theme.muted) }
        }.listRowBackground(Theme.surface)
        PairingSection(paired: $paired)
        if !setup.found.isEmpty {
            Section {
                ForEach(setup.found.sorted { PairingMatch.matches(nodeName: $0.name, pairing: paired) && !PairingMatch.matches(nodeName: $1.name, pairing: paired) }) { node in
                    Button { setup.connect(node) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(node.name); Spacer(); Text(String(node.rssi) + " dBm").font(.caption).foregroundColor(Theme.muted) }
                            if PairingMatch.matches(nodeName: node.name, pairing: paired) {
                                Text(model.tr("Este nodo coincide con el código leído")).font(.caption).foregroundColor(Theme.accent)
                            }
                        }
                    }
                }
            }.listRowBackground(Theme.surface)
        }
    }
}

private struct SignInStep: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var setup: NodeSetupModel
    @State private var code = ""
    @State private var secret = ""
    @State private var user = "admin"
    @State private var password = ""

    var body: some View {
        if let hello = setup.hello {
            Section {
                Text(hello.name.isEmpty ? hello.nodeId : hello.name).font(.headline)
                Text(hello.kind.label(model.translator)).font(.caption).foregroundColor(Theme.accent)
                Text(model.trf("MAC %s · firmware %s", hello.mac, hello.firmware)).font(.caption).foregroundColor(Theme.muted)
                Text(hello.hasIp ? model.trf("Red: %s", hello.ip) : model.tr("Sin dirección de red todavía")).font(.caption).foregroundColor(Theme.muted)
                if hello.staConnected { Text("Wi-Fi: \(hello.staSsid)").font(.caption).foregroundColor(Theme.muted) }
            }.listRowBackground(Theme.surface)
            Section {
                if hello.setup {
                    Text(model.tr("Este nodo no tiene usuarios. Escribe el código de configuración (el que muestra por su consola USB, o el de la flota) y elige el administrador.")).font(.footnote).foregroundColor(Theme.muted)
                    TextField(model.tr("Código de configuración"), text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    SecureField(model.tr("…o el secreto de la flota (calcula el código desde la MAC)"), text: $secret)
                } else {
                    Text(model.tr("Inicia sesión con un usuario del nodo.")).font(.footnote).foregroundColor(Theme.muted)
                }
                TextField(model.tr("Usuario"), text: $user).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(hello.setup ? model.tr("Contraseña nueva (8 caracteres o más)") : model.tr("Contraseña"), text: $password)
                Button(hello.setup ? model.tr("Crear administrador") : model.tr("Entrar")) { setup.signIn(code: code, secret: secret, user: user, password: password) }
                    .disabled(setup.busy || user.isEmpty || password.isEmpty || (hello.setup && code.isEmpty && secret.isEmpty))
                Button(model.tr("Elegir otro nodo")) { setup.close() }
            }.listRowBackground(Theme.surface)
        }
    }
}

private struct ConfigureStep: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var setup: NodeSetupModel
    @State private var form = NodeSettingsPatch.Form()
    @State private var loadedName = false

    var body: some View {
        if !setup.admin {
            Section { Text(model.tr("Este usuario sólo puede mirar: para cambiar la configuración hace falta un administrador.")) }.listRowBackground(Theme.surface)
        } else {
            let formProblems = NodeSettingsPatch.problems(form, model.translator)
            if let hello = setup.hello {
                Section { Text(hello.kind.label(model.translator) + " · " + hello.nodeId).font(.caption).foregroundColor(Theme.accent) }.listRowBackground(Theme.surface)
            }
            Section(header: Text(model.tr("Nombre y conexión"))) {
                TextField(model.tr("Nombre del nodo"), text: $form.name).autocorrectionDisabled()
                    .onAppear { if !loadedName { form.name = setup.name; loadedName = true } }
                Toggle(form.useWifi ? model.tr("Conexión por Wi-Fi (router o punto de acceso)") : model.tr("Conexión por cable Ethernet"), isOn: $form.useWifi)
                if form.useWifi {
                    Button(model.tr("Buscar redes Wi-Fi")) { setup.searchNetworks() }.disabled(setup.busy)
                    ForEach(setup.networks) { network in
                        Button { form.wifiSsid = network.ssid } label: {
                            HStack { Text(network.ssid); Spacer(); Text(model.trf("%s dBm · canal %s · %s", network.rssi, network.channel, network.security)).font(.caption2).foregroundColor(Theme.muted) }
                        }
                    }
                    TextField(model.tr("Nombre de la red (SSID)"), text: $form.wifiSsid).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField(model.tr("Contraseña del Wi-Fi"), text: $form.wifiPassword)
                    Text(model.tr("El nodo sólo usa redes de 2,4 GHz. Al reiniciar, la app vuelve a buscarlo por Bluetooth y te dice si se ha conectado o por qué no.")).font(.caption).foregroundColor(Theme.muted)
                }
            }.listRowBackground(Theme.surface)
            Section(header: Text(model.tr("Dirección de red"))) {
                Toggle(form.fixedAddress ? model.tr("Dirección fija") : model.tr("Automática (DHCP)"), isOn: $form.fixedAddress)
                if form.fixedAddress {
                    TextField(model.tr("Dirección IP (por ejemplo 192.168.0.60)"), text: $form.address).keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                    TextField(model.tr("Máscara de subred"), text: $form.netmask).keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                    TextField(model.tr("Puerta de enlace (el router)"), text: $form.gateway).keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                    TextField(model.tr("DNS (vacío: la puerta de enlace)"), text: $form.dns).keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                }
            }.listRowBackground(Theme.surface)
            Section(header: Text(model.tr("Broker (opcional)"))) {
                TextField(model.tr("Dirección del broker (mqtt://host:puerto)"), text: $form.brokerUri).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(model.tr("Usuario del broker"), text: $form.brokerUser).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(model.tr("Contraseña del broker"), text: $form.brokerPassword)
            }.listRowBackground(Theme.surface)
            Section(header: Text(model.tr("Bluetooth después del reinicio"))) {
                Picker(model.tr("Bluetooth después del reinicio"), selection: $form.bluetoothMode) {
                    Text(model.tr("no cambiar")).tag("")
                    Text(model.tr("sólo mientras el nodo no tenga usuarios")).tag("setup")
                    Text(model.tr("siempre (hace falta iniciar sesión)")).tag("always")
                    Text(model.tr("apagado")).tag("off")
                }.pickerStyle(.inline).labelsHidden()
            }.listRowBackground(Theme.surface)
            Section {
                if !setup.problems.isEmpty {
                    Text(model.tr("Valores que el nodo no acepta: ") + setup.problems.joined(separator: "; ")).font(.caption).foregroundColor(Theme.danger)
                }
                ForEach(formProblems, id: \.self) { Text($0).font(.caption).foregroundColor(Theme.danger) }
                Button(model.tr("Guardar en el nodo")) { setup.apply(form) }.disabled(setup.busy || !formProblems.isEmpty)
                if setup.saved { Button(model.tr("Reiniciar el nodo y comprobar la conexión")) { setup.reboot() }.disabled(setup.busy) }
            }.listRowBackground(Theme.surface)
        }
    }
}

private struct VerifyStep: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var setup: NodeSetupModel
    let onDone: () -> Void

    var body: some View {
        if setup.checking {
            Section {
                ProgressView()
                Text(model.tr("Esto tarda hasta un par de minutos: el nodo se reinicia y se conecta.")).font(.footnote).foregroundColor(Theme.muted)
            }.listRowBackground(Theme.surface)
        }
        switch setup.outcome {
        case .online(let ip, let ssid)?:
            Section {
                Text(model.tr("El nodo está en la red")).font(.headline).foregroundColor(Theme.ok)
                Text(model.trf("Dirección: %s", ip))
                if !ssid.isEmpty { Text("Wi-Fi: \(ssid)") }
                Text(model.trf("Ya puedes abrir su panel en http://%s/ o añadirlo en Studio.", ip)).font(.caption).foregroundColor(Theme.muted)
            }.listRowBackground(Theme.surface)
        case .failed(let reason)?:
            Section {
                Text(model.tr("El nodo no se ha conectado")).font(.headline).foregroundColor(Theme.danger)
                Text(reason)
                Text(model.tr("Sigue con el Bluetooth encendido mientras no tenga red: puedes corregir el Wi-Fi y probar otra vez.")).font(.caption).foregroundColor(Theme.muted)
            }.listRowBackground(Theme.surface)
        default: EmptyView()
        }
        if !setup.checking {
            Section {
                Button(model.tr("Volver a comprobar")) { setup.check() }.disabled(setup.busy)
                if case .failed? = setup.outcome, let target = setup.target { Button(model.tr("Cambiar la configuración")) { setup.connect(target) }.disabled(setup.busy) }
                Button(model.tr("Terminar"), action: onDone)
            }.listRowBackground(Theme.surface)
        }
    }
}

// MARK: the pairing code

/// The pairing code of a node: shown as a QR code (the name of the node and the address of the server, no secret) or read with the camera, which marks the node in the list.
private struct PairingSection: View {
    @EnvironmentObject var model: AppModel
    @Binding var paired: Pairing?
    @State private var open = false
    @State private var nodeId = ""
    @State private var message = ""
    @State private var scanning = false

    var body: some View {
        let origin = model.activeOrigin ?? ""
        let text = PairingCode.build(nodeId: nodeId.trimmingCharacters(in: .whitespaces), server: origin)
        Section(header: Text(model.tr("Código de emparejamiento"))) {
            Button(open ? model.tr("Ocultar el código") : model.tr("Mostrar el código")) { open.toggle() }
            Button(model.tr("Escanear el código")) { message = ""; scanning = true }
                .sheet(isPresented: $scanning) { scanner(origin: origin) }
            if !message.isEmpty { Text(message).font(.footnote).foregroundColor(Theme.muted) }
            if open {
                TextField(model.tr("Nombre del nodo (para el código)"), text: $nodeId).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: nodeId) { nodeId = $0.lowercased() }
                if let text, let picture = PairingQr.image(text) {
                    Image(uiImage: picture).interpolation(.none).resizable().scaledToFit().padding(12).background(Color.white).frame(maxWidth: .infinity)
                        .accessibilityLabel(model.tr("Código QR de emparejamiento del nodo"))
                    Text(model.tr("El código lleva solo el nombre del nodo y la dirección del servidor, sin contraseña.")).font(.caption).foregroundColor(Theme.muted)
                } else {
                    Text(origin.isEmpty ? model.tr("Configura el servidor en Ajustes para mostrar el código.") : model.tr("El nombre del nodo o la dirección del servidor no es válida.")).font(.caption).foregroundColor(Theme.muted)
                }
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func scanner(origin: String) -> some View {
        NavigationStack {
            QRScannerView(onCode: { code in
                scanning = false
                if let read = PairingCode.parse(code) {
                    paired = read; nodeId = read.nodeId
                    message = model.trf("Código leído: nodo %s en %s.", read.nodeId, read.server) + (PairingMatch.otherServer(read, origin: origin) ? " " + model.tr("El servidor del código no es el de esta app.") : "")
                } else { message = model.tr("Ese código no es un código de emparejamiento de A.R.M.O.R.") }
            }, onFail: { scanning = false; message = model.tr("No se pudo abrir el lector de códigos en este teléfono.") })
            .ignoresSafeArea()
            .navigationTitle(model.tr("Escanear el código")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(model.tr("Cancelar")) { scanning = false } } }
        }
    }
}

enum PairingQr {
    /// The QR code of a text as a picture (black on white, scaled up without blurring), or nil when it cannot be drawn.
    static func image(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Reads a QR code with the camera. Asks for the camera permission the first time; `onFail` when it is refused or the phone has no camera.
struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onFail: () -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onCode = onCode
        controller.onFail = onFail
        return controller
    }

    func updateUIViewController(_ controller: QRScannerController, context: Context) {}
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onFail: (() -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: prepare()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in DispatchQueue.main.async { if granted { self.prepare() } else { self.onFail?() } } }
        default: onFail?()
        }
    }

    private func prepare() {
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { onFail?(); return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { onFail?(); return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer
        let running = session
        DispatchQueue.global(qos: .userInitiated).async { running.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let running = session
        DispatchQueue.global(qos: .userInitiated).async { if running.isRunning { running.stopRunning() } }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !finished, let code = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first?.stringValue else { return }
        finished = true
        onCode?(code)
    }
}
