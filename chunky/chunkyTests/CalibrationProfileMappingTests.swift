// chunky/chunkyTests/CalibrationProfileMappingTests.swift
import XCTest
@testable import chunky

final class CalibrationProfileMappingTests: XCTestCase {
    @MainActor func testScaleRoundTripsThroughProfile() {
        let scale = CalibrationScale(pixelsPerMeter: 1234.5, imageUpUnit: Vec2(0, -1))
        let created = Date(timeIntervalSince1970: 1_000_000)
        let profile = CalibrationProfileMapping.profile(from: scale, lens: .telephoto,
                                                        cameraDistanceM: 3.0, createdAt: created)
        XCTAssertEqual(profile.pxPerMeter, 1234.5, accuracy: 1e-9)
        XCTAssertEqual(profile.imageUpX, 0, accuracy: 1e-9)
        XCTAssertEqual(profile.imageUpY, -1, accuracy: 1e-9)
        XCTAssertEqual(profile.lens, .telephoto)

        let back = CalibrationProfileMapping.scale(from: profile)
        XCTAssertEqual(back.pixelsPerMeter, scale.pixelsPerMeter, accuracy: 1e-9)
        XCTAssertEqual(back.imageUpUnit.x, scale.imageUpUnit.x, accuracy: 1e-9)
        XCTAssertEqual(back.imageUpUnit.y, scale.imageUpUnit.y, accuracy: 1e-9)
    }
}
