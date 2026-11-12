// Generated from the A.R.M.O.R. JSON Schemas by tools/generate_swift_parsers.py. Do not edit.
import Foundation

public enum Contract {
    /// What a document gets wrong: where (`/zones/0/id`) and what.
    public struct ContractError: Error, Equatable, CustomStringConvertible {
        public let path: String
        public let detail: String
        public init(path: String, detail: String) {
            self.path = path
            self.detail = detail
        }
        public var description: String { "\(path.isEmpty ? "$" : path): \(detail)" }
    }

    // MARK: reading values of a document (a value of the wrong kind never crashes: it takes a harmless default)

    static func isBool(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return String(cString: number.objCType) == "c"
    }

    static func numberOf(_ value: Any) -> Double? {
        if isBool(value) { return nil }
        guard let number = value as? NSNumber else { return nil }
        return number.doubleValue
    }

    static func asStr(_ value: Any) -> String { value as? String ?? "" }
    static func asInt(_ value: Any) -> Int64 { numberOf(value).map { ($0.isFinite && abs($0) < 9.2e18) ? Int64($0) : 0 } ?? 0 }
    static func asNum(_ value: Any) -> Double { numberOf(value) ?? 0 }
    static func asFlag(_ value: Any) -> Bool { isBool(value) ? ((value as? NSNumber)?.boolValue ?? false) : false }
    static func objOf(_ value: Any) -> [String: Any] { value as? [String: Any] ?? [:] }
    static func listOf(_ value: Any) -> [Any] { value as? [Any] ?? [] }

    static func str(_ o: [String: Any], _ key: String) -> String { o[key].map(asStr) ?? "" }
    static func int(_ o: [String: Any], _ key: String) -> Int64 { o[key].map(asInt) ?? 0 }
    static func num(_ o: [String: Any], _ key: String) -> Double { o[key].map(asNum) ?? 0 }
    static func flag(_ o: [String: Any], _ key: String) -> Bool { o[key].map(asFlag) ?? false }
    static func objAt(_ o: [String: Any], _ key: String) -> [String: Any] { o[key].map(objOf) ?? [:] }
    static func listAt(_ o: [String: Any], _ key: String) -> [Any] { o[key].map(listOf) ?? [] }

    // MARK: the interpreter of the schemas

    private static let regexLock = NSLock()
    private static var compiled: [String: NSRegularExpression] = [:]

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        regexLock.lock()
        var regex = compiled[pattern]
        if regex == nil {
            regex = try? NSRegularExpression(pattern: pattern, options: [])
            compiled[pattern] = regex
        }
        regexLock.unlock()
        guard let found = regex else { return false }
        return found.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    private static func typeMatches(_ value: Any, _ type: String) -> Bool {
        switch type {
        case "object": return value is [String: Any]
        case "array": return value is [Any]
        case "string": return value is String
        case "boolean": return isBool(value)
        case "integer":
            guard let number = numberOf(value), number.isFinite else { return false }
            return number == number.rounded(.towardZero)
        case "number":
            guard let number = numberOf(value) else { return false }
            return number.isFinite
        default: return false
        }
    }

    private static func same(_ a: Any, _ b: Any) -> Bool {
        if isBool(a) || isBool(b) { return isBool(a) && isBool(b) && asFlag(a) == asFlag(b) }
        if let x = numberOf(a), let y = numberOf(b) { return x == y }
        if let x = a as? String, let y = b as? String { return x == y }
        return false
    }

