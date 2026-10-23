import XCTest
@testable import ArmorCore

final class MjpegTests: XCTestCase {
    private func jpeg(_ fill: UInt8, count: Int = 10) -> Data { Data([0xFF, 0xD8] + [UInt8](repeating: fill, count: count) + [0xFF, 0xD9]) }
    private func part(_ frame: Data) -> Data { Data("--frame\r\nContent-Type: image/jpeg\r\nContent-Length: \(frame.count)\r\n\r\n".utf8) + frame + Data("\r\n".utf8) }

    func testCutsPicturesOutOfMultipartData() {
        var parser = MjpegFrameParser()
        let frames = parser.feed(part(jpeg(1)) + part(jpeg(2)))
        XCTAssertEqual(frames, [jpeg(1), jpeg(2)])
    }
    func testAPictureSplitAcrossChunksIsJoined() {
        var parser = MjpegFrameParser()
        let all = part(jpeg(7, count: 100))
        var frames: [Data] = []
        for index in stride(from: 0, to: all.count, by: 7) { frames += parser.feed(all.subdata(in: index..<min(index + 7, all.count))) }
        XCTAssertEqual(frames, [jpeg(7, count: 100)])
    }
    func testAMarkerSplitInTwoChunksIsFound() {
        var parser = MjpegFrameParser()
        var frames = parser.feed(Data([0x00, 0xFF]))
        frames += parser.feed(Data([0xD8, 0x01, 0x02, 0xFF]))
        frames += parser.feed(Data([0xD9]))
        XCTAssertEqual(frames, [Data([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9])])
    }
    func testGarbageBetweenPicturesIsDropped() {
        var parser = MjpegFrameParser()
        XCTAssertEqual(parser.feed(Data("hello".utf8) + jpeg(3) + Data("garbage".utf8)), [jpeg(3)])
    }
    func testAnEndlessPictureIsThrownAway() {
        var parser = MjpegFrameParser()
        _ = parser.feed(Data([0xFF, 0xD8]))
        for _ in 0..<5 { _ = parser.feed(Data(repeating: 0x11, count: 1024 * 1024)) }
        XCTAssertEqual(parser.feed(jpeg(9)), [jpeg(9)])
    }
    func testBackoffDoublesAndResets() {
        var backoff = Backoff()
        XCTAssertEqual(backoff.delaySeconds, 1)
        backoff.failed(); XCTAssertEqual(backoff.delaySeconds, 2)
        backoff.failed(); XCTAssertEqual(backoff.delaySeconds, 4)
        for _ in 0..<20 { backoff.failed() }
        XCTAssertEqual(backoff.delaySeconds, 30)
        backoff.succeeded()
        XCTAssertEqual(backoff.delaySeconds, 1)
    }
    func testOnlySixTilesRun() {
        XCTAssertEqual(CameraGrid.live(visible: (1...10).map(String.init)).count, 6)
        XCTAssertEqual(CameraGrid.live(visible: ["a"]), ["a"])
    }
}
