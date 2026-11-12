// ARMOR-IOS-CONTROL - reading a message of the shared contract without losing it to a member the app does not know.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

extension Contract {
    /// The document without the members that a closed object of the schema (`additionalProperties: false`) does not name, at every level. The members that an open object may carry
    /// (a map of counts, say) and everything the schema does name are left as they are, so a wrong value, a missing member or a bad pattern still fail the check. A newer server that
    /// adds a member must not empty a screen of an older app; a document that is really wrong still gets nothing.
    public static func withoutUnknownMembers(_ name: String, _ document: [String: Any]) -> [String: Any]? {
        guard let schema = schemas[name], let cleaned = pruned(document, schema) as? [String: Any] else { return nil }
        return cleaned
    }

    /// `Contract.parse` after `withoutUnknownMembers`: the struct of the message called `name`, or nil when the document is not that message even without its unknown members.
    public static func parseTolerant(_ name: String, _ document: [String: Any]) -> Any? {
        guard let cleaned = withoutUnknownMembers(name, document) else { return nil }
        return parse(name, cleaned)
    }

    private static func pruned(_ value: Any, _ schema: [String: Any]) -> Any {
        if let object = value as? [String: Any] {
            let properties = schema["properties"] as? [String: Any] ?? [:]
            let extra = schema["additionalProperties"]
            let closed = extra.map { isBool($0) && !asFlag($0) } ?? false
            var out: [String: Any] = [:]
            for (name, member) in object {
                if let rule = properties[name] as? [String: Any] {
                    out[name] = pruned(member, rule)
                } else if closed {
                    continue
                } else if let rule = extra as? [String: Any] {
                    out[name] = pruned(member, rule)
                } else {
                    out[name] = member
                }
            }
            return out
        }
        if let list = value as? [Any], let items = schema["items"] as? [String: Any] {
            return list.map { pruned($0, items) }
        }
        return value
    }
}
