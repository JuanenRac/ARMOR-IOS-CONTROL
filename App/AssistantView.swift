// ARMOR-IOS-CONTROL - the assistant: written commands (a closed list the voice service of the server understands, in eight languages), with a confirmation bound to the person for arming and disarming.
// Dictation is the keyboard's own microphone key: the app never records audio itself.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct AssistantView: View {
    @EnvironmentObject var model: AppModel
    @State private var text = ""
    @State private var lines: [(mine: Bool, text: String)] = []
    @State private var pending: (phrase: String, token: String)?
    @State private var working = false

    var body: some View {
        NavigationStack {
            VStack {
                if !model.voiceAvailable {
                    Text(model.tr("Este sistema no tiene instalado el asistente de voz.")).foregroundColor(Theme.muted).padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if lines.isEmpty {
                                Text(model.tr("Escribe o di una orden: armar o desarmar el sistema (te pido confirmar), el estado, las alarmas, los nodos, las luces o silenciar la alarma.")).foregroundColor(Theme.muted)
                            }
                            ForEach(lines.indices, id: \.self) { index in
                                HStack {
                                    if lines[index].mine { Spacer() }
                                    Text(lines[index].text).padding(10)
                                        .background(lines[index].mine ? Theme.accent.opacity(0.25) : Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                                    if !lines[index].mine { Spacer() }
                                }
                            }
                            if let pending {
                                HStack {
                                    Button(model.tr("Confirmar")) { Task { await confirm(pending) } }.buttonStyle(.borderedProminent).tint(Theme.accent)
                                    Button(model.tr("Cancelar")) { self.pending = nil }.buttonStyle(.bordered)
                                }
                            }
                        }.padding()
                    }
                    HStack {
                        TextField(model.tr("Escribe o di órdenes: armar, desarmar, el estado o silenciar la alarma"), text: $text).textFieldStyle(.roundedBorder).submitLabel(.send)
                            .onSubmit { Task { await send() } }
                        Button { Task { await send() } } label: { Image(systemName: "paperplane.fill") }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || working)
                    }.padding()
                }
            }
            .background(Theme.background)
            .navigationTitle(model.tr("Asistente"))
        }
    }

    private func send() async {
        let phrase = text.trimmingCharacters(in: .whitespaces)
        guard !phrase.isEmpty else { return }
        text = ""; lines.append((true, phrase)); pending = nil; working = true; defer { working = false }
        await ask(phrase, token: nil)
    }

    private func confirm(_ item: (phrase: String, token: String)) async {
        pending = nil; working = true; defer { working = false }
        await ask(item.phrase, token: item.token)
    }

    private func ask(_ phrase: String, token: String?) async {
        do {
            let reply = try await model.controller.ask(phrase, confirmation: token)
            lines.append((false, reply.line(model.translator)))
            if reply.outcome == "confirmation-needed", let next = reply.confirmationToken { pending = (phrase, next) }
            if reply.executed { await model.refresh() }
        } catch ControllerError.lockRefused {
            lines.append((false, model.tr("No se ha confirmado con el bloqueo del teléfono: no se ha hecho nada.")))
        } catch let error as ArmorApiError {
            lines.append((false, error.detail.isEmpty ? model.describe(error) : error.detail))
        } catch { lines.append((false, error.localizedDescription)) }
    }
}