    private static func show(_ value: Any?) -> String {
        guard let value = value else { return "" }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys]), let text = String(data: data, encoding: .utf8) { return text }
        return "\(value)"
    }

    /// The first way in which `value` does not satisfy `schema`, in the order Python's validator finds it, or nil.
    private static func firstError(_ value: Any, _ schema: [String: Any], _ path: String) -> ContractError? {
        if let type = schema["type"] as? String, !typeMatches(value, type) { return ContractError(path: path, detail: "must be of type \(type)") }
        if let fixed = schema["const"], !same(value, fixed) { return ContractError(path: path, detail: "must equal \(show(fixed))") }
        if let options = schema["enum"] as? [Any], !options.contains(where: { same(value, $0) }) { return ContractError(path: path, detail: "must be one of \(show(options))") }
        if let text = value as? String, !isBool(value) {
            let length = text.unicodeScalars.count
            if let least = schema["minLength"] as? Int, length < least { return ContractError(path: path, detail: "must have at least \(least) characters") }
            if let most = schema["maxLength"] as? Int, length > most { return ContractError(path: path, detail: "must have at most \(most) characters") }
            if let pattern = schema["pattern"] as? String, !matches(pattern, text) { return ContractError(path: path, detail: "must match \(pattern)") }
        }
        if let number = numberOf(value) {
            if let least = schema["minimum"], let limit = numberOf(least), number < limit { return ContractError(path: path, detail: "must be at least \(show(least))") }
            if let most = schema["maximum"], let limit = numberOf(most), number > limit { return ContractError(path: path, detail: "must be at most \(show(most))") }
        }
        if let list = value as? [Any] {
            if let least = schema["minItems"] as? Int, list.count < least { return ContractError(path: path, detail: "must have at least \(least) items") }
            if let most = schema["maxItems"] as? Int, list.count > most { return ContractError(path: path, detail: "must have at most \(most) items") }
            if let items = schema["items"] as? [String: Any] {
                for (index, element) in list.enumerated() {
                    if let found = firstError(element, items, "\(path)/\(index)") { return found }
                }
            }
        }
        if let object = value as? [String: Any] {
            let properties = schema["properties"] as? [String: Any] ?? [:]
            if let required = schema["required"] as? [String] {
                for name in required where object[name] == nil { return ContractError(path: "\(path)/\(name)", detail: "is required") }
            }
            let names = object.keys.sorted()
            if let most = schema["maxProperties"] as? Int, names.count > most { return ContractError(path: path, detail: "must have at most \(most) properties") }
            if let rule = schema["propertyNames"] as? [String: Any], let pattern = rule["pattern"] as? String {
                for name in names where !matches(pattern, name) { return ContractError(path: "\(path)/\(name)", detail: "the name must match \(pattern)") }
            }
            let extra = schema["additionalProperties"]
            if let allowed = extra as? [String: Any] {
                for name in names where properties[name] == nil {
                    if let found = firstError(object[name] as Any, allowed, "\(path)/\(name)") { return found }
                }
            } else if let allowed = extra, isBool(allowed), !asFlag(allowed) {
                for name in names where properties[name] == nil { return ContractError(path: "\(path)/\(name)", detail: "is not allowed") }
            }
            for name in properties.keys.sorted() {
                guard let member = object[name], let rule = properties[name] as? [String: Any] else { continue }
                if let found = firstError(member, rule, "\(path)/\(name)") { return found }
            }
        }
        return nil
    }

    private static func read(_ text: String) -> [String: Any] {
        guard let data = text.data(using: .utf8), let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return value
    }

    /// The schema of each message, by the name of its file.
    public static let schemas: [String: [String: Any]] = {
        var found: [String: [String: Any]] = [:]
        for (name, text) in schemaTexts { found[name] = read(text) }
        return found
    }()

    /// The names of the messages.
    public static var messageNames: [String] { schemaTexts.keys.sorted() }

    /// The first thing wrong with the document as the message called `name`, or nil when it is valid. An unknown name is an error.
    public static func check(_ name: String, _ value: Any) -> ContractError? {
        guard let schema = schemas[name] else { return ContractError(path: "", detail: "unknown message \(name)") }
        return firstError(value, schema, "")
    }

    private static let schemaTexts: [String: String] = [
        "ai_observation": #"{"type":"object","additionalProperties":false,"required":["camera_id","severity","reasons","profile","motion","radar_tracks"],"properties":{"camera_id":{"type":"string","pattern":"^[A-Za-z0-9._-]{3,80}(?![\\s\\S])"},"severity":{"type":"string","enum":["review","high"]},"reasons":{"type":"array","maxItems":5,"items":{"type":"string","maxLength":200}},"profile":{"type":"string","enum":["daylight","low-light"]},"motion":{"type":"number","minimum":0,"maximum":1},"motion_ratio":{"type":"number","minimum":0,"maximum":1},"regions":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["x","y","w","h"],"properties":{"x":{"type":"number","minimum":0,"maximum":1},"y":{"type":"number","minimum":0,"maximum":1},"w":{"type":"number","minimum":0.0001,"maximum":1},"h":{"type":"number","minimum":0.0001,"maximum":1}}}},"radar_tracks":{"type":"integer","minimum":0,"maximum":1000}}}"#,
        "alarm": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","phase","mode","siren","locked_out","commands_enabled","zones","open_zones","events"],"properties":{"kind":{"type":"string","const":"alarm"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"phase":{"type":"string","enum":["disarmed","exit_delay","armed","entry_delay","alarm"]},"mode":{"type":"string","enum":["disarmed","away","stay"]},"siren":{"type":"boolean"},"locked_out":{"type":"boolean"},"commands_enabled":{"type":"boolean"},"zones":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["id","kind","state","bypassed"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"name":{"type":"string","minLength":1,"maxLength":160},"kind":{"type":"string","enum":["instant","entry","interior","always"]},"state":{"type":"string","enum":["normal","triggered","tamper","trouble"]},"bypassed":{"type":"boolean"}}}},"open_zones":{"type":"array","maxItems":16,"items":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"}},"events":{"type":"array","maxItems":10,"items":{"type":"object","additionalProperties":false,"required":["ago_s","kind"],"properties":{"ago_s":{"type":"integer","minimum":0},"kind":{"type":"string","enum":["armed","exit_delay_started","entry_delay_started","alarm","siren_timed_out","disarmed","bad_pin","locked_out","zone_bypassed","siren_silenced"]},"zone":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"}}}},"arm_profiles":{"type":"boolean"},"profile":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,15}(?![\\s\\S])"},"siren_loop":{"type":"string","enum":["unknown","ok","open","short","unreadable"]},"siren_fault":{"type":"boolean"},"seq":{"type":"integer","minimum":0,"maximum":9007199254740991},"sig":{"type":"string","pattern":"^[0-9a-f]{64}(?![\\s\\S])"}}}"#,
        "alarm_command": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","command_id","action"],"properties":{"kind":{"type":"string","const":"alarm_command"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"action":{"type":"string","enum":["arm","disarm","silence"]},"mode":{"type":"string","enum":["away","stay"]},"force":{"type":"boolean"},"profile":{"type":"object","additionalProperties":false,"required":["id","name","base"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,15}(?![\\s\\S])"},"name":{"type":"string","minLength":1,"maxLength":32},"base":{"type":"string","enum":["away","stay"]},"exit_delay_s":{"type":"integer","minimum":0,"maximum":300},"entry_delay_s":{"type":"integer","minimum":0,"maximum":300},"siren":{"type":"boolean"},"notify":{"type":"string","enum":["urgent","normal"]},"zones":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["id"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"armed":{"type":"boolean"},"delay":{"type":"string","enum":["instant","entry"]}}}}}}}}"#,
        "alarm_policy": #"{"type":"object","additionalProperties":false,"required":["config_hash","zone_feed","zone_feed_signature"],"properties":{"config_hash":{"type":"boolean"},"zone_feed":{"type":"boolean"},"zone_feed_signature":{"type":"boolean"},"disarm_pin":{"type":"string","enum":["never","if_set","always"]},"nvs_encryption":{"type":"string","enum":["secrets"]}}}"#,
        "alarm_result": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","command_id","action","accepted","refusal","phase"],"properties":{"kind":{"type":"string","const":"alarm_result"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"action":{"type":"string","enum":["arm","disarm","silence"]},"accepted":{"type":"boolean"},"refusal":{"type":"string","enum":["none","not_disarmed","zones_open","not_armed","bad_pin","locked_out"]},"phase":{"type":"string","enum":["disarmed","exit_delay","armed","entry_delay","alarm"]}}}"#,
        "alarm_zone_feed": #"{"type":"object","additionalProperties":false,"required":["zone","state","battery_low"],"properties":{"zone":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"state":{"type":"string","enum":["normal","triggered","tamper"]},"battery_low":{"type":"boolean"},"seq":{"type":"integer","minimum":0,"maximum":9007199254740991},"sig":{"type":"string","pattern":"^[0-9a-f]{64}(?![\\s\\S])"}}}"#,
        "arm_profile": #"{"type":"object","additionalProperties":false,"required":["id","name","base"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,15}(?![\\s\\S])"},"name":{"type":"string","minLength":1,"maxLength":32},"base":{"type":"string","enum":["away","stay"]},"exit_delay_s":{"type":"integer","minimum":0,"maximum":300},"entry_delay_s":{"type":"integer","minimum":0,"maximum":300},"siren":{"type":"boolean"},"notify":{"type":"string","enum":["urgent","normal"]},"zones":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["id"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"armed":{"type":"boolean"},"delay":{"type":"string","enum":["instant","entry"]}}}}}}"#,
        "arming_modes": #"{"type":"object","additionalProperties":false,"required":["modes"],"properties":{"modes":{"type":"object","additionalProperties":false,"required":["away","home","night"],"properties":{"away":{"type":"object","additionalProperties":false,"properties":{"entry":{"type":"array","maxItems":64,"items":{"type":"string","pattern":"^(zone|device|node|camera):[^ \\t\\n\\r\\f\\x0b]([^\\n]{0,62}[^ \\t\\n\\r\\f\\x0b])?(?![\\s\\S])"}},"exit_delay_s":{"type":"integer","minimum":0,"maximum":300},"entry_delay_s":{"type":"integer","minimum":0,"maximum":300}}},"home":{"type":"object","additionalProperties":false,"properties":{"defends":{"type":"array","maxItems":64,"items":{"type":"string","pattern":"^(zone|device|node|camera):[^ \\t\\n\\r\\f\\x0b]([^\\n]{0,62}[^ \\t\\n\\r\\f\\x0b])?(?![\\s\\S])"}},"entry":{"type":"array","maxItems":64,"items":{"type":"string","pattern":"^(zone|device|node|camera):[^ \\t\\n\\r\\f\\x0b]([^\\n]{0,62}[^ \\t\\n\\r\\f\\x0b])?(?![\\s\\S])"}},"exit_delay_s":{"type":"integer","minimum":0,"maximum":300},"entry_delay_s":{"type":"integer","minimum":0,"maximum":300}}},"night":{"type":"object","additionalProperties":false,"properties":{"defends":{"type":"array","maxItems":64,"items":{"type":"string","pattern":"^(zone|device|node|camera):[^ \\t\\n\\r\\f\\x0b]([^\\n]{0,62}[^ \\t\\n\\r\\f\\x0b])?(?![\\s\\S])"}},"entry":{"type":"array","maxItems":64,"items":{"type":"string","pattern":"^(zone|device|node|camera):[^ \\t\\n\\r\\f\\x0b]([^\\n]{0,62}[^ \\t\\n\\r\\f\\x0b])?(?![\\s\\S])"}},"exit_delay_s":{"type":"integer","minimum":0,"maximum":300},"entry_delay_s":{"type":"integer","minimum":0,"maximum":300}}}}},"schedule":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["mode","days","at"],"properties":{"mode":{"type":"string","enum":["away","home","night"]},"days":{"type":"array","minItems":1,"maxItems":7,"items":{"type":"integer","minimum":1,"maximum":7}},"at":{"type":"string","pattern":"^([01][0-9]|2[0-3]):[0-5][0-9](?![\\s\\S])"}}}},"panel_map":{"type":"object","additionalProperties":false,"properties":{"profiles":{"type":"object","additionalProperties":false,"properties":{"away":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,15}(?![\\s\\S])"},"home":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,15}(?![\\s\\S])"},"night":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,15}(?![\\s\\S])"}}},"only":{"type":"array","maxItems":32,"items":{"type":"string","pattern":"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"}}}}}}"#,
        "command": #"{"type":"object","additionalProperties":false,"required":["node_id","timestamp_ms","command"],"properties":{"kind":{"type":"string","const":"command"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command":{"type":"string","enum":["calibrate","set_thresholds","restart"]},"sensitivity":{"type":"integer","minimum":1,"maximum":10}}}"#,
        "connection_client": #"{"type":"object","additionalProperties":false,"required":["id","kind","first_seen","last_seen","active_sessions","logins_ok","logins_failed"],"properties":{"id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"kind":{"type":"string","enum":["studio","android","node","voice","other"]},"user":{"type":"string","minLength":1,"maxLength":60},"label":{"type":"string","minLength":1,"maxLength":80},"app_version":{"type":"string","pattern":"^[0-9A-Za-z._-]{1,24}(?![\\s\\S])"},"origin":{"type":"string","enum":["local","remote"]},"two_factor":{"type":"boolean"},"first_seen":{"type":"string","minLength":1,"maxLength":40},"last_seen":{"type":"string","minLength":1,"maxLength":40},"last_failure":{"type":"string","minLength":1,"maxLength":40},"active_sessions":{"type":"integer","minimum":0},"logins_ok":{"type":"integer","minimum":0},"logins_failed":{"type":"integer","minimum":0},"ip":{"type":"string","minLength":1,"maxLength":64},"agent":{"type":"string","minLength":1,"maxLength":120}}}"#,
        "connection_event": #"{"type":"object","additionalProperties":false,"required":["id","at","type","action","client_kind","client_id"],"properties":{"id":{"type":"integer","minimum":1},"at":{"type":"string","minLength":1,"maxLength":40},"type":{"type":"string","const":"connection"},"action":{"type":"string","enum":["first_seen","login","login_failed","second_factor_failed","logout","session_ended","session_expired","panel_opened"]},"client_kind":{"type":"string","enum":["studio","android","node","voice","other"]},"client_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"user":{"type":"string","minLength":1,"maxLength":60},"origin":{"type":"string","enum":["local","remote"]},"two_factor":{"type":"boolean"},"app_version":{"type":"string","pattern":"^[0-9A-Za-z._-]{1,24}(?![\\s\\S])"},"subject":{"type":"string","minLength":1,"maxLength":80},"ip":{"type":"string","minLength":1,"maxLength":64},"agent":{"type":"string","minLength":1,"maxLength":120}}}"#,
        "daily_summary": #"{"type":"object","additionalProperties":false,"required":["date","language","summary","findings","text"],"properties":{"date":{"type":"string","pattern":"^[0-9]{4}-[0-9]{2}-[0-9]{2}(?![\\s\\S])"},"language":{"type":"string","enum":["en","es","de","fr","it","ja","zh","pt"]},"summary":{"type":"object","required":["schema","totals","by_type","by_zone","by_hour"],"properties":{"schema":{"type":"string","const":"armor-daily-summary/1"},"totals":{"type":"object","required":["events","alarms","serious_alarms","false_alarms"],"properties":{"events":{"type":"integer","minimum":0},"alarms":{"type":"integer","minimum":0},"serious_alarms":{"type":"integer","minimum":0},"false_alarms":{"type":"integer","minimum":0}}},"by_type":{"type":"object","additionalProperties":{"type":"integer"}},"by_zone":{"type":"object","additionalProperties":{"type":"integer"}},"by_hour":{"type":"array","minItems":24,"maxItems":24,"items":{"type":"integer","minimum":0}},"serious_alarms":{"type":"array","items":{"type":"object","required":["t_s"],"properties":{"t_s":{"type":"number","minimum":0,"maximum":86400},"code":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"zone":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"node":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"sensor":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"severity":{"type":"string","enum":["info","low","medium","high","critical"]},"watts":{"type":"number"},"value":{"type":"number"},"duration_s":{"type":"number","minimum":0},"mean_w":{"type":"number"},"limit_w":{"type":"number"}}}},"nodes_link_lost":{"type":"array","items":{"type":"object","required":["node","count","total_s"],"properties":{"node":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"count":{"type":"integer","minimum":1},"total_s":{"type":"number","minimum":0}}}},"outlier_readings":{"type":"array","items":{"type":"object","required":["t_s","node","sensor","value","median","score"],"properties":{"t_s":{"type":"number","minimum":0,"maximum":86400},"node":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"sensor":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"value":{"type":"number"},"median":{"type":"number"},"score":{"type":"number"}}}},"consumption":{"type":"object","required":["samples","peaks"],"properties":{"samples":{"type":"integer","minimum":0},"peaks":{"type":"array","items":{"type":"object","required":["t_s"],"properties":{"t_s":{"type":"number","minimum":0,"maximum":86400},"code":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"zone":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"node":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"sensor":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"severity":{"type":"string","enum":["info","low","medium","high","critical"]},"watts":{"type":"number"},"value":{"type":"number"},"duration_s":{"type":"number","minimum":0},"mean_w":{"type":"number"},"limit_w":{"type":"number"}}}}}}}},"findings":{"type":"array","maxItems":200,"items":{"type":"object","additionalProperties":false,"required":["kind","subject","count","detail","evidence"],"properties":{"kind":{"type":"string","enum":["hourly_repeat","intermittent_sensor","intermittent_link","recurrent_false_alarm","anomalous_consumption"]},"subject":{"type":"object","properties":{"code":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"zone":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"node":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"}}},"count":{"type":"integer","minimum":0},"detail":{"type":"object","properties":{"hours":{"type":"array","items":{"type":"integer","minimum":0,"maximum":23}},"tolerance_min":{"type":"number"},"max_gap_s":{"type":"number"},"limit_s":{"type":"number"},"minimum":{"type":"integer"},"window":{"type":"integer"},"sigma":{"type":"number"},"min_ratio":{"type":"number"}}},"evidence":{"type":"array","maxItems":20,"items":{"type":"object","required":["t_s"],"properties":{"t_s":{"type":"number","minimum":0,"maximum":86400},"code":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"zone":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"node":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"sensor":{"type":"string","pattern":"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}(?![\\s\\S])"},"severity":{"type":"string","enum":["info","low","medium","high","critical"]},"watts":{"type":"number"},"value":{"type":"number"},"duration_s":{"type":"number","minimum":0},"mean_w":{"type":"number"},"limit_w":{"type":"number"}}}}}}},"text":{"type":"string","maxLength":20000},"ai_note":{"type":"string","maxLength":2000}}}"#,
        "device_state": #"{"type":"object","additionalProperties":false,"required":["on"],"properties":{"on":{"type":"boolean"}}}"#,
        "diagnostic_token_created": #"{"type":"object","additionalProperties":false,"required":["id","token","scope","nodes","created_at","expires_at","created_by"],"properties":{"id":{"type":"string","pattern":"^[a-f0-9]{12}(?![\\s\\S])"},"token":{"type":"string","pattern":"^armor-diag-[A-Za-z0-9_-]{43}(?![\\s\\S])"},"scope":{"type":"string","const":"read_only"},"nodes":{"type":"array","minItems":1,"maxItems":16,"items":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"}},"label":{"type":"string","minLength":1,"maxLength":48},"created_at":{"type":"string","pattern":"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]{8,12}Z(?![\\s\\S])"},"expires_at":{"type":"string","pattern":"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]{8,12}Z(?![\\s\\S])"},"created_by":{"type":"string","pattern":"^[A-Za-z0-9._@ -]{1,64}(?![\\s\\S])"}}}"#,
        "diagnostic_token_info": #"{"type":"object","additionalProperties":false,"required":["id","scope","nodes","created_at","expires_at","created_by","status","uses"],"properties":{"id":{"type":"string","pattern":"^[a-f0-9]{12}(?![\\s\\S])"},"scope":{"type":"string","const":"read_only"},"nodes":{"type":"array","minItems":1,"maxItems":16,"items":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"}},"label":{"type":"string","minLength":1,"maxLength":48},"created_at":{"type":"string","pattern":"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]{8,12}Z(?![\\s\\S])"},"expires_at":{"type":"string","pattern":"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]{8,12}Z(?![\\s\\S])"},"created_by":{"type":"string","pattern":"^[A-Za-z0-9._@ -]{1,64}(?![\\s\\S])"},"status":{"type":"string","enum":["active","expired","revoked"]},"revoked_at":{"type":"string","pattern":"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]{8,12}Z(?![\\s\\S])"},"revoked_by":{"type":"string","pattern":"^[A-Za-z0-9._@ -]{1,64}(?![\\s\\S])"},"uses":{"type":"integer","minimum":0},"last_used_at":{"type":"string","pattern":"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]{8,12}Z(?![\\s\\S])"}}}"#,
        "diagnostic_token_request": #"{"type":"object","additionalProperties":false,"required":["nodes"],"properties":{"nodes":{"type":"array","minItems":1,"maxItems":16,"items":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"}},"ttl_s":{"type":"integer","minimum":300,"maximum":86400},"label":{"type":"string","minLength":1,"maxLength":48}}}"#,
        "electrical": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","channels"],"properties":{"kind":{"type":"string","const":"electrical"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"switching_enabled":{"type":"boolean"},"channels":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["id","domain"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"domain":{"type":"string","enum":["ac","dc"]},"label":{"type":"string","minLength":1,"maxLength":40},"voltage_v":{"type":"number","minimum":0,"maximum":1000},"current_a":{"type":"number","minimum":-1000,"maximum":1000},"power_w":{"type":"number","minimum":-1000000,"maximum":1000000},"energy_kwh":{"type":"number","minimum":0,"maximum":10000000},"reading_age_ms":{"type":"integer","minimum":0},"errors":{"type":"integer","minimum":0},"power_estimated":{"type":"boolean"},"frequency_hz":{"type":"number","minimum":0,"maximum":100},"power_factor":{"type":"number","minimum":-1,"maximum":1},"state":{"type":"string","enum":["closed","open","unknown"]},"alarm":{"type":"boolean"},"alarm_code":{"type":"string","pattern":"^[a-z][a-z0-9_]{0,39}(?![\\s\\S])"}}}},"switches":{"type":"array","maxItems":4,"items":{"type":"object","additionalProperties":false,"required":["id","kind","a_closed","b_closed","selected","wanted","closing","armed","fault"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"kind":{"type":"string","const":"transfer"},"label":{"type":"string","minLength":1,"maxLength":40},"source_a":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"source_b":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"a_closed":{"type":"boolean"},"b_closed":{"type":"boolean"},"selected":{"type":"string","enum":["none","a","b"]},"wanted":{"type":"string","enum":["none","a","b"]},"closing":{"type":"boolean"},"armed":{"type":"boolean"},"fault":{"type":"string","enum":["none","did_not_close","did_not_open","both_closed","disabled"]}}}}}}"#,
        "electrical_command": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","command_id","switch","action"],"properties":{"kind":{"type":"string","const":"electrical_command"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"switch":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"action":{"type":"string","enum":["arm","close_a","close_b","open","acknowledge"]},"token":{"type":"string","pattern":"^[a-z0-9]{8,32}(?![\\s\\S])"}}}"#,
        "electrical_result": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","command_id","switch","action","accepted","refusal"],"properties":{"kind":{"type":"string","const":"electrical_result"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"switch":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"action":{"type":"string","enum":["arm","close_a","close_b","open","acknowledge"]},"accepted":{"type":"boolean"},"refusal":{"type":"string","enum":["none","disabled","fault","not_armed","not_confirmed_open","unknown_switch","bad_token","not_supported"]},"token":{"type":"string","pattern":"^[a-z0-9]{8,32}(?![\\s\\S])"}}}"#,
        "health": #"{"type":"object","additionalProperties":false,"required":["node_id","timestamp_ms","online"],"properties":{"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"online":{"type":"boolean"},"kind":{"type":"string","enum":["radar","panel"]}}}"#,
        "heatmap": #"{"type":"object","required":["schema","camera_id","cols","rows","accepted_positions","rejected_positions","total","max","weights","normalized","contains_images"],"properties":{"schema":{"type":"string","const":"armor.vision.heatmap/v1"},"camera_id":{"type":"string","pattern":"^[A-Za-z0-9._-]{1,80}(?![\\s\\S])"},"cols":{"type":"integer","minimum":1,"maximum":65536},"rows":{"type":"integer","minimum":1,"maximum":65536},"accepted_positions":{"type":"integer","minimum":0},"rejected_positions":{"type":"integer","minimum":0},"total":{"type":"number","minimum":0},"max":{"type":"number","minimum":0},"weights":{"type":"array","minItems":1,"maxItems":65536,"items":{"type":"array","minItems":1,"maxItems":65536,"items":{"type":"number","minimum":0}}},"normalized":{"type":"array","minItems":1,"maxItems":65536,"items":{"type":"array","minItems":1,"maxItems":65536,"items":{"type":"number","minimum":0,"maximum":1}}},"contains_images":{"type":"boolean","const":false}}}"#,
        "info": #"{"type":"object","additionalProperties":false,"required":["node_id","timestamp_ms","name","firmware","ip","port"],"properties":{"kind":{"type":"string","const":"info"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"name":{"type":"string","minLength":1,"maxLength":48},"firmware":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"},"ip":{"type":"string","pattern":"^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}(?![\\s\\S])"},"port":{"type":"integer","minimum":1,"maximum":65535},"contract":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"}}}"#,
        "network": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","interface","internet","devices"],"properties":{"kind":{"type":"string","const":"network"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"contract":{"type":"integer","minimum":1},"timestamp_ms":{"type":"integer","minimum":0},"interface":{"type":"object","additionalProperties":false,"required":["name","ip","cidr"],"properties":{"name":{"type":"string","minLength":1,"maxLength":64},"ip":{"type":"string","pattern":"^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(?![\\s\\S])"},"cidr":{"type":"string","pattern":"^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])/(?:3[0-2]|[12]?[0-9])(?![\\s\\S])"},"gateway":{"type":"string","pattern":"^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(?![\\s\\S])"},"rx_bps":{"type":"integer","minimum":0},"tx_bps":{"type":"integer","minimum":0}}},"internet":{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"string","enum":["up","degraded","down","lan_down","unknown"]},"since_ms":{"type":"integer","minimum":0},"gateway_ok":{"type":"boolean"},"latency_ms":{"type":"number","minimum":0,"maximum":60000},"loss_percent":{"type":"number","minimum":0,"maximum":100},"probes":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"required":["target","kind","ok"],"properties":{"target":{"type":"string","minLength":1,"maxLength":64},"kind":{"type":"string","enum":["icmp","tcp","dns","http"]},"ok":{"type":"boolean"},"latency_ms":{"type":"number","minimum":0,"maximum":60000}}}},"last_outage":{"type":"object","additionalProperties":false,"required":["started_ms","ended_ms","duration_s"],"properties":{"started_ms":{"type":"integer","minimum":0},"ended_ms":{"type":"integer","minimum":0},"duration_s":{"type":"integer","minimum":0}}},"outages_24h":{"type":"integer","minimum":0},"downtime_24h_s":{"type":"integer","minimum":0,"maximum":86400}}},"devices":{"type":"array","maxItems":512,"items":{"type":"object","additionalProperties":false,"required":["id","ip","online","first_seen_ms","last_seen_ms"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9:._-]{0,63}(?![\\s\\S])"},"ip":{"type":"string","pattern":"^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(?![\\s\\S])"},"mac":{"type":"string","pattern":"^[0-9a-f]{2}(:[0-9a-f]{2}){5}(?![\\s\\S])"},"randomized_mac":{"type":"boolean"},"vendor":{"type":"string","minLength":1,"maxLength":64},"hostname":{"type":"string","minLength":1,"maxLength":64},"kind":{"type":"string","enum":["router","computer","phone","tv","printer","camera","iot","server","nas","network","unknown"]},"os":{"type":"string","minLength":1,"maxLength":32},"online":{"type":"boolean"},"first_seen_ms":{"type":"integer","minimum":0},"last_seen_ms":{"type":"integer","minimum":0},"latency_ms":{"type":"number","minimum":0,"maximum":60000},"ports":{"type":"array","maxItems":64,"items":{"type":"object","additionalProperties":false,"required":["port","proto"],"properties":{"port":{"type":"integer","minimum":1,"maximum":65535},"proto":{"type":"string","enum":["tcp","udp"]},"service":{"type":"string","minLength":1,"maxLength":32},"banner":{"type":"string","minLength":1,"maxLength":80}}}},"services":{"type":"array","maxItems":16,"items":{"type":"string","minLength":1,"maxLength":48}}}}},"events":{"type":"array","maxItems":64,"items":{"type":"object","additionalProperties":false,"required":["id","kind","at_ms"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"kind":{"type":"string","enum":["new_device","device_online","device_offline","ip_changed","arp_conflict","port_opened","port_closed","internet_down","internet_up","gateway_down","gateway_up"]},"at_ms":{"type":"integer","minimum":0},"device_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9:._-]{0,63}(?![\\s\\S])"},"port":{"type":"integer","minimum":1,"maximum":65535},"outage_s":{"type":"integer","minimum":0},"detail":{"type":"string","minLength":1,"maxLength":120}}}},"scan":{"type":"object","additionalProperties":false,"required":["last_ms","hosts"],"properties":{"last_ms":{"type":"integer","minimum":0},"hosts":{"type":"integer","minimum":0,"maximum":1024},"duration_ms":{"type":"integer","minimum":0}}},"public":{"type":"object","additionalProperties":false,"required":["ip","checked_ms"],"properties":{"ip":{"type":"string","maxLength":45},"hostname":{"type":"string","maxLength":128},"city":{"type":"string","maxLength":64},"region":{"type":"string","maxLength":64},"country":{"type":"string","maxLength":64},"org":{"type":"string","maxLength":128},"timezone":{"type":"string","maxLength":64},"checked_ms":{"type":"integer","minimum":0},"changed_ms":{"type":"integer","minimum":0},"dns":{"type":"object","additionalProperties":false,"required":["name","addresses","matches"],"properties":{"name":{"type":"string","minLength":1,"maxLength":253},"addresses":{"type":"array","maxItems":8,"items":{"type":"string","minLength":1,"maxLength":45}},"matches":{"type":"boolean"}}}}},"results":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["id","type","ok","finished_ms"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"type":{"type":"string","enum":["scan_now","ping","traceroute","wake","ports","http","inspect"]},"ok":{"type":"boolean"},"finished_ms":{"type":"integer","minimum":0},"device_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9:._-]{0,63}(?![\\s\\S])"},"output":{"type":"string","maxLength":2000},"ports":{"type":"array","maxItems":64,"items":{"type":"object","additionalProperties":false,"required":["port","proto"],"properties":{"port":{"type":"integer","minimum":1,"maximum":65535},"proto":{"type":"string","enum":["tcp","udp"]},"service":{"type":"string","maxLength":32},"banner":{"type":"string","maxLength":80}}}},"latency_ms":{"type":"number","minimum":0}}}}}}"#,
        "network_orders": #"{"type":"object","additionalProperties":false,"required":["accepted","commands"],"properties":{"accepted":{"type":"boolean","const":true},"commands":{"type":"array","maxItems":4,"items":{"type":"object","additionalProperties":false,"required":["id","type"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"type":{"type":"string","enum":["scan_now","ping","traceroute","wake","ports","http","inspect"]},"device_id":{"type":"string","minLength":1,"maxLength":80},"ip":{"type":"string","pattern":"^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(?![\\s\\S])"},"mac":{"type":"string","pattern":"^[0-9a-f]{2}(:[0-9a-f]{2}){5}(?![\\s\\S])"},"port":{"type":"integer","minimum":1,"maximum":65535},"auth_sealed":{"type":"string","minLength":64,"maxLength":2048,"pattern":"^[A-Za-z0-9+/]+={0,2}(?![\\s\\S])"}}}}}}"#,
        "node_control_command": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","command_id","action","operation","mode","requested_by"],"properties":{"kind":{"type":"string","const":"node_control_command"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"action":{"type":"string","enum":["arm","execute"]},"operation":{"type":"string","enum":["restart","pause","resume","standby","identify","diagnostics","maintenance_on","maintenance_off"]},"mode":{"type":"string","enum":["now","rolling"]},"delay_s":{"type":"integer","minimum":0,"maximum":600},"slot":{"type":"integer","minimum":0,"maximum":63},"duration_s":{"type":"integer","minimum":1,"maximum":86400},"token":{"type":"string","pattern":"^[a-z0-9]{16,32}(?![\\s\\S])"},"requested_by":{"type":"string","pattern":"^[A-Za-z0-9._@ -]{1,64}(?![\\s\\S])"},"detail":{"type":"string","enum":["package","log"]}}}"#,
        "node_control_result": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","command_id","action","operation","stage","accepted","refusal"],"properties":{"kind":{"type":"string","const":"node_control_result"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"action":{"type":"string","enum":["arm","execute"]},"operation":{"type":"string","enum":["restart","pause","resume","standby","identify","diagnostics","maintenance_on","maintenance_off"]},"stage":{"type":"string","enum":["armed","restarting","applied","diagnostics","rejected"]},"accepted":{"type":"boolean"},"refusal":{"type":"string","enum":["none","not_armed","invalid_token","token_expired","rate_limited","already_restarting","already_in_state","busy_update","busy_upload","busy_slot_copy","busy_battery","unavailable"]},"token":{"type":"string","pattern":"^[a-z0-9]{16,32}(?![\\s\\S])"},"token_ttl_s":{"type":"integer","minimum":1,"maximum":120},"reason":{"type":"string","enum":["requested_by_server"]},"mode":{"type":"string","enum":["now","rolling"]},"restart_in_s":{"type":"integer","minimum":0,"maximum":3600},"uptime_s":{"type":"integer","minimum":0},"firmware":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"},"requested_by":{"type":"string","pattern":"^[A-Za-z0-9._@ -]{1,64}(?![\\s\\S])"},"state":{"type":"string","enum":["running","paused","standby"]},"maintenance":{"type":"boolean"},"until_s":{"type":"integer","minimum":0,"maximum":86400},"since_ms":{"type":"integer","minimum":0},"diagnostics":{"type":"object","additionalProperties":false,"required":["firmware","uptime_s","reset_reason","heap_free","heap_min","mqtt_connected","state","maintenance"],"properties":{"firmware":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"},"uptime_s":{"type":"integer","minimum":0},"reset_reason":{"type":"string","enum":["power_on","external","software","panic","int_wdt","task_wdt","other_wdt","deep_sleep","brownout","sdio","usb","jtag","efuse","power_glitch","cpu_lockup","unknown"]},"heap_free":{"type":"integer","minimum":0},"heap_min":{"type":"integer","minimum":0},"psram_free":{"type":"integer","minimum":0},"stack_min_free":{"type":"integer","minimum":0},"rssi":{"type":"integer","minimum":-120,"maximum":0},"mqtt_connected":{"type":"boolean"},"state":{"type":"string","enum":["running","paused","standby"]},"maintenance":{"type":"boolean"},"package":{"type":"object","additionalProperties":false,"required":["detail","log","truncated"],"properties":{"detail":{"type":"string","enum":["package","log"]},"heap":{"type":"object","additionalProperties":false,"required":["internal_free","internal_min","internal_largest","total_free","total_min"],"properties":{"internal_free":{"type":"integer","minimum":0},"internal_min":{"type":"integer","minimum":0},"internal_largest":{"type":"integer","minimum":0},"total_free":{"type":"integer","minimum":0},"total_min":{"type":"integer","minimum":0},"psram_free":{"type":"integer","minimum":0}}},"tasks":{"type":"array","maxItems":40,"items":{"type":"object","additionalProperties":false,"required":["name","stack_free","priority","state"],"properties":{"name":{"type":"string","minLength":1,"maxLength":15},"stack_free":{"type":"integer","minimum":0},"priority":{"type":"integer","minimum":0,"maximum":63},"state":{"type":"string","enum":["R","r","B","S","D","?"]}}}},"resets":{"type":"object","additionalProperties":false,"required":["reason","uptime_s","guard_restarts_in_hour"],"properties":{"reason":{"type":"string","enum":["power_on","external","software","panic","int_wdt","task_wdt","other_wdt","deep_sleep","brownout","sdio","usb","jtag","efuse","power_glitch","cpu_lockup","unknown"]},"uptime_s":{"type":"integer","minimum":0},"guard_restarts_in_hour":{"type":"integer","minimum":0,"maximum":3}}},"boot":{"type":"object","additionalProperties":false,"required":["cause","reset_reason","coredump","deliberate","guard"],"properties":{"cause":{"type":"string","enum":["panic","task_watchdog","interrupt_watchdog","other_watchdog","brownout","power_glitch","cpu_lockup","out_of_memory","guard_missing_task","guard_low_memory","guard_dead_man","guard"]},"reset_reason":{"type":"string","enum":["power_on","external","software","panic","int_wdt","task_wdt","other_wdt","deep_sleep","brownout","sdio","usb","jtag","efuse","power_glitch","cpu_lockup","unknown"]},"uptime_before_s":{"type":"integer","minimum":0},"heap_internal_free":{"type":"integer","minimum":0},"heap_internal_largest":{"type":"integer","minimum":0},"coredump":{"type":"boolean"},"deliberate":{"type":"boolean"},"guard":{"type":"boolean"}}},"memory_gate":{"type":"object","additionalProperties":false,"required":["closed","transitions","close_free","close_block","open_free","open_block"],"properties":{"closed":{"type":"boolean"},"transitions":{"type":"integer","minimum":0},"close_free":{"type":"integer","minimum":0},"close_block":{"type":"integer","minimum":0},"open_free":{"type":"integer","minimum":0},"open_block":{"type":"integer","minimum":0}}},"versions":{"type":"object","additionalProperties":false,"required":["firmware","idf","sensors"],"properties":{"firmware":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"},"idf":{"type":"string","maxLength":32},"board":{"type":"string","minLength":1,"maxLength":32},"sensors":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"required":["name","version"],"properties":{"name":{"type":"string","maxLength":32},"version":{"type":"string","maxLength":32}}}}}},"config":{"type":"object","maxProperties":64,"additionalProperties":{"type":"string","maxLength":96}},"coredump":{"type":"object","additionalProperties":false,"required":["present"],"properties":{"present":{"type":"boolean"},"size":{"type":"integer","minimum":1},"summary":{"type":"object","additionalProperties":false,"required":["task"],"properties":{"task":{"type":"string","maxLength":16},"reason":{"type":"string","maxLength":96},"pc":{"type":"string","pattern":"^0x[0-9a-fA-F]{1,16}(?![\\s\\S])"},"backtrace":{"type":"array","maxItems":16,"items":{"type":"string","pattern":"^0x[0-9a-fA-F]{1,16}(?![\\s\\S])"}},"app_sha256":{"type":"string","maxLength":16}}}}},"log":{"type":"string","maxLength":6000},"truncated":{"type":"boolean"}}}}}}}"#,
        "node_health": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","family","firmware","uptime_s","reset_reason","heap_free","heap_min","link","link_up","broker_reconnects"],"properties":{"kind":{"type":"string","const":"node_health"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"family":{"type":"string","enum":["radar","solar","electrical","alarm","hmi"]},"firmware":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"},"contract":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"},"board":{"type":"string","minLength":1,"maxLength":32},"uptime_s":{"type":"integer","minimum":0},"reset_reason":{"type":"string","enum":["power_on","external","software","panic","int_wdt","task_wdt","other_wdt","deep_sleep","brownout","sdio","usb","jtag","efuse","power_glitch","cpu_lockup","unknown"]},"heap_free":{"type":"integer","minimum":0},"heap_min":{"type":"integer","minimum":0},"heap_internal_free":{"type":"integer","minimum":0},"heap_internal_min":{"type":"integer","minimum":0},"heap_internal_largest":{"type":"integer","minimum":0},"psram_free":{"type":"integer","minimum":0},"link":{"type":"string","enum":["wifi","ethernet","none"]},"link_up":{"type":"boolean"},"rssi_dbm":{"type":"integer","minimum":-120,"maximum":0},"broker_reconnects":{"type":"integer","minimum":0},"low_stack_tasks":{"type":"integer","minimum":0,"maximum":64},"last_error":{"type":"string","minLength":1,"maxLength":96},"control_state":{"type":"string","enum":["running","paused","standby"]},"control_since_ms":{"type":"integer","minimum":0},"control_by":{"type":"string","pattern":"^[A-Za-z0-9._@ -]{1,64}(?![\\s\\S])"},"control_until_s":{"type":"integer","minimum":0,"maximum":86400},"maintenance":{"type":"boolean"},"maintenance_until_s":{"type":"integer","minimum":0,"maximum":86400},"boot":{"type":"object","additionalProperties":false,"required":["cause","reset_reason","coredump","deliberate","guard"],"properties":{"cause":{"type":"string","enum":["panic","task_watchdog","interrupt_watchdog","other_watchdog","brownout","power_glitch","cpu_lockup","out_of_memory","guard_missing_task","guard_low_memory","guard_dead_man","guard"]},"reset_reason":{"type":"string","enum":["power_on","external","software","panic","int_wdt","task_wdt","other_wdt","deep_sleep","brownout","sdio","usb","jtag","efuse","power_glitch","cpu_lockup","unknown"]},"uptime_before_s":{"type":"integer","minimum":0},"heap_internal_free":{"type":"integer","minimum":0},"heap_internal_largest":{"type":"integer","minimum":0},"coredump":{"type":"boolean"},"deliberate":{"type":"boolean"},"guard":{"type":"boolean"}}},"memory_gate":{"type":"object","additionalProperties":false,"required":["closed","transitions","close_free","close_block","open_free","open_block"],"properties":{"closed":{"type":"boolean"},"transitions":{"type":"integer","minimum":0},"close_free":{"type":"integer","minimum":0},"close_block":{"type":"integer","minimum":0},"open_free":{"type":"integer","minimum":0},"open_block":{"type":"integer","minimum":0}}},"coredump":{"type":"object","additionalProperties":false,"required":["present"],"properties":{"present":{"type":"boolean"},"size":{"type":"integer","minimum":1}}},"config_check":{"type":"object","additionalProperties":false,"properties":{"snapshot":{"type":"string","enum":["restored","failed"]},"reverted":{"type":"string","enum":["reapplied","failed"]}}},"sensors":{"type":"array","maxItems":3,"items":{"type":"object","additionalProperties":false,"required":["sensor_id","model","state","firmware_known","bluetooth"],"properties":{"sensor_id":{"type":"integer","minimum":1,"maximum":3},"model":{"type":"string","enum":["ld2450","ld2461","ld2410","ld2412","ld2410s","mr24hpc1"]},"state":{"type":"string","enum":["reporting","no_data","garbled","silent","bridge"]},"firmware_known":{"type":"boolean"},"firmware":{"type":"string","pattern":"^[0-9A-Za-z._:-]{1,24}(?![\\s\\S])"},"bluetooth":{"type":"string","enum":["unknown","open","closed","none"]},"mac":{"type":"string","pattern":"^[0-9A-Za-z:._-]{1,17}(?![\\s\\S])"},"bluetooth_alert":{"type":"boolean"},"quirk":{"type":"string","enum":["ld2412_bad_firmware","ld2412_unknown_firmware"]}}}},"radar":{"type":"object","additionalProperties":false,"required":["perimeter_enabled","masked","wifi_jam","bridge_open","events_buffered","sensor_bluetooth_off"],"properties":{"perimeter_enabled":{"type":"boolean"},"masked":{"type":"boolean"},"wifi_jam":{"type":"boolean"},"bridge_open":{"type":"boolean"},"events_buffered":{"type":"integer","minimum":0,"maximum":1000},"sensor_bluetooth_off":{"type":"boolean"}}}}}"#,
        "node_maintenance": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","active","reason","firmware"],"properties":{"kind":{"type":"string","const":"node_maintenance"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"active":{"type":"boolean"},"reason":{"type":"string","enum":["restart","pause","standby","update","upload","operator"]},"expected_s":{"type":"integer","minimum":1,"maximum":3600},"firmware":{"type":"string","pattern":"^[0-9]+[.][0-9]+[.][0-9]+([.][0-9]+)?(?![\\s\\S])"},"requested_by":{"type":"string","pattern":"^[A-Za-z0-9._@ -]{1,64}(?![\\s\\S])"}}}"#,
        "radar_event": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","boot","seq","event"],"properties":{"kind":{"type":"string","const":"radar_event"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"boot":{"type":"integer","minimum":0,"maximum":4294967295},"seq":{"type":"integer","minimum":1,"maximum":4294967295},"event":{"type":"string","enum":["zone_occupied","zone_clear","loiter","tripwire","path_violation","masking","masking_end","sensor_bluetooth_open","sensor_bluetooth_closed","wifi_jam","wifi_jam_end","bridge_opened","bridge_closed"]},"name":{"type":"string","minLength":1,"maxLength":24},"sensor_id":{"type":"integer","minimum":1,"maximum":3},"track_id":{"type":"integer","minimum":1,"maximum":255},"movement":{"type":"string","enum":["still","walking","running"]},"value":{"type":"integer","minimum":0},"count":{"type":"integer","minimum":0},"direction":{"type":"string","enum":["in","out"]},"from":{"type":"string","minLength":1,"maxLength":24},"by":{"type":"string","pattern":"^[A-Za-z0-9._-]{1,32}(?![\\s\\S])"}}}"#,
        "server_alert": #"{"type":"object","additionalProperties":false,"required":["service","event","at","mode"],"properties":{"service":{"type":"string","const":"armor-server"},"event":{"type":"string","enum":["alert.raised","alert.cleared","node.offline","node.stale","camera.offline","alarm.raised","alarm.escalated","automation.notify","login.remote","alert.test"]},"at":{"type":"string","minLength":1,"maxLength":40},"mode":{"type":"string","enum":["armed","disarmed"]},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"camera_id":{"type":"string","minLength":1,"maxLength":80},"targets":{"type":"integer","minimum":0},"minutes":{"type":"integer","minimum":0},"alarm_id":{"type":"string","minLength":1,"maxLength":80},"severity":{"type":"string","enum":["critical","high","warning"]},"code":{"type":"string","pattern":"^[a-z][a-z0-9_]{0,63}(?![\\s\\S])"},"device_id":{"type":"string","minLength":1,"maxLength":80},"solar_id":{"type":"string","minLength":1,"maxLength":80},"electrical_id":{"type":"string","minLength":1,"maxLength":80},"alarm_node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"network_id":{"type":"string","minLength":1,"maxLength":80},"silent":{"type":"boolean","const":true},"automation":{"type":"string","minLength":1,"maxLength":80},"login_user":{"type":"string","minLength":1,"maxLength":80},"login_from":{"type":"string","minLength":1,"maxLength":64},"login_country":{"type":"string","pattern":"^[A-Z]{2}(?![\\s\\S])"},"login_country_new":{"type":"boolean","const":true}}}"#,
        "solar_battery": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","device","timestamp_ms","modules","stack"],"properties":{"kind":{"type":"string","const":"battery"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"device":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"modules":{"type":"integer","minimum":0,"maximum":16},"state":{"type":"string","enum":["charging","discharging","idle"]},"voltage_v":{"type":"number","minimum":0,"maximum":1000},"current_a":{"type":"number","minimum":-1000,"maximum":1000},"temperature_min_c":{"type":"number","minimum":-50,"maximum":200},"temperature_max_c":{"type":"number","minimum":-50,"maximum":200},"cell_min_v":{"type":"number","minimum":0,"maximum":10},"cell_max_v":{"type":"number","minimum":0,"maximum":10},"soc_percent":{"type":"integer","minimum":0,"maximum":100},"alarm":{"type":"boolean"},"stack":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["n","present"],"properties":{"n":{"type":"integer","minimum":1,"maximum":16},"present":{"type":"boolean"},"voltage_v":{"type":"number","minimum":0,"maximum":1000},"current_a":{"type":"number","minimum":-1000,"maximum":1000},"temperature_c":{"type":"number","minimum":-50,"maximum":200},"soc_percent":{"type":"integer","minimum":0,"maximum":100},"state":{"type":"string","minLength":1,"maxLength":16},"cells_v":{"type":"array","maxItems":32,"items":{"type":"number","minimum":0,"maximum":10}},"counters":{"type":"object","maxProperties":48,"propertyNames":{"pattern":"^[a-z][a-z0-9_]{0,31}(?![\\s\\S])"},"additionalProperties":{"type":"integer","minimum":0,"maximum":9999999999}},"temperatures_c":{"type":"array","maxItems":8,"items":{"type":"number","minimum":-50,"maximum":200}},"capacity_ah":{"type":"number","minimum":0,"maximum":100000},"full_capacity_ah":{"type":"number","minimum":0,"maximum":100000},"cycles":{"type":"integer","minimum":0,"maximum":1000000},"health_percent":{"type":"integer","minimum":0,"maximum":100},"model":{"type":"string","minLength":1,"maxLength":24},"cell_count":{"type":"integer","minimum":1,"maximum":32},"max_charge_a":{"type":"number","minimum":0,"maximum":1000},"max_discharge_a":{"type":"number","minimum":0,"maximum":1000},"console_baud":{"type":"integer","minimum":300,"maximum":1000000},"soh_counts":{"type":"array","maxItems":32,"items":{"type":"integer","minimum":0,"maximum":1000000}},"soh_abnormal":{"type":"array","maxItems":32,"items":{"type":"integer","minimum":0,"maximum":31}},"last_event":{"type":"object","additionalProperties":false,"required":["index","time"],"properties":{"index":{"type":"integer","minimum":0,"maximum":1000000},"time":{"type":"string","minLength":1,"maxLength":40},"voltage_v":{"type":"number","minimum":0,"maximum":1000},"current_a":{"type":"number","minimum":-1000,"maximum":1000},"temperature_c":{"type":"number","minimum":-50,"maximum":200},"percent":{"type":"integer","minimum":0,"maximum":100},"base_state":{"type":"string","minLength":1,"maxLength":40},"voltage_state":{"type":"string","minLength":1,"maxLength":40},"current_state":{"type":"string","minLength":1,"maxLength":40},"temperature_state":{"type":"string","minLength":1,"maxLength":40},"coulomb_state":{"type":"string","minLength":1,"maxLength":40},"power_events":{"type":"string","minLength":1,"maxLength":40},"battery_events":{"type":"string","minLength":1,"maxLength":40},"system_fault":{"type":"string","minLength":1,"maxLength":40}}},"board_version":{"type":"string","minLength":1,"maxLength":24},"main_soft_version":{"type":"string","minLength":1,"maxLength":24},"soft_version":{"type":"string","minLength":1,"maxLength":24}}}},"model":{"type":"string","minLength":1,"maxLength":24},"capacity_ah":{"type":"number","minimum":0,"maximum":100000},"full_capacity_ah":{"type":"number","minimum":0,"maximum":100000},"energy_kwh":{"type":"number","minimum":0,"maximum":10000},"cycles":{"type":"integer","minimum":0,"maximum":1000000},"health_percent":{"type":"integer","minimum":0,"maximum":100},"power_w":{"type":"number","minimum":-1000000,"maximum":1000000},"balancing":{"type":"integer","minimum":0,"maximum":64},"protecting":{"type":"boolean"},"charge_mos":{"type":"integer","minimum":0,"maximum":255},"discharge_mos":{"type":"integer","minimum":0,"maximum":255}}}"#,
        "solar_battery_command": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","command_id","port","action"],"properties":{"kind":{"type":"string","const":"solar_battery_command"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"port":{"type":"integer","minimum":1,"maximum":10},"action":{"type":"string","enum":["arm","execute","cancel","stage"]},"op":{"type":"string","enum":["set_clock","clear_stats","clear_log","clear_data","restart","shutdown","soc_capacity","mosfail_test","soc_reset","pcb_setup","limits_set","limits_default","protections_set","protections_default","output_set","fault_clear","write_barcode","eeprom_erase","firmware_update","expert_command"]},"params":{"type":"object","additionalProperties":false,"properties":{"which":{"type":"string","enum":["event","history"]},"group":{"type":"string","enum":["module_voltage","cell_voltage","temperature"]},"values":{"type":"object","additionalProperties":false,"properties":{"pov":{"type":"integer","minimum":-40000,"maximum":100000},"povr":{"type":"integer","minimum":-40000,"maximum":100000},"phv":{"type":"integer","minimum":-40000,"maximum":100000},"phvr":{"type":"integer","minimum":-40000,"maximum":100000},"plv":{"type":"integer","minimum":-40000,"maximum":100000},"plvr":{"type":"integer","minimum":-40000,"maximum":100000},"puv":{"type":"integer","minimum":-40000,"maximum":100000},"puvr":{"type":"integer","minimum":-40000,"maximum":100000},"pslp":{"type":"integer","minimum":-40000,"maximum":100000},"bov":{"type":"integer","minimum":-40000,"maximum":100000},"bovr":{"type":"integer","minimum":-40000,"maximum":100000},"bhv":{"type":"integer","minimum":-40000,"maximum":100000},"bhvr":{"type":"integer","minimum":-40000,"maximum":100000},"blv":{"type":"integer","minimum":-40000,"maximum":100000},"blvr":{"type":"integer","minimum":-40000,"maximum":100000},"buv":{"type":"integer","minimum":-40000,"maximum":100000},"buvr":{"type":"integer","minimum":-40000,"maximum":100000},"bslp":{"type":"integer","minimum":-40000,"maximum":100000},"cot":{"type":"integer","minimum":-40000,"maximum":100000},"cotr":{"type":"integer","minimum":-40000,"maximum":100000},"cht":{"type":"integer","minimum":-40000,"maximum":100000},"chtr":{"type":"integer","minimum":-40000,"maximum":100000},"clt":{"type":"integer","minimum":-40000,"maximum":100000},"cltr":{"type":"integer","minimum":-40000,"maximum":100000},"cut":{"type":"integer","minimum":-40000,"maximum":100000},"cutr":{"type":"integer","minimum":-40000,"maximum":100000}}},"items":{"type":"object","additionalProperties":false,"properties":{"bov":{"type":"string","enum":["en","dis"]},"bhv":{"type":"string","enum":["en","dis"]},"blv":{"type":"string","enum":["en","dis"]},"buv":{"type":"string","enum":["en","dis"]},"bslp":{"type":"string","enum":["en","dis"]},"pov":{"type":"string","enum":["en","dis"]},"phv":{"type":"string","enum":["en","dis"]},"plv":{"type":"string","enum":["en","dis"]},"puv":{"type":"string","enum":["en","dis"]},"pslp":{"type":"string","enum":["en","dis"]},"coc":{"type":"string","enum":["en","dis"]},"coc2":{"type":"string","enum":["en","dis"]},"doc":{"type":"string","enum":["en","dis"]},"doc2":{"type":"string","enum":["en","dis"]}}},"accept_risk":{"type":"boolean"},"output":{"type":"string","enum":["cfet","dfet","buzz","heat"]},"state":{"type":"string","enum":["on","off"]},"serial":{"type":"string","pattern":"^[A-Za-z0-9_-]{10,24}(?![\\s\\S])"},"restore_barcode":{"type":"boolean"},"image_size":{"type":"integer","minimum":65536,"maximum":524288},"image_crc32":{"type":"integer","minimum":0,"maximum":4294967295},"image_version":{"type":"string","minLength":1,"maxLength":12},"clear_eeprom":{"type":"boolean"},"line":{"type":"string","minLength":1,"maxLength":48}}},"serial":{"type":"string","pattern":"^[A-Za-z0-9_-]{8,24}(?![\\s\\S])"},"token":{"type":"string","pattern":"^[0-9a-f]{32}(?![\\s\\S])"},"stage":{"type":"object","additionalProperties":false,"required":["id","index","total","size","crc32","data"],"properties":{"id":{"type":"string","pattern":"^[a-z0-9]{8,32}(?![\\s\\S])"},"index":{"type":"integer","minimum":0,"maximum":2047},"total":{"type":"integer","minimum":1,"maximum":2048},"size":{"type":"integer","minimum":65536,"maximum":524288},"crc32":{"type":"integer","minimum":0,"maximum":4294967295},"data":{"type":"string","minLength":4,"maxLength":344,"pattern":"^[A-Za-z0-9+/]+={0,2}(?![\\s\\S])"}}}}}"#,
        "solar_battery_result": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","timestamp_ms","command_id","port","action","stage","accepted","refusal"],"properties":{"kind":{"type":"string","const":"solar_battery_result"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"command_id":{"type":"string","pattern":"^[0-9a-f]{16}(?![\\s\\S])"},"port":{"type":"integer","minimum":1,"maximum":10},"action":{"type":"string","enum":["arm","execute","cancel","stage"]},"op":{"type":"string","maxLength":32},"stage":{"type":"string","enum":["armed","started","progress","cancel_requested","final","rejected","staged"]},"accepted":{"type":"boolean"},"refusal":{"type":"string","enum":["none","disabled","invalid_params","unknown_op","not_pylontech","no_battery","unknown_model","unknown_firmware","serial_mismatch","serial_unreadable","not_idle","critical_alarm","busy","cooldown","locked","not_armed","bad_token","expired","chip_unknown","image_missing","image_mismatch","unsupported_model","no_official_value","risk_not_accepted","expert_blocked","no_password","battery_changed","clock_not_set","not_cancellable","no_memory","no_answer","login_failed","preflight_failed","stage_invalid","stage_order","stage_data","stage_size","stage_crc"]},"token":{"type":"string","pattern":"^[0-9a-f]{32}(?![\\s\\S])"},"canonical":{"type":"string","maxLength":600},"summary":{"type":"string","maxLength":300},"risk":{"type":"string","enum":["low","medium","high","irreversible"]},"atomic":{"type":"boolean"},"battery":{"type":"object","additionalProperties":false,"required":["model","serial","soft_version","board"],"properties":{"model":{"type":"string","maxLength":24},"serial":{"type":"string","maxLength":32},"soft_version":{"type":"string","maxLength":24},"board":{"type":"string","maxLength":24},"capacity_ah":{"type":"integer","minimum":0,"maximum":1000}}},"snapshot_before":{"type":"string","maxLength":4000},"outcome":{"type":"string","enum":["running","ok","failed","partial","retry","rejected"]},"code":{"type":"string","maxLength":96},"steps_done":{"type":"integer","minimum":0,"maximum":200},"steps_total":{"type":"integer","minimum":0,"maximum":200},"writes_done":{"type":"integer","minimum":0,"maximum":200},"packets_sent":{"type":"integer","minimum":0,"maximum":2048},"packets_total":{"type":"integer","minimum":0,"maximum":2048},"truncated":{"type":"boolean"},"before":{"type":"string","maxLength":4000},"after":{"type":"string","maxLength":4000},"transcript":{"type":"string","maxLength":8000},"received":{"type":"integer","minimum":0,"maximum":524288}}}"#,
        "solar_inverter": #"{"type":"object","additionalProperties":false,"required":["kind","node_id","device","timestamp_ms","mode","grid_v","grid_hz","out_v","out_hz","out_va","out_w","load_percent","battery_v","battery_a","battery_percent","pv_v","pv_a","pv_w","heatsink_c","ac_charging","pv_charging","load_on","warnings"],"properties":{"kind":{"type":"string","const":"inverter"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"device":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"mode":{"type":"string","enum":["power_on","standby","line","battery","fault","power_saving","shutdown","unknown"]},"grid_v":{"type":"number","minimum":0,"maximum":600},"grid_hz":{"type":"number","minimum":0,"maximum":100},"out_v":{"type":"number","minimum":0,"maximum":600},"out_hz":{"type":"number","minimum":0,"maximum":100},"out_va":{"type":"number","minimum":0,"maximum":100000},"out_w":{"type":"number","minimum":0,"maximum":100000},"load_percent":{"type":"number","minimum":0,"maximum":200},"battery_v":{"type":"number","minimum":0,"maximum":1000},"battery_a":{"type":"number","minimum":-1000,"maximum":1000},"battery_percent":{"type":"number","minimum":0,"maximum":100},"pv_v":{"type":"number","minimum":0,"maximum":1500},"pv_a":{"type":"number","minimum":0,"maximum":500},"pv_w":{"type":"number","minimum":0,"maximum":100000},"heatsink_c":{"type":"number","minimum":-50,"maximum":200},"ac_charging":{"type":"boolean"},"pv_charging":{"type":"boolean"},"load_on":{"type":"boolean"},"warnings":{"type":"array","maxItems":32,"items":{"type":"string","pattern":"^[a-z][a-z0-9_]{0,39}(?![\\s\\S])"}},"warnings_known":{"type":"boolean"},"clamped":{"type":"array","maxItems":16,"items":{"type":"string","maxLength":32}},"pv2_v":{"type":"number","minimum":0,"maximum":1500},"pv2_a":{"type":"number","minimum":0,"maximum":500},"pv2_w":{"type":"number","minimum":0,"maximum":100000},"total_out_w":{"type":"number","minimum":0,"maximum":1000000},"total_out_va":{"type":"number","minimum":0,"maximum":1000000},"total_load_percent":{"type":"number","minimum":0,"maximum":200},"total_charging_a":{"type":"number","minimum":0,"maximum":10000},"units":{"type":"array","maxItems":10,"items":{"type":"object","additionalProperties":false,"required":["unit","mode"],"properties":{"unit":{"type":"integer","minimum":0,"maximum":9},"serial":{"type":"string","maxLength":24},"mode":{"type":"string","enum":["power_on","standby","line","battery","fault","power_saving","shutdown","unknown"]},"fault_code":{"type":"string","pattern":"^[0-9]{2}(?![\\s\\S])"},"grid_v":{"type":"number","minimum":0,"maximum":600},"out_v":{"type":"number","minimum":0,"maximum":600},"out_va":{"type":"number","minimum":0,"maximum":100000},"out_w":{"type":"number","minimum":0,"maximum":100000},"load_percent":{"type":"number","minimum":0,"maximum":200},"battery_v":{"type":"number","minimum":0,"maximum":1000},"battery_percent":{"type":"number","minimum":0,"maximum":100},"pv_v":{"type":"number","minimum":0,"maximum":1500},"charging_a":{"type":"number","minimum":0,"maximum":1000}}}},"bus_v":{"type":"number","minimum":0,"maximum":1500},"serial":{"type":"string","pattern":"^[0-9A-Za-z]{8,20}(?![\\s\\S])"},"firmware":{"type":"string","pattern":"^[0-9A-Za-z._-]{1,24}(?![\\s\\S])"},"pv_energy_total_wh":{"type":"number","minimum":0,"maximum":1000000000000.0},"ratings":{"type":"object","additionalProperties":false,"properties":{"grid_rating_v":{"type":"number","minimum":0,"maximum":600},"out_rating_v":{"type":"number","minimum":0,"maximum":600},"out_rating_hz":{"type":"number","minimum":0,"maximum":100},"out_rating_va":{"type":"number","minimum":0,"maximum":1000000},"out_rating_w":{"type":"number","minimum":0,"maximum":1000000},"battery_rating_v":{"type":"number","minimum":0,"maximum":600},"battery_recharge_v":{"type":"number","minimum":0,"maximum":600},"battery_under_v":{"type":"number","minimum":0,"maximum":600},"battery_bulk_v":{"type":"number","minimum":0,"maximum":600},"battery_float_v":{"type":"number","minimum":0,"maximum":600},"max_charge_a":{"type":"number","minimum":0,"maximum":2000},"max_ac_charge_a":{"type":"number","minimum":0,"maximum":2000},"battery_type":{"type":"string","enum":["agm","flooded","user"]},"input_range":{"type":"string","enum":["appliance","ups"]},"output_priority":{"type":"string","enum":["utility_first","solar_first","sbu"]},"charger_priority":{"type":"string","enum":["utility_first","solar_first","solar_and_utility","solar_only"]}}}}}"#,
        "system_event": #"{"type":"object","additionalProperties":false,"required":["id","at","type","category","action"],"properties":{"id":{"type":"integer","minimum":1},"at":{"type":"string","minLength":1,"maxLength":40},"type":{"type":"string","const":"system"},"category":{"type":"string","enum":["node","broker","settings","service","update","alarm","backup","batteries"]},"action":{"type":"string","enum":["appeared","returned","disappeared","firmware_changed","connected","disconnected","created","changed","removed","started","stopped","restarted","checked","installed","rolled_back","armed","disarmed","silenced","acknowledged","arm_requested","disarm_requested","silence_requested","backup_made","backup_restored","battery_requested","battery_operation","control_requested","control_acknowledged","control_refused","control_applied","control_back","control_lost","maintenance_started","maintenance_ended","maintenance_expired","dirty_boot","sensor_bluetooth_open","sensor_bluetooth_closed","radar_event","diagnostic_token_issued","diagnostic_token_revoked","diagnostic_token_used","diagnostic_token_denied"]},"subject":{"type":"string","minLength":1,"maxLength":80},"by":{"type":"string","minLength":1,"maxLength":60},"version":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"},"previous_version":{"type":"string","pattern":"^[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?(?![\\s\\S])"},"profile":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,31}(?![\\s\\S])"},"outcome":{"type":"string","enum":["allowed","denied","failed"]}}}"#,
        "telemetry": #"{"type":"object","additionalProperties":false,"required":["node_id","timestamp_ms","lux","targets"],"properties":{"kind":{"type":"string","const":"telemetry"},"node_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9_-]{0,63}(?![\\s\\S])"},"timestamp_ms":{"type":"integer","minimum":0},"lux":{"type":"number","minimum":0,"maximum":200000},"targets":{"type":"array","maxItems":15,"items":{"type":"object","additionalProperties":false,"required":["sensor_id","track_id","x_mm","y_mm","speed_mm_s"],"properties":{"sensor_id":{"type":"integer","minimum":1,"maximum":3},"track_id":{"type":"integer","minimum":1},"x_mm":{"type":"number"},"y_mm":{"type":"number"},"speed_mm_s":{"type":"number"}}}}}}"#,
        "vision_event": #"{"type":"object","additionalProperties":false,"required":["schema","type","camera_id","zone_id","zone_name","track_id","label","confidence","box","timestamp","timestamp_ms","authorizes_action"],"properties":{"schema":{"type":"string","enum":["armor.vision.event/v1","armor.vision.event/v2"]},"type":{"type":"string","enum":["alert","detection"]},"camera_id":{"type":"string","pattern":"^[A-Za-z0-9._-]{3,80}(?![\\s\\S])"},"zone_id":{"type":"string","minLength":1,"maxLength":80},"zone_name":{"type":"string","minLength":1,"maxLength":120},"track_id":{"type":"integer","minimum":1},"label":{"type":"string","minLength":1,"maxLength":60},"confidence":{"type":"number","minimum":0,"maximum":1},"box":{"type":"array","minItems":4,"maxItems":4,"items":{"type":"number","minimum":0,"maximum":1}},"timestamp":{"type":"number","minimum":0},"timestamp_ms":{"type":"integer","minimum":0},"authorizes_action":{"type":"boolean","const":false},"radar_tracks":{"type":"integer","minimum":0,"maximum":1000},"vectors":{"type":"array","maxItems":16,"items":{"type":"object","additionalProperties":false,"required":["track_id","dx","dy","speed"],"properties":{"track_id":{"type":"integer","minimum":1},"dx":{"type":"number","minimum":-1,"maximum":1},"dy":{"type":"number","minimum":-1,"maximum":1},"speed":{"type":"number","minimum":0,"maximum":100}}}}}}"#,
        "voice_turn_meta": #"{"type":"object","additionalProperties":false,"required":["language","encoding","sample_rate","channels"],"properties":{"language":{"type":"string","enum":["en","es","de","fr","it","ja","zh","pt"]},"encoding":{"type":"string","enum":["pcm_s16le"]},"sample_rate":{"type":"integer","enum":[16000]},"channels":{"type":"integer","enum":[1]},"reply_audio":{"type":"string","enum":["base64","binary","none"]}}}"#,
        "voice_turn_result": #"{"type":"object","additionalProperties":false,"required":["heard","reply"],"properties":{"heard":{"type":"string","maxLength":2000},"reply":{"type":"string","maxLength":2000},"audio":{"type":"string","pattern":"^[A-Za-z0-9+/]*={0,2}(?![\\s\\S])","maxLength":1400000},"audio_omitted":{"type":"string","enum":["too_large"]},"challenge":{"type":"string","pattern":"^[0-9]{2,6}(?![\\s\\S])"}}}"#,
    ]

    // MARK: the messages

    public struct RadarTrack {
        public var sensor_id: Int64
        public var track_id: Int64
        public var x_mm: Double
        public var y_mm: Double
        public var speed_mm_s: Double
        public init(sensor_id: Int64, track_id: Int64, x_mm: Double, y_mm: Double, speed_mm_s: Double) {
            self.sensor_id = sensor_id
            self.track_id = track_id
            self.x_mm = x_mm
            self.y_mm = y_mm
            self.speed_mm_s = speed_mm_s
        }
    }

    public struct Telemetry {
        public var kind: String?
        public var node_id: String
        public var timestamp_ms: Int64
        public var lux: Double
        public var targets: [RadarTrack]
        public init(kind: String? = nil, node_id: String, timestamp_ms: Int64, lux: Double, targets: [RadarTrack]) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.lux = lux
            self.targets = targets
        }
    }

    public struct Health {
        public var node_id: String
        public var timestamp_ms: Int64
        public var online: Bool
        public var kind: String?
        public init(node_id: String, timestamp_ms: Int64, online: Bool, kind: String? = nil) {
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.online = online
            self.kind = kind
        }
    }

    public struct Command {
        public var kind: String?
        public var node_id: String
        public var timestamp_ms: Int64
        public var command: String
        public var sensitivity: Int64?
        public init(kind: String? = nil, node_id: String, timestamp_ms: Int64, command: String, sensitivity: Int64? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command = command
            self.sensitivity = sensitivity
        }
    }

    public struct Info {
        public var kind: String?
        public var node_id: String
        public var timestamp_ms: Int64
        public var name: String
        public var firmware: String
        public var ip: String
        public var port: Int64
        public var contract: String?
        public init(kind: String? = nil, node_id: String, timestamp_ms: Int64, name: String, firmware: String, ip: String, port: Int64, contract: String? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.name = name
            self.firmware = firmware
            self.ip = ip
            self.port = port
            self.contract = contract
        }
    }

    public struct SolarInverterUnits {
        public var unit: Int64
        public var serial: String?
        public var mode: String
        public var fault_code: String?
        public var grid_v: Double?
        public var out_v: Double?
        public var out_va: Double?
        public var out_w: Double?
        public var load_percent: Double?
        public var battery_v: Double?
        public var battery_percent: Double?
        public var pv_v: Double?
        public var charging_a: Double?
        public init(unit: Int64, serial: String? = nil, mode: String, fault_code: String? = nil, grid_v: Double? = nil, out_v: Double? = nil, out_va: Double? = nil, out_w: Double? = nil, load_percent: Double? = nil, battery_v: Double? = nil, battery_percent: Double? = nil, pv_v: Double? = nil, charging_a: Double? = nil) {
            self.unit = unit
            self.serial = serial
            self.mode = mode
            self.fault_code = fault_code
            self.grid_v = grid_v
            self.out_v = out_v
            self.out_va = out_va
            self.out_w = out_w
            self.load_percent = load_percent
            self.battery_v = battery_v
            self.battery_percent = battery_percent
            self.pv_v = pv_v
            self.charging_a = charging_a
        }
    }

    public struct SolarInverterRatings {
        public var grid_rating_v: Double?
        public var out_rating_v: Double?
        public var out_rating_hz: Double?
        public var out_rating_va: Double?
        public var out_rating_w: Double?
        public var battery_rating_v: Double?
        public var battery_recharge_v: Double?
        public var battery_under_v: Double?
        public var battery_bulk_v: Double?
        public var battery_float_v: Double?
        public var max_charge_a: Double?
        public var max_ac_charge_a: Double?
        public var battery_type: String?
        public var input_range: String?
        public var output_priority: String?
        public var charger_priority: String?
        public init(grid_rating_v: Double? = nil, out_rating_v: Double? = nil, out_rating_hz: Double? = nil, out_rating_va: Double? = nil, out_rating_w: Double? = nil, battery_rating_v: Double? = nil, battery_recharge_v: Double? = nil, battery_under_v: Double? = nil, battery_bulk_v: Double? = nil, battery_float_v: Double? = nil, max_charge_a: Double? = nil, max_ac_charge_a: Double? = nil, battery_type: String? = nil, input_range: String? = nil, output_priority: String? = nil, charger_priority: String? = nil) {
            self.grid_rating_v = grid_rating_v
            self.out_rating_v = out_rating_v
            self.out_rating_hz = out_rating_hz
            self.out_rating_va = out_rating_va
            self.out_rating_w = out_rating_w
            self.battery_rating_v = battery_rating_v
            self.battery_recharge_v = battery_recharge_v
            self.battery_under_v = battery_under_v
            self.battery_bulk_v = battery_bulk_v
            self.battery_float_v = battery_float_v
            self.max_charge_a = max_charge_a
            self.max_ac_charge_a = max_ac_charge_a
            self.battery_type = battery_type
            self.input_range = input_range
            self.output_priority = output_priority
            self.charger_priority = charger_priority
        }
    }

    public struct SolarInverter {
        public var kind: String
        public var node_id: String
        public var device: String
        public var timestamp_ms: Int64
        public var mode: String
        public var grid_v: Double
        public var grid_hz: Double
        public var out_v: Double
        public var out_hz: Double
        public var out_va: Double
        public var out_w: Double
        public var load_percent: Double
        public var battery_v: Double
        public var battery_a: Double
        public var battery_percent: Double
        public var pv_v: Double
        public var pv_a: Double
        public var pv_w: Double
        public var heatsink_c: Double
        public var ac_charging: Bool
        public var pv_charging: Bool
        public var load_on: Bool
        public var warnings: [String]
        public var warnings_known: Bool?
        public var clamped: [String]?
        public var pv2_v: Double?
        public var pv2_a: Double?
        public var pv2_w: Double?
        public var total_out_w: Double?
        public var total_out_va: Double?
        public var total_load_percent: Double?
        public var total_charging_a: Double?
        public var units: [SolarInverterUnits]?
        public var bus_v: Double?
        public var serial: String?
        public var firmware: String?
        public var pv_energy_total_wh: Double?
        public var ratings: SolarInverterRatings?
        public init(kind: String = "inverter", node_id: String, device: String, timestamp_ms: Int64, mode: String, grid_v: Double, grid_hz: Double, out_v: Double, out_hz: Double, out_va: Double, out_w: Double, load_percent: Double, battery_v: Double, battery_a: Double, battery_percent: Double, pv_v: Double, pv_a: Double, pv_w: Double, heatsink_c: Double, ac_charging: Bool, pv_charging: Bool, load_on: Bool, warnings: [String], warnings_known: Bool? = nil, clamped: [String]? = nil, pv2_v: Double? = nil, pv2_a: Double? = nil, pv2_w: Double? = nil, total_out_w: Double? = nil, total_out_va: Double? = nil, total_load_percent: Double? = nil, total_charging_a: Double? = nil, units: [SolarInverterUnits]? = nil, bus_v: Double? = nil, serial: String? = nil, firmware: String? = nil, pv_energy_total_wh: Double? = nil, ratings: SolarInverterRatings? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.device = device
            self.timestamp_ms = timestamp_ms
            self.mode = mode
            self.grid_v = grid_v
            self.grid_hz = grid_hz
            self.out_v = out_v
            self.out_hz = out_hz
            self.out_va = out_va
            self.out_w = out_w
            self.load_percent = load_percent
            self.battery_v = battery_v
            self.battery_a = battery_a
            self.battery_percent = battery_percent
            self.pv_v = pv_v
            self.pv_a = pv_a
            self.pv_w = pv_w
            self.heatsink_c = heatsink_c
            self.ac_charging = ac_charging
            self.pv_charging = pv_charging
            self.load_on = load_on
            self.warnings = warnings
            self.warnings_known = warnings_known
            self.clamped = clamped
            self.pv2_v = pv2_v
            self.pv2_a = pv2_a
            self.pv2_w = pv2_w
            self.total_out_w = total_out_w
            self.total_out_va = total_out_va
            self.total_load_percent = total_load_percent
            self.total_charging_a = total_charging_a
            self.units = units
            self.bus_v = bus_v
            self.serial = serial
            self.firmware = firmware
            self.pv_energy_total_wh = pv_energy_total_wh
            self.ratings = ratings
        }
    }

    public struct SolarModuleLastEvent {
        public var index: Int64
        public var time: String
        public var voltage_v: Double?
        public var current_a: Double?
        public var temperature_c: Double?
        public var percent: Int64?
        public var base_state: String?
        public var voltage_state: String?
        public var current_state: String?
        public var temperature_state: String?
        public var coulomb_state: String?
        public var power_events: String?
        public var battery_events: String?
        public var system_fault: String?
        public init(index: Int64, time: String, voltage_v: Double? = nil, current_a: Double? = nil, temperature_c: Double? = nil, percent: Int64? = nil, base_state: String? = nil, voltage_state: String? = nil, current_state: String? = nil, temperature_state: String? = nil, coulomb_state: String? = nil, power_events: String? = nil, battery_events: String? = nil, system_fault: String? = nil) {
            self.index = index
            self.time = time
            self.voltage_v = voltage_v
            self.current_a = current_a
            self.temperature_c = temperature_c
            self.percent = percent
            self.base_state = base_state
            self.voltage_state = voltage_state
            self.current_state = current_state
            self.temperature_state = temperature_state
            self.coulomb_state = coulomb_state
            self.power_events = power_events
            self.battery_events = battery_events
            self.system_fault = system_fault
        }
    }

    public struct SolarModule {
        public var n: Int64
        public var present: Bool
        public var voltage_v: Double?
        public var current_a: Double?
        public var temperature_c: Double?
        public var soc_percent: Int64?
        public var state: String?
        public var cells_v: [Double]?
        public var counters: [String: Int64]?
        public var temperatures_c: [Double]?
        public var capacity_ah: Double?
        public var full_capacity_ah: Double?
        public var cycles: Int64?
        public var health_percent: Int64?
        public var model: String?
        public var cell_count: Int64?
        public var max_charge_a: Double?
        public var max_discharge_a: Double?
        public var console_baud: Int64?
        public var soh_counts: [Int64]?
        public var soh_abnormal: [Int64]?
        public var last_event: SolarModuleLastEvent?
        public var board_version: String?
        public var main_soft_version: String?
        public var soft_version: String?
        public init(n: Int64, present: Bool, voltage_v: Double? = nil, current_a: Double? = nil, temperature_c: Double? = nil, soc_percent: Int64? = nil, state: String? = nil, cells_v: [Double]? = nil, counters: [String: Int64]? = nil, temperatures_c: [Double]? = nil, capacity_ah: Double? = nil, full_capacity_ah: Double? = nil, cycles: Int64? = nil, health_percent: Int64? = nil, model: String? = nil, cell_count: Int64? = nil, max_charge_a: Double? = nil, max_discharge_a: Double? = nil, console_baud: Int64? = nil, soh_counts: [Int64]? = nil, soh_abnormal: [Int64]? = nil, last_event: SolarModuleLastEvent? = nil, board_version: String? = nil, main_soft_version: String? = nil, soft_version: String? = nil) {
            self.n = n
            self.present = present
            self.voltage_v = voltage_v
            self.current_a = current_a
            self.temperature_c = temperature_c
            self.soc_percent = soc_percent
            self.state = state
            self.cells_v = cells_v
            self.counters = counters
            self.temperatures_c = temperatures_c
            self.capacity_ah = capacity_ah
            self.full_capacity_ah = full_capacity_ah
            self.cycles = cycles
            self.health_percent = health_percent
            self.model = model
            self.cell_count = cell_count
            self.max_charge_a = max_charge_a
            self.max_discharge_a = max_discharge_a
            self.console_baud = console_baud
            self.soh_counts = soh_counts
            self.soh_abnormal = soh_abnormal
            self.last_event = last_event
            self.board_version = board_version
            self.main_soft_version = main_soft_version
            self.soft_version = soft_version
        }
    }

    public struct SolarBattery {
        public var kind: String
        public var node_id: String
        public var device: String
        public var timestamp_ms: Int64
        public var modules: Int64
        public var state: String?
        public var voltage_v: Double?
        public var current_a: Double?
        public var temperature_min_c: Double?
        public var temperature_max_c: Double?
        public var cell_min_v: Double?
        public var cell_max_v: Double?
        public var soc_percent: Int64?
        public var alarm: Bool?
        public var stack: [SolarModule]
        public var model: String?
        public var capacity_ah: Double?
        public var full_capacity_ah: Double?
        public var energy_kwh: Double?
        public var cycles: Int64?
        public var health_percent: Int64?
        public var power_w: Double?
        public var balancing: Int64?
        public var protecting: Bool?
        public var charge_mos: Int64?
        public var discharge_mos: Int64?
        public init(kind: String = "battery", node_id: String, device: String, timestamp_ms: Int64, modules: Int64, state: String? = nil, voltage_v: Double? = nil, current_a: Double? = nil, temperature_min_c: Double? = nil, temperature_max_c: Double? = nil, cell_min_v: Double? = nil, cell_max_v: Double? = nil, soc_percent: Int64? = nil, alarm: Bool? = nil, stack: [SolarModule], model: String? = nil, capacity_ah: Double? = nil, full_capacity_ah: Double? = nil, energy_kwh: Double? = nil, cycles: Int64? = nil, health_percent: Int64? = nil, power_w: Double? = nil, balancing: Int64? = nil, protecting: Bool? = nil, charge_mos: Int64? = nil, discharge_mos: Int64? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.device = device
            self.timestamp_ms = timestamp_ms
            self.modules = modules
            self.state = state
            self.voltage_v = voltage_v
            self.current_a = current_a
            self.temperature_min_c = temperature_min_c
            self.temperature_max_c = temperature_max_c
            self.cell_min_v = cell_min_v
            self.cell_max_v = cell_max_v
            self.soc_percent = soc_percent
            self.alarm = alarm
            self.stack = stack
            self.model = model
            self.capacity_ah = capacity_ah
            self.full_capacity_ah = full_capacity_ah
            self.energy_kwh = energy_kwh
            self.cycles = cycles
            self.health_percent = health_percent
            self.power_w = power_w
            self.balancing = balancing
            self.protecting = protecting
            self.charge_mos = charge_mos
            self.discharge_mos = discharge_mos
        }
    }

    public struct ElectricalChannel {
        public var id: String
        public var domain: String
        public var label: String?
        public var voltage_v: Double?
        public var current_a: Double?
        public var power_w: Double?
        public var energy_kwh: Double?
        public var reading_age_ms: Int64?
        public var errors: Int64?
        public var power_estimated: Bool?
        public var frequency_hz: Double?
        public var power_factor: Double?
        public var state: String?
        public var alarm: Bool?
        public var alarm_code: String?
        public init(id: String, domain: String, label: String? = nil, voltage_v: Double? = nil, current_a: Double? = nil, power_w: Double? = nil, energy_kwh: Double? = nil, reading_age_ms: Int64? = nil, errors: Int64? = nil, power_estimated: Bool? = nil, frequency_hz: Double? = nil, power_factor: Double? = nil, state: String? = nil, alarm: Bool? = nil, alarm_code: String? = nil) {
            self.id = id
            self.domain = domain
            self.label = label
            self.voltage_v = voltage_v
            self.current_a = current_a
            self.power_w = power_w
            self.energy_kwh = energy_kwh
            self.reading_age_ms = reading_age_ms
            self.errors = errors
            self.power_estimated = power_estimated
            self.frequency_hz = frequency_hz
            self.power_factor = power_factor
            self.state = state
            self.alarm = alarm
            self.alarm_code = alarm_code
        }
    }

    public struct ElectricalSwitch {
        public var id: String
        public var kind: String
        public var label: String?
        public var source_a: String?
        public var source_b: String?
        public var a_closed: Bool
        public var b_closed: Bool
        public var selected: String
        public var wanted: String
        public var closing: Bool
        public var armed: Bool
        public var fault: String
        public init(id: String, kind: String = "transfer", label: String? = nil, source_a: String? = nil, source_b: String? = nil, a_closed: Bool, b_closed: Bool, selected: String, wanted: String, closing: Bool, armed: Bool, fault: String) {
            self.id = id
            self.kind = kind
            self.label = label
            self.source_a = source_a
            self.source_b = source_b
            self.a_closed = a_closed
            self.b_closed = b_closed
            self.selected = selected
            self.wanted = wanted
            self.closing = closing
            self.armed = armed
            self.fault = fault
        }
    }

    public struct Electrical {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var switching_enabled: Bool?
        public var channels: [ElectricalChannel]
        public var switches: [ElectricalSwitch]?
        public init(kind: String = "electrical", node_id: String, timestamp_ms: Int64, switching_enabled: Bool? = nil, channels: [ElectricalChannel], switches: [ElectricalSwitch]? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.switching_enabled = switching_enabled
            self.channels = channels
            self.switches = switches
        }
    }

    public struct ElectricalCommand {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var command_id: String
        public var `switch`: String
        public var action: String
        public var token: String?
        public init(kind: String = "electrical_command", node_id: String, timestamp_ms: Int64, command_id: String, `switch`: String, action: String, token: String? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command_id = command_id
            self.`switch` = `switch`
            self.action = action
            self.token = token
        }
    }

    public struct ElectricalResult {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var command_id: String
        public var `switch`: String
        public var action: String
        public var accepted: Bool
        public var refusal: String
        public var token: String?
        public init(kind: String = "electrical_result", node_id: String, timestamp_ms: Int64, command_id: String, `switch`: String, action: String, accepted: Bool, refusal: String, token: String? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command_id = command_id
            self.`switch` = `switch`
            self.action = action
            self.accepted = accepted
            self.refusal = refusal
            self.token = token
        }
    }

    public struct SolarBatteryStage {
        public var id: String
        public var index: Int64
        public var total: Int64
        public var size: Int64
        public var crc32: Int64
        public var data: String
        public init(id: String, index: Int64, total: Int64, size: Int64, crc32: Int64, data: String) {
            self.id = id
            self.index = index
            self.total = total
            self.size = size
            self.crc32 = crc32
            self.data = data
        }
    }

    public struct SolarBatteryCommandParamsValues {
        public var pov: Int64?
        public var povr: Int64?
        public var phv: Int64?
        public var phvr: Int64?
        public var plv: Int64?
        public var plvr: Int64?
        public var puv: Int64?
        public var puvr: Int64?
        public var pslp: Int64?
        public var bov: Int64?
        public var bovr: Int64?
        public var bhv: Int64?
        public var bhvr: Int64?
        public var blv: Int64?
        public var blvr: Int64?
        public var buv: Int64?
        public var buvr: Int64?
        public var bslp: Int64?
        public var cot: Int64?
        public var cotr: Int64?
        public var cht: Int64?
        public var chtr: Int64?
        public var clt: Int64?
        public var cltr: Int64?
        public var cut: Int64?
        public var cutr: Int64?
        public init(pov: Int64? = nil, povr: Int64? = nil, phv: Int64? = nil, phvr: Int64? = nil, plv: Int64? = nil, plvr: Int64? = nil, puv: Int64? = nil, puvr: Int64? = nil, pslp: Int64? = nil, bov: Int64? = nil, bovr: Int64? = nil, bhv: Int64? = nil, bhvr: Int64? = nil, blv: Int64? = nil, blvr: Int64? = nil, buv: Int64? = nil, buvr: Int64? = nil, bslp: Int64? = nil, cot: Int64? = nil, cotr: Int64? = nil, cht: Int64? = nil, chtr: Int64? = nil, clt: Int64? = nil, cltr: Int64? = nil, cut: Int64? = nil, cutr: Int64? = nil) {
            self.pov = pov
            self.povr = povr
            self.phv = phv
            self.phvr = phvr
            self.plv = plv
            self.plvr = plvr
            self.puv = puv
            self.puvr = puvr
            self.pslp = pslp
            self.bov = bov
            self.bovr = bovr
            self.bhv = bhv
            self.bhvr = bhvr
            self.blv = blv
            self.blvr = blvr
            self.buv = buv
            self.buvr = buvr
            self.bslp = bslp
            self.cot = cot
            self.cotr = cotr
            self.cht = cht
            self.chtr = chtr
            self.clt = clt
            self.cltr = cltr
            self.cut = cut
            self.cutr = cutr
        }
    }

    public struct SolarBatteryCommandParamsItems {
        public var bov: String?
        public var bhv: String?
        public var blv: String?
        public var buv: String?
        public var bslp: String?
        public var pov: String?
        public var phv: String?
        public var plv: String?
        public var puv: String?
        public var pslp: String?
        public var coc: String?
        public var coc2: String?
        public var doc: String?
        public var doc2: String?
        public init(bov: String? = nil, bhv: String? = nil, blv: String? = nil, buv: String? = nil, bslp: String? = nil, pov: String? = nil, phv: String? = nil, plv: String? = nil, puv: String? = nil, pslp: String? = nil, coc: String? = nil, coc2: String? = nil, doc: String? = nil, doc2: String? = nil) {
            self.bov = bov
            self.bhv = bhv
            self.blv = blv
            self.buv = buv
            self.bslp = bslp
            self.pov = pov
            self.phv = phv
            self.plv = plv
            self.puv = puv
            self.pslp = pslp
            self.coc = coc
            self.coc2 = coc2
            self.doc = doc
            self.doc2 = doc2
        }
    }

    public struct SolarBatteryCommandParams {
        public var which: String?
        public var group: String?
        public var values: SolarBatteryCommandParamsValues?
        public var items: SolarBatteryCommandParamsItems?
        public var accept_risk: Bool?
        public var output: String?
        public var state: String?
        public var serial: String?
        public var restore_barcode: Bool?
        public var image_size: Int64?
        public var image_crc32: Int64?
        public var image_version: String?
        public var clear_eeprom: Bool?
        public var line: String?
        public init(which: String? = nil, group: String? = nil, values: SolarBatteryCommandParamsValues? = nil, items: SolarBatteryCommandParamsItems? = nil, accept_risk: Bool? = nil, output: String? = nil, state: String? = nil, serial: String? = nil, restore_barcode: Bool? = nil, image_size: Int64? = nil, image_crc32: Int64? = nil, image_version: String? = nil, clear_eeprom: Bool? = nil, line: String? = nil) {
            self.which = which
            self.group = group
            self.values = values
            self.items = items
            self.accept_risk = accept_risk
            self.output = output
            self.state = state
            self.serial = serial
            self.restore_barcode = restore_barcode
            self.image_size = image_size
            self.image_crc32 = image_crc32
            self.image_version = image_version
            self.clear_eeprom = clear_eeprom
            self.line = line
        }
    }

    public struct SolarBatteryCommand {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var command_id: String
        public var port: Int64
        public var action: String
        public var op: String?
        public var params: SolarBatteryCommandParams?
        public var serial: String?
        public var token: String?
        public var stage: SolarBatteryStage?
        public init(kind: String = "solar_battery_command", node_id: String, timestamp_ms: Int64, command_id: String, port: Int64, action: String, op: String? = nil, params: SolarBatteryCommandParams? = nil, serial: String? = nil, token: String? = nil, stage: SolarBatteryStage? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command_id = command_id
            self.port = port
            self.action = action
            self.op = op
            self.params = params
            self.serial = serial
            self.token = token
            self.stage = stage
        }
    }

    public struct SolarBatteryIdentity {
        public var model: String
        public var serial: String
        public var soft_version: String
        public var board: String
        public var capacity_ah: Int64?
        public init(model: String, serial: String, soft_version: String, board: String, capacity_ah: Int64? = nil) {
            self.model = model
            self.serial = serial
            self.soft_version = soft_version
            self.board = board
            self.capacity_ah = capacity_ah
        }
    }

    public struct SolarBatteryResult {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var command_id: String
        public var port: Int64
        public var action: String
        public var op: String?
        public var stage: String
        public var accepted: Bool
        public var refusal: String
        public var token: String?
        public var canonical: String?
        public var summary: String?
        public var risk: String?
        public var atomic: Bool?
        public var battery: SolarBatteryIdentity?
        public var snapshot_before: String?
        public var outcome: String?
        public var code: String?
        public var steps_done: Int64?
        public var steps_total: Int64?
        public var writes_done: Int64?
        public var packets_sent: Int64?
        public var packets_total: Int64?
        public var truncated: Bool?
        public var before: String?
        public var after: String?
        public var transcript: String?
        public var received: Int64?
        public init(kind: String = "solar_battery_result", node_id: String, timestamp_ms: Int64, command_id: String, port: Int64, action: String, op: String? = nil, stage: String, accepted: Bool, refusal: String, token: String? = nil, canonical: String? = nil, summary: String? = nil, risk: String? = nil, atomic: Bool? = nil, battery: SolarBatteryIdentity? = nil, snapshot_before: String? = nil, outcome: String? = nil, code: String? = nil, steps_done: Int64? = nil, steps_total: Int64? = nil, writes_done: Int64? = nil, packets_sent: Int64? = nil, packets_total: Int64? = nil, truncated: Bool? = nil, before: String? = nil, after: String? = nil, transcript: String? = nil, received: Int64? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command_id = command_id
            self.port = port
            self.action = action
            self.op = op
            self.stage = stage
            self.accepted = accepted
            self.refusal = refusal
            self.token = token
            self.canonical = canonical
            self.summary = summary
            self.risk = risk
            self.atomic = atomic
            self.battery = battery
            self.snapshot_before = snapshot_before
            self.outcome = outcome
            self.code = code
            self.steps_done = steps_done
            self.steps_total = steps_total
            self.writes_done = writes_done
            self.packets_sent = packets_sent
            self.packets_total = packets_total
            self.truncated = truncated
            self.before = before
            self.after = after
            self.transcript = transcript
            self.received = received
        }
    }

    public struct NodeControlCommand {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var command_id: String
        public var action: String
        public var operation: String
        public var mode: String
        public var delay_s: Int64?
        public var slot: Int64?
        public var duration_s: Int64?
        public var token: String?
        public var requested_by: String
        public var detail: String?
        public init(kind: String = "node_control_command", node_id: String, timestamp_ms: Int64, command_id: String, action: String, operation: String, mode: String, delay_s: Int64? = nil, slot: Int64? = nil, duration_s: Int64? = nil, token: String? = nil, requested_by: String, detail: String? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command_id = command_id
            self.action = action
            self.operation = operation
            self.mode = mode
            self.delay_s = delay_s
            self.slot = slot
            self.duration_s = duration_s
            self.token = token
            self.requested_by = requested_by
            self.detail = detail
        }
    }

    public struct NodeControlResultDiagnosticsPackageHeap {
        public var internal_free: Int64
        public var internal_min: Int64
        public var internal_largest: Int64
        public var total_free: Int64
        public var total_min: Int64
        public var psram_free: Int64?
        public init(internal_free: Int64, internal_min: Int64, internal_largest: Int64, total_free: Int64, total_min: Int64, psram_free: Int64? = nil) {
            self.internal_free = internal_free
            self.internal_min = internal_min
            self.internal_largest = internal_largest
            self.total_free = total_free
            self.total_min = total_min
            self.psram_free = psram_free
        }
    }

    public struct NodeControlResultDiagnosticsPackageTasks {
        public var name: String
        public var stack_free: Int64
        public var priority: Int64
        public var state: String
        public init(name: String, stack_free: Int64, priority: Int64, state: String) {
            self.name = name
            self.stack_free = stack_free
            self.priority = priority
            self.state = state
        }
    }

    public struct NodeControlResultDiagnosticsPackageResets {
        public var reason: String
        public var uptime_s: Int64
        public var guard_restarts_in_hour: Int64
        public init(reason: String, uptime_s: Int64, guard_restarts_in_hour: Int64) {
            self.reason = reason
            self.uptime_s = uptime_s
            self.guard_restarts_in_hour = guard_restarts_in_hour
        }
    }

    public struct NodeControlResultDiagnosticsPackageBoot {
        public var cause: String
        public var reset_reason: String
        public var uptime_before_s: Int64?
        public var heap_internal_free: Int64?
        public var heap_internal_largest: Int64?
        public var coredump: Bool
        public var deliberate: Bool
        public var `guard`: Bool
        public init(cause: String, reset_reason: String, uptime_before_s: Int64? = nil, heap_internal_free: Int64? = nil, heap_internal_largest: Int64? = nil, coredump: Bool, deliberate: Bool, `guard`: Bool) {
            self.cause = cause
            self.reset_reason = reset_reason
            self.uptime_before_s = uptime_before_s
            self.heap_internal_free = heap_internal_free
            self.heap_internal_largest = heap_internal_largest
            self.coredump = coredump
            self.deliberate = deliberate
            self.`guard` = `guard`
        }
    }

    public struct NodeControlResultDiagnosticsPackageMemoryGate {
        public var closed: Bool
        public var transitions: Int64
        public var close_free: Int64
        public var close_block: Int64
        public var open_free: Int64
        public var open_block: Int64
        public init(closed: Bool, transitions: Int64, close_free: Int64, close_block: Int64, open_free: Int64, open_block: Int64) {
            self.closed = closed
            self.transitions = transitions
            self.close_free = close_free
            self.close_block = close_block
            self.open_free = open_free
            self.open_block = open_block
        }
    }

    public struct NodeControlResultDiagnosticsPackageVersionsSensors {
        public var name: String
        public var version: String
        public init(name: String, version: String) {
            self.name = name
            self.version = version
        }
    }

    public struct NodeControlResultDiagnosticsPackageVersions {
        public var firmware: String
        public var idf: String
        public var board: String?
        public var sensors: [NodeControlResultDiagnosticsPackageVersionsSensors]
        public init(firmware: String, idf: String, board: String? = nil, sensors: [NodeControlResultDiagnosticsPackageVersionsSensors]) {
            self.firmware = firmware
            self.idf = idf
            self.board = board
            self.sensors = sensors
        }
    }

    public struct NodeControlResultDiagnosticsPackageCoredumpSummary {
        public var task: String
        public var reason: String?
        public var pc: String?
        public var backtrace: [String]?
        public var app_sha256: String?
        public init(task: String, reason: String? = nil, pc: String? = nil, backtrace: [String]? = nil, app_sha256: String? = nil) {
            self.task = task
            self.reason = reason
            self.pc = pc
            self.backtrace = backtrace
            self.app_sha256 = app_sha256
        }
    }

    public struct NodeControlResultDiagnosticsPackageCoredump {
        public var present: Bool
        public var size: Int64?
        public var summary: NodeControlResultDiagnosticsPackageCoredumpSummary?
        public init(present: Bool, size: Int64? = nil, summary: NodeControlResultDiagnosticsPackageCoredumpSummary? = nil) {
            self.present = present
            self.size = size
            self.summary = summary
        }
    }

    public struct NodeControlResultDiagnosticsPackage {
        public var detail: String
        public var heap: NodeControlResultDiagnosticsPackageHeap?
        public var tasks: [NodeControlResultDiagnosticsPackageTasks]?
        public var resets: NodeControlResultDiagnosticsPackageResets?
        public var boot: NodeControlResultDiagnosticsPackageBoot?
        public var memory_gate: NodeControlResultDiagnosticsPackageMemoryGate?
        public var versions: NodeControlResultDiagnosticsPackageVersions?
        public var config: [String: String]?
        public var coredump: NodeControlResultDiagnosticsPackageCoredump?
        public var log: String
        public var truncated: Bool
        public init(detail: String, heap: NodeControlResultDiagnosticsPackageHeap? = nil, tasks: [NodeControlResultDiagnosticsPackageTasks]? = nil, resets: NodeControlResultDiagnosticsPackageResets? = nil, boot: NodeControlResultDiagnosticsPackageBoot? = nil, memory_gate: NodeControlResultDiagnosticsPackageMemoryGate? = nil, versions: NodeControlResultDiagnosticsPackageVersions? = nil, config: [String: String]? = nil, coredump: NodeControlResultDiagnosticsPackageCoredump? = nil, log: String, truncated: Bool) {
            self.detail = detail
            self.heap = heap
            self.tasks = tasks
            self.resets = resets
            self.boot = boot
            self.memory_gate = memory_gate
            self.versions = versions
            self.config = config
            self.coredump = coredump
            self.log = log
            self.truncated = truncated
        }
    }

    public struct NodeControlResultDiagnostics {
        public var firmware: String
        public var uptime_s: Int64
        public var reset_reason: String
        public var heap_free: Int64
        public var heap_min: Int64
        public var psram_free: Int64?
        public var stack_min_free: Int64?
        public var rssi: Int64?
        public var mqtt_connected: Bool
        public var state: String
        public var maintenance: Bool
        public var package: NodeControlResultDiagnosticsPackage?
        public init(firmware: String, uptime_s: Int64, reset_reason: String, heap_free: Int64, heap_min: Int64, psram_free: Int64? = nil, stack_min_free: Int64? = nil, rssi: Int64? = nil, mqtt_connected: Bool, state: String, maintenance: Bool, package: NodeControlResultDiagnosticsPackage? = nil) {
            self.firmware = firmware
            self.uptime_s = uptime_s
            self.reset_reason = reset_reason
            self.heap_free = heap_free
            self.heap_min = heap_min
            self.psram_free = psram_free
            self.stack_min_free = stack_min_free
            self.rssi = rssi
            self.mqtt_connected = mqtt_connected
            self.state = state
            self.maintenance = maintenance
            self.package = package
        }
    }

    public struct NodeControlResult {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var command_id: String
        public var action: String
        public var operation: String
        public var stage: String
        public var accepted: Bool
        public var refusal: String
        public var token: String?
        public var token_ttl_s: Int64?
        public var reason: String?
        public var mode: String?
        public var restart_in_s: Int64?
        public var uptime_s: Int64?
        public var firmware: String?
        public var requested_by: String?
        public var state: String?
        public var maintenance: Bool?
        public var until_s: Int64?
        public var since_ms: Int64?
        public var diagnostics: NodeControlResultDiagnostics?
        public init(kind: String = "node_control_result", node_id: String, timestamp_ms: Int64, command_id: String, action: String, operation: String, stage: String, accepted: Bool, refusal: String, token: String? = nil, token_ttl_s: Int64? = nil, reason: String? = nil, mode: String? = nil, restart_in_s: Int64? = nil, uptime_s: Int64? = nil, firmware: String? = nil, requested_by: String? = nil, state: String? = nil, maintenance: Bool? = nil, until_s: Int64? = nil, since_ms: Int64? = nil, diagnostics: NodeControlResultDiagnostics? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command_id = command_id
            self.action = action
            self.operation = operation
            self.stage = stage
            self.accepted = accepted
            self.refusal = refusal
            self.token = token
            self.token_ttl_s = token_ttl_s
            self.reason = reason
            self.mode = mode
            self.restart_in_s = restart_in_s
            self.uptime_s = uptime_s
            self.firmware = firmware
            self.requested_by = requested_by
            self.state = state
            self.maintenance = maintenance
            self.until_s = until_s
            self.since_ms = since_ms
            self.diagnostics = diagnostics
        }
    }

    public struct NodeMaintenance {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var active: Bool
        public var reason: String
        public var expected_s: Int64?
        public var firmware: String
        public var requested_by: String?
        public init(kind: String = "node_maintenance", node_id: String, timestamp_ms: Int64, active: Bool, reason: String, expected_s: Int64? = nil, firmware: String, requested_by: String? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.active = active
            self.reason = reason
            self.expected_s = expected_s
            self.firmware = firmware
            self.requested_by = requested_by
        }
    }

    public struct RadarEvent {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var boot: Int64
        public var seq: Int64
        public var event: String
        public var name: String?
        public var sensor_id: Int64?
        public var track_id: Int64?
        public var movement: String?
        public var value: Int64?
        public var count: Int64?
        public var direction: String?
        public var from: String?
        public var by: String?
        public init(kind: String = "radar_event", node_id: String, timestamp_ms: Int64, boot: Int64, seq: Int64, event: String, name: String? = nil, sensor_id: Int64? = nil, track_id: Int64? = nil, movement: String? = nil, value: Int64? = nil, count: Int64? = nil, direction: String? = nil, from: String? = nil, by: String? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.boot = boot
            self.seq = seq
            self.event = event
            self.name = name
            self.sensor_id = sensor_id
            self.track_id = track_id
            self.movement = movement
            self.value = value
            self.count = count
            self.direction = direction
            self.from = from
            self.by = by
        }
    }

    public struct DiagnosticTokenRequest {
        public var nodes: [String]
        public var ttl_s: Int64?
        public var label: String?
        public init(nodes: [String], ttl_s: Int64? = nil, label: String? = nil) {
            self.nodes = nodes
            self.ttl_s = ttl_s
            self.label = label
        }
    }

    public struct DiagnosticTokenCreated {
        public var id: String
        public var token: String
        public var scope: String
        public var nodes: [String]
        public var label: String?
        public var created_at: String
        public var expires_at: String
        public var created_by: String
        public init(id: String, token: String, scope: String = "read_only", nodes: [String], label: String? = nil, created_at: String, expires_at: String, created_by: String) {
            self.id = id
            self.token = token
            self.scope = scope
            self.nodes = nodes
            self.label = label
            self.created_at = created_at
            self.expires_at = expires_at
            self.created_by = created_by
        }
    }

    public struct DiagnosticTokenInfo {
        public var id: String
        public var scope: String
        public var nodes: [String]
        public var label: String?
        public var created_at: String
        public var expires_at: String
        public var created_by: String
        public var status: String
        public var revoked_at: String?
        public var revoked_by: String?
        public var uses: Int64
        public var last_used_at: String?
        public init(id: String, scope: String = "read_only", nodes: [String], label: String? = nil, created_at: String, expires_at: String, created_by: String, status: String, revoked_at: String? = nil, revoked_by: String? = nil, uses: Int64, last_used_at: String? = nil) {
            self.id = id
            self.scope = scope
            self.nodes = nodes
            self.label = label
            self.created_at = created_at
            self.expires_at = expires_at
            self.created_by = created_by
            self.status = status
            self.revoked_at = revoked_at
            self.revoked_by = revoked_by
            self.uses = uses
            self.last_used_at = last_used_at
        }
    }

    public struct AlarmZone {
        public var id: String
        public var name: String?
        public var kind: String
        public var state: String
        public var bypassed: Bool
        public init(id: String, name: String? = nil, kind: String, state: String, bypassed: Bool) {
            self.id = id
            self.name = name
            self.kind = kind
            self.state = state
            self.bypassed = bypassed
        }
    }

    public struct AlarmEvent {
        public var ago_s: Int64
        public var kind: String
        public var zone: String?
        public init(ago_s: Int64, kind: String, zone: String? = nil) {
            self.ago_s = ago_s
            self.kind = kind
            self.zone = zone
        }
    }

    public struct Alarm {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var phase: String
        public var mode: String
        public var siren: Bool
        public var locked_out: Bool
        public var commands_enabled: Bool
        public var zones: [AlarmZone]
        public var open_zones: [String]
        public var events: [AlarmEvent]
        public var arm_profiles: Bool?
        public var profile: String?
        public var siren_loop: String?
        public var siren_fault: Bool?
        public var seq: Int64?
        public var sig: String?
        public init(kind: String = "alarm", node_id: String, timestamp_ms: Int64, phase: String, mode: String, siren: Bool, locked_out: Bool, commands_enabled: Bool, zones: [AlarmZone], open_zones: [String], events: [AlarmEvent], arm_profiles: Bool? = nil, profile: String? = nil, siren_loop: String? = nil, siren_fault: Bool? = nil, seq: Int64? = nil, sig: String? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.phase = phase
            self.mode = mode
            self.siren = siren
            self.locked_out = locked_out
            self.commands_enabled = commands_enabled
            self.zones = zones
            self.open_zones = open_zones
            self.events = events
            self.arm_profiles = arm_profiles
            self.profile = profile
            self.siren_loop = siren_loop
            self.siren_fault = siren_fault
            self.seq = seq
            self.sig = sig
        }
    }

    public struct ArmProfileZone {
        public var id: String
        public var armed: Bool?
        public var delay: String?
        public init(id: String, armed: Bool? = nil, delay: String? = nil) {
            self.id = id
            self.armed = armed
            self.delay = delay
        }
    }

    public struct ArmProfile {
        public var id: String
        public var name: String
        public var base: String
        public var exit_delay_s: Int64?
        public var entry_delay_s: Int64?
        public var siren: Bool?
        public var notify: String?
        public var zones: [ArmProfileZone]?
        public init(id: String, name: String, base: String, exit_delay_s: Int64? = nil, entry_delay_s: Int64? = nil, siren: Bool? = nil, notify: String? = nil, zones: [ArmProfileZone]? = nil) {
            self.id = id
            self.name = name
            self.base = base
            self.exit_delay_s = exit_delay_s
            self.entry_delay_s = entry_delay_s
            self.siren = siren
            self.notify = notify
            self.zones = zones
        }
    }

    public struct AlarmCommand {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var command_id: String
        public var action: String
        public var mode: String?
        public var force: Bool?
        public var profile: ArmProfile?
        public init(kind: String = "alarm_command", node_id: String, timestamp_ms: Int64, command_id: String, action: String, mode: String? = nil, force: Bool? = nil, profile: ArmProfile? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command_id = command_id
            self.action = action
            self.mode = mode
            self.force = force
            self.profile = profile
        }
    }

    public struct AlarmResult {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var command_id: String
        public var action: String
        public var accepted: Bool
        public var refusal: String
        public var phase: String
        public init(kind: String = "alarm_result", node_id: String, timestamp_ms: Int64, command_id: String, action: String, accepted: Bool, refusal: String, phase: String) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.command_id = command_id
            self.action = action
            self.accepted = accepted
            self.refusal = refusal
            self.phase = phase
        }
    }

    public struct ArmingModesModesAway {
        public var entry: [String]?
        public var exit_delay_s: Int64?
        public var entry_delay_s: Int64?
        public init(entry: [String]? = nil, exit_delay_s: Int64? = nil, entry_delay_s: Int64? = nil) {
            self.entry = entry
            self.exit_delay_s = exit_delay_s
            self.entry_delay_s = entry_delay_s
        }
    }

    public struct ArmingModesModesHome {
        public var defends: [String]?
        public var entry: [String]?
        public var exit_delay_s: Int64?
        public var entry_delay_s: Int64?
        public init(defends: [String]? = nil, entry: [String]? = nil, exit_delay_s: Int64? = nil, entry_delay_s: Int64? = nil) {
            self.defends = defends
            self.entry = entry
            self.exit_delay_s = exit_delay_s
            self.entry_delay_s = entry_delay_s
        }
    }

    public struct ArmingModesModesNight {
        public var defends: [String]?
        public var entry: [String]?
        public var exit_delay_s: Int64?
        public var entry_delay_s: Int64?
        public init(defends: [String]? = nil, entry: [String]? = nil, exit_delay_s: Int64? = nil, entry_delay_s: Int64? = nil) {
            self.defends = defends
            self.entry = entry
            self.exit_delay_s = exit_delay_s
            self.entry_delay_s = entry_delay_s
        }
    }

    public struct ArmingModesModes {
        public var away: ArmingModesModesAway
        public var home: ArmingModesModesHome
        public var night: ArmingModesModesNight
        public init(away: ArmingModesModesAway, home: ArmingModesModesHome, night: ArmingModesModesNight) {
            self.away = away
            self.home = home
            self.night = night
        }
    }

    public struct ArmingModesSchedule {
        public var mode: String
        public var days: [Int64]
        public var at: String
        public init(mode: String, days: [Int64], at: String) {
            self.mode = mode
            self.days = days
            self.at = at
        }
    }

    public struct ArmingModesPanelMapProfiles {
        public var away: String?
        public var home: String?
        public var night: String?
        public init(away: String? = nil, home: String? = nil, night: String? = nil) {
            self.away = away
            self.home = home
            self.night = night
        }
    }

    public struct ArmingModesPanelMap {
        public var profiles: ArmingModesPanelMapProfiles?
        public var only: [String]?
        public init(profiles: ArmingModesPanelMapProfiles? = nil, only: [String]? = nil) {
            self.profiles = profiles
            self.only = only
        }
    }

    public struct ArmingModes {
        public var modes: ArmingModesModes
        public var schedule: [ArmingModesSchedule]?
        public var panel_map: ArmingModesPanelMap?
        public init(modes: ArmingModesModes, schedule: [ArmingModesSchedule]? = nil, panel_map: ArmingModesPanelMap? = nil) {
            self.modes = modes
            self.schedule = schedule
            self.panel_map = panel_map
        }
    }

    public struct AlarmZoneFeed {
        public var zone: String
        public var state: String
        public var battery_low: Bool
        public var seq: Int64?
        public var sig: String?
        public init(zone: String, state: String, battery_low: Bool, seq: Int64? = nil, sig: String? = nil) {
            self.zone = zone
            self.state = state
            self.battery_low = battery_low
            self.seq = seq
            self.sig = sig
        }
    }

    public struct AlarmPolicy {
        public var config_hash: Bool
        public var zone_feed: Bool
        public var zone_feed_signature: Bool
        public var disarm_pin: String?
        public var nvs_encryption: String?
        public init(config_hash: Bool, zone_feed: Bool, zone_feed_signature: Bool, disarm_pin: String? = nil, nvs_encryption: String? = nil) {
            self.config_hash = config_hash
            self.zone_feed = zone_feed
            self.zone_feed_signature = zone_feed_signature
            self.disarm_pin = disarm_pin
            self.nvs_encryption = nvs_encryption
        }
    }

    public struct NodeHealthBoot {
        public var cause: String
        public var reset_reason: String
        public var uptime_before_s: Int64?
        public var heap_internal_free: Int64?
        public var heap_internal_largest: Int64?
        public var coredump: Bool
        public var deliberate: Bool
        public var `guard`: Bool
        public init(cause: String, reset_reason: String, uptime_before_s: Int64? = nil, heap_internal_free: Int64? = nil, heap_internal_largest: Int64? = nil, coredump: Bool, deliberate: Bool, `guard`: Bool) {
            self.cause = cause
            self.reset_reason = reset_reason
            self.uptime_before_s = uptime_before_s
            self.heap_internal_free = heap_internal_free
            self.heap_internal_largest = heap_internal_largest
            self.coredump = coredump
            self.deliberate = deliberate
            self.`guard` = `guard`
        }
    }

    public struct NodeHealthMemoryGate {
        public var closed: Bool
        public var transitions: Int64
        public var close_free: Int64
        public var close_block: Int64
        public var open_free: Int64
        public var open_block: Int64
        public init(closed: Bool, transitions: Int64, close_free: Int64, close_block: Int64, open_free: Int64, open_block: Int64) {
            self.closed = closed
            self.transitions = transitions
            self.close_free = close_free
            self.close_block = close_block
            self.open_free = open_free
            self.open_block = open_block
        }
    }

    public struct NodeHealthCoredump {
        public var present: Bool
        public var size: Int64?
        public init(present: Bool, size: Int64? = nil) {
            self.present = present
            self.size = size
        }
    }

    public struct NodeHealthConfigCheck {
        public var snapshot: String?
        public var reverted: String?
        public init(snapshot: String? = nil, reverted: String? = nil) {
            self.snapshot = snapshot
            self.reverted = reverted
        }
    }

    public struct NodeHealthSensors {
        public var sensor_id: Int64
        public var model: String
        public var state: String
        public var firmware_known: Bool
        public var firmware: String?
        public var bluetooth: String
        public var mac: String?
        public var bluetooth_alert: Bool?
        public var quirk: String?
        public init(sensor_id: Int64, model: String, state: String, firmware_known: Bool, firmware: String? = nil, bluetooth: String, mac: String? = nil, bluetooth_alert: Bool? = nil, quirk: String? = nil) {
            self.sensor_id = sensor_id
            self.model = model
            self.state = state
            self.firmware_known = firmware_known
            self.firmware = firmware
            self.bluetooth = bluetooth
            self.mac = mac
            self.bluetooth_alert = bluetooth_alert
            self.quirk = quirk
        }
    }

    public struct NodeHealthRadar {
        public var perimeter_enabled: Bool
        public var masked: Bool
        public var wifi_jam: Bool
        public var bridge_open: Bool
        public var events_buffered: Int64
        public var sensor_bluetooth_off: Bool
        public init(perimeter_enabled: Bool, masked: Bool, wifi_jam: Bool, bridge_open: Bool, events_buffered: Int64, sensor_bluetooth_off: Bool) {
            self.perimeter_enabled = perimeter_enabled
            self.masked = masked
            self.wifi_jam = wifi_jam
            self.bridge_open = bridge_open
            self.events_buffered = events_buffered
            self.sensor_bluetooth_off = sensor_bluetooth_off
        }
    }

    public struct NodeHealth {
        public var kind: String
        public var node_id: String
        public var timestamp_ms: Int64
        public var family: String
        public var firmware: String
        public var contract: String?
        public var board: String?
        public var uptime_s: Int64
        public var reset_reason: String
        public var heap_free: Int64
        public var heap_min: Int64
        public var heap_internal_free: Int64?
        public var heap_internal_min: Int64?
        public var heap_internal_largest: Int64?
        public var psram_free: Int64?
        public var link: String
        public var link_up: Bool
        public var rssi_dbm: Int64?
        public var broker_reconnects: Int64
        public var low_stack_tasks: Int64?
        public var last_error: String?
        public var control_state: String?
        public var control_since_ms: Int64?
        public var control_by: String?
        public var control_until_s: Int64?
        public var maintenance: Bool?
        public var maintenance_until_s: Int64?
        public var boot: NodeHealthBoot?
        public var memory_gate: NodeHealthMemoryGate?
        public var coredump: NodeHealthCoredump?
        public var config_check: NodeHealthConfigCheck?
        public var sensors: [NodeHealthSensors]?
        public var radar: NodeHealthRadar?
        public init(kind: String = "node_health", node_id: String, timestamp_ms: Int64, family: String, firmware: String, contract: String? = nil, board: String? = nil, uptime_s: Int64, reset_reason: String, heap_free: Int64, heap_min: Int64, heap_internal_free: Int64? = nil, heap_internal_min: Int64? = nil, heap_internal_largest: Int64? = nil, psram_free: Int64? = nil, link: String, link_up: Bool, rssi_dbm: Int64? = nil, broker_reconnects: Int64, low_stack_tasks: Int64? = nil, last_error: String? = nil, control_state: String? = nil, control_since_ms: Int64? = nil, control_by: String? = nil, control_until_s: Int64? = nil, maintenance: Bool? = nil, maintenance_until_s: Int64? = nil, boot: NodeHealthBoot? = nil, memory_gate: NodeHealthMemoryGate? = nil, coredump: NodeHealthCoredump? = nil, config_check: NodeHealthConfigCheck? = nil, sensors: [NodeHealthSensors]? = nil, radar: NodeHealthRadar? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.timestamp_ms = timestamp_ms
            self.family = family
            self.firmware = firmware
            self.contract = contract
            self.board = board
            self.uptime_s = uptime_s
            self.reset_reason = reset_reason
            self.heap_free = heap_free
            self.heap_min = heap_min
            self.heap_internal_free = heap_internal_free
            self.heap_internal_min = heap_internal_min
            self.heap_internal_largest = heap_internal_largest
            self.psram_free = psram_free
            self.link = link
            self.link_up = link_up
            self.rssi_dbm = rssi_dbm
            self.broker_reconnects = broker_reconnects
            self.low_stack_tasks = low_stack_tasks
            self.last_error = last_error
            self.control_state = control_state
            self.control_since_ms = control_since_ms
            self.control_by = control_by
            self.control_until_s = control_until_s
            self.maintenance = maintenance
            self.maintenance_until_s = maintenance_until_s
            self.boot = boot
            self.memory_gate = memory_gate
            self.coredump = coredump
            self.config_check = config_check
            self.sensors = sensors
            self.radar = radar
        }
    }

    public struct VoiceTurnMeta {
        public var language: String
        public var encoding: String
        public var sample_rate: Int64
        public var channels: Int64
        public var reply_audio: String?
        public init(language: String, encoding: String, sample_rate: Int64, channels: Int64, reply_audio: String? = nil) {
            self.language = language
            self.encoding = encoding
            self.sample_rate = sample_rate
            self.channels = channels
            self.reply_audio = reply_audio
        }
    }

    public struct VoiceTurnResult {
        public var heard: String
        public var reply: String
        public var audio: String?
        public var audio_omitted: String?
        public var challenge: String?
        public init(heard: String, reply: String, audio: String? = nil, audio_omitted: String? = nil, challenge: String? = nil) {
            self.heard = heard
            self.reply = reply
            self.audio = audio
            self.audio_omitted = audio_omitted
            self.challenge = challenge
        }
    }

    public struct ConnectionEvent {
        public var id: Int64
        public var at: String
        public var type: String
        public var action: String
        public var client_kind: String
        public var client_id: String
        public var user: String?
        public var origin: String?
        public var two_factor: Bool?
        public var app_version: String?
        public var subject: String?
        public var ip: String?
        public var agent: String?
        public init(id: Int64, at: String, type: String = "connection", action: String, client_kind: String, client_id: String, user: String? = nil, origin: String? = nil, two_factor: Bool? = nil, app_version: String? = nil, subject: String? = nil, ip: String? = nil, agent: String? = nil) {
            self.id = id
            self.at = at
            self.type = type
            self.action = action
            self.client_kind = client_kind
            self.client_id = client_id
            self.user = user
            self.origin = origin
            self.two_factor = two_factor
            self.app_version = app_version
            self.subject = subject
            self.ip = ip
            self.agent = agent
        }
    }

    public struct SystemEvent {
        public var id: Int64
        public var at: String
        public var type: String
        public var category: String
        public var action: String
        public var subject: String?
        public var by: String?
        public var version: String?
        public var previous_version: String?
        public var profile: String?
        public var outcome: String?
        public init(id: Int64, at: String, type: String = "system", category: String, action: String, subject: String? = nil, by: String? = nil, version: String? = nil, previous_version: String? = nil, profile: String? = nil, outcome: String? = nil) {
            self.id = id
            self.at = at
            self.type = type
            self.category = category
            self.action = action
            self.subject = subject
            self.by = by
            self.version = version
            self.previous_version = previous_version
            self.profile = profile
            self.outcome = outcome
        }
    }

    public struct ConnectionClient {
        public var id: String
        public var kind: String
        public var user: String?
        public var label: String?
        public var app_version: String?
        public var origin: String?
        public var two_factor: Bool?
        public var first_seen: String
        public var last_seen: String
        public var last_failure: String?
        public var active_sessions: Int64
        public var logins_ok: Int64
        public var logins_failed: Int64
        public var ip: String?
        public var agent: String?
        public init(id: String, kind: String, user: String? = nil, label: String? = nil, app_version: String? = nil, origin: String? = nil, two_factor: Bool? = nil, first_seen: String, last_seen: String, last_failure: String? = nil, active_sessions: Int64, logins_ok: Int64, logins_failed: Int64, ip: String? = nil, agent: String? = nil) {
            self.id = id
            self.kind = kind
            self.user = user
            self.label = label
            self.app_version = app_version
            self.origin = origin
            self.two_factor = two_factor
            self.first_seen = first_seen
            self.last_seen = last_seen
            self.last_failure = last_failure
            self.active_sessions = active_sessions
            self.logins_ok = logins_ok
            self.logins_failed = logins_failed
            self.ip = ip
            self.agent = agent
        }
    }

    public struct DailySummaryBodyTotals {
        public var events: Int64
        public var alarms: Int64
        public var serious_alarms: Int64
        public var false_alarms: Int64
        public init(events: Int64, alarms: Int64, serious_alarms: Int64, false_alarms: Int64) {
            self.events = events
            self.alarms = alarms
            self.serious_alarms = serious_alarms
            self.false_alarms = false_alarms
        }
    }

    public struct DailySummaryBodySeriousAlarms {
        public var t_s: Double
        public var code: String?
        public var zone: String?
        public var node: String?
        public var sensor: String?
        public var severity: String?
        public var watts: Double?
        public var value: Double?
        public var duration_s: Double?
        public var mean_w: Double?
        public var limit_w: Double?
        public init(t_s: Double, code: String? = nil, zone: String? = nil, node: String? = nil, sensor: String? = nil, severity: String? = nil, watts: Double? = nil, value: Double? = nil, duration_s: Double? = nil, mean_w: Double? = nil, limit_w: Double? = nil) {
            self.t_s = t_s
            self.code = code
            self.zone = zone
            self.node = node
            self.sensor = sensor
            self.severity = severity
            self.watts = watts
            self.value = value
            self.duration_s = duration_s
            self.mean_w = mean_w
            self.limit_w = limit_w
        }
    }

    public struct DailySummaryBodyNodesLinkLost {
        public var node: String
        public var count: Int64
        public var total_s: Double
        public init(node: String, count: Int64, total_s: Double) {
            self.node = node
            self.count = count
            self.total_s = total_s
        }
    }

    public struct DailySummaryBodyOutlierReadings {
        public var t_s: Double
        public var node: String
        public var sensor: String
        public var value: Double
        public var median: Double
        public var score: Double
        public init(t_s: Double, node: String, sensor: String, value: Double, median: Double, score: Double) {
            self.t_s = t_s
            self.node = node
            self.sensor = sensor
            self.value = value
            self.median = median
            self.score = score
        }
    }

    public struct DailySummaryBodyConsumptionPeaks {
        public var t_s: Double
        public var code: String?
        public var zone: String?
        public var node: String?
        public var sensor: String?
        public var severity: String?
        public var watts: Double?
        public var value: Double?
        public var duration_s: Double?
        public var mean_w: Double?
        public var limit_w: Double?
        public init(t_s: Double, code: String? = nil, zone: String? = nil, node: String? = nil, sensor: String? = nil, severity: String? = nil, watts: Double? = nil, value: Double? = nil, duration_s: Double? = nil, mean_w: Double? = nil, limit_w: Double? = nil) {
            self.t_s = t_s
            self.code = code
            self.zone = zone
            self.node = node
            self.sensor = sensor
            self.severity = severity
            self.watts = watts
            self.value = value
            self.duration_s = duration_s
            self.mean_w = mean_w
            self.limit_w = limit_w
        }
    }

    public struct DailySummaryBodyConsumption {
        public var samples: Int64
        public var peaks: [DailySummaryBodyConsumptionPeaks]
        public init(samples: Int64, peaks: [DailySummaryBodyConsumptionPeaks]) {
            self.samples = samples
            self.peaks = peaks
        }
    }

    public struct DailySummaryBody {
        public var schema: String
        public var totals: DailySummaryBodyTotals
        public var by_type: [String: Int64]
        public var by_zone: [String: Int64]
        public var by_hour: [Int64]
        public var serious_alarms: [DailySummaryBodySeriousAlarms]?
        public var nodes_link_lost: [DailySummaryBodyNodesLinkLost]?
        public var outlier_readings: [DailySummaryBodyOutlierReadings]?
        public var consumption: DailySummaryBodyConsumption?
        public init(schema: String = "armor-daily-summary/1", totals: DailySummaryBodyTotals, by_type: [String: Int64], by_zone: [String: Int64], by_hour: [Int64], serious_alarms: [DailySummaryBodySeriousAlarms]? = nil, nodes_link_lost: [DailySummaryBodyNodesLinkLost]? = nil, outlier_readings: [DailySummaryBodyOutlierReadings]? = nil, consumption: DailySummaryBodyConsumption? = nil) {
            self.schema = schema
            self.totals = totals
            self.by_type = by_type
            self.by_zone = by_zone
            self.by_hour = by_hour
            self.serious_alarms = serious_alarms
            self.nodes_link_lost = nodes_link_lost
            self.outlier_readings = outlier_readings
            self.consumption = consumption
        }
    }

    public struct DailySummaryFindingSubject {
        public var code: String?
        public var zone: String?
        public var node: String?
        public init(code: String? = nil, zone: String? = nil, node: String? = nil) {
            self.code = code
            self.zone = zone
            self.node = node
        }
    }

    public struct DailySummaryFindingDetail {
        public var hours: [Int64]?
        public var tolerance_min: Double?
        public var max_gap_s: Double?
        public var limit_s: Double?
        public var minimum: Int64?
        public var window: Int64?
        public var sigma: Double?
        public var min_ratio: Double?
        public init(hours: [Int64]? = nil, tolerance_min: Double? = nil, max_gap_s: Double? = nil, limit_s: Double? = nil, minimum: Int64? = nil, window: Int64? = nil, sigma: Double? = nil, min_ratio: Double? = nil) {
            self.hours = hours
            self.tolerance_min = tolerance_min
            self.max_gap_s = max_gap_s
            self.limit_s = limit_s
            self.minimum = minimum
            self.window = window
            self.sigma = sigma
            self.min_ratio = min_ratio
        }
    }

    public struct DailySummaryFindingEvidence {
        public var t_s: Double
        public var code: String?
        public var zone: String?
        public var node: String?
        public var sensor: String?
        public var severity: String?
        public var watts: Double?
        public var value: Double?
        public var duration_s: Double?
        public var mean_w: Double?
        public var limit_w: Double?
        public init(t_s: Double, code: String? = nil, zone: String? = nil, node: String? = nil, sensor: String? = nil, severity: String? = nil, watts: Double? = nil, value: Double? = nil, duration_s: Double? = nil, mean_w: Double? = nil, limit_w: Double? = nil) {
            self.t_s = t_s
            self.code = code
            self.zone = zone
            self.node = node
            self.sensor = sensor
            self.severity = severity
            self.watts = watts
            self.value = value
            self.duration_s = duration_s
            self.mean_w = mean_w
            self.limit_w = limit_w
        }
    }

    public struct DailySummaryFinding {
        public var kind: String
        public var subject: DailySummaryFindingSubject
        public var count: Int64
        public var detail: DailySummaryFindingDetail
        public var evidence: [DailySummaryFindingEvidence]
        public init(kind: String, subject: DailySummaryFindingSubject, count: Int64, detail: DailySummaryFindingDetail, evidence: [DailySummaryFindingEvidence]) {
            self.kind = kind
            self.subject = subject
            self.count = count
            self.detail = detail
            self.evidence = evidence
        }
    }

    public struct DailySummary {
        public var date: String
        public var language: String
        public var summary: DailySummaryBody
        public var findings: [DailySummaryFinding]
        public var text: String
        public var ai_note: String?
        public init(date: String, language: String, summary: DailySummaryBody, findings: [DailySummaryFinding], text: String, ai_note: String? = nil) {
            self.date = date
            self.language = language
            self.summary = summary
            self.findings = findings
            self.text = text
            self.ai_note = ai_note
        }
    }

    public struct Heatmap {
        public var schema: String
        public var camera_id: String
        public var cols: Int64
        public var rows: Int64
        public var accepted_positions: Int64
        public var rejected_positions: Int64
        public var total: Double
        public var max: Double
        public var weights: [[Double]]
        public var normalized: [[Double]]
        public var contains_images: Bool
        public init(schema: String = "armor.vision.heatmap/v1", camera_id: String, cols: Int64, rows: Int64, accepted_positions: Int64, rejected_positions: Int64, total: Double, max: Double, weights: [[Double]], normalized: [[Double]], contains_images: Bool = false) {
            self.schema = schema
            self.camera_id = camera_id
            self.cols = cols
            self.rows = rows
            self.accepted_positions = accepted_positions
            self.rejected_positions = rejected_positions
            self.total = total
            self.max = max
            self.weights = weights
            self.normalized = normalized
            self.contains_images = contains_images
        }
    }

    public struct NetworkInterface {
        public var name: String
        public var ip: String
        public var cidr: String
        public var gateway: String?
        public var rx_bps: Int64?
        public var tx_bps: Int64?
        public init(name: String, ip: String, cidr: String, gateway: String? = nil, rx_bps: Int64? = nil, tx_bps: Int64? = nil) {
            self.name = name
            self.ip = ip
            self.cidr = cidr
            self.gateway = gateway
            self.rx_bps = rx_bps
            self.tx_bps = tx_bps
        }
    }

    public struct NetworkProbe {
        public var target: String
        public var kind: String
        public var ok: Bool
        public var latency_ms: Double?
        public init(target: String, kind: String, ok: Bool, latency_ms: Double? = nil) {
            self.target = target
            self.kind = kind
            self.ok = ok
            self.latency_ms = latency_ms
        }
    }

    public struct NetworkOutage {
        public var started_ms: Int64
        public var ended_ms: Int64
        public var duration_s: Int64
        public init(started_ms: Int64, ended_ms: Int64, duration_s: Int64) {
            self.started_ms = started_ms
            self.ended_ms = ended_ms
            self.duration_s = duration_s
        }
    }

    public struct NetworkInternet {
        public var state: String
        public var since_ms: Int64?
        public var gateway_ok: Bool?
        public var latency_ms: Double?
        public var loss_percent: Double?
        public var probes: [NetworkProbe]?
        public var last_outage: NetworkOutage?
        public var outages_24h: Int64?
        public var downtime_24h_s: Int64?
        public init(state: String, since_ms: Int64? = nil, gateway_ok: Bool? = nil, latency_ms: Double? = nil, loss_percent: Double? = nil, probes: [NetworkProbe]? = nil, last_outage: NetworkOutage? = nil, outages_24h: Int64? = nil, downtime_24h_s: Int64? = nil) {
            self.state = state
            self.since_ms = since_ms
            self.gateway_ok = gateway_ok
            self.latency_ms = latency_ms
            self.loss_percent = loss_percent
            self.probes = probes
            self.last_outage = last_outage
            self.outages_24h = outages_24h
            self.downtime_24h_s = downtime_24h_s
        }
    }

    public struct NetworkPort {
        public var port: Int64
        public var proto: String
        public var service: String?
        public var banner: String?
        public init(port: Int64, proto: String, service: String? = nil, banner: String? = nil) {
            self.port = port
            self.proto = proto
            self.service = service
            self.banner = banner
        }
    }

    public struct NetworkDevice {
        public var id: String
        public var ip: String
        public var mac: String?
        public var randomized_mac: Bool?
        public var vendor: String?
        public var hostname: String?
        public var kind: String?
        public var os: String?
        public var online: Bool
        public var first_seen_ms: Int64
        public var last_seen_ms: Int64
        public var latency_ms: Double?
        public var ports: [NetworkPort]?
        public var services: [String]?
        public init(id: String, ip: String, mac: String? = nil, randomized_mac: Bool? = nil, vendor: String? = nil, hostname: String? = nil, kind: String? = nil, os: String? = nil, online: Bool, first_seen_ms: Int64, last_seen_ms: Int64, latency_ms: Double? = nil, ports: [NetworkPort]? = nil, services: [String]? = nil) {
            self.id = id
            self.ip = ip
            self.mac = mac
            self.randomized_mac = randomized_mac
            self.vendor = vendor
            self.hostname = hostname
            self.kind = kind
            self.os = os
            self.online = online
            self.first_seen_ms = first_seen_ms
            self.last_seen_ms = last_seen_ms
            self.latency_ms = latency_ms
            self.ports = ports
            self.services = services
        }
    }

    public struct NetworkEvent {
        public var id: String
        public var kind: String
        public var at_ms: Int64
        public var device_id: String?
        public var port: Int64?
        public var outage_s: Int64?
        public var detail: String?
        public init(id: String, kind: String, at_ms: Int64, device_id: String? = nil, port: Int64? = nil, outage_s: Int64? = nil, detail: String? = nil) {
            self.id = id
            self.kind = kind
            self.at_ms = at_ms
            self.device_id = device_id
            self.port = port
            self.outage_s = outage_s
            self.detail = detail
        }
    }

    public struct NetworkScan {
        public var last_ms: Int64
        public var hosts: Int64
        public var duration_ms: Int64?
        public init(last_ms: Int64, hosts: Int64, duration_ms: Int64? = nil) {
            self.last_ms = last_ms
            self.hosts = hosts
            self.duration_ms = duration_ms
        }
    }

    public struct NetworkPublicDns {
        public var name: String
        public var addresses: [String]
        public var matches: Bool
        public init(name: String, addresses: [String], matches: Bool) {
            self.name = name
            self.addresses = addresses
            self.matches = matches
        }
    }

    public struct NetworkPublic {
        public var ip: String
        public var hostname: String?
        public var city: String?
        public var region: String?
        public var country: String?
        public var org: String?
        public var timezone: String?
        public var checked_ms: Int64
        public var changed_ms: Int64?
        public var dns: NetworkPublicDns?
        public init(ip: String, hostname: String? = nil, city: String? = nil, region: String? = nil, country: String? = nil, org: String? = nil, timezone: String? = nil, checked_ms: Int64, changed_ms: Int64? = nil, dns: NetworkPublicDns? = nil) {
            self.ip = ip
            self.hostname = hostname
            self.city = city
            self.region = region
            self.country = country
            self.org = org
            self.timezone = timezone
            self.checked_ms = checked_ms
            self.changed_ms = changed_ms
            self.dns = dns
        }
    }

    public struct NetworkResults {
        public var id: String
        public var type: String
        public var ok: Bool
        public var finished_ms: Int64
        public var device_id: String?
        public var output: String?
        public var ports: [NetworkPort]?
        public var latency_ms: Double?
        public init(id: String, type: String, ok: Bool, finished_ms: Int64, device_id: String? = nil, output: String? = nil, ports: [NetworkPort]? = nil, latency_ms: Double? = nil) {
            self.id = id
            self.type = type
            self.ok = ok
            self.finished_ms = finished_ms
            self.device_id = device_id
            self.output = output
            self.ports = ports
            self.latency_ms = latency_ms
        }
    }

    public struct Network {
        public var kind: String
        public var node_id: String
        public var contract: Int64?
        public var timestamp_ms: Int64
        public var interface: NetworkInterface
        public var internet: NetworkInternet
        public var devices: [NetworkDevice]
        public var events: [NetworkEvent]?
        public var scan: NetworkScan?
        public var `public`: NetworkPublic?
        public var results: [NetworkResults]?
        public init(kind: String = "network", node_id: String, contract: Int64? = nil, timestamp_ms: Int64, interface: NetworkInterface, internet: NetworkInternet, devices: [NetworkDevice], events: [NetworkEvent]? = nil, scan: NetworkScan? = nil, `public`: NetworkPublic? = nil, results: [NetworkResults]? = nil) {
            self.kind = kind
            self.node_id = node_id
            self.contract = contract
            self.timestamp_ms = timestamp_ms
            self.interface = interface
            self.internet = internet
            self.devices = devices
            self.events = events
            self.scan = scan
            self.`public` = `public`
            self.results = results
        }
    }

    public struct AiObservationRegions {
        public var x: Double
        public var y: Double
        public var w: Double
        public var h: Double
        public init(x: Double, y: Double, w: Double, h: Double) {
            self.x = x
            self.y = y
            self.w = w
            self.h = h
        }
    }

    public struct AiObservation {
        public var camera_id: String
        public var severity: String
        public var reasons: [String]
        public var profile: String
        public var motion: Double
        public var motion_ratio: Double?
        public var regions: [AiObservationRegions]?
        public var radar_tracks: Int64
        public init(camera_id: String, severity: String, reasons: [String], profile: String, motion: Double, motion_ratio: Double? = nil, regions: [AiObservationRegions]? = nil, radar_tracks: Int64) {
            self.camera_id = camera_id
            self.severity = severity
            self.reasons = reasons
            self.profile = profile
            self.motion = motion
            self.motion_ratio = motion_ratio
            self.regions = regions
            self.radar_tracks = radar_tracks
        }
    }

    public struct DeviceState {
        public var on: Bool
        public init(on: Bool) {
            self.on = on
        }
    }

    public struct NetworkOrdersCommands {
        public var id: String
        public var type: String
        public var device_id: String?
        public var ip: String?
        public var mac: String?
        public var port: Int64?
        public var auth_sealed: String?
        public init(id: String, type: String, device_id: String? = nil, ip: String? = nil, mac: String? = nil, port: Int64? = nil, auth_sealed: String? = nil) {
            self.id = id
            self.type = type
            self.device_id = device_id
            self.ip = ip
            self.mac = mac
            self.port = port
            self.auth_sealed = auth_sealed
        }
    }

    public struct NetworkOrders {
        public var accepted: Bool
        public var commands: [NetworkOrdersCommands]
        public init(accepted: Bool = true, commands: [NetworkOrdersCommands]) {
            self.accepted = accepted
            self.commands = commands
        }
    }

    public struct ServerAlert {
        public var service: String
        public var event: String
        public var at: String
        public var mode: String
        public var node_id: String?
        public var camera_id: String?
        public var targets: Int64?
        public var minutes: Int64?
        public var alarm_id: String?
        public var severity: String?
        public var code: String?
        public var device_id: String?
        public var solar_id: String?
        public var electrical_id: String?
        public var alarm_node_id: String?
        public var network_id: String?
        public var silent: Bool?
        public var automation: String?
        public var login_user: String?
        public var login_from: String?
        public var login_country: String?
        public var login_country_new: Bool?
        public init(service: String = "armor-server", event: String, at: String, mode: String, node_id: String? = nil, camera_id: String? = nil, targets: Int64? = nil, minutes: Int64? = nil, alarm_id: String? = nil, severity: String? = nil, code: String? = nil, device_id: String? = nil, solar_id: String? = nil, electrical_id: String? = nil, alarm_node_id: String? = nil, network_id: String? = nil, silent: Bool? = nil, automation: String? = nil, login_user: String? = nil, login_from: String? = nil, login_country: String? = nil, login_country_new: Bool? = nil) {
            self.service = service
            self.event = event
            self.at = at
            self.mode = mode
            self.node_id = node_id
            self.camera_id = camera_id
            self.targets = targets
            self.minutes = minutes
            self.alarm_id = alarm_id
            self.severity = severity
            self.code = code
            self.device_id = device_id
            self.solar_id = solar_id
            self.electrical_id = electrical_id
            self.alarm_node_id = alarm_node_id
            self.network_id = network_id
            self.silent = silent
            self.automation = automation
            self.login_user = login_user
            self.login_from = login_from
            self.login_country = login_country
            self.login_country_new = login_country_new
        }
    }

    public struct VisionEventVectors {
        public var track_id: Int64
        public var dx: Double
        public var dy: Double
        public var speed: Double
        public init(track_id: Int64, dx: Double, dy: Double, speed: Double) {
            self.track_id = track_id
            self.dx = dx
            self.dy = dy
            self.speed = speed
        }
    }

    public struct VisionEvent {
        public var schema: String
        public var type: String
        public var camera_id: String
        public var zone_id: String
        public var zone_name: String
        public var track_id: Int64
        public var label: String
        public var confidence: Double
        public var box: [Double]
        public var timestamp: Double
        public var timestamp_ms: Int64
        public var authorizes_action: Bool
        public var radar_tracks: Int64?
        public var vectors: [VisionEventVectors]?
        public init(schema: String, type: String, camera_id: String, zone_id: String, zone_name: String, track_id: Int64, label: String, confidence: Double, box: [Double], timestamp: Double, timestamp_ms: Int64, authorizes_action: Bool = false, radar_tracks: Int64? = nil, vectors: [VisionEventVectors]? = nil) {
            self.schema = schema
            self.type = type
            self.camera_id = camera_id
            self.zone_id = zone_id
            self.zone_name = zone_name
            self.track_id = track_id
            self.label = label
            self.confidence = confidence
            self.box = box
            self.timestamp = timestamp
            self.timestamp_ms = timestamp_ms
            self.authorizes_action = authorizes_action
            self.radar_tracks = radar_tracks
            self.vectors = vectors
        }
    }

    // MARK: reading by name

    /// The `ai_observation` message, or nil when the document does not satisfy its schema.
    public static func parseAiObservation(_ document: [String: Any]) -> AiObservation? { check("ai_observation", document) == nil ? AiObservation(reading: document) : nil }
    /// The `alarm` message, or nil when the document does not satisfy its schema.
    public static func parseAlarm(_ document: [String: Any]) -> Alarm? { check("alarm", document) == nil ? Alarm(reading: document) : nil }
    /// The `alarm_command` message, or nil when the document does not satisfy its schema.
    public static func parseAlarmCommand(_ document: [String: Any]) -> AlarmCommand? { check("alarm_command", document) == nil ? AlarmCommand(reading: document) : nil }
    /// The `alarm_policy` message, or nil when the document does not satisfy its schema.
    public static func parseAlarmPolicy(_ document: [String: Any]) -> AlarmPolicy? { check("alarm_policy", document) == nil ? AlarmPolicy(reading: document) : nil }
    /// The `alarm_result` message, or nil when the document does not satisfy its schema.
    public static func parseAlarmResult(_ document: [String: Any]) -> AlarmResult? { check("alarm_result", document) == nil ? AlarmResult(reading: document) : nil }
    /// The `alarm_zone_feed` message, or nil when the document does not satisfy its schema.
    public static func parseAlarmZoneFeed(_ document: [String: Any]) -> AlarmZoneFeed? { check("alarm_zone_feed", document) == nil ? AlarmZoneFeed(reading: document) : nil }
    /// The `arm_profile` message, or nil when the document does not satisfy its schema.
    public static func parseArmProfile(_ document: [String: Any]) -> ArmProfile? { check("arm_profile", document) == nil ? ArmProfile(reading: document) : nil }
    /// The `arming_modes` message, or nil when the document does not satisfy its schema.
    public static func parseArmingModes(_ document: [String: Any]) -> ArmingModes? { check("arming_modes", document) == nil ? ArmingModes(reading: document) : nil }
    /// The `command` message, or nil when the document does not satisfy its schema.
    public static func parseCommand(_ document: [String: Any]) -> Command? { check("command", document) == nil ? Command(reading: document) : nil }
    /// The `connection_client` message, or nil when the document does not satisfy its schema.
    public static func parseConnectionClient(_ document: [String: Any]) -> ConnectionClient? { check("connection_client", document) == nil ? ConnectionClient(reading: document) : nil }
    /// The `connection_event` message, or nil when the document does not satisfy its schema.
    public static func parseConnectionEvent(_ document: [String: Any]) -> ConnectionEvent? { check("connection_event", document) == nil ? ConnectionEvent(reading: document) : nil }
    /// The `daily_summary` message, or nil when the document does not satisfy its schema.
    public static func parseDailySummary(_ document: [String: Any]) -> DailySummary? { check("daily_summary", document) == nil ? DailySummary(reading: document) : nil }
    /// The `device_state` message, or nil when the document does not satisfy its schema.
    public static func parseDeviceState(_ document: [String: Any]) -> DeviceState? { check("device_state", document) == nil ? DeviceState(reading: document) : nil }
    /// The `diagnostic_token_created` message, or nil when the document does not satisfy its schema.
    public static func parseDiagnosticTokenCreated(_ document: [String: Any]) -> DiagnosticTokenCreated? { check("diagnostic_token_created", document) == nil ? DiagnosticTokenCreated(reading: document) : nil }
    /// The `diagnostic_token_info` message, or nil when the document does not satisfy its schema.
    public static func parseDiagnosticTokenInfo(_ document: [String: Any]) -> DiagnosticTokenInfo? { check("diagnostic_token_info", document) == nil ? DiagnosticTokenInfo(reading: document) : nil }
    /// The `diagnostic_token_request` message, or nil when the document does not satisfy its schema.
    public static func parseDiagnosticTokenRequest(_ document: [String: Any]) -> DiagnosticTokenRequest? { check("diagnostic_token_request", document) == nil ? DiagnosticTokenRequest(reading: document) : nil }
    /// The `electrical` message, or nil when the document does not satisfy its schema.
    public static func parseElectrical(_ document: [String: Any]) -> Electrical? { check("electrical", document) == nil ? Electrical(reading: document) : nil }
    /// The `electrical_command` message, or nil when the document does not satisfy its schema.
    public static func parseElectricalCommand(_ document: [String: Any]) -> ElectricalCommand? { check("electrical_command", document) == nil ? ElectricalCommand(reading: document) : nil }
    /// The `electrical_result` message, or nil when the document does not satisfy its schema.
    public static func parseElectricalResult(_ document: [String: Any]) -> ElectricalResult? { check("electrical_result", document) == nil ? ElectricalResult(reading: document) : nil }
    /// The `health` message, or nil when the document does not satisfy its schema.
    public static func parseHealth(_ document: [String: Any]) -> Health? { check("health", document) == nil ? Health(reading: document) : nil }
    /// The `heatmap` message, or nil when the document does not satisfy its schema.
    public static func parseHeatmap(_ document: [String: Any]) -> Heatmap? { check("heatmap", document) == nil ? Heatmap(reading: document) : nil }
    /// The `info` message, or nil when the document does not satisfy its schema.
    public static func parseInfo(_ document: [String: Any]) -> Info? { check("info", document) == nil ? Info(reading: document) : nil }
    /// The `network` message, or nil when the document does not satisfy its schema.
    public static func parseNetwork(_ document: [String: Any]) -> Network? { check("network", document) == nil ? Network(reading: document) : nil }
    /// The `network_orders` message, or nil when the document does not satisfy its schema.
    public static func parseNetworkOrders(_ document: [String: Any]) -> NetworkOrders? { check("network_orders", document) == nil ? NetworkOrders(reading: document) : nil }
    /// The `node_control_command` message, or nil when the document does not satisfy its schema.
    public static func parseNodeControlCommand(_ document: [String: Any]) -> NodeControlCommand? { check("node_control_command", document) == nil ? NodeControlCommand(reading: document) : nil }
    /// The `node_control_result` message, or nil when the document does not satisfy its schema.
    public static func parseNodeControlResult(_ document: [String: Any]) -> NodeControlResult? { check("node_control_result", document) == nil ? NodeControlResult(reading: document) : nil }
    /// The `node_health` message, or nil when the document does not satisfy its schema.
    public static func parseNodeHealth(_ document: [String: Any]) -> NodeHealth? { check("node_health", document) == nil ? NodeHealth(reading: document) : nil }
    /// The `node_maintenance` message, or nil when the document does not satisfy its schema.
    public static func parseNodeMaintenance(_ document: [String: Any]) -> NodeMaintenance? { check("node_maintenance", document) == nil ? NodeMaintenance(reading: document) : nil }
    /// The `radar_event` message, or nil when the document does not satisfy its schema.
    public static func parseRadarEvent(_ document: [String: Any]) -> RadarEvent? { check("radar_event", document) == nil ? RadarEvent(reading: document) : nil }
    /// The `server_alert` message, or nil when the document does not satisfy its schema.
    public static func parseServerAlert(_ document: [String: Any]) -> ServerAlert? { check("server_alert", document) == nil ? ServerAlert(reading: document) : nil }
    /// The `solar_battery` message, or nil when the document does not satisfy its schema.
    public static func parseSolarBattery(_ document: [String: Any]) -> SolarBattery? { check("solar_battery", document) == nil ? SolarBattery(reading: document) : nil }
    /// The `solar_battery_command` message, or nil when the document does not satisfy its schema.
    public static func parseSolarBatteryCommand(_ document: [String: Any]) -> SolarBatteryCommand? { check("solar_battery_command", document) == nil ? SolarBatteryCommand(reading: document) : nil }
    /// The `solar_battery_result` message, or nil when the document does not satisfy its schema.
    public static func parseSolarBatteryResult(_ document: [String: Any]) -> SolarBatteryResult? { check("solar_battery_result", document) == nil ? SolarBatteryResult(reading: document) : nil }
    /// The `solar_inverter` message, or nil when the document does not satisfy its schema.
    public static func parseSolarInverter(_ document: [String: Any]) -> SolarInverter? { check("solar_inverter", document) == nil ? SolarInverter(reading: document) : nil }
    /// The `system_event` message, or nil when the document does not satisfy its schema.
    public static func parseSystemEvent(_ document: [String: Any]) -> SystemEvent? { check("system_event", document) == nil ? SystemEvent(reading: document) : nil }
    /// The `telemetry` message, or nil when the document does not satisfy its schema.
    public static func parseTelemetry(_ document: [String: Any]) -> Telemetry? { check("telemetry", document) == nil ? Telemetry(reading: document) : nil }
    /// The `vision_event` message, or nil when the document does not satisfy its schema.
    public static func parseVisionEvent(_ document: [String: Any]) -> VisionEvent? { check("vision_event", document) == nil ? VisionEvent(reading: document) : nil }
    /// The `voice_turn_meta` message, or nil when the document does not satisfy its schema.
    public static func parseVoiceTurnMeta(_ document: [String: Any]) -> VoiceTurnMeta? { check("voice_turn_meta", document) == nil ? VoiceTurnMeta(reading: document) : nil }
    /// The `voice_turn_result` message, or nil when the document does not satisfy its schema.
    public static func parseVoiceTurnResult(_ document: [String: Any]) -> VoiceTurnResult? { check("voice_turn_result", document) == nil ? VoiceTurnResult(reading: document) : nil }

    /// The document as the message called `name`: its struct, or nil when it does not satisfy the schema or the name is not known.
    public static func parse(_ name: String, _ document: [String: Any]) -> Any? {
        switch name {
        case "ai_observation": return parseAiObservation(document)
        case "alarm": return parseAlarm(document)
        case "alarm_command": return parseAlarmCommand(document)
        case "alarm_policy": return parseAlarmPolicy(document)
        case "alarm_result": return parseAlarmResult(document)
        case "alarm_zone_feed": return parseAlarmZoneFeed(document)
        case "arm_profile": return parseArmProfile(document)
        case "arming_modes": return parseArmingModes(document)
        case "command": return parseCommand(document)
        case "connection_client": return parseConnectionClient(document)
        case "connection_event": return parseConnectionEvent(document)
        case "daily_summary": return parseDailySummary(document)
        case "device_state": return parseDeviceState(document)
        case "diagnostic_token_created": return parseDiagnosticTokenCreated(document)
        case "diagnostic_token_info": return parseDiagnosticTokenInfo(document)
        case "diagnostic_token_request": return parseDiagnosticTokenRequest(document)
        case "electrical": return parseElectrical(document)
        case "electrical_command": return parseElectricalCommand(document)
        case "electrical_result": return parseElectricalResult(document)
        case "health": return parseHealth(document)
        case "heatmap": return parseHeatmap(document)
        case "info": return parseInfo(document)
        case "network": return parseNetwork(document)
        case "network_orders": return parseNetworkOrders(document)
        case "node_control_command": return parseNodeControlCommand(document)
        case "node_control_result": return parseNodeControlResult(document)
        case "node_health": return parseNodeHealth(document)
        case "node_maintenance": return parseNodeMaintenance(document)
        case "radar_event": return parseRadarEvent(document)
        case "server_alert": return parseServerAlert(document)
        case "solar_battery": return parseSolarBattery(document)
        case "solar_battery_command": return parseSolarBatteryCommand(document)
        case "solar_battery_result": return parseSolarBatteryResult(document)
        case "solar_inverter": return parseSolarInverter(document)
        case "system_event": return parseSystemEvent(document)
        case "telemetry": return parseTelemetry(document)
        case "vision_event": return parseVisionEvent(document)
        case "voice_turn_meta": return parseVoiceTurnMeta(document)
        case "voice_turn_result": return parseVoiceTurnResult(document)
        default: return nil
        }
    }

    /// A valid document read and written again: the members the schema names, as the struct holds them; nil when the document is not valid.
    public static func rewrite(_ name: String, _ document: [String: Any]) -> [String: Any]? {
        switch name {
        case "ai_observation": return parseAiObservation(document)?.toJSON()
        case "alarm": return parseAlarm(document)?.toJSON()
        case "alarm_command": return parseAlarmCommand(document)?.toJSON()
        case "alarm_policy": return parseAlarmPolicy(document)?.toJSON()
        case "alarm_result": return parseAlarmResult(document)?.toJSON()
        case "alarm_zone_feed": return parseAlarmZoneFeed(document)?.toJSON()
        case "arm_profile": return parseArmProfile(document)?.toJSON()
        case "arming_modes": return parseArmingModes(document)?.toJSON()
        case "command": return parseCommand(document)?.toJSON()
        case "connection_client": return parseConnectionClient(document)?.toJSON()
        case "connection_event": return parseConnectionEvent(document)?.toJSON()
        case "daily_summary": return parseDailySummary(document)?.toJSON()
        case "device_state": return parseDeviceState(document)?.toJSON()
        case "diagnostic_token_created": return parseDiagnosticTokenCreated(document)?.toJSON()
        case "diagnostic_token_info": return parseDiagnosticTokenInfo(document)?.toJSON()
        case "diagnostic_token_request": return parseDiagnosticTokenRequest(document)?.toJSON()
        case "electrical": return parseElectrical(document)?.toJSON()
        case "electrical_command": return parseElectricalCommand(document)?.toJSON()
        case "electrical_result": return parseElectricalResult(document)?.toJSON()
        case "health": return parseHealth(document)?.toJSON()
        case "heatmap": return parseHeatmap(document)?.toJSON()
        case "info": return parseInfo(document)?.toJSON()
        case "network": return parseNetwork(document)?.toJSON()
        case "network_orders": return parseNetworkOrders(document)?.toJSON()
        case "node_control_command": return parseNodeControlCommand(document)?.toJSON()
        case "node_control_result": return parseNodeControlResult(document)?.toJSON()
        case "node_health": return parseNodeHealth(document)?.toJSON()
        case "node_maintenance": return parseNodeMaintenance(document)?.toJSON()
        case "radar_event": return parseRadarEvent(document)?.toJSON()
        case "server_alert": return parseServerAlert(document)?.toJSON()
        case "solar_battery": return parseSolarBattery(document)?.toJSON()
        case "solar_battery_command": return parseSolarBatteryCommand(document)?.toJSON()
        case "solar_battery_result": return parseSolarBatteryResult(document)?.toJSON()
        case "solar_inverter": return parseSolarInverter(document)?.toJSON()
        case "system_event": return parseSystemEvent(document)?.toJSON()
        case "telemetry": return parseTelemetry(document)?.toJSON()
        case "vision_event": return parseVisionEvent(document)?.toJSON()
        case "voice_turn_meta": return parseVoiceTurnMeta(document)?.toJSON()
        case "voice_turn_result": return parseVoiceTurnResult(document)?.toJSON()
        default: return nil
        }
    }
}

