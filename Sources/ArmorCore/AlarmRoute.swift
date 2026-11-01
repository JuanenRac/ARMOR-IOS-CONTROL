// ARMOR-IOS-CONTROL - where an alarm takes the person: the screen that handles what raised it. The same routes as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The screen that handles an alarm.
public enum AlarmTarget: String, Equatable, Sendable {
    case cameras, devices, solar, batteries, electrical, network, alarmPanels, radar, alarms
}

public enum AlarmRoute {
    /// Where an alarm is handled, as Studio does it: what a camera raised opens the cameras, a device's the devices, solar equipment's the inverters or the batteries, an electrical node's
    /// the electrical screen, the network's the network, an alarm panel's the panels, and what a field node raised the radar. Anything else stays on the alarms.
    public static func of(sourceType: String, code: String) -> AlarmTarget {
        switch sourceType {
        case "camera": return .cameras
        case "device": return .devices
        case "solar": return code.range(of: "battery|pylon", options: [.regularExpression, .caseInsensitive]) != nil ? .batteries : .solar
        case "electrical": return .electrical
        case "network": return .network
        case "alarm": return .alarmPanels
        case "node": return .radar
        default: return .alarms
        }
    }

    public static func of(_ alarm: Alarm) -> AlarmTarget { of(sourceType: alarm.sourceType, code: alarm.code) }
}
