// ARMOR-IOS-CONTROL - the site as Studio designed it, the live radar targets, and the geometry that puts one on the other. The same rules as Studio's designer (model.ts, radarMap.ts) and as the
// Android app, so the phone shows what the plan on the computer shows. Reading only; the drawing is in the app target.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct SitePoint: Equatable, Sendable {
    public let x: Double, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

public struct SiteDimensions: Equatable, Sendable {
    public let width: Double, depth: Double, height: Double
    public init(width: Double, depth: Double, height: Double) { self.width = width; self.depth = depth; self.height = height }
}

public struct SiteBuilding: Equatable, Sendable, Identifiable {
    public let id: String, name: String
    public let points: [SitePoint]
    public let base: Double
    public let floors: [Double]
    public let thickness: Double
    public let color: String?
    public let roofStyle: String
    public let roofSlope: Double
    public let roofColor: String?
    public var height: Double { max(2.0, floors.reduce(0, +)) }
}

public struct SiteFeature: Equatable, Sendable, Identifiable {
    public let id: String, kind: String
    public let x: Double, y: Double, z: Double, width: Double, depth: Double, height: Double, rotation: Double
    public let color: String?
}

/// A radar of the design. x and y are percentages of the work area (as Studio stores them); `channel` is the radar number of its node (0: any).
public struct SiteSensor: Equatable, Sendable, Identifiable {
    public let id: String, name: String
    public let x: Double, y: Double
    public let kind: String
    public let heading: Double?
    public let z: Double
    public let node: String?
    public let channel: Int
    public let mirror: Bool
    /// The floor of the building the radar is on, 0 for the ground floor, as Studio stores it; nil when the design does not say (the app only reads it).
    public let floor: Int?

    public init(id: String, name: String, x: Double, y: Double, kind: String, heading: Double?, z: Double = 1.5, node: String?, channel: Int = 0, mirror: Bool = false, floor: Int? = nil) {
        self.id = id; self.name = name; self.x = x; self.y = y; self.kind = kind; self.heading = heading; self.z = z; self.node = node; self.channel = channel; self.mirror = mirror; self.floor = floor
    }
}

public struct SiteCamera: Equatable, Sendable, Identifiable {
    public let id: String
    public let x: Double, y: Double
    public let heading: Double?, fov: Double?, range: Double?
}

public struct SiteDesign: Equatable, Sendable {
    public let dimensions: SiteDimensions
    public let terrain: [SitePoint]
    public let terrainColor: String?
    public let buildings: [SiteBuilding]
    public let features: [SiteFeature]
    public let sensors: [SiteSensor]
    public let cameras: [SiteCamera]
    /// True when Studio has saved a design that has a radar: without one there is nothing to put the targets on.
    public var hasRadar: Bool { !sensors.isEmpty }

    public init(dimensions: SiteDimensions, terrain: [SitePoint], terrainColor: String?, buildings: [SiteBuilding], features: [SiteFeature], sensors: [SiteSensor], cameras: [SiteCamera]) {
        self.dimensions = dimensions; self.terrain = terrain; self.terrainColor = terrainColor; self.buildings = buildings; self.features = features; self.sensors = sensors; self.cameras = cameras
    }
}

/// A target as the node reported it, in the radar's own frame: millimetres, x sideways and y ahead.
public struct LiveTarget: Equatable, Sendable {
    public let sensorId: Int, trackId: Int
    public let xMm: Double, yMm: Double, speedMmS: Double
    public let counted: Bool
    public init(sensorId: Int, trackId: Int, xMm: Double, yMm: Double, speedMmS: Double, counted: Bool) {
        self.sensorId = sensorId; self.trackId = trackId; self.xMm = xMm; self.yMm = yMm; self.speedMmS = speedMmS; self.counted = counted
    }
}

/// A target on the site, in metres (x east, y north).
public struct PlacedTarget: Equatable, Sendable, Identifiable {
    public let node: String, sensorId: String
    public let trackId: Int
    public let at: SitePoint, apex: SitePoint
    public let counted: Bool, inRated: Bool
    public let speedMmS: Double
    public var id: String { "\(node)/\(sensorId)/\(trackId)" }
}

public enum SiteParser {
    private static func number(_ json: JSON, _ key: String, _ fallback: Double) -> Double { json.double(key) ?? fallback }

    private static func points(_ json: JSON, _ key: String) -> [SitePoint] {
        json.objects(key).compactMap { $0.has("x") && $0.has("y") ? SitePoint($0.double("x") ?? 0, $0.double("y") ?? 0) : nil }
    }

