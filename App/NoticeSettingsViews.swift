// ARMOR-IOS-CONTROL - the settings of the notices: which ones the phone shows, the sound of each one, and the voice that says them.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ArmorCore

/// The title of a kind of notice (the same words in the filters and in the sounds).
func noticeKindTitle(_ kind: String, _ model: AppModel) -> String {
    switch kind {
    case "alert": return model.tr("Alertas del radar")
    case "camera": return model.tr("Cámaras sin respuesta")
    case "node": return model.tr("Nodos fuera de línea o en silencio")
    case "alarm.device": return model.tr("Alarmas de dispositivos")
    case "alarm.solar": return model.tr("Alarmas de la instalación solar")
    case "alarm.electrical": return model.tr("Alarmas eléctricas")
    case "alarm.network": return model.tr("Alarmas de red")
    case "alarm.alarm": return model.tr("Alarmas de las centrales")
    default: return model.tr("Otras alarmas")
    }
}

/// Which notices the phone shows and how: nothing at all, without sound, and which severities and kinds are wanted.
struct NoticeSettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let settings = model.notices
        Form {
            Section(footer: Text(model.tr("Todo queda siempre en el historial; aquí eliges de qué te avisa el móvil. Una alarma crítica (humo, gas, agua, pánico) avisa siempre, salvo que silencies todos los avisos."))) {
                row(model.tr("Silenciar todos los avisos"), note: model.tr("No aparece ninguna notificación."), on: settings.muted) { var next = settings; next.muted = $0; model.setNotices(next) }
                row(model.tr("Avisos sin sonido"), note: model.tr("Aparecen sin sonido ni vibración y el móvil no los dice en voz alta (las críticas siguen sonando)."), on: settings.silent, disabled: settings.muted) { var next = settings; next.silent = $0; model.setNotices(next) }
            }
            Section(header: Text(model.tr("Avisarme de") + " · " + model.tr("Por gravedad"))) {
                row(model.tr("Altas"), on: !settings.mutedSeverities.contains("high"), disabled: settings.muted) { model.setNotices(settings.withSeverity("high", off: !$0)) }
                row(model.tr("Avisos (gravedad baja)"), on: !settings.mutedSeverities.contains("warning"), disabled: settings.muted) { model.setNotices(settings.withSeverity("warning", off: !$0)) }
            }
            Section(header: Text(model.tr("Por tipo"))) {
                ForEach(NoticeKinds.choices, id: \.self) { kind in
                    row(noticeKindTitle(kind, model), on: !settings.mutedKinds.contains(kind), disabled: settings.muted) { model.setNotices(settings.withKind(kind, off: !$0)) }
                }
            }
        }
        .navigationTitle(model.tr("Qué avisos quiero"))
    }

    private func row(_ title: String, note: String? = nil, on: Bool, disabled: Bool = false, set: @escaping (Bool) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: Binding(get: { on }, set: set)).disabled(disabled)
            if let note { Text(note).font(.caption).foregroundColor(Theme.muted) }
        }
    }
}

/// The sound of each severity and of each kind of notice, with the button that plays it.
struct SoundSettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var picking: (key: String, isKind: Bool)?
    @State private var importing = false
    @State private var note: String?
    @State private var playing: String?

    var body: some View {
        Form {
            Section(footer: Text(model.tr("Elige el sonido de cada gravedad y, si quieres, el de cada tipo de aviso (el del tipo manda sobre el de la gravedad). Tiene que ser un archivo tuyo .aiff, .wav o .caf de menos de 3 MB y de menos de 30 segundos. Pulsa el botón de reproducir para oírlo."))) {
                if let note { Text(note).foregroundColor(Theme.amber) }
            }
            Section(header: Text(model.tr("Por gravedad"))) {
                ForEach(SoundSettings.severities, id: \.self) { severity in soundRow(key: severity, title: severityTitle(severity), isKind: false) }
            }
            Section(header: Text(model.tr("Por tipo"))) {
                ForEach(NoticeKinds.choices, id: \.self) { kind in soundRow(key: kind, title: noticeKindTitle(kind, model), isKind: true) }
            }
            Section(footer: Text(model.tr("La vibración y el modo No molestar de cada gravedad se ajustan en los ajustes del iPhone. Las alarmas críticas solo saltan el modo No molestar si el sistema da permiso a la app para avisos críticos."))) {
                Button(model.tr("Abrir los ajustes de avisos del móvil")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
        }
        .navigationTitle(model.tr("Sonido de cada aviso"))
        .onDisappear { AlarmSounds.shared.stop() }
        .confirmationDialog(model.tr("Elige un sonido"), isPresented: Binding(get: { picking != nil && !importing }, set: { if !$0 && !importing { picking = nil } }), titleVisibility: .visible) {
            Button(model.tr("Predeterminado")) { choose(SoundChoice()) }
            Button(model.tr("Un archivo mío…")) { importing = true }
            Button(model.tr("Cancelar"), role: .cancel) { picking = nil }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            defer { importing = false }
            guard picking != nil else { return }
            if case .success(let urls) = result, let url = urls.first, let kept = AlarmSounds.shared.keep(url) { note = nil; choose(kept) }
            else if case .failure = result { picking = nil }
            else { note = model.tr("Ese archivo no sirve: tiene que ser .aiff, .wav o .caf, de menos de 3 MB y de menos de 30 segundos."); picking = nil }
        }
    }

    @ViewBuilder
    private func soundRow(key: String, title: String, isKind: Bool) -> some View {
        let choice = (isKind ? model.sounds.byKind[key] : model.sounds.bySeverity[key]) ?? SoundChoice()
        let id = (isKind ? "K" : "S") + key
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle(choice, isKind: isKind)).font(.caption).foregroundColor(Theme.muted)
            }
            Spacer()
            if !choice.isDefault {
                Button {
                    if playing == id { AlarmSounds.shared.stop(); playing = nil } else { AlarmSounds.shared.play(choice.file); playing = id }
                } label: { Image(systemName: playing == id ? "stop.fill" : "play.fill") }
                    .buttonStyle(.borderless).accessibilityLabel(model.tr("Probar"))
            }
            Button(model.tr("Cambiar")) { AlarmSounds.shared.stop(); playing = nil; picking = (key, isKind) }.buttonStyle(.bordered).tint(Theme.accent)
        }
    }

    private func choose(_ choice: SoundChoice) {
        guard let target = picking else { return }
        let next = model.sounds.applying(choice, key: target.key, isKind: target.isKind)
        picking = nil
        model.setSounds(next)
    }

    private func subtitle(_ choice: SoundChoice, isKind: Bool) -> String {
        choice.isDefault ? (isKind ? model.tr("Como su gravedad") : model.tr("Predeterminado")) : model.trf("Mío: %s", choice.name)
    }

    private func severityTitle(_ severity: String) -> String {
        switch severity {
        case "critical": return model.tr("Alarmas críticas")
        case "high": return model.tr("Altas")
        default: return model.tr("Avisos (gravedad baja)")
        }
    }
}

