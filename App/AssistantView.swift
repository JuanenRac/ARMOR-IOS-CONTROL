// ARMOR-IOS-CONTROL - the assistant: written commands (a closed list the voice service of the server understands, in eight languages), with a confirmation bound to the person for arming and disarming.
// Dictation is the keyboard's own microphone key. The app records audio itself only through the second button, the spoken turn, which exists once the person turned it on in More
// (SpokenTurnViews.swift); it sends the sound to the server and shows the number of the challenge mode when the server asks for one.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct AssistantView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var spoken: SpokenTurnModel
    @State private var text = ""
    @State private var lines: [(mine: Bool, text: String)] = []
    @State private var pending: (phrase: String, token: String)?
    @State private var working = false
    @State private var speak = true

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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(AssistantSuggestions.phrases(model.translator), id: \.self) { phrase in
                                Button(phrase) { Task { await send(phrase) } }.buttonStyle(.bordered).font(.footnote).disabled(working)
                            }
                        }.padding(.horizontal)
                    }
                    if let shown = spoken.challenge { ChallengeCard(challenge: shown) { spoken.clearChallenge() }.padding(.horizontal) }
                    if let notice = spoken.notice { Text(notice).font(.footnote).foregroundColor(Theme.muted).padding(.horizontal) }
                    if spoken.listening { Text(model.tr("Te escucho: toca el botón otra vez cuando acabes.")).font(.footnote).foregroundColor(Theme.accent).padding(.horizontal) }
                    if spoken.sending { Text(model.tr("Enviando tu voz al servidor…")).font(.footnote).foregroundColor(Theme.muted).padding(.horizontal) }
                    HStack {
                        TextField(model.tr("Escribe o di órdenes: armar, desarmar, el estado o silenciar la alarma"), text: $text).textFieldStyle(.roundedBorder).submitLabel(.send)
                            .onSubmit { Task { await send() } }
                        if spoken.enabled {
                            Button { Task { await tapSpoken() } } label: { Image(systemName: spoken.listening ? "stop.circle.fill" : "waveform") }
                                .accessibilityLabel(spoken.listening ? model.tr("Terminar de hablar") : model.tr("Hablar al servidor")).disabled(working || spoken.sending)
                        }
                        Button { Task { await send() } } label: { Image(systemName: "paperplane.fill") }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || working)
                    }.padding()
                }
            }
            .background(Theme.background)
            .navigationTitle(model.tr("Asistente"))
            .onDisappear { spoken.clearChallenge() }   // the number does not outlive the screen
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { speak.toggle(); if !speak { AlarmSpeaker.shared.stop() } } label: { Image(systemName: speak ? "speaker.wave.2.fill" : "speaker.slash.fill") }
                        .accessibilityLabel(speak ? model.tr("Silenciar la voz del móvil") : model.tr("Activar la voz del móvil"))
                    Button { lines = []; pending = nil } label: { Image(systemName: "trash") }
                        .accessibilityLabel(model.tr("Borrar la conversación")).disabled(lines.isEmpty)
                }
            }
        }
    }

    /// Sends what was typed, or a phrase of the chips.
    private func send(_ chosen: String? = nil) async {
        let phrase = (chosen ?? text).trimmingCharacters(in: .whitespaces)
        guard !phrase.isEmpty else { return }
        if chosen == nil { text = "" }
        lines.append((true, phrase)); pending = nil; working = true; defer { working = false }
        await ask(phrase, token: nil)
    }

    /// The spoken turn: a first tap listens, the next one sends. A person who can only look (a viewer) cannot start one.
    private func tapSpoken() async {
        if spoken.listening { spoken.stopListening(); return }
        guard let origin = model.activeOrigin, model.state.facts.canChange else {
            spoken.notice = model.tr("Tu usuario solo puede mirar: no puede cambiar nada.")
            return
        }
        guard let heard = await spoken.run(origin: origin, api: model.controller.api, language: model.translator.language, translator: model.translator) else { return }
        lines.append((true, heard.heard.isEmpty ? "…" : heard.heard))
        lines.append((false, heard.reply))
        // The number is shown, never said: if the reply carried it, the phone does not read it aloud.
        if speak, spoken.challenge.map({ !heard.reply.contains($0.number) }) ?? true { AlarmSpeaker.shared.say(heard.reply, voice: model.voice, language: model.translator.language) }
    }

    private func confirm(_ item: (phrase: String, token: String)) async {
        pending = nil; working = true; defer { working = false }
        await ask(item.phrase, token: item.token)
    }

    private func ask(_ phrase: String, token: String?) async {
        do {
            let reply = try await model.controller.ask(phrase, confirmation: token)
            let said = reply.line(model.translator)
            lines.append((false, said))
            if speak { AlarmSpeaker.shared.say(said, voice: model.voice, language: model.translator.language) }
            if reply.outcome == "confirmation-needed", let next = reply.confirmationToken { pending = (phrase, next) }
            if reply.executed { await model.refresh() }
        } catch ControllerError.lockRefused {
            lines.append((false, model.tr("No se ha confirmado con el bloqueo del teléfono: no se ha hecho nada.")))
        } catch let error as ArmorApiError {
            lines.append((false, error.detail.isEmpty ? model.describe(error) : error.detail))
        } catch { lines.append((false, error.localizedDescription)) }
    }
}