    private static func colour(_ json: JSON, _ key: String) -> String? {
        let text = json.str(key)
        return text.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil ? text.lowercased() : nil
    }

    private static func isBoolean(_ value: Any) -> Bool {
        #if canImport(Darwin)
        if let number = value as? NSNumber { return CFGetTypeID(number) == CFBooleanGetTypeID() }
        return false
        #else
        return value is Bool
        #endif
    }

    /// The floor of a radar of the design: a whole number from 0 to 29, or nil (anything else is not a floor).
    static func floorOf(_ sensor: JSON) -> Int? {
        guard let raw = sensor["floor"], !(raw is NSNull), !isBoolean(raw), let number = (raw as? NSNumber)?.doubleValue else { return nil }
        return number == number.rounded(.down) && number >= 0 && number < 30 ? Int(number) : nil
    }

    /// The server's answer to GET /api/v1/site ({"revision":..,"site":{..}}), or the site object itself. Nil when nothing usable is there.
    public static func parse(_ document: JSON) -> SiteDesign? {
        let site: JSON
        if let inner = document.object("site") { site = inner }
        else if document.has("dimensions") || document.has("sensors") { site = document }
        else { return nil }
        let dims = site.object("dimensions")
        let dimensions = SiteDimensions(width: min(500, max(5, dims.map { number($0, "width", 60) } ?? 60)), depth: min(500, max(5, dims.map { number($0, "depth", 40) } ?? 40)), height: dims.map { number($0, "height", 12) } ?? 12)
        let terrainObject = site.object("terrain")
        var terrain = terrainObject.map { points($0, "points") } ?? []
        if terrain.isEmpty { terrain = [SitePoint(0, 0), SitePoint(dimensions.width, 0), SitePoint(dimensions.width, dimensions.depth), SitePoint(0, dimensions.depth)] }
        let buildings: [SiteBuilding] = site.objects("buildings").compactMap { b in
            let corners = points(b, "points")
            if corners.count < 3 { return nil }
            let roof = b.object("roof")
            var floors = ((b["floors"] as? [Any]) ?? []).map { value -> Double in min(20, max(1, (value as? NSNumber)?.doubleValue ?? 2.8)) }
            if floors.isEmpty { floors = [2.8] }
            return SiteBuilding(id: b.str("id"), name: b.str("name"), points: corners, base: number(b, "base", 0), floors: floors, thickness: number(b, "thickness", 0.25), color: colour(b, "color"),
                                roofStyle: roof?.str("style", "flat") ?? "flat", roofSlope: roof.map { number($0, "slope", 20) } ?? 20, roofColor: colour(b, "roofColor"))
        }
        let features = site.objects("features").map { f in
            SiteFeature(id: f.str("id"), kind: f.str("kind"), x: number(f, "x", 0), y: number(f, "y", 0), z: number(f, "z", 0), width: number(f, "width", 1), depth: number(f, "depth", 1),
                        height: number(f, "height", 1), rotation: number(f, "rotation", 0), color: colour(f, "color"))
        }
        let sensors: [SiteSensor] = site.objects("sensors").compactMap { s in
            let id = s.str("id")
            if id.isEmpty || !s.has("x") || !s.has("y") { return nil }
            let node = s.str("node")
            return SiteSensor(id: id, name: s.str("name", id), x: number(s, "x", 0), y: number(s, "y", 0), kind: s.str("kind") == "LD2461" ? "LD2461" : "LD2450",
                              heading: s.has("heading") ? s.double("heading") : nil, z: number(s, "z", 1.5), node: node.isEmpty ? nil : node, channel: s.int("channel", 0), mirror: s.bool("mirror"), floor: floorOf(s))
        }
        var cameras: [SiteCamera] = []
        if let places = site.object("cameraPlacements") {
            for id in places.keys.sorted() {
                guard let p = places[id] as? JSON, p.has("x"), p.has("y") else { continue }
                cameras.append(SiteCamera(id: id, x: number(p, "x", 0), y: number(p, "y", 0), heading: p.has("heading") ? p.double("heading") : nil, fov: p.has("fov") ? p.double("fov") : nil, range: p.has("range") ? p.double("range") : nil))
            }
        }
        return SiteDesign(dimensions: dimensions, terrain: terrain, terrainColor: terrainObject.flatMap { colour($0, "color") }, buildings: buildings, features: features, sensors: sensors, cameras: cameras)
    }