extension Contract.RadarTrack {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.sensor_id = Contract.int(document, "sensor_id")
        self.track_id = Contract.int(document, "track_id")
        self.x_mm = Contract.num(document, "x_mm")
        self.y_mm = Contract.num(document, "y_mm")
        self.speed_mm_s = Contract.num(document, "speed_mm_s")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["sensor_id"] = self.sensor_id
        out["track_id"] = self.track_id
        out["x_mm"] = self.x_mm
        out["y_mm"] = self.y_mm
        out["speed_mm_s"] = self.speed_mm_s
        return out
    }
}

extension Contract.Telemetry {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["kind"] != nil { self.kind = Contract.str(document, "kind") } else { self.kind = nil }
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.lux = Contract.num(document, "lux")
        self.targets = Contract.listAt(document, "targets").map { Contract.RadarTrack(reading: Contract.objOf($0)) }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.kind { out["kind"] = value }
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["lux"] = self.lux
        out["targets"] = self.targets.map { $0.toJSON() }
        return out
    }
}

extension Contract.Health {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.online = Contract.flag(document, "online")
        if document["kind"] != nil { self.kind = Contract.str(document, "kind") } else { self.kind = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["online"] = self.online
        if let value = self.kind { out["kind"] = value }
        return out
    }
}

extension Contract.Command {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["kind"] != nil { self.kind = Contract.str(document, "kind") } else { self.kind = nil }
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command = Contract.str(document, "command")
        if document["sensitivity"] != nil { self.sensitivity = Contract.int(document, "sensitivity") } else { self.sensitivity = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.kind { out["kind"] = value }
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command"] = self.command
        if let value = self.sensitivity { out["sensitivity"] = value }
        return out
    }
}

