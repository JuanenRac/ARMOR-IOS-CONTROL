// ARMOR-IOS-CONTROL - Update the programs of the machine that runs the server, for administrators: choose a program, see what is installed against the newest release (nothing changes), and
// apply the update with the program's name typed again, a new proof of identity (the same sheet as for the other critical actions), the one-time code and the lock of the phone. Only a signed
// release is put in place; the switch is off at the server and on the maintenance helper until the owner turns it on, and then this screen offers nothing. The same screen as the Android app.
// Written without a Mac: not built or seen on a device yet.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

/// Carries the answer out of the closure an order runs in.
private final class Answer<Value>: @unchecked Sendable { var value: Value? }

@MainActor
final class MachineUpdateScreenState: ObservableObject {
    @Published var state: MachineUpdateState?
    @Published var preview: MachineUpdatePreview?
    @Published var previewAt = Date()
    @Published var job: MachineJobView?
    @Published var jobLog: [String] = []
    @Published var busy = false
    @Published var message: String?

    /// The switch and the programs; a failure leaves the screen with its message.
    func load(model: AppModel) async {
        let answer = Answer<MachineUpdateState>()
        let api = model.controller.api
        await run(model: model, reason: model.tr("Actualizar el equipo"), locked: false) { origin in answer.value = try await api.machineUpdateState(origin) }
        if let value = answer.value { state = value }
    }

    /// Step one: the versions of `project` and, when it is outdated, the plan (good once, for a few minutes). Nothing changes on the machine.
    func check(model: AppModel, project: String) async {
        let answer = Answer<MachineUpdatePreview>()
        let api = model.controller.api
        await run(model: model, reason: model.tr("Actualizar el equipo"), locked: false) { origin in answer.value = try await api.machineUpdatePreview(origin, project: project) }
        if let value = answer.value { preview = value; previewAt = Date(); job = nil; jobLog = [] }
    }

    /// Step two: the plan of the preview, the name typed again and the one-time code. The phone lock is asked first, as for the other critical actions; the code is never kept.
    func apply(model: AppModel, project: String, planId: String, confirm: String, code: String) async {
        let answer = Answer<String>()
        let api = model.controller.api
        await run(model: model, reason: model.trf("Actualizar %s", project), locked: true) { origin in
            answer.value = try await api.machineUpdateApply(origin, project: project, planId: planId, confirm: confirm, code: code.isEmpty ? nil : code)
        }
        if let id = answer.value { preview = nil; job = MachineJobView(id: id, state: "running", percent: 0, steps: [], error: "", log: [], logTotal: 0); jobLog = [] }
    }

    /// The job under way, while the screen is open. A failure is ignored; the next pass tries again.
    func poll(model: AppModel) async {
        guard let origin = model.activeOrigin, let current = job, !current.id.isEmpty, current.running else { return }
        if let value = try? await model.controller.api.machineUpdateJob(origin, id: current.id, since: jobLog.count) {
            jobLog = MachineUpdateParser.mergeLog(jobLog, since: jobLog.count, fresh: value.log)
            job = value
        }
    }

    /// Asks again until the screen goes away: the job under way, every few seconds.
    func watch(model: AppModel) async {
        await load(model: model)
        let seconds = ScreenPolling.bundled().batterySeconds
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if Task.isCancelled { break }
            await poll(model: model)
        }
    }

    /// Leaves the finished job and the preview to start again.
    func close() { preview = nil; job = nil; jobLog = []; message = nil }

    /// One call to the server. A read goes straight; if the server asks for a new proof of identity (or the call is a change, `locked`) it goes behind the lock of the phone and the sheet of the
    /// proof, like the other critical actions. A refusal of the server is told in the words of this screen.
    private func run(model: AppModel, reason: String, locked: Bool, _ call: @escaping @Sendable (String) async throws -> Void) async {
        busy = true; message = nil
        defer { busy = false }
        let translator = model.translator
        if !locked, let origin = model.activeOrigin {
            do { try await call(origin); return }
            catch let error as ArmorApiError where error.isElevationRequired { /* asked below */ }
            catch { message = MachineUpdateText.errorText(error, translator); return }
        }
        await model.order { asker in
            do {
                try await model.controller.guarded(reason: reason, needs: CapabilityAction.administer, asker: asker) { origin in try await call(origin) }
            } catch let error as ArmorApiError {
                // a refusal of the server is told here; the lock and the proof of identity are told by `order`
                self.message = MachineUpdateText.errorText(error, translator)
            }
        }
    }
}