    /// The targets of a node's state object (`targets` of GET /api/v1/status).
    public static func targets(_ node: JSON) -> [LiveTarget] {
        node.objects("targets").map { t in
            LiveTarget(sensorId: t.int("sensor_id"), trackId: t.int("track_id"), xMm: t.double("x_mm") ?? 0, yMm: t.double("y_mm") ?? 0, speedMmS: t.double("speed_mm_s") ?? 0, counted: t.bool("counted", true))
        }
    }
}

public enum RadarGeometry {
    /// What a model is rated for (its manufacturer's figures): range in metres and half of the horizontal angle in degrees.
    public static func view(_ kind: String) -> (range: Double, half: Double) { kind == "LD2461" ? (8, 45) : (6, 60) }

    /// A radar or camera (percent of the work area) as a point in metres.
    public static func toMetres(_ x: Double, _ y: Double, _ dims: SiteDimensions) -> SitePoint { SitePoint(x / 100 * dims.width, (1 - y / 100) * dims.depth) }

    /// Where it faces, in degrees anticlockwise from east; unless set, toward the middle of the work area.
    public static func headingOf(_ x: Double, _ y: Double, _ heading: Double?, _ dims: SiteDimensions) -> Double {
        if let heading, heading.isFinite { return (heading.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
        let at = toMetres(x, y, dims)
        let dx = dims.width / 2 - at.x, dy = dims.depth / 2 - at.y
        if (dx * dx + dy * dy).squareRoot() < 1e-6 { return 90 }
        return ((atan2(dy, dx) * 180 / Double.pi) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// A target in the radar's frame as a point of the site. Which side positive x lies on is an assumption (to the right of where the radar faces) unless `mirror`.
    public static func targetToSite(apex: SitePoint, headingDeg: Double, xMm: Double, yMm: Double, mirror: Bool) -> SitePoint {
        let forward = yMm / 1000
        let sideways = (mirror ? -1.0 : 1.0) * xMm / 1000
        let h = headingDeg * Double.pi / 180
        return SitePoint(apex.x + cos(h) * forward + sin(h) * sideways, apex.y + sin(h) * forward - cos(h) * sideways)
    }

    public static func inSector(_ point: SitePoint, apex: SitePoint, headingDeg: Double, halfAngleDeg: Double, rangeM: Double) -> Bool {
        let dx = point.x - apex.x, dy = point.y - apex.y
        if (dx * dx + dy * dy).squareRoot() > rangeM { return false }
        let angle = atan2(dy, dx) * 180 / Double.pi
        return abs(((angle - headingDeg + 540).truncatingRemainder(dividingBy: 360)) - 180) <= halfAngleDeg
    }

    /// The corners of a detection sector: the apex, then the arc.
    public static func sector(apex: SitePoint, headingDeg: Double, halfAngleDeg: Double, rangeM: Double, steps: Int = 24) -> [SitePoint] {
        var corners = [apex]
        for i in 0...steps {
            let a = (headingDeg - halfAngleDeg + 2 * halfAngleDeg * Double(i) / Double(steps)) * Double.pi / 180
            corners.append(SitePoint(apex.x + cos(a) * rangeM, apex.y + sin(a) * rangeM))
        }
        return corners
    }

    /// The radar of the design that produces a node's radar number: the one wired to that node and channel, else one of the node with no channel.
    public static func sensorFor(_ sensors: [SiteSensor], node: String, channel: Int) -> SiteSensor? {
        let wired = sensors.filter { $0.node == node }
        return wired.first { $0.channel != 0 && $0.channel == channel } ?? wired.first { $0.channel == 0 }
    }

    /// Every live target of the nodes that are online and not stale, that can be placed; the rest are counted apart.
    public static func place(_ design: SiteDesign, nodes: [FieldNode]) -> (placed: [PlacedTarget], missing: Int) {
        var placed: [PlacedTarget] = []
        var missing = 0
        for node in nodes where node.online && !node.stale {
            for target in node.targets {
                guard let sensor = sensorFor(design.sensors, node: node.id, channel: target.sensorId) else { missing += 1; continue }
                let apex = toMetres(sensor.x, sensor.y, design.dimensions)
                let heading = headingOf(sensor.x, sensor.y, sensor.heading, design.dimensions)
                let at = targetToSite(apex: apex, headingDeg: heading, xMm: target.xMm, yMm: target.yMm, mirror: sensor.mirror)
                let rated = view(sensor.kind)
                placed.append(PlacedTarget(node: node.id, sensorId: sensor.id, trackId: target.trackId, at: at, apex: apex, counted: target.counted,
                                           inRated: inSector(at, apex: apex, headingDeg: heading, halfAngleDeg: rated.half, rangeM: rated.range), speedMmS: target.speedMmS))
            }
        }
        return (placed, missing)
    }
}