extension Contract.Info {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["kind"] != nil { self.kind = Contract.str(document, "kind") } else { self.kind = nil }
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.name = Contract.str(document, "name")
        self.firmware = Contract.str(document, "firmware")
        self.ip = Contract.str(document, "ip")
        self.port = Contract.int(document, "port")
        if document["contract"] != nil { self.contract = Contract.str(document, "contract") } else { self.contract = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.kind { out["kind"] = value }
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["name"] = self.name
        out["firmware"] = self.firmware
        out["ip"] = self.ip
        out["port"] = self.port
        if let value = self.contract { out["contract"] = value }
        return out
    }
}

extension Contract.SolarInverterUnits {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.unit = Contract.int(document, "unit")
        if document["serial"] != nil { self.serial = Contract.str(document, "serial") } else { self.serial = nil }
        self.mode = Contract.str(document, "mode")
        if document["fault_code"] != nil { self.fault_code = Contract.str(document, "fault_code") } else { self.fault_code = nil }
        if document["grid_v"] != nil { self.grid_v = Contract.num(document, "grid_v") } else { self.grid_v = nil }
        if document["out_v"] != nil { self.out_v = Contract.num(document, "out_v") } else { self.out_v = nil }
        if document["out_va"] != nil { self.out_va = Contract.num(document, "out_va") } else { self.out_va = nil }
        if document["out_w"] != nil { self.out_w = Contract.num(document, "out_w") } else { self.out_w = nil }
        if document["load_percent"] != nil { self.load_percent = Contract.num(document, "load_percent") } else { self.load_percent = nil }
        if document["battery_v"] != nil { self.battery_v = Contract.num(document, "battery_v") } else { self.battery_v = nil }
        if document["battery_percent"] != nil { self.battery_percent = Contract.num(document, "battery_percent") } else { self.battery_percent = nil }
        if document["pv_v"] != nil { self.pv_v = Contract.num(document, "pv_v") } else { self.pv_v = nil }
        if document["charging_a"] != nil { self.charging_a = Contract.num(document, "charging_a") } else { self.charging_a = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["unit"] = self.unit
        if let value = self.serial { out["serial"] = value }
        out["mode"] = self.mode
        if let value = self.fault_code { out["fault_code"] = value }
        if let value = self.grid_v { out["grid_v"] = value }
        if let value = self.out_v { out["out_v"] = value }
        if let value = self.out_va { out["out_va"] = value }
        if let value = self.out_w { out["out_w"] = value }
        if let value = self.load_percent { out["load_percent"] = value }
        if let value = self.battery_v { out["battery_v"] = value }
        if let value = self.battery_percent { out["battery_percent"] = value }
        if let value = self.pv_v { out["pv_v"] = value }
        if let value = self.charging_a { out["charging_a"] = value }
        return out
    }
}

