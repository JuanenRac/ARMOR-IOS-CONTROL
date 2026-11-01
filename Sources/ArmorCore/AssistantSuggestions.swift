// ARMOR-IOS-CONTROL - the phrases the assistant understands that the screen offers to tap. The same list as the Android app; the server understands them in every language of the app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum AssistantSuggestions {
    public static func phrases(_ t: Translator) -> [String] {
        [t.tr("Estado del sistema"), t.tr("Armar el sistema"), t.tr("Desarmar el sistema"), t.tr("Silenciar la alarma"), t.tr("Alarmas activas"), t.tr("Hay alguien"), t.tr("Estado de los nodos"),
         t.tr("Estado de las cámaras"), t.tr("Estado solar"), t.tr("Consumo eléctrico"), t.tr("Estado de la red"), t.tr("Qué hora es"), t.tr("Enciende las luces"), t.tr("Apaga las luces"), t.tr("Ayuda")]
    }
}
