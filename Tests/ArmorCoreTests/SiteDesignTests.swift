import XCTest
@testable import ArmorCore

/// The same expectations as Studio's designer tests (and the Android app): the phone must put a person where the plan on the computer puts them.
final class SiteDesignTests: XCTestCase {
    private let dims = SiteDimensions(width: 60, depth: 40, height: 3)

    private func object(_ text: String) -> JSON { (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? JSON ?? [:] }

    // at (10, 10) m facing east
    private func sensor(_ id: String = "s1", node: String? = "gate", channel: Int = 0, mirror: Bool = false, kind: String = "LD2450") -> SiteSensor {
        SiteSensor(id: id, name: "Gate", x: 10.0 / 60.0 * 100.0, y: 75, kind: kind, heading: 0, z: 1.5, node: node, channel: channel, mirror: mirror)
    }

    private func node(_ id: String = "gate", online: Bool = true, stale: Bool = false, targets: [LiveTarget] = [LiveTarget(sensorId: 1, trackId: 4, xMm: 0, yMm: 3000, speedMmS: 0, counted: true)]) -> FieldNode {
        FieldNode(id: id, online: online, lux: 5, targetCount: targets.count, alertLevel: "review", stale: stale, targets: targets)
    }

    private func design(_ sensors: SiteSensor...) -> SiteDesign {
        SiteDesign(dimensions: dims, terrain: [], terrainColor: nil, buildings: [], features: [], sensors: sensors, cameras: [])
    }

    func testTheFloorOfARadarIsReadAsTheDesignStoresItAndAnythingElseIsNoFloor() {
        func floorOf(_ value: String) -> Int? {
            SiteParser.parse(object("{\"site\":{\"dimensions\":{\"width\":60,\"depth\":40,\"height\":3},\"sensors\":[{\"id\":\"s1\",\"x\":10,\"y\":10,\"kind\":\"LD2450\"\(value)}]}}"))?.sensors[0].floor
        }
        XCTAssertNil(floorOf(""), "an old design has no floor")
        XCTAssertEqual(floorOf(",\"floor\":0"), 0)
        XCTAssertEqual(floorOf(",\"floor\":2"), 2)
        for bad in ["-1", "1.5", "\"1\"", "null", "30", "999", "true"] { XCTAssertNil(floorOf(",\"floor\":\(bad)"), bad) }
    }

    func testARadarOrCameraInPercentIsAPointInMetres() {
        let p = RadarGeometry.toMetres(50, 25, dims)
        XCTAssertEqual(p.x, 30, accuracy: 1e-9)
        XCTAssertEqual(p.y, 30, accuracy: 1e-9)   // y is counted from the top of the plan: 25 % from the top is 30 m of 40 from the south
    }

    func testTheDefaultFacingIsTowardTheMiddleAndAnExplicitFacingWins() {
        XCTAssertEqual(RadarGeometry.headingOf(50, 50, nil, dims), 90, accuracy: 1e-9)
        XCTAssertEqual(RadarGeometry.headingOf(0, 50, nil, dims), 0, accuracy: 1e-9)          // west edge, middle: faces east
        XCTAssertEqual(RadarGeometry.headingOf(10, 10, -90, dims), 270, accuracy: 1e-9)
    }

    func testATargetAheadOfARadarThatFacesEastIsEastOfItAndTheSidewaysAxisIsToTheRight() {
        let apex = SitePoint(10, 10)
        let ahead = RadarGeometry.targetToSite(apex: apex, headingDeg: 0, xMm: 0, yMm: 3000, mirror: false)
        XCTAssertEqual(ahead.x, 13, accuracy: 1e-9); XCTAssertEqual(ahead.y, 10, accuracy: 1e-9)
        let right = RadarGeometry.targetToSite(apex: apex, headingDeg: 0, xMm: 1000, yMm: 2000, mirror: false)
        XCTAssertEqual(right.x, 12, accuracy: 1e-9); XCTAssertEqual(right.y, 9, accuracy: 1e-9)   // 1 m to the right of east is south
        let mirrored = RadarGeometry.targetToSite(apex: apex, headingDeg: 0, xMm: 1000, yMm: 2000, mirror: true)
        XCTAssertEqual(mirrored.y, 11, accuracy: 1e-9)
        let north = RadarGeometry.targetToSite(apex: apex, headingDeg: 90, xMm: -500, yMm: 1000, mirror: false)
        XCTAssertEqual(north.x, 9.5, accuracy: 1e-9); XCTAssertEqual(north.y, 11, accuracy: 1e-9)   // facing north, half a metre to the left is west
    }

    func testTheSectorOfEachModel() {
        XCTAssertEqual(RadarGeometry.view("LD2450").range, 6); XCTAssertEqual(RadarGeometry.view("LD2450").half, 60)
        XCTAssertEqual(RadarGeometry.view("LD2461").range, 8); XCTAssertEqual(RadarGeometry.view("LD2461").half, 45)
        let apex = SitePoint(0, 0)
        XCTAssertTrue(RadarGeometry.inSector(SitePoint(5, 0), apex: apex, headingDeg: 0, halfAngleDeg: 60, rangeM: 6))
        XCTAssertFalse(RadarGeometry.inSector(SitePoint(7, 0), apex: apex, headingDeg: 0, halfAngleDeg: 60, rangeM: 6))
        XCTAssertFalse(RadarGeometry.inSector(SitePoint(0, 5), apex: apex, headingDeg: 0, halfAngleDeg: 60, rangeM: 6))
        XCTAssertEqual(RadarGeometry.sector(apex: apex, headingDeg: 0, halfAngleDeg: 60, rangeM: 6).count, 26)
    }

    func testTheRadarWiredToANodeIsFoundByItsNumberThenByAny() {
        let any = sensor("any"), second = sensor("second", channel: 2)
        XCTAssertEqual(RadarGeometry.sensorFor([any, second], node: "gate", channel: 2)?.id, "second")
        XCTAssertEqual(RadarGeometry.sensorFor([any, second], node: "gate", channel: 1)?.id, "any")
        XCTAssertNil(RadarGeometry.sensorFor([any], node: "other", channel: 1))
        XCTAssertNil(RadarGeometry.sensorFor([sensor(node: nil)], node: "gate", channel: 1))
    }

    func testTargetsArePlacedOnTheSiteAndSilentNodesAndUnwiredOnesAreLeftOut() {
        let result = RadarGeometry.place(design(sensor()), nodes: [node()])
        XCTAssertEqual(result.placed.count, 1); XCTAssertEqual(result.missing, 0)
        XCTAssertEqual(result.placed[0].at.x, 13, accuracy: 1e-6); XCTAssertEqual(result.placed[0].at.y, 10, accuracy: 1e-6)
        XCTAssertTrue(result.placed[0].inRated); XCTAssertTrue(result.placed[0].counted); XCTAssertEqual(result.placed[0].trackId, 4)
        let far = RadarGeometry.place(design(sensor()), nodes: [node(targets: [LiveTarget(sensorId: 1, trackId: 1, xMm: 0, yMm: 7000, speedMmS: 0, counted: false)])])
        XCTAssertFalse(far.placed[0].inRated); XCTAssertFalse(far.placed[0].counted)
        let unwired = RadarGeometry.place(design(sensor()), nodes: [node("north")])
        XCTAssertEqual(unwired.placed.count, 0); XCTAssertEqual(unwired.missing, 1)
        XCTAssertTrue(RadarGeometry.place(design(sensor()), nodes: [node(stale: true)]).placed.isEmpty)
        XCTAssertTrue(RadarGeometry.place(design(sensor()), nodes: [node(online: false)]).placed.isEmpty)
    }

    func testTheSiteDocumentOfTheServerIsRead() throws {
        let document = object("""
        {"revision":3,"site":{"schema":"armor-studio/site/1","dimensions":{"width":60,"depth":40,"height":12},
         "terrain":{"points":[{"x":0,"y":0},{"x":60,"y":0},{"x":60,"y":40},{"x":0,"y":40}],"color":"#17414D"},
         "buildings":[{"id":"b1","name":"House","points":[{"x":16,"y":12},{"x":28,"y":12},{"x":28,"y":20},{"x":16,"y":20}],"base":0,"floors":[2.8,2.8],"thickness":0.25,"roof":{"style":"gable","slope":30,"overhang":0.4,"ridge":0},"color":"#d9e3e6"}],
         "features":[{"id":"t1","kind":"tree","x":10,"y":26,"z":0,"width":4,"depth":4,"height":6,"rotation":0,"slope":0,"style":"oak","color":"#7a2cff"}],
         "sensors":[{"id":"s1","name":"Gate","x":16.7,"y":75,"kind":"LD2461","heading":0,"node":"perimetro-1","channel":2,"mirror":true}],
         "cameraPlacements":{"cam1":{"x":50,"y":10,"heading":180,"fov":80}}}}
        """)
        let design = try XCTUnwrap(SiteParser.parse(document))
        XCTAssertEqual(design.dimensions.width, 60)
        XCTAssertEqual(design.terrainColor, "#17414d")
        XCTAssertEqual(design.terrain.count, 4)
        XCTAssertEqual(design.buildings.count, 1)
        XCTAssertEqual(design.buildings[0].height, 5.6, accuracy: 1e-9)
        XCTAssertEqual(design.buildings[0].roofStyle, "gable")
        XCTAssertEqual(design.features[0].color, "#7a2cff")
        XCTAssertTrue(design.hasRadar)
        let s = design.sensors[0]
        XCTAssertEqual(s.kind, "LD2461"); XCTAssertEqual(s.node, "perimetro-1"); XCTAssertEqual(s.channel, 2); XCTAssertTrue(s.mirror)
        XCTAssertEqual(design.cameras[0].id, "cam1"); XCTAssertEqual(design.cameras[0].fov, 80)
    }

    func testNoDesignSavedOrAnEmptyOneGivesNothingToDrawOn() throws {
        XCTAssertNil(SiteParser.parse(object(#"{"revision":0,"updated_at":null,"updated_by":null,"site":null}"#)))
        let empty = try XCTUnwrap(SiteParser.parse(object(#"{"revision":1,"site":{"schema":"armor-studio/site/1"}}"#)))
        XCTAssertFalse(empty.hasRadar)
        XCTAssertEqual(empty.terrain.count, 4)   // a plain rectangle of the default size
    }

    func testTargetsOfANodeStateAreRead() {
        let t = SiteParser.targets(object(#"{"online":true,"targets":[{"sensor_id":2,"track_id":7,"x_mm":-300,"y_mm":1500,"speed_mm_s":120,"counted":false}]}"#))
        XCTAssertEqual(t.count, 1); XCTAssertEqual(t[0].sensorId, 2); XCTAssertEqual(t[0].trackId, 7); XCTAssertEqual(t[0].xMm, -300); XCTAssertFalse(t[0].counted)
        XCTAssertTrue(SiteParser.targets(object(#"{"online":true}"#)).isEmpty)
    }

    func testTheStatusOfTheServerCarriesTheTargetsOfEachNode() {
        let snapshot = ArmorSnapshot.parse(object(#"{"mode":"armed","nodes":{"gate":{"online":true,"target_count":1,"targets":[{"sensor_id":1,"track_id":4,"x_mm":0,"y_mm":3000,"speed_mm_s":0,"counted":true}]}}}"#))
        XCTAssertEqual(snapshot.nodes[0].targets.map { $0.trackId }, [4])
    }
}
