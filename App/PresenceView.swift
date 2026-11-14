// ARMOR-IOS-CONTROL - More > Reminder on leaving home: the switch, the button that saves the place the phone is in as home, and what the permission is for. Nothing leaves the phone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct PresenceView: View {
    @EnvironmentObject var model: AppModel
    @State private var on = false
    @State private var share = false
    @State private var saved = false
    @State private var message: String?

    var body: some View {
        Form {
            Section(footer: Text(model.tr("Te avisa si sales de casa con la alarma desarmada. Todo se queda en el móvil: tu ubicación no se envía a ningún sitio."))) {
                Toggle(model.tr("Recordatorio al salir de casa"), isOn: Binding(get: { on }, set: { value in
                    on = value; message = nil
                    model.setPresenceEnabled(value)
                    if value && !model.presenceAuthorized { model.askPresencePermission() }
                }))
                Toggle(model.tr("Decir a mi servidor si estoy en casa"), isOn: Binding(get: { share }, set: { value in
                    share = value; message = nil
                    model.setPresenceShare(value)
                    if value && !model.presenceAuthorized { model.askPresencePermission() }
                }))
                Text(model.tr("Envía solo la palabra en casa o fuera cuando el móvil entra o sale del círculo de casa. Tu ubicación no se envía a ningún sitio.")).font(.caption).foregroundColor(Theme.muted)
                if on || share {
                    Button(saved ? model.tr("Cambiar la casa por mi ubicación actual") : model.tr("Usar mi ubicación actual como casa")) {
                        message = nil
                        guard model.presenceAuthorized else { model.askPresencePermission(); message = model.tr("Se necesita el permiso de ubicación, también con la app cerrada, para avisarte al salir."); return }
                        model.saveHomeHere { ok in
                            saved = ok || saved
                            message = ok ? model.tr("Casa guardada.") : model.tr("No se pudo leer tu ubicación.")
                        }
                    }
                }
                if let message { Text(message).font(.caption).foregroundColor(Theme.muted) }
            }
        }
        .navigationTitle(model.tr("Recordatorio al salir de casa"))
        .onAppear { on = model.presenceEnabled; share = model.presenceShare; saved = model.presenceHasHome }
    }
}
