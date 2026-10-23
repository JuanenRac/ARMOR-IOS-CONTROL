// ARMOR-IOS-CONTROL - the help of the app, in the eight languages: what each screen does and what the app will never do.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI

struct HelpView: View {
    @EnvironmentObject var model: AppModel

    /// Title and text, as the Spanish phrases of the translation tables.
    static let topics: [(title: String, body: String)] = [
        ("Conectar con tu casa", "En casa la app usa la dirección privada de tu servidor; fuera de casa, la dirección de fuera (un nombre DNS que sigue a tu casa o la VPN). Si una no responde, prueba la otra y te dice qué falla."),
        ("Estado, armar y desarmar", "La pantalla Estado muestra si el sistema está armado y cada nodo. Antes de armar, el servidor avisa de lo que quedaría ciego o ruidoso. Para desarmar se pide el PIN si tu usuario tiene uno."),
        ("Alarmas", "Las alarmas activas esperan a que alguien las confirme. Las centrales de alarma se arman, se desarman y se silencian desde aquí si el servidor lo permite. Con la app abierta recibes avisos del teléfono cuando algo ocurre."),
        ("Cámaras", "Cada cámara se ve a través del servidor: la app nunca conoce la contraseña de la cámara. Solo se mueven las imágenes que están en pantalla, y si se corta la imagen la app vuelve a pedirla esperando cada vez un poco más."),
        ("Asistente", "Escribe una orden (o usa el micrófono del teclado): el estado, las alarmas, armar o desarmar. Armar y desarmar piden una confirmación aparte que solo puedes dar tú."),
        ("Bloqueo con el teléfono", "La app pide Face ID, Touch ID o el código del iPhone antes de armar, desarmar, silenciar y desbloquear, y, si lo activas, para abrirla. Tu administrador puede exigirlo, nunca quitarlo. Un teléfono sin código nunca se queda fuera."),
        ("Seguridad", "La contraseña viaja una sola vez al servidor. Solo se guarda si marcas Recordarme, cifrada en el llavero del iPhone. Fuera de casa se exige una conexión https, y la app recuerda la clave del certificado de tu instalación para avisarte si cambia."),
        ("Lo que la app no hace", "La app no guarda contraseñas de cámaras, no graba audio y no vigila en segundo plano: iOS no deja a una app consultar el servidor cuando está cerrada. Los avisos con la app cerrada llegan solo si tu servidor tiene los avisos push activados."),
    ]

    var body: some View {
        List {
            ForEach(Self.topics.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.tr(Self.topics[index].title)).font(.headline).foregroundColor(Theme.accent)
                    Text(model.tr(Self.topics[index].body)).font(.callout)
                }.listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Ayuda"))
    }
}