struct MachineUpdateView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var update = MachineUpdateScreenState()
    @State private var project = ""
    @State private var typed = ""
    @State private var code = ""
    @State private var now = Date()

    private var isAdmin: Bool { model.state.facts.isAdmin }

    var body: some View {
        let t = model.translator
        List {
            Section {
                Text(model.tr("Actualiza desde el móvil los programas del equipo donde corre el servidor. Primero se ve qué hay instalado y qué hay publicado, sin cambiar nada; después se confirma escribiendo el nombre del programa. Solo se instala una versión firmada."))
                    .font(.footnote).foregroundColor(Theme.muted)
                if !isAdmin { Text(model.tr("Solo un administrador puede usar esta pantalla.")).foregroundColor(Theme.danger) }
                if let message = update.message { Text(message).font(.footnote).foregroundColor(Theme.danger) }
            }.listRowBackground(Theme.surface)
            if isAdmin {
                if let job = update.job { jobSection(job) }
                else if let state = update.state {
                    if !state.enabled {
                        Section { Text(MachineUpdateText.reason(state.reason, t)).font(.footnote).foregroundColor(Theme.amber) }.listRowBackground(Theme.surface)
                    } else {
                        Section(header: Text(model.tr("Programa"))) {
                            if state.projects.isEmpty { Text(model.tr("El ayudante no ofrece ningún programa.")).foregroundColor(Theme.muted) }
                            ForEach(state.projects.sorted(), id: \.self) { name in
                                choice(project == name, name) { project = name; typed = ""; code = "" }
                            }
                            Button(model.tr("Comprobar versiones")) { Task { await update.check(model: model, project: project) } }
                                .disabled(update.busy || !MachineUpdateParser.isProject(project))
                        }.listRowBackground(Theme.surface)
                        if let preview = update.preview { previewSection(preview) }
                    }
                } else {
                    Section { Text(update.busy ? model.tr("Cargando…") : model.tr("No se pudo consultar el estado de la actualización.")).font(.footnote).foregroundColor(Theme.muted) }
                        .listRowBackground(Theme.surface)
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Actualizar el equipo"))
        .task { await update.watch(model: model) }
        .task(id: update.preview?.planId) {
            while update.preview?.planId.isEmpty == false && !Task.isCancelled { now = Date(); try? await Task.sleep(nanoseconds: 1_000_000_000) }
        }
        .refreshable { await update.load(model: model) }
    }

    private func previewSection(_ preview: MachineUpdatePreview) -> some View {
        let left = MachineUpdateParser.secondsLeft(expiresInS: preview.expiresInS, elapsedMs: Int(now.timeIntervalSince(update.previewAt) * 1000))
        let from = preview.localVersion.isEmpty ? "-" : preview.localVersion
        let to = preview.githubVersion.isEmpty ? "-" : preview.githubVersion
        return Section {
            Text(preview.project).font(.headline)
            Text(model.trf("Instalada: %s · Publicada: %s", from, to)).font(.footnote)
            if !preview.updateAvailable || preview.planId.isEmpty {
                Text(model.tr("Ya está al día.")).foregroundColor(Theme.ok)
            } else {
                Text(model.trf("Hay una versión nueva: %s → %s", from, to)).font(.subheadline.weight(.semibold)).foregroundColor(Theme.accent)
                Text(left > 0 ? model.trf("El plan vale una sola vez y caduca en %s s.", left) : model.tr("El plan ha caducado. Comprueba las versiones otra vez."))
                    .font(.caption).foregroundColor(left > 0 ? Theme.muted : Theme.amber)
                TextField(model.tr("Escribe el nombre del programa para confirmar"), text: $typed)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable).onChange(of: typed) { value in typed = String(value.prefix(64)) }
                TextField(model.tr("Código de un solo uso (si tu cuenta tiene segundo factor)"), text: $code)
                    .keyboardType(.numberPad).onChange(of: code) { value in code = String(value.filter(\.isNumber).prefix(6)) }
                Text(model.tr("Desde fuera de casa se pedirá la contraseña otra vez. Si la versión no está firmada, no se toca nada.")).font(.caption).foregroundColor(Theme.muted)
                Button(model.tr("Actualizar ahora")) {
                    let (name, plan, confirm, otp) = (preview.project, preview.planId, typed, code)
                    typed = ""; code = ""
                    Task { await update.apply(model: model, project: name, planId: plan, confirm: confirm, code: otp) }
                }.disabled(update.busy || left <= 0 || !MachineUpdateParser.confirmationOk(project: preview.project, typed: typed) || !MachineUpdateParser.codeOk(code))
            }
        }.listRowBackground(Theme.surface)
    }

    private func jobSection(_ job: MachineJobView) -> some View {
        let t = model.translator
        let color: Color = job.state == "done" ? Theme.ok : (job.failed ? Theme.danger : Theme.accent)
        return Section {
            Text(model.tr("Actualización en curso")).font(.headline)
            Text(job.state == "done" ? model.tr("Terminada") : (job.failed ? model.tr("Falló") : model.tr("En curso"))).font(.subheadline.weight(.semibold)).foregroundColor(color)
            if job.running { ProgressView(value: job.percent / 100.0) }
            ForEach(job.steps) { step in
                Text(MachineUpdateText.stepName(step.id, t) + " · " + MachineUpdateText.stepState(step.state, percent: step.percent, t)).font(.footnote)
            }
            if job.failed && !job.error.isEmpty { Text(String(job.error.prefix(300))).font(.caption).foregroundColor(Theme.danger) }
            if !update.jobLog.isEmpty {
                Text(model.tr("Registro")).font(.footnote.weight(.semibold))
                Text(update.jobLog.suffix(MachineUpdateParser.logLines).joined(separator: "\n")).font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.muted)
            }
            if !job.running { Button(model.tr("Nueva comprobación")) { update.close() } }
        }.listRowBackground(Theme.surface)
    }

    private func choice(_ selected: Bool, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(label).foregroundColor(.white).multilineTextAlignment(.leading); Spacer(); if selected { Image(systemName: "checkmark").foregroundColor(Theme.accent) } }
        }
    }
}
