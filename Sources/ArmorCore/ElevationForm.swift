// ARMOR-IOS-CONTROL - the rules of the sheet that asks for the proof of identity again: when the button works and what is sent.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum ElevationForm {
    /// The code of the app is typed with the number pad: spaces and line breaks around it (or inside a pasted group) are not part of it.
    public static func cleanCode(_ code: String) -> String { code.filter { !$0.isWhitespace } }

    /// The button works when there is a password or a code; a code of only spaces is nothing.
    public static func canConfirm(password: String, code: String) -> Bool { !password.isEmpty || !cleanCode(code).isEmpty }

    /// What the sheet answers to the server: the password as typed and the code without spaces.
    public static func answer(password: String, code: String) -> (password: String, code: String) { (password, cleanCode(code)) }
}