extension Contract.SolarInverterRatings {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["grid_rating_v"] != nil { self.grid_rating_v = Contract.num(document, "grid_rating_v") } else { self.grid_rating_v = nil }
        if document["out_rating_v"] != nil { self.out_rating_v = Contract.num(document, "out_rating_v") } else { self.out_rating_v = nil }
        if document["out_rating_hz"] != nil { self.out_rating_hz = Contract.num(document, "out_rating_hz") } else { self.out_rating_hz = nil }
        if document["out_rating_va"] != nil { self.out_rating_va = Contract.num(document, "out_rating_va") } else { self.out_rating_va = nil }
        if document["out_rating_w"] != nil { self.out_rating_w = Contract.num(document, "out_rating_w") } else { self.out_rating_w = nil }
        if document["battery_rating_v"] != nil { self.battery_rating_v = Contract.num(document, "battery_rating_v") } else { self.battery_rating_v = nil }
        if document["battery_recharge_v"] != nil { self.battery_recharge_v = Contract.num(document, "battery_recharge_v") } else { self.battery_recharge_v = nil }
        if document["battery_under_v"] != nil { self.battery_under_v = Contract.num(document, "battery_under_v") } else { self.battery_under_v = nil }
        if document["battery_bulk_v"] != nil { self.battery_bulk_v = Contract.num(document, "battery_bulk_v") } else { self.battery_bulk_v = nil }
        if document["battery_float_v"] != nil { self.battery_float_v = Contract.num(document, "battery_float_v") } else { self.battery_float_v = nil }
        if document["max_charge_a"] != nil { self.max_charge_a = Contract.num(document, "max_charge_a") } else { self.max_charge_a = nil }
        if document["max_ac_charge_a"] != nil { self.max_ac_charge_a = Contract.num(document, "max_ac_charge_a") } else { self.max_ac_charge_a = nil }
        if document["battery_type"] != nil { self.battery_type = Contract.str(document, "battery_type") } else { self.battery_type = nil }
        if document["input_range"] != nil { self.input_range = Contract.str(document, "input_range") } else { self.input_range = nil }
        if document["output_priority"] != nil { self.output_priority = Contract.str(document, "output_priority") } else { self.output_priority = nil }
        if document["charger_priority"] != nil { self.charger_priority = Contract.str(document, "charger_priority") } else { self.charger_priority = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.grid_rating_v { out["grid_rating_v"] = value }
        if let value = self.out_rating_v { out["out_rating_v"] = value }
        if let value = self.out_rating_hz { out["out_rating_hz"] = value }
        if let value = self.out_rating_va { out["out_rating_va"] = value }
        if let value = self.out_rating_w { out["out_rating_w"] = value }
        if let value = self.battery_rating_v { out["battery_rating_v"] = value }
        if let value = self.battery_recharge_v { out["battery_recharge_v"] = value }
        if let value = self.battery_under_v { out["battery_under_v"] = value }
        if let value = self.battery_bulk_v { out["battery_bulk_v"] = value }
        if let value = self.battery_float_v { out["battery_float_v"] = value }
        if let value = self.max_charge_a { out["max_charge_a"] = value }
        if let value = self.max_ac_charge_a { out["max_ac_charge_a"] = value }
        if let value = self.battery_type { out["battery_type"] = value }
        if let value = self.input_range { out["input_range"] = value }
        if let value = self.output_priority { out["output_priority"] = value }
        if let value = self.charger_priority { out["charger_priority"] = value }
        return out
    }
}

extension Contract.SolarInverter {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.device = Contract.str(document, "device")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.mode = Contract.str(document, "mode")
        self.grid_v = Contract.num(document, "grid_v")
        self.grid_hz = Contract.num(document, "grid_hz")
        self.out_v = Contract.num(document, "out_v")
        self.out_hz = Contract.num(document, "out_hz")
        self.out_va = Contract.num(document, "out_va")
        self.out_w = Contract.num(document, "out_w")
        self.load_percent = Contract.num(document, "load_percent")
        self.battery_v = Contract.num(document, "battery_v")
        self.battery_a = Contract.num(document, "battery_a")
        self.battery_percent = Contract.num(document, "battery_percent")
        self.pv_v = Contract.num(document, "pv_v")
        self.pv_a = Contract.num(document, "pv_a")
        self.pv_w = Contract.num(document, "pv_w")
        self.heatsink_c = Contract.num(document, "heatsink_c")
        self.ac_charging = Contract.flag(document, "ac_charging")
        self.pv_charging = Contract.flag(document, "pv_charging")
        self.load_on = Contract.flag(document, "load_on")
        self.warnings = Contract.listAt(document, "warnings").map(Contract.asStr)
        if document["warnings_known"] != nil { self.warnings_known = Contract.flag(document, "warnings_known") } else { self.warnings_known = nil }
        if document["clamped"] != nil { self.clamped = Contract.listAt(document, "clamped").map(Contract.asStr) } else { self.clamped = nil }
        if document["pv2_v"] != nil { self.pv2_v = Contract.num(document, "pv2_v") } else { self.pv2_v = nil }
        if document["pv2_a"] != nil { self.pv2_a = Contract.num(document, "pv2_a") } else { self.pv2_a = nil }
        if document["pv2_w"] != nil { self.pv2_w = Contract.num(document, "pv2_w") } else { self.pv2_w = nil }
        if document["total_out_w"] != nil { self.total_out_w = Contract.num(document, "total_out_w") } else { self.total_out_w = nil }
        if document["total_out_va"] != nil { self.total_out_va = Contract.num(document, "total_out_va") } else { self.total_out_va = nil }
        if document["total_load_percent"] != nil { self.total_load_percent = Contract.num(document, "total_load_percent") } else { self.total_load_percent = nil }
        if document["total_charging_a"] != nil { self.total_charging_a = Contract.num(document, "total_charging_a") } else { self.total_charging_a = nil }
        if document["units"] != nil { self.units = Contract.listAt(document, "units").map { Contract.SolarInverterUnits(reading: Contract.objOf($0)) } } else { self.units = nil }
        if document["bus_v"] != nil { self.bus_v = Contract.num(document, "bus_v") } else { self.bus_v = nil }
        if document["serial"] != nil { self.serial = Contract.str(document, "serial") } else { self.serial = nil }
        if document["firmware"] != nil { self.firmware = Contract.str(document, "firmware") } else { self.firmware = nil }
        if document["pv_energy_total_wh"] != nil { self.pv_energy_total_wh = Contract.num(document, "pv_energy_total_wh") } else { self.pv_energy_total_wh = nil }
        if document["ratings"] != nil { self.ratings = Contract.SolarInverterRatings(reading: Contract.objAt(document, "ratings")) } else { self.ratings = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["device"] = self.device
        out["timestamp_ms"] = self.timestamp_ms
        out["mode"] = self.mode
        out["grid_v"] = self.grid_v
        out["grid_hz"] = self.grid_hz
        out["out_v"] = self.out_v
        out["out_hz"] = self.out_hz
        out["out_va"] = self.out_va
        out["out_w"] = self.out_w
        out["load_percent"] = self.load_percent
        out["battery_v"] = self.battery_v
        out["battery_a"] = self.battery_a
        out["battery_percent"] = self.battery_percent
        out["pv_v"] = self.pv_v
        out["pv_a"] = self.pv_a
        out["pv_w"] = self.pv_w
        out["heatsink_c"] = self.heatsink_c
        out["ac_charging"] = self.ac_charging
        out["pv_charging"] = self.pv_charging
        out["load_on"] = self.load_on
        out["warnings"] = self.warnings
        if let value = self.warnings_known { out["warnings_known"] = value }
        if let value = self.clamped { out["clamped"] = value }
        if let value = self.pv2_v { out["pv2_v"] = value }
        if let value = self.pv2_a { out["pv2_a"] = value }
        if let value = self.pv2_w { out["pv2_w"] = value }
        if let value = self.total_out_w { out["total_out_w"] = value }
        if let value = self.total_out_va { out["total_out_va"] = value }
        if let value = self.total_load_percent { out["total_load_percent"] = value }
        if let value = self.total_charging_a { out["total_charging_a"] = value }
        if let value = self.units { out["units"] = value.map { $0.toJSON() } }
        if let value = self.bus_v { out["bus_v"] = value }
        if let value = self.serial { out["serial"] = value }
        if let value = self.firmware { out["firmware"] = value }
        if let value = self.pv_energy_total_wh { out["pv_energy_total_wh"] = value }
        if let value = self.ratings { out["ratings"] = value.toJSON() }
        return out
    }
}

extension Contract.SolarModuleLastEvent {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.index = Contract.int(document, "index")
        self.time = Contract.str(document, "time")
        if document["voltage_v"] != nil { self.voltage_v = Contract.num(document, "voltage_v") } else { self.voltage_v = nil }
        if document["current_a"] != nil { self.current_a = Contract.num(document, "current_a") } else { self.current_a = nil }
        if document["temperature_c"] != nil { self.temperature_c = Contract.num(document, "temperature_c") } else { self.temperature_c = nil }
        if document["percent"] != nil { self.percent = Contract.int(document, "percent") } else { self.percent = nil }
        if document["base_state"] != nil { self.base_state = Contract.str(document, "base_state") } else { self.base_state = nil }
        if document["voltage_state"] != nil { self.voltage_state = Contract.str(document, "voltage_state") } else { self.voltage_state = nil }
        if document["current_state"] != nil { self.current_state = Contract.str(document, "current_state") } else { self.current_state = nil }
        if document["temperature_state"] != nil { self.temperature_state = Contract.str(document, "temperature_state") } else { self.temperature_state = nil }
        if document["coulomb_state"] != nil { self.coulomb_state = Contract.str(document, "coulomb_state") } else { self.coulomb_state = nil }
        if document["power_events"] != nil { self.power_events = Contract.str(document, "power_events") } else { self.power_events = nil }
        if document["battery_events"] != nil { self.battery_events = Contract.str(document, "battery_events") } else { self.battery_events = nil }
        if document["system_fault"] != nil { self.system_fault = Contract.str(document, "system_fault") } else { self.system_fault = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["index"] = self.index
        out["time"] = self.time
        if let value = self.voltage_v { out["voltage_v"] = value }
        if let value = self.current_a { out["current_a"] = value }
        if let value = self.temperature_c { out["temperature_c"] = value }
        if let value = self.percent { out["percent"] = value }
        if let value = self.base_state { out["base_state"] = value }
        if let value = self.voltage_state { out["voltage_state"] = value }
        if let value = self.current_state { out["current_state"] = value }
        if let value = self.temperature_state { out["temperature_state"] = value }
        if let value = self.coulomb_state { out["coulomb_state"] = value }
        if let value = self.power_events { out["power_events"] = value }
        if let value = self.battery_events { out["battery_events"] = value }
        if let value = self.system_fault { out["system_fault"] = value }
        return out
    }
}

