// chunky/chunkyTests/ScaleSanityTests.swift
import XCTest
@testable import chunky

final class ScaleSanityTests: XCTestCase {
    func testPixelsPerMeterFromRadius() {
        // radius 20px, diameter 0.04267m → 40px / 0.04267 ≈ 937.4 px/m
        XCTAssertEqual(ScaleSanity.pixelsPerMeter(ballRadiusPx: 20), 40.0 / 0.04267, accuracy: 1e-6)
    }
    func testAgreementWithinTolerance() {
        XCTAssertTrue(ScaleSanity.agrees(estimatedPxPerMeter: 1000, calibratedPxPerMeter: 1100, tolerance: 0.25))
        XCTAssertFalse(ScaleSanity.agrees(estimatedPxPerMeter: 1000, calibratedPxPerMeter: 2000, tolerance: 0.25))
    }
}
