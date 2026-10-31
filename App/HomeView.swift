// ARMOR-IOS-CONTROL - the status: whether the system is armed, the nodes, what would be wrong if it were armed now, and the buttons to arm and disarm.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var preflight: Preflight?
    @State private var confirmArm = false
    @State private var askDisarm = false
    @State private var pin = ""
    // the arming modes of the server (Away, Home, Night), while the server has them on
    @State private var pickMode = false
    @State private var modeAfterCheck: String?
    @State private var unassignedMode: String?
    @State private var pinMode: String?
    @State private var modePin = ""
    @State private var modeProblem: String?
    @State private var modeConfirmed = false

    private var modes: ArmingModesView? { model.state.armingModes.flatMap { $0.enabled ? $0 : nil } }

    private var canChange: Bool { model.state.facts.canChange }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Card {
                        HStack {
                            Image(systemName: model.state.snapshot.armed ? "lock.shield.fill" : "lock.open.fill").font(.largeTitle)
                                .foregroundColor(model.state.snapshot.armed ? Theme.ok : Theme.amber)
                            VStack(alignment: .leading) {
                                Text(model.state.snapshot.armed ? model.tr("Sistema ARMADO") : model.tr("Sistema DESARMADO")).font(.title3.weight(.bold))
                                Text(model.isAway ? model.tr("Fuera de casa") : model.tr("En casa")).font(.caption).foregroundColor(Theme.muted)
                                if modes != nil, model.state.snapshot.armed, let mode = model.state.snapshot.armingMode, mode != "disarmed" {
                                    Text(model.trf("Modo: %s", ArmingText.name(mode, model.translator))).font(.caption.weight(.semibold))
                                }
                            }
                            Spacer()
                        }
                        if model.state.lastRefreshFailed { Text(model.tr("Servidor sin respuesta")).font(.caption).foregroundColor(Theme.amber) }
                        if model.state.snapshot.armed {
                            if modes != nil {
                                Button(model.tr("Modo de armado")) { pickMode = true }.buttonStyle(PrimaryButtonStyle(color: Theme.ok)).disabled(!canChange || model.busy)
                            }
                            Button(model.tr("Desarmar")) { pin = ""; askDisarm = true }.buttonStyle(PrimaryButtonStyle(color: Theme.amber)).disabled(!canChange || model.busy)
                        } else if modes != nil {
                            Button(model.tr("Armar")) { pickMode = true }.buttonStyle(PrimaryButtonStyle(color: Theme.ok)).disabled(!canChange || model.busy)
                        } else {
                            Button(model.tr("Armar")) { Task { await prepareArm() } }.buttonStyle(PrimaryButtonStyle(color: Theme.ok)).disabled(!canChange || model.busy)
                        }
                        if !canChange { Text(model.tr("Tu usuario solo puede mirar: no puede cambiar nada.")).font(.caption).foregroundColor(Theme.muted) }
                    }

                    if model.state.unseenAlarms > 0 {
                        Card { Label(model.trf("%d alarmas sin confirmar", model.state.unseenAlarms), systemImage: "exclamationmark.triangle.fill").foregroundColor(Theme.danger) }
                    }

                    Card {
                        Text(model.tr("Estado de los nodos")).font(.headline)
                        ForEach(model.state.snapshot.nodes) { node in
                            HStack {
                                Circle().fill(color(node)).frame(width: 10, height: 10)
                                Text(node.id)
                                Spacer()
                                Text(node.alertLevel == "high" ? model.tr("ALTA") : node.alertLevel).font(.caption).foregroundColor(node.alertLevel == "high" ? Theme.danger : Theme.muted)
                                if node.targetCount > 0 { Pill(text: "\(node.targetCount)", color: Theme.amber) }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("A.R.M.O.R.")
            .refreshable { await model.refresh() }
            .confirmationDialog(model.tr("¿Armar el sistema?"), isPresented: $confirmArm, titleVisibility: .visible) {
                Button(model.tr("Armar igualmente"), role: .destructive) { Task { if let mode = modeAfterCheck { modeAfterCheck = nil; await chooseMode(mode, checked: true) } else { await arm() } } }
                Button(model.tr("Cancelar"), role: .cancel) {}
            } message: {
                Text((preflight?.issues ?? []).map { Preflight.describe($0, model.translator) }.joined(separator: "\n"))
            }
            .confirmationDialog(model.tr("Modo de armado"), isPresented: $pickMode, titleVisibility: .visible) {
                if let modes {
                    ForEach(modes.armable.filter { $0 != modes.current }, id: \.self) { mode in
                        Button("\(model.state.snapshot.armed ? model.trf("Cambiar a %s", ArmingText.name(mode, model.translator)) : model.trf("Armar: %s", ArmingText.name(mode, model.translator))) · \(ArmingText.defends(modes, mode, model.translator))") { Task { await chooseMode(mode) } }
                    }
                }
                Button(model.tr("Cancelar"), role: .cancel) {}
            } message: {
                Text(model.trf("Ahora: %s", ArmingText.name(modes?.current ?? "disarmed", model.translator)))
            }
            .confirmationDialog(model.trf("Nada asignado a %s", ArmingText.name(unassignedMode ?? "home", model.translator)), isPresented: Binding(get: { unassignedMode != nil }, set: { if !$0 { unassignedMode = nil } }), titleVisibility: .visible) {
                Button(model.tr("Armar igualmente"), role: .destructive) { if let mode = unassignedMode { unassignedMode = nil; modeConfirmed = true; Task { await chooseMode(mode, checked: true, confirm: true) } } }
                Button(model.tr("Cancelar"), role: .cancel) { unassignedMode = nil }
            } message: {
                Text(model.trf("%s no tiene zonas ni sensores: armarlo no defendería nada. Asígnalos en Studio o arma igualmente.", ArmingText.name(unassignedMode ?? "home", model.translator)))
            }
            .alert(model.tr("Hace falta el PIN"), isPresented: Binding(get: { pinMode != nil }, set: { if !$0 { pinMode = nil } })) {
                SecureField(model.tr("PIN (si tienes uno)"), text: $modePin).keyboardType(.numberPad)
                Button(model.trf("Armar: %s", ArmingText.name(pinMode ?? "home", model.translator))) { if let mode = pinMode { pinMode = nil; Task { await chooseMode(mode, checked: true, confirm: modeConfirmed, typedPin: modePin) } } }
                Button(model.tr("Cancelar"), role: .cancel) { pinMode = nil; modePin = "" }
            } message: {
                Text(modeProblem.map { ArmingText.refusal($0, model.translator) } ?? model.trf("%s defiende menos que el modo actual: pide tu PIN, como desarmar.", ArmingText.name(pinMode ?? "home", model.translator)))
            }
            .alert(model.tr("¿Desarmar el sistema?"), isPresented: $askDisarm) {
                SecureField(model.tr("PIN (si tienes uno)"), text: $pin).keyboardType(.numberPad)
                Button(model.tr("Sí, desarmar"), role: .destructive) { Task { await disarm() } }
                Button(model.tr("Cancelar"), role: .cancel) {}
            }
        }
    }

    private func color(_ node: FieldNode) -> Color { !node.online ? Theme.danger : (node.stale ? Theme.amber : Theme.ok) }

    /// Asks the server what would leave the perimeter blind or noisy; arms at once when nothing is wrong, asks first when something is.
    private func prepareArm() async {
        let found = try? await model.controller.preflight()
        preflight = found
        if let found, !found.issues.isEmpty { confirmArm = true } else { await arm() }
    }

    /// Arms in a mode of the server. Arming from disarmed goes through the same check as a plain arm; the server decides whether the mode needs the confirmation (nothing assigned) or the PIN
    /// (it defends less than the one in force) and the picker then asks, never guessing it.
    private func chooseMode(_ mode: String, checked: Bool = false, confirm: Bool = false, typedPin: String? = nil) async {
        if !checked && !model.state.snapshot.armed {
            let found = try? await model.controller.preflight()
            if let found, !found.issues.isEmpty { preflight = found; modeAfterCheck = mode; confirmArm = true; return }
        }
        let typed = (typedPin ?? "").isEmpty ? nil : typedPin
        modePin = ""
        let refusal = await model.armInMode(mode, pin: typed, confirmUnassigned: confirm)
        modeConfirmed = confirm
        switch refusal {
        case "no_zones_assigned": unassignedMode = mode
        case "wrong_pin", "pin_locked", "pin_not_set": modeProblem = typed == nil && refusal == "wrong_pin" ? nil : refusal; pinMode = mode
        default: modeProblem = nil
        }
    }

    private func arm() async {
        await model.order(model.tr("Armar el sistema")) { asker in try await model.controller.arm(asker: asker) }
    }

    private func disarm() async {
        let typed = pin.isEmpty ? nil : pin
        pin = ""
        await model.order(model.tr("Desarmar el sistema")) { asker in try await model.controller.disarm(pin: typed, asker: asker) }
    }
}