extension Contract.SolarModule {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.n = Contract.int(document, "n")
        self.present = Contract.flag(document, "present")
        if document["voltage_v"] != nil { self.voltage_v = Contract.num(document, "voltage_v") } else { self.voltage_v = nil }
        if document["current_a"] != nil { self.current_a = Contract.num(document, "current_a") } else { self.current_a = nil }
        if document["temperature_c"] != nil { self.temperature_c = Contract.num(document, "temperature_c") } else { self.temperature_c = nil }
        if document["soc_percent"] != nil { self.soc_percent = Contract.int(document, "soc_percent") } else { self.soc_percent = nil }
        if document["state"] != nil { self.state = Contract.str(document, "state") } else { self.state = nil }
        if document["cells_v"] != nil { self.cells_v = Contract.listAt(document, "cells_v").map(Contract.asNum) } else { self.cells_v = nil }
        if document["counters"] != nil { self.counters = Contract.objAt(document, "counters").mapValues(Contract.asInt) } else { self.counters = nil }
        if document["temperatures_c"] != nil { self.temperatures_c = Contract.listAt(document, "temperatures_c").map(Contract.asNum) } else { self.temperatures_c = nil }
        if document["capacity_ah"] != nil { self.capacity_ah = Contract.num(document, "capacity_ah") } else { self.capacity_ah = nil }
        if document["full_capacity_ah"] != nil { self.full_capacity_ah = Contract.num(document, "full_capacity_ah") } else { self.full_capacity_ah = nil }
        if document["cycles"] != nil { self.cycles = Contract.int(document, "cycles") } else { self.cycles = nil }
        if document["health_percent"] != nil { self.health_percent = Contract.int(document, "health_percent") } else { self.health_percent = nil }
        if document["model"] != nil { self.model = Contract.str(document, "model") } else { self.model = nil }
        if document["cell_count"] != nil { self.cell_count = Contract.int(document, "cell_count") } else { self.cell_count = nil }
        if document["max_charge_a"] != nil { self.max_charge_a = Contract.num(document, "max_charge_a") } else { self.max_charge_a = nil }
        if document["max_discharge_a"] != nil { self.max_discharge_a = Contract.num(document, "max_discharge_a") } else { self.max_discharge_a = nil }
        if document["console_baud"] != nil { self.console_baud = Contract.int(document, "console_baud") } else { self.console_baud = nil }
        if document["soh_counts"] != nil { self.soh_counts = Contract.listAt(document, "soh_counts").map(Contract.asInt) } else { self.soh_counts = nil }
        if document["soh_abnormal"] != nil { self.soh_abnormal = Contract.listAt(document, "soh_abnormal").map(Contract.asInt) } else { self.soh_abnormal = nil }
        if document["last_event"] != nil { self.last_event = Contract.SolarModuleLastEvent(reading: Contract.objAt(document, "last_event")) } else { self.last_event = nil }
        if document["board_version"] != nil { self.board_version = Contract.str(document, "board_version") } else { self.board_version = nil }
        if document["main_soft_version"] != nil { self.main_soft_version = Contract.str(document, "main_soft_version") } else { self.main_soft_version = nil }
        if document["soft_version"] != nil { self.soft_version = Contract.str(document, "soft_version") } else { self.soft_version = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["n"] = self.n
        out["present"] = self.present
        if let value = self.voltage_v { out["voltage_v"] = value }
        if let value = self.current_a { out["current_a"] = value }
        if let value = self.temperature_c { out["temperature_c"] = value }
        if let value = self.soc_percent { out["soc_percent"] = value }
        if let value = self.state { out["state"] = value }
        if let value = self.cells_v { out["cells_v"] = value }
        if let value = self.counters { out["counters"] = value }
        if let value = self.temperatures_c { out["temperatures_c"] = value }
        if let value = self.capacity_ah { out["capacity_ah"] = value }
        if let value = self.full_capacity_ah { out["full_capacity_ah"] = value }
        if let value = self.cycles { out["cycles"] = value }
        if let value = self.health_percent { out["health_percent"] = value }
        if let value = self.model { out["model"] = value }
        if let value = self.cell_count { out["cell_count"] = value }
        if let value = self.max_charge_a { out["max_charge_a"] = value }
        if let value = self.max_discharge_a { out["max_discharge_a"] = value }
        if let value = self.console_baud { out["console_baud"] = value }
        if let value = self.soh_counts { out["soh_counts"] = value }
        if let value = self.soh_abnormal { out["soh_abnormal"] = value }
        if let value = self.last_event { out["last_event"] = value.toJSON() }
        if let value = self.board_version { out["board_version"] = value }
        if let value = self.main_soft_version { out["main_soft_version"] = value }
        if let value = self.soft_version { out["soft_version"] = value }
        return out
    }
}

extension Contract.SolarBattery {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.device = Contract.str(document, "device")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.modules = Contract.int(document, "modules")
        if document["state"] != nil { self.state = Contract.str(document, "state") } else { self.state = nil }
        if document["voltage_v"] != nil { self.voltage_v = Contract.num(document, "voltage_v") } else { self.voltage_v = nil }
        if document["current_a"] != nil { self.current_a = Contract.num(document, "current_a") } else { self.current_a = nil }
        if document["temperature_min_c"] != nil { self.temperature_min_c = Contract.num(document, "temperature_min_c") } else { self.temperature_min_c = nil }
        if document["temperature_max_c"] != nil { self.temperature_max_c = Contract.num(document, "temperature_max_c") } else { self.temperature_max_c = nil }
        if document["cell_min_v"] != nil { self.cell_min_v = Contract.num(document, "cell_min_v") } else { self.cell_min_v = nil }
        if document["cell_max_v"] != nil { self.cell_max_v = Contract.num(document, "cell_max_v") } else { self.cell_max_v = nil }
        if document["soc_percent"] != nil { self.soc_percent = Contract.int(document, "soc_percent") } else { self.soc_percent = nil }
        if document["alarm"] != nil { self.alarm = Contract.flag(document, "alarm") } else { self.alarm = nil }
        self.stack = Contract.listAt(document, "stack").map { Contract.SolarModule(reading: Contract.objOf($0)) }
        if document["model"] != nil { self.model = Contract.str(document, "model") } else { self.model = nil }
        if document["capacity_ah"] != nil { self.capacity_ah = Contract.num(document, "capacity_ah") } else { self.capacity_ah = nil }
        if document["full_capacity_ah"] != nil { self.full_capacity_ah = Contract.num(document, "full_capacity_ah") } else { self.full_capacity_ah = nil }
        if document["energy_kwh"] != nil { self.energy_kwh = Contract.num(document, "energy_kwh") } else { self.energy_kwh = nil }
        if document["cycles"] != nil { self.cycles = Contract.int(document, "cycles") } else { self.cycles = nil }
        if document["health_percent"] != nil { self.health_percent = Contract.int(document, "health_percent") } else { self.health_percent = nil }
        if document["power_w"] != nil { self.power_w = Contract.num(document, "power_w") } else { self.power_w = nil }
        if document["balancing"] != nil { self.balancing = Contract.int(document, "balancing") } else { self.balancing = nil }
        if document["protecting"] != nil { self.protecting = Contract.flag(document, "protecting") } else { self.protecting = nil }
        if document["charge_mos"] != nil { self.charge_mos = Contract.int(document, "charge_mos") } else { self.charge_mos = nil }
        if document["discharge_mos"] != nil { self.discharge_mos = Contract.int(document, "discharge_mos") } else { self.discharge_mos = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["device"] = self.device
        out["timestamp_ms"] = self.timestamp_ms
        out["modules"] = self.modules
        if let value = self.state { out["state"] = value }
        if let value = self.voltage_v { out["voltage_v"] = value }
        if let value = self.current_a { out["current_a"] = value }
        if let value = self.temperature_min_c { out["temperature_min_c"] = value }
        if let value = self.temperature_max_c { out["temperature_max_c"] = value }
        if let value = self.cell_min_v { out["cell_min_v"] = value }
        if let value = self.cell_max_v { out["cell_max_v"] = value }
        if let value = self.soc_percent { out["soc_percent"] = value }
        if let value = self.alarm { out["alarm"] = value }
        out["stack"] = self.stack.map { $0.toJSON() }
        if let value = self.model { out["model"] = value }
        if let value = self.capacity_ah { out["capacity_ah"] = value }
        if let value = self.full_capacity_ah { out["full_capacity_ah"] = value }
        if let value = self.energy_kwh { out["energy_kwh"] = value }
        if let value = self.cycles { out["cycles"] = value }
        if let value = self.health_percent { out["health_percent"] = value }
        if let value = self.power_w { out["power_w"] = value }
        if let value = self.balancing { out["balancing"] = value }
        if let value = self.protecting { out["protecting"] = value }
        if let value = self.charge_mos { out["charge_mos"] = value }
        if let value = self.discharge_mos { out["discharge_mos"] = value }
        return out
    }
}

extension Contract.ElectricalChannel {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.domain = Contract.str(document, "domain")
        if document["label"] != nil { self.label = Contract.str(document, "label") } else { self.label = nil }
        if document["voltage_v"] != nil { self.voltage_v = Contract.num(document, "voltage_v") } else { self.voltage_v = nil }
        if document["current_a"] != nil { self.current_a = Contract.num(document, "current_a") } else { self.current_a = nil }
        if document["power_w"] != nil { self.power_w = Contract.num(document, "power_w") } else { self.power_w = nil }
        if document["energy_kwh"] != nil { self.energy_kwh = Contract.num(document, "energy_kwh") } else { self.energy_kwh = nil }
        if document["reading_age_ms"] != nil { self.reading_age_ms = Contract.int(document, "reading_age_ms") } else { self.reading_age_ms = nil }
        if document["errors"] != nil { self.errors = Contract.int(document, "errors") } else { self.errors = nil }
        if document["power_estimated"] != nil { self.power_estimated = Contract.flag(document, "power_estimated") } else { self.power_estimated = nil }
        if document["frequency_hz"] != nil { self.frequency_hz = Contract.num(document, "frequency_hz") } else { self.frequency_hz = nil }
        if document["power_factor"] != nil { self.power_factor = Contract.num(document, "power_factor") } else { self.power_factor = nil }
        if document["state"] != nil { self.state = Contract.str(document, "state") } else { self.state = nil }
        if document["alarm"] != nil { self.alarm = Contract.flag(document, "alarm") } else { self.alarm = nil }
        if document["alarm_code"] != nil { self.alarm_code = Contract.str(document, "alarm_code") } else { self.alarm_code = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["domain"] = self.domain
        if let value = self.label { out["label"] = value }
        if let value = self.voltage_v { out["voltage_v"] = value }
        if let value = self.current_a { out["current_a"] = value }
        if let value = self.power_w { out["power_w"] = value }
        if let value = self.energy_kwh { out["energy_kwh"] = value }
        if let value = self.reading_age_ms { out["reading_age_ms"] = value }
        if let value = self.errors { out["errors"] = value }
        if let value = self.power_estimated { out["power_estimated"] = value }
        if let value = self.frequency_hz { out["frequency_hz"] = value }
        if let value = self.power_factor { out["power_factor"] = value }
        if let value = self.state { out["state"] = value }
        if let value = self.alarm { out["alarm"] = value }
        if let value = self.alarm_code { out["alarm_code"] = value }
        return out
    }
}

extension Contract.ElectricalSwitch {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.kind = Contract.str(document, "kind")
        if document["label"] != nil { self.label = Contract.str(document, "label") } else { self.label = nil }
        if document["source_a"] != nil { self.source_a = Contract.str(document, "source_a") } else { self.source_a = nil }
        if document["source_b"] != nil { self.source_b = Contract.str(document, "source_b") } else { self.source_b = nil }
        self.a_closed = Contract.flag(document, "a_closed")
        self.b_closed = Contract.flag(document, "b_closed")
        self.selected = Contract.str(document, "selected")
        self.wanted = Contract.str(document, "wanted")
        self.closing = Contract.flag(document, "closing")
        self.armed = Contract.flag(document, "armed")
        self.fault = Contract.str(document, "fault")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["kind"] = self.kind
        if let value = self.label { out["label"] = value }
        if let value = self.source_a { out["source_a"] = value }
        if let value = self.source_b { out["source_b"] = value }
        out["a_closed"] = self.a_closed
        out["b_closed"] = self.b_closed
        out["selected"] = self.selected
        out["wanted"] = self.wanted
        out["closing"] = self.closing
        out["armed"] = self.armed
        out["fault"] = self.fault
        return out
    }
}

extension Contract.Electrical {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        if document["switching_enabled"] != nil { self.switching_enabled = Contract.flag(document, "switching_enabled") } else { self.switching_enabled = nil }
        self.channels = Contract.listAt(document, "channels").map { Contract.ElectricalChannel(reading: Contract.objOf($0)) }
        if document["switches"] != nil { self.switches = Contract.listAt(document, "switches").map { Contract.ElectricalSwitch(reading: Contract.objOf($0)) } } else { self.switches = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        if let value = self.switching_enabled { out["switching_enabled"] = value }
        out["channels"] = self.channels.map { $0.toJSON() }
        if let value = self.switches { out["switches"] = value.map { $0.toJSON() } }
        return out
    }
}

extension Contract.ElectricalCommand {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command_id = Contract.str(document, "command_id")
        self.`switch` = Contract.str(document, "switch")
        self.action = Contract.str(document, "action")
        if document["token"] != nil { self.token = Contract.str(document, "token") } else { self.token = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command_id"] = self.command_id
        out["switch"] = self.`switch`
        out["action"] = self.action
        if let value = self.token { out["token"] = value }
        return out
    }
}

extension Contract.ElectricalResult {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command_id = Contract.str(document, "command_id")
        self.`switch` = Contract.str(document, "switch")
        self.action = Contract.str(document, "action")
        self.accepted = Contract.flag(document, "accepted")
        self.refusal = Contract.str(document, "refusal")
        if document["token"] != nil { self.token = Contract.str(document, "token") } else { self.token = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command_id"] = self.command_id
        out["switch"] = self.`switch`
        out["action"] = self.action
        out["accepted"] = self.accepted
        out["refusal"] = self.refusal
        if let value = self.token { out["token"] = value }
        return out
    }
}

extension Contract.SolarBatteryStage {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.index = Contract.int(document, "index")
        self.total = Contract.int(document, "total")
        self.size = Contract.int(document, "size")
        self.crc32 = Contract.int(document, "crc32")
        self.data = Contract.str(document, "data")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["index"] = self.index
        out["total"] = self.total
        out["size"] = self.size
        out["crc32"] = self.crc32
        out["data"] = self.data
        return out
    }
}

extension Contract.SolarBatteryCommandParamsValues {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["pov"] != nil { self.pov = Contract.int(document, "pov") } else { self.pov = nil }
        if document["povr"] != nil { self.povr = Contract.int(document, "povr") } else { self.povr = nil }
        if document["phv"] != nil { self.phv = Contract.int(document, "phv") } else { self.phv = nil }
        if document["phvr"] != nil { self.phvr = Contract.int(document, "phvr") } else { self.phvr = nil }
        if document["plv"] != nil { self.plv = Contract.int(document, "plv") } else { self.plv = nil }
        if document["plvr"] != nil { self.plvr = Contract.int(document, "plvr") } else { self.plvr = nil }
        if document["puv"] != nil { self.puv = Contract.int(document, "puv") } else { self.puv = nil }
        if document["puvr"] != nil { self.puvr = Contract.int(document, "puvr") } else { self.puvr = nil }
        if document["pslp"] != nil { self.pslp = Contract.int(document, "pslp") } else { self.pslp = nil }
        if document["bov"] != nil { self.bov = Contract.int(document, "bov") } else { self.bov = nil }
        if document["bovr"] != nil { self.bovr = Contract.int(document, "bovr") } else { self.bovr = nil }
        if document["bhv"] != nil { self.bhv = Contract.int(document, "bhv") } else { self.bhv = nil }
        if document["bhvr"] != nil { self.bhvr = Contract.int(document, "bhvr") } else { self.bhvr = nil }
        if document["blv"] != nil { self.blv = Contract.int(document, "blv") } else { self.blv = nil }
        if document["blvr"] != nil { self.blvr = Contract.int(document, "blvr") } else { self.blvr = nil }
        if document["buv"] != nil { self.buv = Contract.int(document, "buv") } else { self.buv = nil }
        if document["buvr"] != nil { self.buvr = Contract.int(document, "buvr") } else { self.buvr = nil }
        if document["bslp"] != nil { self.bslp = Contract.int(document, "bslp") } else { self.bslp = nil }
        if document["cot"] != nil { self.cot = Contract.int(document, "cot") } else { self.cot = nil }
        if document["cotr"] != nil { self.cotr = Contract.int(document, "cotr") } else { self.cotr = nil }
        if document["cht"] != nil { self.cht = Contract.int(document, "cht") } else { self.cht = nil }
        if document["chtr"] != nil { self.chtr = Contract.int(document, "chtr") } else { self.chtr = nil }
        if document["clt"] != nil { self.clt = Contract.int(document, "clt") } else { self.clt = nil }
        if document["cltr"] != nil { self.cltr = Contract.int(document, "cltr") } else { self.cltr = nil }
        if document["cut"] != nil { self.cut = Contract.int(document, "cut") } else { self.cut = nil }
        if document["cutr"] != nil { self.cutr = Contract.int(document, "cutr") } else { self.cutr = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.pov { out["pov"] = value }
        if let value = self.povr { out["povr"] = value }
        if let value = self.phv { out["phv"] = value }
        if let value = self.phvr { out["phvr"] = value }
        if let value = self.plv { out["plv"] = value }
        if let value = self.plvr { out["plvr"] = value }
        if let value = self.puv { out["puv"] = value }
        if let value = self.puvr { out["puvr"] = value }
        if let value = self.pslp { out["pslp"] = value }
        if let value = self.bov { out["bov"] = value }
        if let value = self.bovr { out["bovr"] = value }
        if let value = self.bhv { out["bhv"] = value }
        if let value = self.bhvr { out["bhvr"] = value }
        if let value = self.blv { out["blv"] = value }
        if let value = self.blvr { out["blvr"] = value }
        if let value = self.buv { out["buv"] = value }
        if let value = self.buvr { out["buvr"] = value }
        if let value = self.bslp { out["bslp"] = value }
        if let value = self.cot { out["cot"] = value }
        if let value = self.cotr { out["cotr"] = value }
        if let value = self.cht { out["cht"] = value }
        if let value = self.chtr { out["chtr"] = value }
        if let value = self.clt { out["clt"] = value }
        if let value = self.cltr { out["cltr"] = value }
        if let value = self.cut { out["cut"] = value }
        if let value = self.cutr { out["cutr"] = value }
        return out
    }
}

extension Contract.SolarBatteryCommandParamsItems {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["bov"] != nil { self.bov = Contract.str(document, "bov") } else { self.bov = nil }
        if document["bhv"] != nil { self.bhv = Contract.str(document, "bhv") } else { self.bhv = nil }
        if document["blv"] != nil { self.blv = Contract.str(document, "blv") } else { self.blv = nil }
        if document["buv"] != nil { self.buv = Contract.str(document, "buv") } else { self.buv = nil }
        if document["bslp"] != nil { self.bslp = Contract.str(document, "bslp") } else { self.bslp = nil }
        if document["pov"] != nil { self.pov = Contract.str(document, "pov") } else { self.pov = nil }
        if document["phv"] != nil { self.phv = Contract.str(document, "phv") } else { self.phv = nil }
        if document["plv"] != nil { self.plv = Contract.str(document, "plv") } else { self.plv = nil }
        if document["puv"] != nil { self.puv = Contract.str(document, "puv") } else { self.puv = nil }
        if document["pslp"] != nil { self.pslp = Contract.str(document, "pslp") } else { self.pslp = nil }
        if document["coc"] != nil { self.coc = Contract.str(document, "coc") } else { self.coc = nil }
        if document["coc2"] != nil { self.coc2 = Contract.str(document, "coc2") } else { self.coc2 = nil }
        if document["doc"] != nil { self.doc = Contract.str(document, "doc") } else { self.doc = nil }
        if document["doc2"] != nil { self.doc2 = Contract.str(document, "doc2") } else { self.doc2 = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.bov { out["bov"] = value }
        if let value = self.bhv { out["bhv"] = value }
        if let value = self.blv { out["blv"] = value }
        if let value = self.buv { out["buv"] = value }
        if let value = self.bslp { out["bslp"] = value }
        if let value = self.pov { out["pov"] = value }
        if let value = self.phv { out["phv"] = value }
        if let value = self.plv { out["plv"] = value }
        if let value = self.puv { out["puv"] = value }
        if let value = self.pslp { out["pslp"] = value }
        if let value = self.coc { out["coc"] = value }
        if let value = self.coc2 { out["coc2"] = value }
        if let value = self.doc { out["doc"] = value }
        if let value = self.doc2 { out["doc2"] = value }
        return out
    }
}

extension Contract.SolarBatteryCommandParams {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["which"] != nil { self.which = Contract.str(document, "which") } else { self.which = nil }
        if document["group"] != nil { self.group = Contract.str(document, "group") } else { self.group = nil }
        if document["values"] != nil { self.values = Contract.SolarBatteryCommandParamsValues(reading: Contract.objAt(document, "values")) } else { self.values = nil }
        if document["items"] != nil { self.items = Contract.SolarBatteryCommandParamsItems(reading: Contract.objAt(document, "items")) } else { self.items = nil }
        if document["accept_risk"] != nil { self.accept_risk = Contract.flag(document, "accept_risk") } else { self.accept_risk = nil }
        if document["output"] != nil { self.output = Contract.str(document, "output") } else { self.output = nil }
        if document["state"] != nil { self.state = Contract.str(document, "state") } else { self.state = nil }
        if document["serial"] != nil { self.serial = Contract.str(document, "serial") } else { self.serial = nil }
        if document["restore_barcode"] != nil { self.restore_barcode = Contract.flag(document, "restore_barcode") } else { self.restore_barcode = nil }
        if document["image_size"] != nil { self.image_size = Contract.int(document, "image_size") } else { self.image_size = nil }
        if document["image_crc32"] != nil { self.image_crc32 = Contract.int(document, "image_crc32") } else { self.image_crc32 = nil }
        if document["image_version"] != nil { self.image_version = Contract.str(document, "image_version") } else { self.image_version = nil }
        if document["clear_eeprom"] != nil { self.clear_eeprom = Contract.flag(document, "clear_eeprom") } else { self.clear_eeprom = nil }
        if document["line"] != nil { self.line = Contract.str(document, "line") } else { self.line = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.which { out["which"] = value }
        if let value = self.group { out["group"] = value }
        if let value = self.values { out["values"] = value.toJSON() }
        if let value = self.items { out["items"] = value.toJSON() }
        if let value = self.accept_risk { out["accept_risk"] = value }
        if let value = self.output { out["output"] = value }
        if let value = self.state { out["state"] = value }
        if let value = self.serial { out["serial"] = value }
        if let value = self.restore_barcode { out["restore_barcode"] = value }
        if let value = self.image_size { out["image_size"] = value }
        if let value = self.image_crc32 { out["image_crc32"] = value }
        if let value = self.image_version { out["image_version"] = value }
        if let value = self.clear_eeprom { out["clear_eeprom"] = value }
        if let value = self.line { out["line"] = value }
        return out
    }
}

extension Contract.SolarBatteryCommand {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command_id = Contract.str(document, "command_id")
        self.port = Contract.int(document, "port")
        self.action = Contract.str(document, "action")
        if document["op"] != nil { self.op = Contract.str(document, "op") } else { self.op = nil }
        if document["params"] != nil { self.params = Contract.SolarBatteryCommandParams(reading: Contract.objAt(document, "params")) } else { self.params = nil }
        if document["serial"] != nil { self.serial = Contract.str(document, "serial") } else { self.serial = nil }
        if document["token"] != nil { self.token = Contract.str(document, "token") } else { self.token = nil }
        if document["stage"] != nil { self.stage = Contract.SolarBatteryStage(reading: Contract.objAt(document, "stage")) } else { self.stage = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command_id"] = self.command_id
        out["port"] = self.port
        out["action"] = self.action
        if let value = self.op { out["op"] = value }
        if let value = self.params { out["params"] = value.toJSON() }
        if let value = self.serial { out["serial"] = value }
        if let value = self.token { out["token"] = value }
        if let value = self.stage { out["stage"] = value.toJSON() }
        return out
    }
}

extension Contract.SolarBatteryIdentity {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.model = Contract.str(document, "model")
        self.serial = Contract.str(document, "serial")
        self.soft_version = Contract.str(document, "soft_version")
        self.board = Contract.str(document, "board")
        if document["capacity_ah"] != nil { self.capacity_ah = Contract.int(document, "capacity_ah") } else { self.capacity_ah = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["model"] = self.model
        out["serial"] = self.serial
        out["soft_version"] = self.soft_version
        out["board"] = self.board
        if let value = self.capacity_ah { out["capacity_ah"] = value }
        return out
    }
}

extension Contract.SolarBatteryResult {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command_id = Contract.str(document, "command_id")
        self.port = Contract.int(document, "port")
        self.action = Contract.str(document, "action")
        if document["op"] != nil { self.op = Contract.str(document, "op") } else { self.op = nil }
        self.stage = Contract.str(document, "stage")
        self.accepted = Contract.flag(document, "accepted")
        self.refusal = Contract.str(document, "refusal")
        if document["token"] != nil { self.token = Contract.str(document, "token") } else { self.token = nil }
        if document["canonical"] != nil { self.canonical = Contract.str(document, "canonical") } else { self.canonical = nil }
        if document["summary"] != nil { self.summary = Contract.str(document, "summary") } else { self.summary = nil }
        if document["risk"] != nil { self.risk = Contract.str(document, "risk") } else { self.risk = nil }
        if document["atomic"] != nil { self.atomic = Contract.flag(document, "atomic") } else { self.atomic = nil }
        if document["battery"] != nil { self.battery = Contract.SolarBatteryIdentity(reading: Contract.objAt(document, "battery")) } else { self.battery = nil }
        if document["snapshot_before"] != nil { self.snapshot_before = Contract.str(document, "snapshot_before") } else { self.snapshot_before = nil }
        if document["outcome"] != nil { self.outcome = Contract.str(document, "outcome") } else { self.outcome = nil }
        if document["code"] != nil { self.code = Contract.str(document, "code") } else { self.code = nil }
        if document["steps_done"] != nil { self.steps_done = Contract.int(document, "steps_done") } else { self.steps_done = nil }
        if document["steps_total"] != nil { self.steps_total = Contract.int(document, "steps_total") } else { self.steps_total = nil }
        if document["writes_done"] != nil { self.writes_done = Contract.int(document, "writes_done") } else { self.writes_done = nil }
        if document["packets_sent"] != nil { self.packets_sent = Contract.int(document, "packets_sent") } else { self.packets_sent = nil }
        if document["packets_total"] != nil { self.packets_total = Contract.int(document, "packets_total") } else { self.packets_total = nil }
        if document["truncated"] != nil { self.truncated = Contract.flag(document, "truncated") } else { self.truncated = nil }
        if document["before"] != nil { self.before = Contract.str(document, "before") } else { self.before = nil }
        if document["after"] != nil { self.after = Contract.str(document, "after") } else { self.after = nil }
        if document["transcript"] != nil { self.transcript = Contract.str(document, "transcript") } else { self.transcript = nil }
        if document["received"] != nil { self.received = Contract.int(document, "received") } else { self.received = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command_id"] = self.command_id
        out["port"] = self.port
        out["action"] = self.action
        if let value = self.op { out["op"] = value }
        out["stage"] = self.stage
        out["accepted"] = self.accepted
        out["refusal"] = self.refusal
        if let value = self.token { out["token"] = value }
        if let value = self.canonical { out["canonical"] = value }
        if let value = self.summary { out["summary"] = value }
        if let value = self.risk { out["risk"] = value }
        if let value = self.atomic { out["atomic"] = value }
        if let value = self.battery { out["battery"] = value.toJSON() }
        if let value = self.snapshot_before { out["snapshot_before"] = value }
        if let value = self.outcome { out["outcome"] = value }
        if let value = self.code { out["code"] = value }
        if let value = self.steps_done { out["steps_done"] = value }
        if let value = self.steps_total { out["steps_total"] = value }
        if let value = self.writes_done { out["writes_done"] = value }
        if let value = self.packets_sent { out["packets_sent"] = value }
        if let value = self.packets_total { out["packets_total"] = value }
        if let value = self.truncated { out["truncated"] = value }
        if let value = self.before { out["before"] = value }
        if let value = self.after { out["after"] = value }
        if let value = self.transcript { out["transcript"] = value }
        if let value = self.received { out["received"] = value }
        return out
    }
}

