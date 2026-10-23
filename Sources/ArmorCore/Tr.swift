// ARMOR-IOS-CONTROL - the languages of the app: the eight of A.R.M.O.R. (English, Spanish, German, French, Italian, Japanese, Chinese, Portuguese of Portugal).
// The source text is Spanish and each phrase is looked up by it in a table per language (Resources/i18n/<code>.json: Spanish phrase -> translation), the same scheme as the Android app.
// A phrase with a hole is written with %s (or %d) and filled by `trf`. A phrase missing in a language shows in Spanish rather than nothing; a test keeps every phrase in every table.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public final class Translator: @unchecked Sendable {
    /// The languages, in the order of the picker: code and its name in itself.
    public static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("es", "Español"), ("de", "Deutsch"), ("fr", "Français"), ("it", "Italiano"), ("ja", "日本語"), ("zh", "中文"), ("pt", "Português"),
    ]
    public typealias Loader = (String) -> [String: String]?

    private let lock = NSLock()
    private let loader: Loader
    private var tables: [String: [String: String]] = [:]
    private var current = "es"

    public init(language: String = "es", loader: @escaping Loader = Translator.bundled) {
        self.loader = loader
        select(language)
    }

    public var language: String { lock.lock(); defer { lock.unlock() }; return current }

    /// Chooses a language; a code that is not one of the eight becomes English.
    public func select(_ code: String) {
        let chosen = Translator.languages.contains { $0.code == code } ? code : "en"
        lock.lock(); defer { lock.unlock() }
        current = chosen
        if chosen != "es", tables[chosen] == nil { tables[chosen] = loader(chosen) ?? [:] }
    }

    /// The one to use: a saved code that is one of the eight, else the phone's if it is, else English.
    public static func pick(saved: String?, phone: String) -> String {
        if let saved, languages.contains(where: { $0.code == saved }) { return saved }
        if languages.contains(where: { $0.code == phone }) { return phone }
        return "en"
    }

    /// The phrase (written in Spanish in the source) in the language of the app.
    public func tr(_ es: String) -> String {
        lock.lock(); defer { lock.unlock() }
        if current == "es" { return es }
        return tables[current]?[es] ?? es
    }

    /// The same for a phrase with holes (%s, %d), filled in order with the text of the arguments.
    public func trf(_ es: String, _ args: Any...) -> String {
        Translator.fill(tr(es), args)
    }

    /// Fills `%s` and `%d` in order, and `%1$s`, `%2$d`... by position (a translation may need to put the holes in another order).
    static func fill(_ template: String, _ args: [Any]) -> String {
        let chars = Array(template)
        var out = ""
        var index = 0
        var i = 0
        while i < chars.count {
            let c = chars[i]
            guard c == "%", i + 1 < chars.count else { out.append(c); i += 1; continue }
            // %% is a percent sign
            if chars[i + 1] == "%" { out.append("%"); i += 2; continue }
            // %s or %d
            if chars[i + 1] == "s" || chars[i + 1] == "d" {
                if index < args.count { out += String(describing: args[index]); index += 1 }
                i += 2; continue
            }
            // %N$s or %N$d
            var j = i + 1
            var digits = ""
            while j < chars.count, chars[j].isASCII, chars[j].isNumber { digits.append(chars[j]); j += 1 }
            if !digits.isEmpty, j + 1 < chars.count, chars[j] == "$", chars[j + 1] == "s" || chars[j + 1] == "d" {
                if let position = Int(digits), position >= 1, position <= args.count { out += String(describing: args[position - 1]) }
                i = j + 2; continue
            }
            out.append(c); i += 1
        }
        return out
    }

    /// The tables shipped inside the package.
    public static func bundled(_ code: String) -> [String: String]? {
        guard let url = Bundle.module.url(forResource: code, withExtension: "json", subdirectory: "i18n"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return nil }
        return object
    }
}