/// The voice that says the alarms: woman or man, age, style and speed, with a button to hear it.
struct VoiceSettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let voice = model.voice
        Form {
            Section(footer: Text(model.tr("Cómo suena depende de las voces que tenga instaladas tu móvil: si ninguna dice que es de mujer o de hombre, se aproxima con el tono."))) {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(model.tr("Decir la alarma en voz alta"), isOn: Binding(get: { model.speaksAlarms }, set: { model.setSpeaksAlarms($0) }))
                    Text(model.tr("Con la voz del móvil, para las críticas y las altas.")).font(.caption).foregroundColor(Theme.muted)
                }
            }
            Section {
                Picker(model.tr("Voz"), selection: Binding(get: { voice.gender }, set: { var next = voice; next.gender = $0; model.setVoice(next) })) {
                    ForEach(VoiceSettings.genders, id: \.self) { Text(genderTitle($0)).tag($0) }
                }.pickerStyle(.segmented)
                Picker(model.tr("Edad"), selection: Binding(get: { voice.age }, set: { var next = voice; next.age = $0; model.setVoice(next) })) {
                    ForEach(VoiceSettings.ages, id: \.self) { Text(ageTitle($0)).tag($0) }
                }.pickerStyle(.segmented)
                Picker(model.tr("Estilo"), selection: Binding(get: { voice.style }, set: { var next = voice; next.style = $0; model.setVoice(next) })) {
                    ForEach(VoiceSettings.styles, id: \.self) { Text(styleTitle($0)).tag($0) }
                }.pickerStyle(.menu)
                VStack(alignment: .leading) {
                    Text(model.trf("Velocidad: %s", "\(voice.speed) %")).font(.caption).foregroundColor(Theme.muted)
                    Slider(value: Binding(get: { Double(voice.speed) }, set: { var next = voice; next.speed = Int($0); model.setVoice(next) }),
                           in: Double(VoiceSettings.minSpeed)...Double(VoiceSettings.maxSpeed), step: 5)
                }
                Toggle(model.tr("Decir también los avisos de gravedad baja"), isOn: Binding(get: { voice.warnings }, set: { var next = voice; next.warnings = $0; model.setVoice(next) }))
            }
            Section {
                Button { AlarmSpeaker.shared.stop(); AlarmSpeaker.shared.say(model.tr("Alarma de prueba. Humo detectado en la cocina."), voice: voice, language: model.language) } label: {
                    Label(model.tr("Probar la voz"), systemImage: "play.fill")
                }
            }
        }
        .navigationTitle(model.tr("Voz de las alarmas"))
        .onDisappear { AlarmSpeaker.shared.stop() }
    }

    private func genderTitle(_ value: String) -> String {
        switch value {
        case "female": return model.tr("Mujer")
        case "male": return model.tr("Hombre")
        default: return model.tr("Cualquiera")
        }
    }
    private func ageTitle(_ value: String) -> String {
        switch value {
        case "child": return model.tr("Niño")
        case "senior": return model.tr("Mayor")
        default: return model.tr("Adulto")
        }
    }
    private func styleTitle(_ value: String) -> String {
        switch value {
        case "hero": return model.tr("Héroe de acción: rápido y brillante")
        case "dark": return model.tr("Señor oscuro: lento y grave")
        default: return model.tr("Normal")
        }
    }
}
