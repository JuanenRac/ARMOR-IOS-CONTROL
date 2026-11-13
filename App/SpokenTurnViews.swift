// ARMOR-IOS-CONTROL - the spoken turn on the iPhone: its state, the settings where the person turns it on, and the card that shows the number of the challenge mode.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
//
// Off by default. The rules are in ArmorCore/SpokenTurn.swift (the same as the Android app's); this file only draws them and owns the microphone while a turn lasts.
import SwiftUI
import ArmorCore

/// A flag that the recording loop reads from another thread.
final class StopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    var value: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func set(_ on: Bool) { lock.lock(); stopped = on; lock.unlock() }
}

@MainActor
final class SpokenTurnModel: ObservableObject {
    let settings: SpokenTurnSettings
    let tokens: VoiceTokenVault
    let audit: StoreTurnAudit
    private let recorder = TurnMicrophone()
    private let stopFlag = StopFlag()

    @Published var enabled: Bool
    @Published var hasToken: Bool
    @Published var listening = false
    @Published var sending = false
    @Published var challenge: ShownChallenge?
    @Published var notice: String?

    init(prefs: KeyValueStore) {
        let settings = SpokenTurnSettings(prefs)
        let tokens = VoiceTokenVault(secrets: KeychainSecrets())
        self.settings = settings
        self.tokens = tokens
        self.audit = StoreTurnAudit(prefs)
        self.enabled = settings.enabled
        self.hasToken = tokens.has
    }

    var active: Bool { listening || sending }

    func setEnabled(_ on: Bool) {
        settings.enabled = on
        enabled = on
        audit.record(on ? "switch_on" : "switch_off")
        if !on { clearChallenge() }
    }

    func saveToken(_ text: String) -> Bool {
        let saved = tokens.save(text)
        hasToken = tokens.has
        if saved { audit.record("token_saved") }
        return saved
    }

    func clearToken() {
        tokens.clear()
        hasToken = false
        audit.record("token_cleared")
    }

    func clearChallenge() { if challenge != nil { challenge = nil } }

    /// The person tapped the button again: the recording ends and the sound is sent.
    func stopListening() {
        stopFlag.set(true)
        if listening { listening = false; sending = true }
    }

    /// One spoken turn. Returns what was heard and answered when the server answered; the number of the challenge, if any, is in `challenge` until it expires.
    func run(origin: String, api: ArmorApi, language: String, translator: Translator) async -> (heard: String, reply: String)? {
        guard !active else { return nil }
        stopFlag.set(false)
        challenge = nil
        notice = nil
        listening = true
        let controller = SpokenTurnController(
            settings: settings, tokens: tokens, recorder: recorder,
            send: { origin, pcm, language, token in try await api.voiceTurn(origin, pcm: pcm, language: language, voiceToken: token) }, audit: audit,
            sendWithSession: { origin, pcm, language in try await api.mobileVoiceTurn(origin, pcm: pcm, language: language) })
        let flag = stopFlag
        let outcome = await controller.run(origin: origin, language: language) { flag.value }
        listening = false
        sending = false
        if case .answered(let heard, let reply, let shown) = outcome {
            challenge = shown
            return (heard, reply)
        }
        notice = SpokenTurnText.notice(outcome, translator)
        return nil
    }
}

/// The number of the challenge mode: big, for the few seconds the wall panel shows it too; then it is gone.
struct ChallengeCard: View {
    @EnvironmentObject var model: AppModel
    let challenge: ShownChallenge
    let onGone: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let left = challenge.remaining(context.date)
            if left > 0 {
                VStack(spacing: 4) {
                    Text(model.tr("Di este número en tu próxima orden")).font(.footnote).foregroundColor(Theme.muted)
                    Text(challenge.number).font(.system(size: 48, weight: .bold, design: .monospaced)).foregroundColor(Theme.accent)
                    Text(model.trf("Se oculta en %s s", String(Int(left.rounded(.up))))).font(.footnote).foregroundColor(Theme.muted)
                }
                .frame(maxWidth: .infinity).padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            } else {
                Color.clear.frame(height: 0).onAppear { onGone() }
            }
        }
    }
}

/// The switch of the spoken turn and the voice token. Off until the person turns it on; turning it off, or forgetting the token, takes effect at once.
struct SpokenTurnSettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var spoken: SpokenTurnModel
    @State private var draft = ""
    @State private var problem = false

    var body: some View {
        Form {
            Section(footer: Text(model.tr("Apagada por defecto. Encendida, el botón de hablar del Asistente graba tu voz (hasta diez segundos), la envía al servidor con la clave de voz y la descarta: el móvil no la guarda. Es lo único de la app que usa el micrófono, y solo cuando tocas el botón. Si el servidor pide un número para silenciar la alarma, lo verás en pantalla unos segundos."))) {
                Toggle(model.tr("Permitir la orden hablada"), isOn: Binding(get: { spoken.enabled }, set: { spoken.setEnabled($0) }))
            }
            if spoken.enabled {
                Section(footer: Text(spoken.hasToken ? model.tr("La clave de voz está guardada, cifrada en este móvil.") : model.tr("Escribe la clave de voz de la instalación (la del servicio de voz). Quien la tenga puede dar órdenes por voz: guárdala solo en móviles tuyos."))) {
                    SecureField(model.tr("Clave de voz"), text: $draft).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if problem { Text(model.tr("La clave no es válida: sin espacios, de 8 a 200 caracteres.")).font(.footnote).foregroundColor(Theme.muted) }
                    Button(model.tr("Guardar la clave")) {
                        if spoken.saveToken(draft) { draft = ""; problem = false } else { problem = true }
                    }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(model.tr("Olvidar la clave"), role: .destructive) { spoken.clearToken() }.disabled(!spoken.hasToken)
                }
            }
        }
        .navigationTitle(model.tr("Orden hablada al servidor"))
    }
}
