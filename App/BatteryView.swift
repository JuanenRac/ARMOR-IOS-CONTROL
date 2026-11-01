// ARMOR-IOS-CONTROL - Battery maintenance: the simple operations on a Pylontech battery (clock, counters, restart, charge capacity, outputs...) through its gateway node, for administrators.
// Two steps with a pause between them: the server has the node read the battery and check everything, the screen shows exactly what will be done, and only then "Do it now" writes (with the
// serial number typed again). The limits, the protections, the firmware and the expert console are done in Studio.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

@MainActor
final class BatteryState: ObservableObject {
    @Published var overview: BatteryOverview?
    @Published var solar: SolarOverview?
    @Published var active: BatteryOperationView?
    @Published var busy = false
    @Published var message: String?

    func reload(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        if let value = try? await model.controller.api.batteryOperations(origin) { overview = value }
        if let value = try? await model.controller.api.solar(origin) { solar = value }
    }

    /// Asks again until the screen goes away: the operation under way, and the list.
    func watch(model: AppModel) async {
        await reload(model: model)
        let seconds = ScreenPolling.bundled().batterySeconds
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if Task.isCancelled { break }
            guard let origin = model.activeOrigin else { continue }
            if let current = active, current.active, let fresh = try? await model.controller.api.batteryOperation(origin, id: current.id) { active = fresh }
            if let value = try? await model.controller.api.batteryOperations(origin) { overview = value }
        }
    }

    func arm(model: AppModel, node: String, port: Int, op: String, output: String, state: String, serial: String) async {
        guard let origin = model.activeOrigin else { return }
        busy = true; message = nil
        defer { busy = false }
        do { active = try await model.controller.api.batteryArm(origin, node: node, port: port, op: op, output: output, state: state, serial: serial) }
        catch { message = BatteryText.errorText(error, model.translator) }
    }

    func execute(model: AppModel, serial: String) async {
        guard let origin = model.activeOrigin, let current = active else { return }
        busy = true; message = nil
        defer { busy = false }
        do { active = try await model.controller.api.batteryExecute(origin, id: current.id, serial: serial) }
        catch { message = BatteryText.errorText(error, model.translator) }
    }

    func cancel(model: AppModel) async {
        guard let origin = model.activeOrigin, let current = active else { return }
        busy = true; message = nil
        defer { busy = false }
        do { active = try await model.controller.api.batteryCancel(origin, id: current.id) }
        catch { message = BatteryText.errorText(error, model.translator) }
    }
}

