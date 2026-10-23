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
                            }
                            Spacer()
                        }
                        if model.state.lastRefreshFailed { Text(model.tr("Servidor sin respuesta")).font(.caption).foregroundColor(Theme.amber) }
                        if model.state.snapshot.armed {
                            Button(model.tr("Desarmar")) { pin = ""; askDisarm = true }.buttonStyle(PrimaryButtonStyle(color: Theme.amber)).disabled(!canChange || model.busy)
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
                Button(model.tr("Armar igualmente"), role: .destructive) { Task { await arm() } }
                Button(model.tr("Cancelar"), role: .cancel) {}
            } message: {
                Text((preflight?.issues ?? []).map { Preflight.describe($0, model.translator) }.joined(separator: "\n"))
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

    private func arm() async {
        await model.order(model.tr("Armar el sistema")) { asker in try await model.controller.arm(asker: asker) }
    }

    private func disarm() async {
        let typed = pin.isEmpty ? nil : pin
        pin = ""
        await model.order(model.tr("Desarmar el sistema")) { asker in try await model.controller.disarm(pin: typed, asker: asker) }
    }
}