extension Contract.NodeControlCommand {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command_id = Contract.str(document, "command_id")
        self.action = Contract.str(document, "action")
        self.operation = Contract.str(document, "operation")
        self.mode = Contract.str(document, "mode")
        if document["delay_s"] != nil { self.delay_s = Contract.int(document, "delay_s") } else { self.delay_s = nil }
        if document["slot"] != nil { self.slot = Contract.int(document, "slot") } else { self.slot = nil }
        if document["duration_s"] != nil { self.duration_s = Contract.int(document, "duration_s") } else { self.duration_s = nil }
        if document["token"] != nil { self.token = Contract.str(document, "token") } else { self.token = nil }
        self.requested_by = Contract.str(document, "requested_by")
        if document["detail"] != nil { self.detail = Contract.str(document, "detail") } else { self.detail = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command_id"] = self.command_id
        out["action"] = self.action
        out["operation"] = self.operation
        out["mode"] = self.mode
        if let value = self.delay_s { out["delay_s"] = value }
        if let value = self.slot { out["slot"] = value }
        if let value = self.duration_s { out["duration_s"] = value }
        if let value = self.token { out["token"] = value }
        out["requested_by"] = self.requested_by
        if let value = self.detail { out["detail"] = value }
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageHeap {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.internal_free = Contract.int(document, "internal_free")
        self.internal_min = Contract.int(document, "internal_min")
        self.internal_largest = Contract.int(document, "internal_largest")
        self.total_free = Contract.int(document, "total_free")
        self.total_min = Contract.int(document, "total_min")
        if document["psram_free"] != nil { self.psram_free = Contract.int(document, "psram_free") } else { self.psram_free = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["internal_free"] = self.internal_free
        out["internal_min"] = self.internal_min
        out["internal_largest"] = self.internal_largest
        out["total_free"] = self.total_free
        out["total_min"] = self.total_min
        if let value = self.psram_free { out["psram_free"] = value }
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageTasks {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.name = Contract.str(document, "name")
        self.stack_free = Contract.int(document, "stack_free")
        self.priority = Contract.int(document, "priority")
        self.state = Contract.str(document, "state")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["name"] = self.name
        out["stack_free"] = self.stack_free
        out["priority"] = self.priority
        out["state"] = self.state
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageResets {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.reason = Contract.str(document, "reason")
        self.uptime_s = Contract.int(document, "uptime_s")
        self.guard_restarts_in_hour = Contract.int(document, "guard_restarts_in_hour")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["reason"] = self.reason
        out["uptime_s"] = self.uptime_s
        out["guard_restarts_in_hour"] = self.guard_restarts_in_hour
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageBoot {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.cause = Contract.str(document, "cause")
        self.reset_reason = Contract.str(document, "reset_reason")
        if document["uptime_before_s"] != nil { self.uptime_before_s = Contract.int(document, "uptime_before_s") } else { self.uptime_before_s = nil }
        if document["heap_internal_free"] != nil { self.heap_internal_free = Contract.int(document, "heap_internal_free") } else { self.heap_internal_free = nil }
        if document["heap_internal_largest"] != nil { self.heap_internal_largest = Contract.int(document, "heap_internal_largest") } else { self.heap_internal_largest = nil }
        self.coredump = Contract.flag(document, "coredump")
        self.deliberate = Contract.flag(document, "deliberate")
        self.`guard` = Contract.flag(document, "guard")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["cause"] = self.cause
        out["reset_reason"] = self.reset_reason
        if let value = self.uptime_before_s { out["uptime_before_s"] = value }
        if let value = self.heap_internal_free { out["heap_internal_free"] = value }
        if let value = self.heap_internal_largest { out["heap_internal_largest"] = value }
        out["coredump"] = self.coredump
        out["deliberate"] = self.deliberate
        out["guard"] = self.`guard`
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageMemoryGate {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.closed = Contract.flag(document, "closed")
        self.transitions = Contract.int(document, "transitions")
        self.close_free = Contract.int(document, "close_free")
        self.close_block = Contract.int(document, "close_block")
        self.open_free = Contract.int(document, "open_free")
        self.open_block = Contract.int(document, "open_block")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["closed"] = self.closed
        out["transitions"] = self.transitions
        out["close_free"] = self.close_free
        out["close_block"] = self.close_block
        out["open_free"] = self.open_free
        out["open_block"] = self.open_block
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageVersionsSensors {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.name = Contract.str(document, "name")
        self.version = Contract.str(document, "version")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["name"] = self.name
        out["version"] = self.version
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageVersions {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.firmware = Contract.str(document, "firmware")
        self.idf = Contract.str(document, "idf")
        if document["board"] != nil { self.board = Contract.str(document, "board") } else { self.board = nil }
        self.sensors = Contract.listAt(document, "sensors").map { Contract.NodeControlResultDiagnosticsPackageVersionsSensors(reading: Contract.objOf($0)) }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["firmware"] = self.firmware
        out["idf"] = self.idf
        if let value = self.board { out["board"] = value }
        out["sensors"] = self.sensors.map { $0.toJSON() }
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageCoredumpSummary {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.task = Contract.str(document, "task")
        if document["reason"] != nil { self.reason = Contract.str(document, "reason") } else { self.reason = nil }
        if document["pc"] != nil { self.pc = Contract.str(document, "pc") } else { self.pc = nil }
        if document["backtrace"] != nil { self.backtrace = Contract.listAt(document, "backtrace").map(Contract.asStr) } else { self.backtrace = nil }
        if document["app_sha256"] != nil { self.app_sha256 = Contract.str(document, "app_sha256") } else { self.app_sha256 = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["task"] = self.task
        if let value = self.reason { out["reason"] = value }
        if let value = self.pc { out["pc"] = value }
        if let value = self.backtrace { out["backtrace"] = value }
        if let value = self.app_sha256 { out["app_sha256"] = value }
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackageCoredump {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.present = Contract.flag(document, "present")
        if document["size"] != nil { self.size = Contract.int(document, "size") } else { self.size = nil }
        if document["summary"] != nil { self.summary = Contract.NodeControlResultDiagnosticsPackageCoredumpSummary(reading: Contract.objAt(document, "summary")) } else { self.summary = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["present"] = self.present
        if let value = self.size { out["size"] = value }
        if let value = self.summary { out["summary"] = value.toJSON() }
        return out
    }
}

extension Contract.NodeControlResultDiagnosticsPackage {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.detail = Contract.str(document, "detail")
        if document["heap"] != nil { self.heap = Contract.NodeControlResultDiagnosticsPackageHeap(reading: Contract.objAt(document, "heap")) } else { self.heap = nil }
        if document["tasks"] != nil { self.tasks = Contract.listAt(document, "tasks").map { Contract.NodeControlResultDiagnosticsPackageTasks(reading: Contract.objOf($0)) } } else { self.tasks = nil }
        if document["resets"] != nil { self.resets = Contract.NodeControlResultDiagnosticsPackageResets(reading: Contract.objAt(document, "resets")) } else { self.resets = nil }
        if document["boot"] != nil { self.boot = Contract.NodeControlResultDiagnosticsPackageBoot(reading: Contract.objAt(document, "boot")) } else { self.boot = nil }
        if document["memory_gate"] != nil { self.memory_gate = Contract.NodeControlResultDiagnosticsPackageMemoryGate(reading: Contract.objAt(document, "memory_gate")) } else { self.memory_gate = nil }
        if document["versions"] != nil { self.versions = Contract.NodeControlResultDiagnosticsPackageVersions(reading: Contract.objAt(document, "versions")) } else { self.versions = nil }
        if document["config"] != nil { self.config = Contract.objAt(document, "config").mapValues(Contract.asStr) } else { self.config = nil }
        if document["coredump"] != nil { self.coredump = Contract.NodeControlResultDiagnosticsPackageCoredump(reading: Contract.objAt(document, "coredump")) } else { self.coredump = nil }
        self.log = Contract.str(document, "log")
        self.truncated = Contract.flag(document, "truncated")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["detail"] = self.detail
        if let value = self.heap { out["heap"] = value.toJSON() }
        if let value = self.tasks { out["tasks"] = value.map { $0.toJSON() } }
        if let value = self.resets { out["resets"] = value.toJSON() }
        if let value = self.boot { out["boot"] = value.toJSON() }
        if let value = self.memory_gate { out["memory_gate"] = value.toJSON() }
        if let value = self.versions { out["versions"] = value.toJSON() }
        if let value = self.config { out["config"] = value }
        if let value = self.coredump { out["coredump"] = value.toJSON() }
        out["log"] = self.log
        out["truncated"] = self.truncated
        return out
    }
}

extension Contract.NodeControlResultDiagnostics {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.firmware = Contract.str(document, "firmware")
        self.uptime_s = Contract.int(document, "uptime_s")
        self.reset_reason = Contract.str(document, "reset_reason")
        self.heap_free = Contract.int(document, "heap_free")
        self.heap_min = Contract.int(document, "heap_min")
        if document["psram_free"] != nil { self.psram_free = Contract.int(document, "psram_free") } else { self.psram_free = nil }
        if document["stack_min_free"] != nil { self.stack_min_free = Contract.int(document, "stack_min_free") } else { self.stack_min_free = nil }
        if document["rssi"] != nil { self.rssi = Contract.int(document, "rssi") } else { self.rssi = nil }
        self.mqtt_connected = Contract.flag(document, "mqtt_connected")
        self.state = Contract.str(document, "state")
        self.maintenance = Contract.flag(document, "maintenance")
        if document["package"] != nil { self.package = Contract.NodeControlResultDiagnosticsPackage(reading: Contract.objAt(document, "package")) } else { self.package = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["firmware"] = self.firmware
        out["uptime_s"] = self.uptime_s
        out["reset_reason"] = self.reset_reason
        out["heap_free"] = self.heap_free
        out["heap_min"] = self.heap_min
        if let value = self.psram_free { out["psram_free"] = value }
        if let value = self.stack_min_free { out["stack_min_free"] = value }
        if let value = self.rssi { out["rssi"] = value }
        out["mqtt_connected"] = self.mqtt_connected
        out["state"] = self.state
        out["maintenance"] = self.maintenance
        if let value = self.package { out["package"] = value.toJSON() }
        return out
    }
}

extension Contract.NodeControlResult {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command_id = Contract.str(document, "command_id")
        self.action = Contract.str(document, "action")
        self.operation = Contract.str(document, "operation")
        self.stage = Contract.str(document, "stage")
        self.accepted = Contract.flag(document, "accepted")
        self.refusal = Contract.str(document, "refusal")
        if document["token"] != nil { self.token = Contract.str(document, "token") } else { self.token = nil }
        if document["token_ttl_s"] != nil { self.token_ttl_s = Contract.int(document, "token_ttl_s") } else { self.token_ttl_s = nil }
        if document["reason"] != nil { self.reason = Contract.str(document, "reason") } else { self.reason = nil }
        if document["mode"] != nil { self.mode = Contract.str(document, "mode") } else { self.mode = nil }
        if document["restart_in_s"] != nil { self.restart_in_s = Contract.int(document, "restart_in_s") } else { self.restart_in_s = nil }
        if document["uptime_s"] != nil { self.uptime_s = Contract.int(document, "uptime_s") } else { self.uptime_s = nil }
        if document["firmware"] != nil { self.firmware = Contract.str(document, "firmware") } else { self.firmware = nil }
        if document["requested_by"] != nil { self.requested_by = Contract.str(document, "requested_by") } else { self.requested_by = nil }
        if document["state"] != nil { self.state = Contract.str(document, "state") } else { self.state = nil }
        if document["maintenance"] != nil { self.maintenance = Contract.flag(document, "maintenance") } else { self.maintenance = nil }
        if document["until_s"] != nil { self.until_s = Contract.int(document, "until_s") } else { self.until_s = nil }
        if document["since_ms"] != nil { self.since_ms = Contract.int(document, "since_ms") } else { self.since_ms = nil }
        if document["diagnostics"] != nil { self.diagnostics = Contract.NodeControlResultDiagnostics(reading: Contract.objAt(document, "diagnostics")) } else { self.diagnostics = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command_id"] = self.command_id
        out["action"] = self.action
        out["operation"] = self.operation
        out["stage"] = self.stage
        out["accepted"] = self.accepted
        out["refusal"] = self.refusal
        if let value = self.token { out["token"] = value }
        if let value = self.token_ttl_s { out["token_ttl_s"] = value }
        if let value = self.reason { out["reason"] = value }
        if let value = self.mode { out["mode"] = value }
        if let value = self.restart_in_s { out["restart_in_s"] = value }
        if let value = self.uptime_s { out["uptime_s"] = value }
        if let value = self.firmware { out["firmware"] = value }
        if let value = self.requested_by { out["requested_by"] = value }
        if let value = self.state { out["state"] = value }
        if let value = self.maintenance { out["maintenance"] = value }
        if let value = self.until_s { out["until_s"] = value }
        if let value = self.since_ms { out["since_ms"] = value }
        if let value = self.diagnostics { out["diagnostics"] = value.toJSON() }
        return out
    }
}

extension Contract.NodeMaintenance {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.active = Contract.flag(document, "active")
        self.reason = Contract.str(document, "reason")
        if document["expected_s"] != nil { self.expected_s = Contract.int(document, "expected_s") } else { self.expected_s = nil }
        self.firmware = Contract.str(document, "firmware")
        if document["requested_by"] != nil { self.requested_by = Contract.str(document, "requested_by") } else { self.requested_by = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["active"] = self.active
        out["reason"] = self.reason
        if let value = self.expected_s { out["expected_s"] = value }
        out["firmware"] = self.firmware
        if let value = self.requested_by { out["requested_by"] = value }
        return out
    }
}

extension Contract.RadarEvent {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.boot = Contract.int(document, "boot")
        self.seq = Contract.int(document, "seq")
        self.event = Contract.str(document, "event")
        if document["name"] != nil { self.name = Contract.str(document, "name") } else { self.name = nil }
        if document["sensor_id"] != nil { self.sensor_id = Contract.int(document, "sensor_id") } else { self.sensor_id = nil }
        if document["track_id"] != nil { self.track_id = Contract.int(document, "track_id") } else { self.track_id = nil }
        if document["movement"] != nil { self.movement = Contract.str(document, "movement") } else { self.movement = nil }
        if document["value"] != nil { self.value = Contract.int(document, "value") } else { self.value = nil }
        if document["count"] != nil { self.count = Contract.int(document, "count") } else { self.count = nil }
        if document["direction"] != nil { self.direction = Contract.str(document, "direction") } else { self.direction = nil }
        if document["from"] != nil { self.from = Contract.str(document, "from") } else { self.from = nil }
        if document["by"] != nil { self.by = Contract.str(document, "by") } else { self.by = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["boot"] = self.boot
        out["seq"] = self.seq
        out["event"] = self.event
        if let value = self.name { out["name"] = value }
        if let value = self.sensor_id { out["sensor_id"] = value }
        if let value = self.track_id { out["track_id"] = value }
        if let value = self.movement { out["movement"] = value }
        if let value = self.value { out["value"] = value }
        if let value = self.count { out["count"] = value }
        if let value = self.direction { out["direction"] = value }
        if let value = self.from { out["from"] = value }
        if let value = self.by { out["by"] = value }
        return out
    }
}

extension Contract.DiagnosticTokenRequest {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.nodes = Contract.listAt(document, "nodes").map(Contract.asStr)
        if document["ttl_s"] != nil { self.ttl_s = Contract.int(document, "ttl_s") } else { self.ttl_s = nil }
        if document["label"] != nil { self.label = Contract.str(document, "label") } else { self.label = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["nodes"] = self.nodes
        if let value = self.ttl_s { out["ttl_s"] = value }
        if let value = self.label { out["label"] = value }
        return out
    }
}

extension Contract.DiagnosticTokenCreated {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.token = Contract.str(document, "token")
        self.scope = Contract.str(document, "scope")
        self.nodes = Contract.listAt(document, "nodes").map(Contract.asStr)
        if document["label"] != nil { self.label = Contract.str(document, "label") } else { self.label = nil }
        self.created_at = Contract.str(document, "created_at")
        self.expires_at = Contract.str(document, "expires_at")
        self.created_by = Contract.str(document, "created_by")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["token"] = self.token
        out["scope"] = self.scope
        out["nodes"] = self.nodes
        if let value = self.label { out["label"] = value }
        out["created_at"] = self.created_at
        out["expires_at"] = self.expires_at
        out["created_by"] = self.created_by
        return out
    }
}

extension Contract.DiagnosticTokenInfo {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.scope = Contract.str(document, "scope")
        self.nodes = Contract.listAt(document, "nodes").map(Contract.asStr)
        if document["label"] != nil { self.label = Contract.str(document, "label") } else { self.label = nil }
        self.created_at = Contract.str(document, "created_at")
        self.expires_at = Contract.str(document, "expires_at")
        self.created_by = Contract.str(document, "created_by")
        self.status = Contract.str(document, "status")
        if document["revoked_at"] != nil { self.revoked_at = Contract.str(document, "revoked_at") } else { self.revoked_at = nil }
        if document["revoked_by"] != nil { self.revoked_by = Contract.str(document, "revoked_by") } else { self.revoked_by = nil }
        self.uses = Contract.int(document, "uses")
        if document["last_used_at"] != nil { self.last_used_at = Contract.str(document, "last_used_at") } else { self.last_used_at = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["scope"] = self.scope
        out["nodes"] = self.nodes
        if let value = self.label { out["label"] = value }
        out["created_at"] = self.created_at
        out["expires_at"] = self.expires_at
        out["created_by"] = self.created_by
        out["status"] = self.status
        if let value = self.revoked_at { out["revoked_at"] = value }
        if let value = self.revoked_by { out["revoked_by"] = value }
        out["uses"] = self.uses
        if let value = self.last_used_at { out["last_used_at"] = value }
        return out
    }
}

extension Contract.AlarmZone {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        if document["name"] != nil { self.name = Contract.str(document, "name") } else { self.name = nil }
        self.kind = Contract.str(document, "kind")
        self.state = Contract.str(document, "state")
        self.bypassed = Contract.flag(document, "bypassed")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        if let value = self.name { out["name"] = value }
        out["kind"] = self.kind
        out["state"] = self.state
        out["bypassed"] = self.bypassed
        return out
    }
}

extension Contract.AlarmEvent {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.ago_s = Contract.int(document, "ago_s")
        self.kind = Contract.str(document, "kind")
        if document["zone"] != nil { self.zone = Contract.str(document, "zone") } else { self.zone = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["ago_s"] = self.ago_s
        out["kind"] = self.kind
        if let value = self.zone { out["zone"] = value }
        return out
    }
}

extension Contract.Alarm {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.phase = Contract.str(document, "phase")
        self.mode = Contract.str(document, "mode")
        self.siren = Contract.flag(document, "siren")
        self.locked_out = Contract.flag(document, "locked_out")
        self.commands_enabled = Contract.flag(document, "commands_enabled")
        self.zones = Contract.listAt(document, "zones").map { Contract.AlarmZone(reading: Contract.objOf($0)) }
        self.open_zones = Contract.listAt(document, "open_zones").map(Contract.asStr)
        self.events = Contract.listAt(document, "events").map { Contract.AlarmEvent(reading: Contract.objOf($0)) }
        if document["arm_profiles"] != nil { self.arm_profiles = Contract.flag(document, "arm_profiles") } else { self.arm_profiles = nil }
        if document["profile"] != nil { self.profile = Contract.str(document, "profile") } else { self.profile = nil }
        if document["siren_loop"] != nil { self.siren_loop = Contract.str(document, "siren_loop") } else { self.siren_loop = nil }
        if document["siren_fault"] != nil { self.siren_fault = Contract.flag(document, "siren_fault") } else { self.siren_fault = nil }
        if document["seq"] != nil { self.seq = Contract.int(document, "seq") } else { self.seq = nil }
        if document["sig"] != nil { self.sig = Contract.str(document, "sig") } else { self.sig = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["phase"] = self.phase
        out["mode"] = self.mode
        out["siren"] = self.siren
        out["locked_out"] = self.locked_out
        out["commands_enabled"] = self.commands_enabled
        out["zones"] = self.zones.map { $0.toJSON() }
        out["open_zones"] = self.open_zones
        out["events"] = self.events.map { $0.toJSON() }
        if let value = self.arm_profiles { out["arm_profiles"] = value }
        if let value = self.profile { out["profile"] = value }
        if let value = self.siren_loop { out["siren_loop"] = value }
        if let value = self.siren_fault { out["siren_fault"] = value }
        if let value = self.seq { out["seq"] = value }
        if let value = self.sig { out["sig"] = value }
        return out
    }
}

extension Contract.ArmProfileZone {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        if document["armed"] != nil { self.armed = Contract.flag(document, "armed") } else { self.armed = nil }
        if document["delay"] != nil { self.delay = Contract.str(document, "delay") } else { self.delay = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        if let value = self.armed { out["armed"] = value }
        if let value = self.delay { out["delay"] = value }
        return out
    }
}

extension Contract.ArmProfile {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.name = Contract.str(document, "name")
        self.base = Contract.str(document, "base")
        if document["exit_delay_s"] != nil { self.exit_delay_s = Contract.int(document, "exit_delay_s") } else { self.exit_delay_s = nil }
        if document["entry_delay_s"] != nil { self.entry_delay_s = Contract.int(document, "entry_delay_s") } else { self.entry_delay_s = nil }
        if document["siren"] != nil { self.siren = Contract.flag(document, "siren") } else { self.siren = nil }
        if document["notify"] != nil { self.notify = Contract.str(document, "notify") } else { self.notify = nil }
        if document["zones"] != nil { self.zones = Contract.listAt(document, "zones").map { Contract.ArmProfileZone(reading: Contract.objOf($0)) } } else { self.zones = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["name"] = self.name
        out["base"] = self.base
        if let value = self.exit_delay_s { out["exit_delay_s"] = value }
        if let value = self.entry_delay_s { out["entry_delay_s"] = value }
        if let value = self.siren { out["siren"] = value }
        if let value = self.notify { out["notify"] = value }
        if let value = self.zones { out["zones"] = value.map { $0.toJSON() } }
        return out
    }
}

extension Contract.AlarmCommand {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command_id = Contract.str(document, "command_id")
        self.action = Contract.str(document, "action")
        if document["mode"] != nil { self.mode = Contract.str(document, "mode") } else { self.mode = nil }
        if document["force"] != nil { self.force = Contract.flag(document, "force") } else { self.force = nil }
        if document["profile"] != nil { self.profile = Contract.ArmProfile(reading: Contract.objAt(document, "profile")) } else { self.profile = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command_id"] = self.command_id
        out["action"] = self.action
        if let value = self.mode { out["mode"] = value }
        if let value = self.force { out["force"] = value }
        if let value = self.profile { out["profile"] = value.toJSON() }
        return out
    }
}

extension Contract.AlarmResult {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.command_id = Contract.str(document, "command_id")
        self.action = Contract.str(document, "action")
        self.accepted = Contract.flag(document, "accepted")
        self.refusal = Contract.str(document, "refusal")
        self.phase = Contract.str(document, "phase")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["command_id"] = self.command_id
        out["action"] = self.action
        out["accepted"] = self.accepted
        out["refusal"] = self.refusal
        out["phase"] = self.phase
        return out
    }
}

extension Contract.ArmingModesModesAway {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["entry"] != nil { self.entry = Contract.listAt(document, "entry").map(Contract.asStr) } else { self.entry = nil }
        if document["exit_delay_s"] != nil { self.exit_delay_s = Contract.int(document, "exit_delay_s") } else { self.exit_delay_s = nil }
        if document["entry_delay_s"] != nil { self.entry_delay_s = Contract.int(document, "entry_delay_s") } else { self.entry_delay_s = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.entry { out["entry"] = value }
        if let value = self.exit_delay_s { out["exit_delay_s"] = value }
        if let value = self.entry_delay_s { out["entry_delay_s"] = value }
        return out
    }
}

extension Contract.ArmingModesModesHome {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["defends"] != nil { self.defends = Contract.listAt(document, "defends").map(Contract.asStr) } else { self.defends = nil }
        if document["entry"] != nil { self.entry = Contract.listAt(document, "entry").map(Contract.asStr) } else { self.entry = nil }
        if document["exit_delay_s"] != nil { self.exit_delay_s = Contract.int(document, "exit_delay_s") } else { self.exit_delay_s = nil }
        if document["entry_delay_s"] != nil { self.entry_delay_s = Contract.int(document, "entry_delay_s") } else { self.entry_delay_s = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.defends { out["defends"] = value }
        if let value = self.entry { out["entry"] = value }
        if let value = self.exit_delay_s { out["exit_delay_s"] = value }
        if let value = self.entry_delay_s { out["entry_delay_s"] = value }
        return out
    }
}

extension Contract.ArmingModesModesNight {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["defends"] != nil { self.defends = Contract.listAt(document, "defends").map(Contract.asStr) } else { self.defends = nil }
        if document["entry"] != nil { self.entry = Contract.listAt(document, "entry").map(Contract.asStr) } else { self.entry = nil }
        if document["exit_delay_s"] != nil { self.exit_delay_s = Contract.int(document, "exit_delay_s") } else { self.exit_delay_s = nil }
        if document["entry_delay_s"] != nil { self.entry_delay_s = Contract.int(document, "entry_delay_s") } else { self.entry_delay_s = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.defends { out["defends"] = value }
        if let value = self.entry { out["entry"] = value }
        if let value = self.exit_delay_s { out["exit_delay_s"] = value }
        if let value = self.entry_delay_s { out["entry_delay_s"] = value }
        return out
    }
}

extension Contract.ArmingModesModes {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.away = Contract.ArmingModesModesAway(reading: Contract.objAt(document, "away"))
        self.home = Contract.ArmingModesModesHome(reading: Contract.objAt(document, "home"))
        self.night = Contract.ArmingModesModesNight(reading: Contract.objAt(document, "night"))
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["away"] = self.away.toJSON()
        out["home"] = self.home.toJSON()
        out["night"] = self.night.toJSON()
        return out
    }
}

extension Contract.ArmingModesSchedule {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.mode = Contract.str(document, "mode")
        self.days = Contract.listAt(document, "days").map(Contract.asInt)
        self.at = Contract.str(document, "at")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["mode"] = self.mode
        out["days"] = self.days
        out["at"] = self.at
        return out
    }
}

extension Contract.ArmingModesPanelMapProfiles {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["away"] != nil { self.away = Contract.str(document, "away") } else { self.away = nil }
        if document["home"] != nil { self.home = Contract.str(document, "home") } else { self.home = nil }
        if document["night"] != nil { self.night = Contract.str(document, "night") } else { self.night = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.away { out["away"] = value }
        if let value = self.home { out["home"] = value }
        if let value = self.night { out["night"] = value }
        return out
    }
}

extension Contract.ArmingModesPanelMap {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["profiles"] != nil { self.profiles = Contract.ArmingModesPanelMapProfiles(reading: Contract.objAt(document, "profiles")) } else { self.profiles = nil }
        if document["only"] != nil { self.only = Contract.listAt(document, "only").map(Contract.asStr) } else { self.only = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.profiles { out["profiles"] = value.toJSON() }
        if let value = self.only { out["only"] = value }
        return out
    }
}

extension Contract.ArmingModes {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.modes = Contract.ArmingModesModes(reading: Contract.objAt(document, "modes"))
        if document["schedule"] != nil { self.schedule = Contract.listAt(document, "schedule").map { Contract.ArmingModesSchedule(reading: Contract.objOf($0)) } } else { self.schedule = nil }
        if document["panel_map"] != nil { self.panel_map = Contract.ArmingModesPanelMap(reading: Contract.objAt(document, "panel_map")) } else { self.panel_map = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["modes"] = self.modes.toJSON()
        if let value = self.schedule { out["schedule"] = value.map { $0.toJSON() } }
        if let value = self.panel_map { out["panel_map"] = value.toJSON() }
        return out
    }
}

extension Contract.AlarmZoneFeed {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.zone = Contract.str(document, "zone")
        self.state = Contract.str(document, "state")
        self.battery_low = Contract.flag(document, "battery_low")
        if document["seq"] != nil { self.seq = Contract.int(document, "seq") } else { self.seq = nil }
        if document["sig"] != nil { self.sig = Contract.str(document, "sig") } else { self.sig = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["zone"] = self.zone
        out["state"] = self.state
        out["battery_low"] = self.battery_low
        if let value = self.seq { out["seq"] = value }
        if let value = self.sig { out["sig"] = value }
        return out
    }
}

extension Contract.AlarmPolicy {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.config_hash = Contract.flag(document, "config_hash")
        self.zone_feed = Contract.flag(document, "zone_feed")
        self.zone_feed_signature = Contract.flag(document, "zone_feed_signature")
        if document["disarm_pin"] != nil { self.disarm_pin = Contract.str(document, "disarm_pin") } else { self.disarm_pin = nil }
        if document["nvs_encryption"] != nil { self.nvs_encryption = Contract.str(document, "nvs_encryption") } else { self.nvs_encryption = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["config_hash"] = self.config_hash
        out["zone_feed"] = self.zone_feed
        out["zone_feed_signature"] = self.zone_feed_signature
        if let value = self.disarm_pin { out["disarm_pin"] = value }
        if let value = self.nvs_encryption { out["nvs_encryption"] = value }
        return out
    }
}

extension Contract.NodeHealthBoot {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.cause = Contract.str(document, "cause")
        self.reset_reason = Contract.str(document, "reset_reason")
        if document["uptime_before_s"] != nil { self.uptime_before_s = Contract.int(document, "uptime_before_s") } else { self.uptime_before_s = nil }
        if document["heap_internal_free"] != nil { self.heap_internal_free = Contract.int(document, "heap_internal_free") } else { self.heap_internal_free = nil }
        if document["heap_internal_largest"] != nil { self.heap_internal_largest = Contract.int(document, "heap_internal_largest") } else { self.heap_internal_largest = nil }
        self.coredump = Contract.flag(document, "coredump")
        self.deliberate = Contract.flag(document, "deliberate")
        self.`guard` = Contract.flag(document, "guard")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["cause"] = self.cause
        out["reset_reason"] = self.reset_reason
        if let value = self.uptime_before_s { out["uptime_before_s"] = value }
        if let value = self.heap_internal_free { out["heap_internal_free"] = value }
        if let value = self.heap_internal_largest { out["heap_internal_largest"] = value }
        out["coredump"] = self.coredump
        out["deliberate"] = self.deliberate
        out["guard"] = self.`guard`
        return out
    }
}

extension Contract.NodeHealthMemoryGate {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.closed = Contract.flag(document, "closed")
        self.transitions = Contract.int(document, "transitions")
        self.close_free = Contract.int(document, "close_free")
        self.close_block = Contract.int(document, "close_block")
        self.open_free = Contract.int(document, "open_free")
        self.open_block = Contract.int(document, "open_block")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["closed"] = self.closed
        out["transitions"] = self.transitions
        out["close_free"] = self.close_free
        out["close_block"] = self.close_block
        out["open_free"] = self.open_free
        out["open_block"] = self.open_block
        return out
    }
}

extension Contract.NodeHealthCoredump {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.present = Contract.flag(document, "present")
        if document["size"] != nil { self.size = Contract.int(document, "size") } else { self.size = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["present"] = self.present
        if let value = self.size { out["size"] = value }
        return out
    }
}

extension Contract.NodeHealthConfigCheck {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["snapshot"] != nil { self.snapshot = Contract.str(document, "snapshot") } else { self.snapshot = nil }
        if document["reverted"] != nil { self.reverted = Contract.str(document, "reverted") } else { self.reverted = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.snapshot { out["snapshot"] = value }
        if let value = self.reverted { out["reverted"] = value }
        return out
    }
}

extension Contract.NodeHealthSensors {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.sensor_id = Contract.int(document, "sensor_id")
        self.model = Contract.str(document, "model")
        self.state = Contract.str(document, "state")
        self.firmware_known = Contract.flag(document, "firmware_known")
        if document["firmware"] != nil { self.firmware = Contract.str(document, "firmware") } else { self.firmware = nil }
        self.bluetooth = Contract.str(document, "bluetooth")
        if document["mac"] != nil { self.mac = Contract.str(document, "mac") } else { self.mac = nil }
        if document["bluetooth_alert"] != nil { self.bluetooth_alert = Contract.flag(document, "bluetooth_alert") } else { self.bluetooth_alert = nil }
        if document["quirk"] != nil { self.quirk = Contract.str(document, "quirk") } else { self.quirk = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["sensor_id"] = self.sensor_id
        out["model"] = self.model
        out["state"] = self.state
        out["firmware_known"] = self.firmware_known
        if let value = self.firmware { out["firmware"] = value }
        out["bluetooth"] = self.bluetooth
        if let value = self.mac { out["mac"] = value }
        if let value = self.bluetooth_alert { out["bluetooth_alert"] = value }
        if let value = self.quirk { out["quirk"] = value }
        return out
    }
}

extension Contract.NodeHealthRadar {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.perimeter_enabled = Contract.flag(document, "perimeter_enabled")
        self.masked = Contract.flag(document, "masked")
        self.wifi_jam = Contract.flag(document, "wifi_jam")
        self.bridge_open = Contract.flag(document, "bridge_open")
        self.events_buffered = Contract.int(document, "events_buffered")
        self.sensor_bluetooth_off = Contract.flag(document, "sensor_bluetooth_off")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["perimeter_enabled"] = self.perimeter_enabled
        out["masked"] = self.masked
        out["wifi_jam"] = self.wifi_jam
        out["bridge_open"] = self.bridge_open
        out["events_buffered"] = self.events_buffered
        out["sensor_bluetooth_off"] = self.sensor_bluetooth_off
        return out
    }
}

extension Contract.NodeHealth {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.family = Contract.str(document, "family")
        self.firmware = Contract.str(document, "firmware")
        if document["contract"] != nil { self.contract = Contract.str(document, "contract") } else { self.contract = nil }
        if document["board"] != nil { self.board = Contract.str(document, "board") } else { self.board = nil }
        self.uptime_s = Contract.int(document, "uptime_s")
        self.reset_reason = Contract.str(document, "reset_reason")
        self.heap_free = Contract.int(document, "heap_free")
        self.heap_min = Contract.int(document, "heap_min")
        if document["heap_internal_free"] != nil { self.heap_internal_free = Contract.int(document, "heap_internal_free") } else { self.heap_internal_free = nil }
        if document["heap_internal_min"] != nil { self.heap_internal_min = Contract.int(document, "heap_internal_min") } else { self.heap_internal_min = nil }
        if document["heap_internal_largest"] != nil { self.heap_internal_largest = Contract.int(document, "heap_internal_largest") } else { self.heap_internal_largest = nil }
        if document["psram_free"] != nil { self.psram_free = Contract.int(document, "psram_free") } else { self.psram_free = nil }
        self.link = Contract.str(document, "link")
        self.link_up = Contract.flag(document, "link_up")
        if document["rssi_dbm"] != nil { self.rssi_dbm = Contract.int(document, "rssi_dbm") } else { self.rssi_dbm = nil }
        self.broker_reconnects = Contract.int(document, "broker_reconnects")
        if document["low_stack_tasks"] != nil { self.low_stack_tasks = Contract.int(document, "low_stack_tasks") } else { self.low_stack_tasks = nil }
        if document["last_error"] != nil { self.last_error = Contract.str(document, "last_error") } else { self.last_error = nil }
        if document["control_state"] != nil { self.control_state = Contract.str(document, "control_state") } else { self.control_state = nil }
        if document["control_since_ms"] != nil { self.control_since_ms = Contract.int(document, "control_since_ms") } else { self.control_since_ms = nil }
        if document["control_by"] != nil { self.control_by = Contract.str(document, "control_by") } else { self.control_by = nil }
        if document["control_until_s"] != nil { self.control_until_s = Contract.int(document, "control_until_s") } else { self.control_until_s = nil }
        if document["maintenance"] != nil { self.maintenance = Contract.flag(document, "maintenance") } else { self.maintenance = nil }
        if document["maintenance_until_s"] != nil { self.maintenance_until_s = Contract.int(document, "maintenance_until_s") } else { self.maintenance_until_s = nil }
        if document["boot"] != nil { self.boot = Contract.NodeHealthBoot(reading: Contract.objAt(document, "boot")) } else { self.boot = nil }
        if document["memory_gate"] != nil { self.memory_gate = Contract.NodeHealthMemoryGate(reading: Contract.objAt(document, "memory_gate")) } else { self.memory_gate = nil }
        if document["coredump"] != nil { self.coredump = Contract.NodeHealthCoredump(reading: Contract.objAt(document, "coredump")) } else { self.coredump = nil }
        if document["config_check"] != nil { self.config_check = Contract.NodeHealthConfigCheck(reading: Contract.objAt(document, "config_check")) } else { self.config_check = nil }
        if document["sensors"] != nil { self.sensors = Contract.listAt(document, "sensors").map { Contract.NodeHealthSensors(reading: Contract.objOf($0)) } } else { self.sensors = nil }
        if document["radar"] != nil { self.radar = Contract.NodeHealthRadar(reading: Contract.objAt(document, "radar")) } else { self.radar = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        out["timestamp_ms"] = self.timestamp_ms
        out["family"] = self.family
        out["firmware"] = self.firmware
        if let value = self.contract { out["contract"] = value }
        if let value = self.board { out["board"] = value }
        out["uptime_s"] = self.uptime_s
        out["reset_reason"] = self.reset_reason
        out["heap_free"] = self.heap_free
        out["heap_min"] = self.heap_min
        if let value = self.heap_internal_free { out["heap_internal_free"] = value }
        if let value = self.heap_internal_min { out["heap_internal_min"] = value }
        if let value = self.heap_internal_largest { out["heap_internal_largest"] = value }
        if let value = self.psram_free { out["psram_free"] = value }
        out["link"] = self.link
        out["link_up"] = self.link_up
        if let value = self.rssi_dbm { out["rssi_dbm"] = value }
        out["broker_reconnects"] = self.broker_reconnects
        if let value = self.low_stack_tasks { out["low_stack_tasks"] = value }
        if let value = self.last_error { out["last_error"] = value }
        if let value = self.control_state { out["control_state"] = value }
        if let value = self.control_since_ms { out["control_since_ms"] = value }
        if let value = self.control_by { out["control_by"] = value }
        if let value = self.control_until_s { out["control_until_s"] = value }
        if let value = self.maintenance { out["maintenance"] = value }
        if let value = self.maintenance_until_s { out["maintenance_until_s"] = value }
        if let value = self.boot { out["boot"] = value.toJSON() }
        if let value = self.memory_gate { out["memory_gate"] = value.toJSON() }
        if let value = self.coredump { out["coredump"] = value.toJSON() }
        if let value = self.config_check { out["config_check"] = value.toJSON() }
        if let value = self.sensors { out["sensors"] = value.map { $0.toJSON() } }
        if let value = self.radar { out["radar"] = value.toJSON() }
        return out
    }
}

extension Contract.VoiceTurnMeta {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.language = Contract.str(document, "language")
        self.encoding = Contract.str(document, "encoding")
        self.sample_rate = Contract.int(document, "sample_rate")
        self.channels = Contract.int(document, "channels")
        if document["reply_audio"] != nil { self.reply_audio = Contract.str(document, "reply_audio") } else { self.reply_audio = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["language"] = self.language
        out["encoding"] = self.encoding
        out["sample_rate"] = self.sample_rate
        out["channels"] = self.channels
        if let value = self.reply_audio { out["reply_audio"] = value }
        return out
    }
}

extension Contract.VoiceTurnResult {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.heard = Contract.str(document, "heard")
        self.reply = Contract.str(document, "reply")
        if document["audio"] != nil { self.audio = Contract.str(document, "audio") } else { self.audio = nil }
        if document["audio_omitted"] != nil { self.audio_omitted = Contract.str(document, "audio_omitted") } else { self.audio_omitted = nil }
        if document["challenge"] != nil { self.challenge = Contract.str(document, "challenge") } else { self.challenge = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["heard"] = self.heard
        out["reply"] = self.reply
        if let value = self.audio { out["audio"] = value }
        if let value = self.audio_omitted { out["audio_omitted"] = value }
        if let value = self.challenge { out["challenge"] = value }
        return out
    }
}

extension Contract.ConnectionEvent {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.int(document, "id")
        self.at = Contract.str(document, "at")
        self.type = Contract.str(document, "type")
        self.action = Contract.str(document, "action")
        self.client_kind = Contract.str(document, "client_kind")
        self.client_id = Contract.str(document, "client_id")
        if document["user"] != nil { self.user = Contract.str(document, "user") } else { self.user = nil }
        if document["origin"] != nil { self.origin = Contract.str(document, "origin") } else { self.origin = nil }
        if document["two_factor"] != nil { self.two_factor = Contract.flag(document, "two_factor") } else { self.two_factor = nil }
        if document["app_version"] != nil { self.app_version = Contract.str(document, "app_version") } else { self.app_version = nil }
        if document["subject"] != nil { self.subject = Contract.str(document, "subject") } else { self.subject = nil }
        if document["ip"] != nil { self.ip = Contract.str(document, "ip") } else { self.ip = nil }
        if document["agent"] != nil { self.agent = Contract.str(document, "agent") } else { self.agent = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["at"] = self.at
        out["type"] = self.type
        out["action"] = self.action
        out["client_kind"] = self.client_kind
        out["client_id"] = self.client_id
        if let value = self.user { out["user"] = value }
        if let value = self.origin { out["origin"] = value }
        if let value = self.two_factor { out["two_factor"] = value }
        if let value = self.app_version { out["app_version"] = value }
        if let value = self.subject { out["subject"] = value }
        if let value = self.ip { out["ip"] = value }
        if let value = self.agent { out["agent"] = value }
        return out
    }
}

extension Contract.SystemEvent {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.int(document, "id")
        self.at = Contract.str(document, "at")
        self.type = Contract.str(document, "type")
        self.category = Contract.str(document, "category")
        self.action = Contract.str(document, "action")
        if document["subject"] != nil { self.subject = Contract.str(document, "subject") } else { self.subject = nil }
        if document["by"] != nil { self.by = Contract.str(document, "by") } else { self.by = nil }
        if document["version"] != nil { self.version = Contract.str(document, "version") } else { self.version = nil }
        if document["previous_version"] != nil { self.previous_version = Contract.str(document, "previous_version") } else { self.previous_version = nil }
        if document["profile"] != nil { self.profile = Contract.str(document, "profile") } else { self.profile = nil }
        if document["outcome"] != nil { self.outcome = Contract.str(document, "outcome") } else { self.outcome = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["at"] = self.at
        out["type"] = self.type
        out["category"] = self.category
        out["action"] = self.action
        if let value = self.subject { out["subject"] = value }
        if let value = self.by { out["by"] = value }
        if let value = self.version { out["version"] = value }
        if let value = self.previous_version { out["previous_version"] = value }
        if let value = self.profile { out["profile"] = value }
        if let value = self.outcome { out["outcome"] = value }
        return out
    }
}

extension Contract.ConnectionClient {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.kind = Contract.str(document, "kind")
        if document["user"] != nil { self.user = Contract.str(document, "user") } else { self.user = nil }
        if document["label"] != nil { self.label = Contract.str(document, "label") } else { self.label = nil }
        if document["app_version"] != nil { self.app_version = Contract.str(document, "app_version") } else { self.app_version = nil }
        if document["origin"] != nil { self.origin = Contract.str(document, "origin") } else { self.origin = nil }
        if document["two_factor"] != nil { self.two_factor = Contract.flag(document, "two_factor") } else { self.two_factor = nil }
        self.first_seen = Contract.str(document, "first_seen")
        self.last_seen = Contract.str(document, "last_seen")
        if document["last_failure"] != nil { self.last_failure = Contract.str(document, "last_failure") } else { self.last_failure = nil }
        self.active_sessions = Contract.int(document, "active_sessions")
        self.logins_ok = Contract.int(document, "logins_ok")
        self.logins_failed = Contract.int(document, "logins_failed")
        if document["ip"] != nil { self.ip = Contract.str(document, "ip") } else { self.ip = nil }
        if document["agent"] != nil { self.agent = Contract.str(document, "agent") } else { self.agent = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["kind"] = self.kind
        if let value = self.user { out["user"] = value }
        if let value = self.label { out["label"] = value }
        if let value = self.app_version { out["app_version"] = value }
        if let value = self.origin { out["origin"] = value }
        if let value = self.two_factor { out["two_factor"] = value }
        out["first_seen"] = self.first_seen
        out["last_seen"] = self.last_seen
        if let value = self.last_failure { out["last_failure"] = value }
        out["active_sessions"] = self.active_sessions
        out["logins_ok"] = self.logins_ok
        out["logins_failed"] = self.logins_failed
        if let value = self.ip { out["ip"] = value }
        if let value = self.agent { out["agent"] = value }
        return out
    }
}

extension Contract.DailySummaryBodyTotals {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.events = Contract.int(document, "events")
        self.alarms = Contract.int(document, "alarms")
        self.serious_alarms = Contract.int(document, "serious_alarms")
        self.false_alarms = Contract.int(document, "false_alarms")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["events"] = self.events
        out["alarms"] = self.alarms
        out["serious_alarms"] = self.serious_alarms
        out["false_alarms"] = self.false_alarms
        return out
    }
}

extension Contract.DailySummaryBodySeriousAlarms {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.t_s = Contract.num(document, "t_s")
        if document["code"] != nil { self.code = Contract.str(document, "code") } else { self.code = nil }
        if document["zone"] != nil { self.zone = Contract.str(document, "zone") } else { self.zone = nil }
        if document["node"] != nil { self.node = Contract.str(document, "node") } else { self.node = nil }
        if document["sensor"] != nil { self.sensor = Contract.str(document, "sensor") } else { self.sensor = nil }
        if document["severity"] != nil { self.severity = Contract.str(document, "severity") } else { self.severity = nil }
        if document["watts"] != nil { self.watts = Contract.num(document, "watts") } else { self.watts = nil }
        if document["value"] != nil { self.value = Contract.num(document, "value") } else { self.value = nil }
        if document["duration_s"] != nil { self.duration_s = Contract.num(document, "duration_s") } else { self.duration_s = nil }
        if document["mean_w"] != nil { self.mean_w = Contract.num(document, "mean_w") } else { self.mean_w = nil }
        if document["limit_w"] != nil { self.limit_w = Contract.num(document, "limit_w") } else { self.limit_w = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["t_s"] = self.t_s
        if let value = self.code { out["code"] = value }
        if let value = self.zone { out["zone"] = value }
        if let value = self.node { out["node"] = value }
        if let value = self.sensor { out["sensor"] = value }
        if let value = self.severity { out["severity"] = value }
        if let value = self.watts { out["watts"] = value }
        if let value = self.value { out["value"] = value }
        if let value = self.duration_s { out["duration_s"] = value }
        if let value = self.mean_w { out["mean_w"] = value }
        if let value = self.limit_w { out["limit_w"] = value }
        return out
    }
}

extension Contract.DailySummaryBodyNodesLinkLost {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.node = Contract.str(document, "node")
        self.count = Contract.int(document, "count")
        self.total_s = Contract.num(document, "total_s")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["node"] = self.node
        out["count"] = self.count
        out["total_s"] = self.total_s
        return out
    }
}

extension Contract.DailySummaryBodyOutlierReadings {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.t_s = Contract.num(document, "t_s")
        self.node = Contract.str(document, "node")
        self.sensor = Contract.str(document, "sensor")
        self.value = Contract.num(document, "value")
        self.median = Contract.num(document, "median")
        self.score = Contract.num(document, "score")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["t_s"] = self.t_s
        out["node"] = self.node
        out["sensor"] = self.sensor
        out["value"] = self.value
        out["median"] = self.median
        out["score"] = self.score
        return out
    }
}