struct BatteryView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var battery = BatteryState()
    @State private var node = ""
    @State private var port = "1"
    @State private var op = "set_clock"
    @State private var output = "cfet"
    @State private var onOff = "off"
    @State private var serial = ""

    private var nodes: [String] { BatteryParser.nodes(battery.solar) }
    private var isAdmin: Bool { model.state.facts.isAdmin }

    var body: some View {
        List {
            Section {
                Text(model.tr("Cambia lo que guarda una batería Pylontech por la consola del nodo pasarela. Algunos cambios no se pueden deshacer y el fabricante puede negar la garantía. Los límites, el firmware y la consola de experto se hacen en Studio."))
                    .font(.footnote).foregroundColor(Theme.muted)
                if !isAdmin { Text(model.tr("Solo un administrador puede usar esta pantalla.")).foregroundColor(Theme.danger) }
                else if let overview = battery.overview, !overview.enabled { Text(model.tr("La escritura en baterías está desactivada: en el servidor, o en el panel del propio nodo.")).foregroundColor(Theme.danger) }
                if let message = battery.message { Text(message).font(.footnote).foregroundColor(Theme.danger) }
            }.listRowBackground(Theme.surface)
            if isAdmin {
                if let active = battery.active { operationSection(active) } else { formSection }
                historySection
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Mantenimiento de baterías"))
        .task { await battery.watch(model: model) }
        .refreshable { await battery.reload(model: model) }
        .onChange(of: nodes) { list in if !list.contains(node) { node = list.first ?? "" } }
    }

    private var portNumber: Int? { Int(port).flatMap { (1...10).contains($0) ? $0 : nil } }

    @ViewBuilder private var formSection: some View {
        Section(header: Text(model.tr("Nodo pasarela"))) {
            if nodes.isEmpty { Text(model.tr("Ningún nodo pasarela con batería está informando.")).foregroundColor(Theme.muted) }
            ForEach(nodes, id: \.self) { item in choice(node == item, item) { node = item } }
            TextField(model.tr("Puerto del nodo (1 a 10)"), text: $port).keyboardType(.numberPad).onChange(of: port) { value in port = String(value.filter(\.isNumber).prefix(2)) }
        }.listRowBackground(Theme.surface)
        Section(header: Text(model.tr("Operación"))) {
            ForEach(BatteryParser.phoneOperations, id: \.self) { item in choice(op == item, BatteryText.operationName(item, model.translator)) { op = item } }
        }.listRowBackground(Theme.surface)
        if op == "output_set" {
            Section(header: Text(model.tr("Salida"))) {
                ForEach(BatteryParser.outputs, id: \.self) { item in choice(output == item, BatteryText.outputName(item, model.translator)) { output = item } }
                choice(onOff == "on", model.tr("encendida")) { onOff = "on" }
                choice(onOff == "off", model.tr("apagada")) { onOff = "off" }
            }.listRowBackground(Theme.surface)
        }
        Section {
            TextField(model.tr("Número de serie de la batería (o NOSERIAL)"), text: $serial).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                .onChange(of: serial) { value in serial = String(value.prefix(24)) }
            let typed = serial.trimmingCharacters(in: .whitespaces)
            let valid = !node.isEmpty && portNumber != nil && BatteryParser.serialLooksRight(typed)
            Button(model.tr("Preparar")) {
                if let number = portNumber { Task { await battery.arm(model: model, node: node, port: number, op: op, output: output, state: onOff, serial: typed) } }
            }.disabled(!valid || battery.busy || battery.overview?.enabled != true)
        }.listRowBackground(Theme.surface)
    }

    private func choice(_ selected: Bool, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(label).foregroundColor(.white); Spacer(); if selected { Image(systemName: "checkmark").foregroundColor(Theme.accent) } }
        }.accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private func operationSection(_ operation: BatteryOperationView) -> some View {
        let t = model.translator
        Section {
            Text(BatteryText.operationName(operation.op, t) + " · " + operation.node + "/" + String(operation.port)).font(.headline)
            Text(BatteryText.stageName(operation.stage, t)).font(.subheadline.weight(.semibold)).foregroundColor(Theme.accent)
            if !operation.summary.isEmpty { Text(operation.summary).font(.footnote) }
            if !operation.model.isEmpty {
                Text(model.trf("Batería: %s · serie %s · firmware %s", operation.model, operation.serial.isEmpty ? "-" : operation.serial, operation.softVersion)).font(.caption).foregroundColor(Theme.muted)
            }
            if !operation.risk.isEmpty {
                Text(model.trf("Riesgo: %s", BatteryText.riskName(operation.risk, t))).font(.footnote).foregroundColor(operation.risk == "high" || operation.risk == "irreversible" ? Theme.amber : Theme.muted)
            }
            if operation.atomic { Text(model.tr("Una vez que empieza no se puede detener: no apagues nada hasta que termine.")).font(.footnote).foregroundColor(Theme.amber) }
            switch operation.stage {
            case "arming":
                Text(model.tr("El nodo está leyendo la batería y comprobándolo todo…")).foregroundColor(Theme.muted)
            case "armed":
                Text(model.tr("Listo. Esto es lo que se hará:")).font(.subheadline.bold())
                Text(operation.canonical).font(.system(size: 13, design: .monospaced))
                TextField(model.tr("Número de serie de la batería (o NOSERIAL)"), text: $serial).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                HStack {
                    Button(model.tr("Hacerlo ahora")) { Task { await battery.execute(model: model, serial: serial.trimmingCharacters(in: .whitespaces)) } }
                        .buttonStyle(.borderedProminent).tint(Theme.accent).disabled(battery.busy || serial.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(model.tr("Retirar")) { Task { await battery.cancel(model: model) } }.buttonStyle(.bordered).disabled(battery.busy)
                }
            case "starting", "running":
                ProgressView(value: Double(operation.percent), total: 100).tint(Theme.accent)
                if operation.stepsTotal > 0 { Text(model.trf("Paso %s de %s", operation.stepsDone, operation.stepsTotal)).font(.caption).foregroundColor(Theme.muted) }
                if !operation.atomic { Button(model.tr("Detener")) { Task { await battery.cancel(model: model) } }.buttonStyle(.bordered).disabled(battery.busy) }
            case "rejected":
                if !operation.refusal.isEmpty { Text(BatteryText.refusalText(operation.refusal, t)).font(.footnote).foregroundColor(Theme.danger) }
            case "expired", "lost":
                Text(BatteryText.refusalText(operation.stage == "expired" ? "expired" : "no_answer", t)).font(.footnote).foregroundColor(Theme.danger)
            case "done":
                Text(BatteryText.resultText(operation, t)).font(.footnote).foregroundColor(operation.outcome == "ok" ? Theme.ok : Theme.danger)
                if !operation.code.isEmpty { Text(model.trf("Detalle: %s", operation.code)).font(.caption).foregroundColor(Theme.muted) }
                Text(model.tr("Qué cambió")).font(.subheadline.bold())
                if operation.diff.isEmpty { Text(model.tr("Sin diferencias leídas.")).foregroundColor(Theme.muted) }
                ForEach(Array(operation.diff.enumerated()), id: \.offset) { _, item in
                    Text(model.trf("%s: antes %s · después %s", item.label, item.before.isEmpty ? "-" : item.before, item.after.isEmpty ? "-" : item.after)).font(.system(size: 12, design: .monospaced))
                }
            default:
                EmptyView()
            }
            if !operation.active { Button(model.tr("Nueva operación")) { battery.active = nil; battery.message = nil } }
        }.listRowBackground(Theme.surface)
    }

    @ViewBuilder private var historySection: some View {
        let history = battery.overview?.operations ?? []
        Section(header: Text(model.tr("Operaciones"))) {
            if history.isEmpty { Text(model.tr("Todavía no se ha hecho ninguna operación en baterías.")).font(.footnote).foregroundColor(Theme.muted) }
            ForEach(history.prefix(10)) { item in
                Button { battery.active = item } label: {
                    Text(BatteryText.operationName(item.op, model.translator) + " · " + item.node + "/" + String(item.port) + " · " + BatteryText.stageName(item.stage, model.translator)).font(.footnote).foregroundColor(.white)
                }
            }
        }.listRowBackground(Theme.surface)
    }
}
