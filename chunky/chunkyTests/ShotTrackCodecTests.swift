// chunky/chunkyTests/ShotTrackCodecTests.swift
import XCTest
@testable import chunky

final class ShotTrackCodecTests: XCTestCase {
    func testRoundTripPreservesTrack() {
        let track = [
            TrackPoint(timeSeconds: 0.0,   pixel: Vec2(10, 20), radiusPx: 5, confidence: 0.9),
            TrackPoint(timeSeconds: 0.004, pixel: Vec2(14, 19), radiusPx: 5, confidence: 0.8),
        ]
        let json = ShotTrackCodec.encode(track)
        XCTAssertFalse(json.isEmpty)
        XCTAssertEqual(ShotTrackCodec.decode(json), track)
    }

    func testEmptyTrackRoundTrips() {
        XCTAssertEqual(ShotTrackCodec.decode(ShotTrackCodec.encode([])), [])
    }

    func testDecodeOfGarbageReturnsNil() {
        XCTAssertNil(ShotTrackCodec.decode("not json"))
    }
}