extension Contract.DailySummaryBodyConsumptionPeaks {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.t_s = Contract.num(document, "t_s")
        if document["code"] != nil { self.code = Contract.str(document, "code") } else { self.code = nil }
        if document["zone"] != nil { self.zone = Contract.str(document, "zone") } else { self.zone = nil }
        if document["node"] != nil { self.node = Contract.str(document, "node") } else { self.node = nil }
        if document["sensor"] != nil { self.sensor = Contract.str(document, "sensor") } else { self.sensor = nil }
        if document["severity"] != nil { self.severity = Contract.str(document, "severity") } else { self.severity = nil }
        if document["watts"] != nil { self.watts = Contract.num(document, "watts") } else { self.watts = nil }
        if document["value"] != nil { self.value = Contract.num(document, "value") } else { self.value = nil }
        if document["duration_s"] != nil { self.duration_s = Contract.num(document, "duration_s") } else { self.duration_s = nil }
        if document["mean_w"] != nil { self.mean_w = Contract.num(document, "mean_w") } else { self.mean_w = nil }
        if document["limit_w"] != nil { self.limit_w = Contract.num(document, "limit_w") } else { self.limit_w = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["t_s"] = self.t_s
        if let value = self.code { out["code"] = value }
        if let value = self.zone { out["zone"] = value }
        if let value = self.node { out["node"] = value }
        if let value = self.sensor { out["sensor"] = value }
        if let value = self.severity { out["severity"] = value }
        if let value = self.watts { out["watts"] = value }
        if let value = self.value { out["value"] = value }
        if let value = self.duration_s { out["duration_s"] = value }
        if let value = self.mean_w { out["mean_w"] = value }
        if let value = self.limit_w { out["limit_w"] = value }
        return out
    }
}

extension Contract.DailySummaryBodyConsumption {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.samples = Contract.int(document, "samples")
        self.peaks = Contract.listAt(document, "peaks").map { Contract.DailySummaryBodyConsumptionPeaks(reading: Contract.objOf($0)) }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["samples"] = self.samples
        out["peaks"] = self.peaks.map { $0.toJSON() }
        return out
    }
}

extension Contract.DailySummaryBody {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.schema = Contract.str(document, "schema")
        self.totals = Contract.DailySummaryBodyTotals(reading: Contract.objAt(document, "totals"))
        self.by_type = Contract.objAt(document, "by_type").mapValues(Contract.asInt)
        self.by_zone = Contract.objAt(document, "by_zone").mapValues(Contract.asInt)
        self.by_hour = Contract.listAt(document, "by_hour").map(Contract.asInt)
        if document["serious_alarms"] != nil { self.serious_alarms = Contract.listAt(document, "serious_alarms").map { Contract.DailySummaryBodySeriousAlarms(reading: Contract.objOf($0)) } } else { self.serious_alarms = nil }
        if document["nodes_link_lost"] != nil { self.nodes_link_lost = Contract.listAt(document, "nodes_link_lost").map { Contract.DailySummaryBodyNodesLinkLost(reading: Contract.objOf($0)) } } else { self.nodes_link_lost = nil }
        if document["outlier_readings"] != nil { self.outlier_readings = Contract.listAt(document, "outlier_readings").map { Contract.DailySummaryBodyOutlierReadings(reading: Contract.objOf($0)) } } else { self.outlier_readings = nil }
        if document["consumption"] != nil { self.consumption = Contract.DailySummaryBodyConsumption(reading: Contract.objAt(document, "consumption")) } else { self.consumption = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["schema"] = self.schema
        out["totals"] = self.totals.toJSON()
        out["by_type"] = self.by_type
        out["by_zone"] = self.by_zone
        out["by_hour"] = self.by_hour
        if let value = self.serious_alarms { out["serious_alarms"] = value.map { $0.toJSON() } }
        if let value = self.nodes_link_lost { out["nodes_link_lost"] = value.map { $0.toJSON() } }
        if let value = self.outlier_readings { out["outlier_readings"] = value.map { $0.toJSON() } }
        if let value = self.consumption { out["consumption"] = value.toJSON() }
        return out
    }
}

extension Contract.DailySummaryFindingSubject {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["code"] != nil { self.code = Contract.str(document, "code") } else { self.code = nil }
        if document["zone"] != nil { self.zone = Contract.str(document, "zone") } else { self.zone = nil }
        if document["node"] != nil { self.node = Contract.str(document, "node") } else { self.node = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.code { out["code"] = value }
        if let value = self.zone { out["zone"] = value }
        if let value = self.node { out["node"] = value }
        return out
    }
}

extension Contract.DailySummaryFindingDetail {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        if document["hours"] != nil { self.hours = Contract.listAt(document, "hours").map(Contract.asInt) } else { self.hours = nil }
        if document["tolerance_min"] != nil { self.tolerance_min = Contract.num(document, "tolerance_min") } else { self.tolerance_min = nil }
        if document["max_gap_s"] != nil { self.max_gap_s = Contract.num(document, "max_gap_s") } else { self.max_gap_s = nil }
        if document["limit_s"] != nil { self.limit_s = Contract.num(document, "limit_s") } else { self.limit_s = nil }
        if document["minimum"] != nil { self.minimum = Contract.int(document, "minimum") } else { self.minimum = nil }
        if document["window"] != nil { self.window = Contract.int(document, "window") } else { self.window = nil }
        if document["sigma"] != nil { self.sigma = Contract.num(document, "sigma") } else { self.sigma = nil }
        if document["min_ratio"] != nil { self.min_ratio = Contract.num(document, "min_ratio") } else { self.min_ratio = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = self.hours { out["hours"] = value }
        if let value = self.tolerance_min { out["tolerance_min"] = value }
        if let value = self.max_gap_s { out["max_gap_s"] = value }
        if let value = self.limit_s { out["limit_s"] = value }
        if let value = self.minimum { out["minimum"] = value }
        if let value = self.window { out["window"] = value }
        if let value = self.sigma { out["sigma"] = value }
        if let value = self.min_ratio { out["min_ratio"] = value }
        return out
    }
}

extension Contract.DailySummaryFindingEvidence {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.t_s = Contract.num(document, "t_s")
        if document["code"] != nil { self.code = Contract.str(document, "code") } else { self.code = nil }
        if document["zone"] != nil { self.zone = Contract.str(document, "zone") } else { self.zone = nil }
        if document["node"] != nil { self.node = Contract.str(document, "node") } else { self.node = nil }
        if document["sensor"] != nil { self.sensor = Contract.str(document, "sensor") } else { self.sensor = nil }
        if document["severity"] != nil { self.severity = Contract.str(document, "severity") } else { self.severity = nil }
        if document["watts"] != nil { self.watts = Contract.num(document, "watts") } else { self.watts = nil }
        if document["value"] != nil { self.value = Contract.num(document, "value") } else { self.value = nil }
        if document["duration_s"] != nil { self.duration_s = Contract.num(document, "duration_s") } else { self.duration_s = nil }
        if document["mean_w"] != nil { self.mean_w = Contract.num(document, "mean_w") } else { self.mean_w = nil }
        if document["limit_w"] != nil { self.limit_w = Contract.num(document, "limit_w") } else { self.limit_w = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["t_s"] = self.t_s
        if let value = self.code { out["code"] = value }
        if let value = self.zone { out["zone"] = value }
        if let value = self.node { out["node"] = value }
        if let value = self.sensor { out["sensor"] = value }
        if let value = self.severity { out["severity"] = value }
        if let value = self.watts { out["watts"] = value }
        if let value = self.value { out["value"] = value }
        if let value = self.duration_s { out["duration_s"] = value }
        if let value = self.mean_w { out["mean_w"] = value }
        if let value = self.limit_w { out["limit_w"] = value }
        return out
    }
}

extension Contract.DailySummaryFinding {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.subject = Contract.DailySummaryFindingSubject(reading: Contract.objAt(document, "subject"))
        self.count = Contract.int(document, "count")
        self.detail = Contract.DailySummaryFindingDetail(reading: Contract.objAt(document, "detail"))
        self.evidence = Contract.listAt(document, "evidence").map { Contract.DailySummaryFindingEvidence(reading: Contract.objOf($0)) }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["subject"] = self.subject.toJSON()
        out["count"] = self.count
        out["detail"] = self.detail.toJSON()
        out["evidence"] = self.evidence.map { $0.toJSON() }
        return out
    }
}

extension Contract.DailySummary {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.date = Contract.str(document, "date")
        self.language = Contract.str(document, "language")
        self.summary = Contract.DailySummaryBody(reading: Contract.objAt(document, "summary"))
        self.findings = Contract.listAt(document, "findings").map { Contract.DailySummaryFinding(reading: Contract.objOf($0)) }
        self.text = Contract.str(document, "text")
        if document["ai_note"] != nil { self.ai_note = Contract.str(document, "ai_note") } else { self.ai_note = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["date"] = self.date
        out["language"] = self.language
        out["summary"] = self.summary.toJSON()
        out["findings"] = self.findings.map { $0.toJSON() }
        out["text"] = self.text
        if let value = self.ai_note { out["ai_note"] = value }
        return out
    }
}

extension Contract.Heatmap {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.schema = Contract.str(document, "schema")
        self.camera_id = Contract.str(document, "camera_id")
        self.cols = Contract.int(document, "cols")
        self.rows = Contract.int(document, "rows")
        self.accepted_positions = Contract.int(document, "accepted_positions")
        self.rejected_positions = Contract.int(document, "rejected_positions")
        self.total = Contract.num(document, "total")
        self.max = Contract.num(document, "max")
        self.weights = Contract.listAt(document, "weights").map { Contract.listOf($0).map(Contract.asNum) }
        self.normalized = Contract.listAt(document, "normalized").map { Contract.listOf($0).map(Contract.asNum) }
        self.contains_images = Contract.flag(document, "contains_images")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["schema"] = self.schema
        out["camera_id"] = self.camera_id
        out["cols"] = self.cols
        out["rows"] = self.rows
        out["accepted_positions"] = self.accepted_positions
        out["rejected_positions"] = self.rejected_positions
        out["total"] = self.total
        out["max"] = self.max
        out["weights"] = self.weights
        out["normalized"] = self.normalized
        out["contains_images"] = self.contains_images
        return out
    }
}

extension Contract.NetworkInterface {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.name = Contract.str(document, "name")
        self.ip = Contract.str(document, "ip")
        self.cidr = Contract.str(document, "cidr")
        if document["gateway"] != nil { self.gateway = Contract.str(document, "gateway") } else { self.gateway = nil }
        if document["rx_bps"] != nil { self.rx_bps = Contract.int(document, "rx_bps") } else { self.rx_bps = nil }
        if document["tx_bps"] != nil { self.tx_bps = Contract.int(document, "tx_bps") } else { self.tx_bps = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["name"] = self.name
        out["ip"] = self.ip
        out["cidr"] = self.cidr
        if let value = self.gateway { out["gateway"] = value }
        if let value = self.rx_bps { out["rx_bps"] = value }
        if let value = self.tx_bps { out["tx_bps"] = value }
        return out
    }
}

extension Contract.NetworkProbe {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.target = Contract.str(document, "target")
        self.kind = Contract.str(document, "kind")
        self.ok = Contract.flag(document, "ok")
        if document["latency_ms"] != nil { self.latency_ms = Contract.num(document, "latency_ms") } else { self.latency_ms = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["target"] = self.target
        out["kind"] = self.kind
        out["ok"] = self.ok
        if let value = self.latency_ms { out["latency_ms"] = value }
        return out
    }
}

extension Contract.NetworkOutage {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.started_ms = Contract.int(document, "started_ms")
        self.ended_ms = Contract.int(document, "ended_ms")
        self.duration_s = Contract.int(document, "duration_s")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["started_ms"] = self.started_ms
        out["ended_ms"] = self.ended_ms
        out["duration_s"] = self.duration_s
        return out
    }
}

extension Contract.NetworkInternet {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.state = Contract.str(document, "state")
        if document["since_ms"] != nil { self.since_ms = Contract.int(document, "since_ms") } else { self.since_ms = nil }
        if document["gateway_ok"] != nil { self.gateway_ok = Contract.flag(document, "gateway_ok") } else { self.gateway_ok = nil }
        if document["latency_ms"] != nil { self.latency_ms = Contract.num(document, "latency_ms") } else { self.latency_ms = nil }
        if document["loss_percent"] != nil { self.loss_percent = Contract.num(document, "loss_percent") } else { self.loss_percent = nil }
        if document["probes"] != nil { self.probes = Contract.listAt(document, "probes").map { Contract.NetworkProbe(reading: Contract.objOf($0)) } } else { self.probes = nil }
        if document["last_outage"] != nil { self.last_outage = Contract.NetworkOutage(reading: Contract.objAt(document, "last_outage")) } else { self.last_outage = nil }
        if document["outages_24h"] != nil { self.outages_24h = Contract.int(document, "outages_24h") } else { self.outages_24h = nil }
        if document["downtime_24h_s"] != nil { self.downtime_24h_s = Contract.int(document, "downtime_24h_s") } else { self.downtime_24h_s = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["state"] = self.state
        if let value = self.since_ms { out["since_ms"] = value }
        if let value = self.gateway_ok { out["gateway_ok"] = value }
        if let value = self.latency_ms { out["latency_ms"] = value }
        if let value = self.loss_percent { out["loss_percent"] = value }
        if let value = self.probes { out["probes"] = value.map { $0.toJSON() } }
        if let value = self.last_outage { out["last_outage"] = value.toJSON() }
        if let value = self.outages_24h { out["outages_24h"] = value }
        if let value = self.downtime_24h_s { out["downtime_24h_s"] = value }
        return out
    }
}

extension Contract.NetworkPort {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.port = Contract.int(document, "port")
        self.proto = Contract.str(document, "proto")
        if document["service"] != nil { self.service = Contract.str(document, "service") } else { self.service = nil }
        if document["banner"] != nil { self.banner = Contract.str(document, "banner") } else { self.banner = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["port"] = self.port
        out["proto"] = self.proto
        if let value = self.service { out["service"] = value }
        if let value = self.banner { out["banner"] = value }
        return out
    }
}

extension Contract.NetworkDevice {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.ip = Contract.str(document, "ip")
        if document["mac"] != nil { self.mac = Contract.str(document, "mac") } else { self.mac = nil }
        if document["randomized_mac"] != nil { self.randomized_mac = Contract.flag(document, "randomized_mac") } else { self.randomized_mac = nil }
        if document["vendor"] != nil { self.vendor = Contract.str(document, "vendor") } else { self.vendor = nil }
        if document["hostname"] != nil { self.hostname = Contract.str(document, "hostname") } else { self.hostname = nil }
        if document["kind"] != nil { self.kind = Contract.str(document, "kind") } else { self.kind = nil }
        if document["os"] != nil { self.os = Contract.str(document, "os") } else { self.os = nil }
        self.online = Contract.flag(document, "online")
        self.first_seen_ms = Contract.int(document, "first_seen_ms")
        self.last_seen_ms = Contract.int(document, "last_seen_ms")
        if document["latency_ms"] != nil { self.latency_ms = Contract.num(document, "latency_ms") } else { self.latency_ms = nil }
        if document["ports"] != nil { self.ports = Contract.listAt(document, "ports").map { Contract.NetworkPort(reading: Contract.objOf($0)) } } else { self.ports = nil }
        if document["services"] != nil { self.services = Contract.listAt(document, "services").map(Contract.asStr) } else { self.services = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["ip"] = self.ip
        if let value = self.mac { out["mac"] = value }
        if let value = self.randomized_mac { out["randomized_mac"] = value }
        if let value = self.vendor { out["vendor"] = value }
        if let value = self.hostname { out["hostname"] = value }
        if let value = self.kind { out["kind"] = value }
        if let value = self.os { out["os"] = value }
        out["online"] = self.online
        out["first_seen_ms"] = self.first_seen_ms
        out["last_seen_ms"] = self.last_seen_ms
        if let value = self.latency_ms { out["latency_ms"] = value }
        if let value = self.ports { out["ports"] = value.map { $0.toJSON() } }
        if let value = self.services { out["services"] = value }
        return out
    }
}

extension Contract.NetworkEvent {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.kind = Contract.str(document, "kind")
        self.at_ms = Contract.int(document, "at_ms")
        if document["device_id"] != nil { self.device_id = Contract.str(document, "device_id") } else { self.device_id = nil }
        if document["port"] != nil { self.port = Contract.int(document, "port") } else { self.port = nil }
        if document["outage_s"] != nil { self.outage_s = Contract.int(document, "outage_s") } else { self.outage_s = nil }
        if document["detail"] != nil { self.detail = Contract.str(document, "detail") } else { self.detail = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["kind"] = self.kind
        out["at_ms"] = self.at_ms
        if let value = self.device_id { out["device_id"] = value }
        if let value = self.port { out["port"] = value }
        if let value = self.outage_s { out["outage_s"] = value }
        if let value = self.detail { out["detail"] = value }
        return out
    }
}

extension Contract.NetworkScan {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.last_ms = Contract.int(document, "last_ms")
        self.hosts = Contract.int(document, "hosts")
        if document["duration_ms"] != nil { self.duration_ms = Contract.int(document, "duration_ms") } else { self.duration_ms = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["last_ms"] = self.last_ms
        out["hosts"] = self.hosts
        if let value = self.duration_ms { out["duration_ms"] = value }
        return out
    }
}

extension Contract.NetworkPublicDns {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.name = Contract.str(document, "name")
        self.addresses = Contract.listAt(document, "addresses").map(Contract.asStr)
        self.matches = Contract.flag(document, "matches")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["name"] = self.name
        out["addresses"] = self.addresses
        out["matches"] = self.matches
        return out
    }
}

extension Contract.NetworkPublic {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.ip = Contract.str(document, "ip")
        if document["hostname"] != nil { self.hostname = Contract.str(document, "hostname") } else { self.hostname = nil }
        if document["city"] != nil { self.city = Contract.str(document, "city") } else { self.city = nil }
        if document["region"] != nil { self.region = Contract.str(document, "region") } else { self.region = nil }
        if document["country"] != nil { self.country = Contract.str(document, "country") } else { self.country = nil }
        if document["org"] != nil { self.org = Contract.str(document, "org") } else { self.org = nil }
        if document["timezone"] != nil { self.timezone = Contract.str(document, "timezone") } else { self.timezone = nil }
        self.checked_ms = Contract.int(document, "checked_ms")
        if document["changed_ms"] != nil { self.changed_ms = Contract.int(document, "changed_ms") } else { self.changed_ms = nil }
        if document["dns"] != nil { self.dns = Contract.NetworkPublicDns(reading: Contract.objAt(document, "dns")) } else { self.dns = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["ip"] = self.ip
        if let value = self.hostname { out["hostname"] = value }
        if let value = self.city { out["city"] = value }
        if let value = self.region { out["region"] = value }
        if let value = self.country { out["country"] = value }
        if let value = self.org { out["org"] = value }
        if let value = self.timezone { out["timezone"] = value }
        out["checked_ms"] = self.checked_ms
        if let value = self.changed_ms { out["changed_ms"] = value }
        if let value = self.dns { out["dns"] = value.toJSON() }
        return out
    }
}

extension Contract.NetworkResults {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.type = Contract.str(document, "type")
        self.ok = Contract.flag(document, "ok")
        self.finished_ms = Contract.int(document, "finished_ms")
        if document["device_id"] != nil { self.device_id = Contract.str(document, "device_id") } else { self.device_id = nil }
        if document["output"] != nil { self.output = Contract.str(document, "output") } else { self.output = nil }
        if document["ports"] != nil { self.ports = Contract.listAt(document, "ports").map { Contract.NetworkPort(reading: Contract.objOf($0)) } } else { self.ports = nil }
        if document["latency_ms"] != nil { self.latency_ms = Contract.num(document, "latency_ms") } else { self.latency_ms = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["type"] = self.type
        out["ok"] = self.ok
        out["finished_ms"] = self.finished_ms
        if let value = self.device_id { out["device_id"] = value }
        if let value = self.output { out["output"] = value }
        if let value = self.ports { out["ports"] = value.map { $0.toJSON() } }
        if let value = self.latency_ms { out["latency_ms"] = value }
        return out
    }
}

extension Contract.Network {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.kind = Contract.str(document, "kind")
        self.node_id = Contract.str(document, "node_id")
        if document["contract"] != nil { self.contract = Contract.int(document, "contract") } else { self.contract = nil }
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.interface = Contract.NetworkInterface(reading: Contract.objAt(document, "interface"))
        self.internet = Contract.NetworkInternet(reading: Contract.objAt(document, "internet"))
        self.devices = Contract.listAt(document, "devices").map { Contract.NetworkDevice(reading: Contract.objOf($0)) }
        if document["events"] != nil { self.events = Contract.listAt(document, "events").map { Contract.NetworkEvent(reading: Contract.objOf($0)) } } else { self.events = nil }
        if document["scan"] != nil { self.scan = Contract.NetworkScan(reading: Contract.objAt(document, "scan")) } else { self.scan = nil }
        if document["public"] != nil { self.`public` = Contract.NetworkPublic(reading: Contract.objAt(document, "public")) } else { self.`public` = nil }
        if document["results"] != nil { self.results = Contract.listAt(document, "results").map { Contract.NetworkResults(reading: Contract.objOf($0)) } } else { self.results = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["kind"] = self.kind
        out["node_id"] = self.node_id
        if let value = self.contract { out["contract"] = value }
        out["timestamp_ms"] = self.timestamp_ms
        out["interface"] = self.interface.toJSON()
        out["internet"] = self.internet.toJSON()
        out["devices"] = self.devices.map { $0.toJSON() }
        if let value = self.events { out["events"] = value.map { $0.toJSON() } }
        if let value = self.scan { out["scan"] = value.toJSON() }
        if let value = self.`public` { out["public"] = value.toJSON() }
        if let value = self.results { out["results"] = value.map { $0.toJSON() } }
        return out
    }
}

extension Contract.AiObservationRegions {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.x = Contract.num(document, "x")
        self.y = Contract.num(document, "y")
        self.w = Contract.num(document, "w")
        self.h = Contract.num(document, "h")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["x"] = self.x
        out["y"] = self.y
        out["w"] = self.w
        out["h"] = self.h
        return out
    }
}

extension Contract.AiObservation {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.camera_id = Contract.str(document, "camera_id")
        self.severity = Contract.str(document, "severity")
        self.reasons = Contract.listAt(document, "reasons").map(Contract.asStr)
        self.profile = Contract.str(document, "profile")
        self.motion = Contract.num(document, "motion")
        if document["motion_ratio"] != nil { self.motion_ratio = Contract.num(document, "motion_ratio") } else { self.motion_ratio = nil }
        if document["regions"] != nil { self.regions = Contract.listAt(document, "regions").map { Contract.AiObservationRegions(reading: Contract.objOf($0)) } } else { self.regions = nil }
        self.radar_tracks = Contract.int(document, "radar_tracks")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["camera_id"] = self.camera_id
        out["severity"] = self.severity
        out["reasons"] = self.reasons
        out["profile"] = self.profile
        out["motion"] = self.motion
        if let value = self.motion_ratio { out["motion_ratio"] = value }
        if let value = self.regions { out["regions"] = value.map { $0.toJSON() } }
        out["radar_tracks"] = self.radar_tracks
        return out
    }
}

extension Contract.DeviceState {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.on = Contract.flag(document, "on")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["on"] = self.on
        return out
    }
}

extension Contract.NetworkOrdersCommands {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.id = Contract.str(document, "id")
        self.type = Contract.str(document, "type")
        if document["device_id"] != nil { self.device_id = Contract.str(document, "device_id") } else { self.device_id = nil }
        if document["ip"] != nil { self.ip = Contract.str(document, "ip") } else { self.ip = nil }
        if document["mac"] != nil { self.mac = Contract.str(document, "mac") } else { self.mac = nil }
        if document["port"] != nil { self.port = Contract.int(document, "port") } else { self.port = nil }
        if document["auth_sealed"] != nil { self.auth_sealed = Contract.str(document, "auth_sealed") } else { self.auth_sealed = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = self.id
        out["type"] = self.type
        if let value = self.device_id { out["device_id"] = value }
        if let value = self.ip { out["ip"] = value }
        if let value = self.mac { out["mac"] = value }
        if let value = self.port { out["port"] = value }
        if let value = self.auth_sealed { out["auth_sealed"] = value }
        return out
    }
}

extension Contract.NetworkOrders {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.accepted = Contract.flag(document, "accepted")
        self.commands = Contract.listAt(document, "commands").map { Contract.NetworkOrdersCommands(reading: Contract.objOf($0)) }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["accepted"] = self.accepted
        out["commands"] = self.commands.map { $0.toJSON() }
        return out
    }
}

extension Contract.ServerAlert {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.service = Contract.str(document, "service")
        self.event = Contract.str(document, "event")
        self.at = Contract.str(document, "at")
        self.mode = Contract.str(document, "mode")
        if document["node_id"] != nil { self.node_id = Contract.str(document, "node_id") } else { self.node_id = nil }
        if document["camera_id"] != nil { self.camera_id = Contract.str(document, "camera_id") } else { self.camera_id = nil }
        if document["targets"] != nil { self.targets = Contract.int(document, "targets") } else { self.targets = nil }
        if document["minutes"] != nil { self.minutes = Contract.int(document, "minutes") } else { self.minutes = nil }
        if document["alarm_id"] != nil { self.alarm_id = Contract.str(document, "alarm_id") } else { self.alarm_id = nil }
        if document["severity"] != nil { self.severity = Contract.str(document, "severity") } else { self.severity = nil }
        if document["code"] != nil { self.code = Contract.str(document, "code") } else { self.code = nil }
        if document["device_id"] != nil { self.device_id = Contract.str(document, "device_id") } else { self.device_id = nil }
        if document["solar_id"] != nil { self.solar_id = Contract.str(document, "solar_id") } else { self.solar_id = nil }
        if document["electrical_id"] != nil { self.electrical_id = Contract.str(document, "electrical_id") } else { self.electrical_id = nil }
        if document["alarm_node_id"] != nil { self.alarm_node_id = Contract.str(document, "alarm_node_id") } else { self.alarm_node_id = nil }
        if document["network_id"] != nil { self.network_id = Contract.str(document, "network_id") } else { self.network_id = nil }
        if document["silent"] != nil { self.silent = Contract.flag(document, "silent") } else { self.silent = nil }
        if document["automation"] != nil { self.automation = Contract.str(document, "automation") } else { self.automation = nil }
        if document["login_user"] != nil { self.login_user = Contract.str(document, "login_user") } else { self.login_user = nil }
        if document["login_from"] != nil { self.login_from = Contract.str(document, "login_from") } else { self.login_from = nil }
        if document["login_country"] != nil { self.login_country = Contract.str(document, "login_country") } else { self.login_country = nil }
        if document["login_country_new"] != nil { self.login_country_new = Contract.flag(document, "login_country_new") } else { self.login_country_new = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["service"] = self.service
        out["event"] = self.event
        out["at"] = self.at
        out["mode"] = self.mode
        if let value = self.node_id { out["node_id"] = value }
        if let value = self.camera_id { out["camera_id"] = value }
        if let value = self.targets { out["targets"] = value }
        if let value = self.minutes { out["minutes"] = value }
        if let value = self.alarm_id { out["alarm_id"] = value }
        if let value = self.severity { out["severity"] = value }
        if let value = self.code { out["code"] = value }
        if let value = self.device_id { out["device_id"] = value }
        if let value = self.solar_id { out["solar_id"] = value }
        if let value = self.electrical_id { out["electrical_id"] = value }
        if let value = self.alarm_node_id { out["alarm_node_id"] = value }
        if let value = self.network_id { out["network_id"] = value }
        if let value = self.silent { out["silent"] = value }
        if let value = self.automation { out["automation"] = value }
        if let value = self.login_user { out["login_user"] = value }
        if let value = self.login_from { out["login_from"] = value }
        if let value = self.login_country { out["login_country"] = value }
        if let value = self.login_country_new { out["login_country_new"] = value }
        return out
    }
}

extension Contract.VisionEventVectors {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.track_id = Contract.int(document, "track_id")
        self.dx = Contract.num(document, "dx")
        self.dy = Contract.num(document, "dy")
        self.speed = Contract.num(document, "speed")
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["track_id"] = self.track_id
        out["dx"] = self.dx
        out["dy"] = self.dy
        out["speed"] = self.speed
        return out
    }
}

extension Contract.VisionEvent {
    /// The message from a document that has passed its schema.
    public init(reading document: [String: Any]) {
        self.schema = Contract.str(document, "schema")
        self.type = Contract.str(document, "type")
        self.camera_id = Contract.str(document, "camera_id")
        self.zone_id = Contract.str(document, "zone_id")
        self.zone_name = Contract.str(document, "zone_name")
        self.track_id = Contract.int(document, "track_id")
        self.label = Contract.str(document, "label")
        self.confidence = Contract.num(document, "confidence")
        self.box = Contract.listAt(document, "box").map(Contract.asNum)
        self.timestamp = Contract.num(document, "timestamp")
        self.timestamp_ms = Contract.int(document, "timestamp_ms")
        self.authorizes_action = Contract.flag(document, "authorizes_action")
        if document["radar_tracks"] != nil { self.radar_tracks = Contract.int(document, "radar_tracks") } else { self.radar_tracks = nil }
        if document["vectors"] != nil { self.vectors = Contract.listAt(document, "vectors").map { Contract.VisionEventVectors(reading: Contract.objOf($0)) } } else { self.vectors = nil }
    }

    /// The document the message was read from, with the members the schema names and no other.
    public func toJSON() -> [String: Any] {
        var out: [String: Any] = [:]
        out["schema"] = self.schema
        out["type"] = self.type
        out["camera_id"] = self.camera_id
        out["zone_id"] = self.zone_id
        out["zone_name"] = self.zone_name
        out["track_id"] = self.track_id
        out["label"] = self.label
        out["confidence"] = self.confidence
        out["box"] = self.box
        out["timestamp"] = self.timestamp
        out["timestamp_ms"] = self.timestamp_ms
        out["authorizes_action"] = self.authorizes_action
        if let value = self.radar_tracks { out["radar_tracks"] = value }
        if let value = self.vectors { out["vectors"] = value.map { $0.toJSON() } }
        return out
    }
}
