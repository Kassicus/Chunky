// chunky/chunkyTests/ShotResultTypesTests.swift
import XCTest
@testable import chunky

final class ShotResultTypesTests: XCTestCase {
    func testMeasuredSpinDefaultTilt() {
        let m = MeasuredSpin(rpm: 2600, confidence: 0.9)
        XCTAssertEqual(m.axisTiltDeg, 0, accuracy: 1e-12)
    }

    func testEnumRawValues() {
        XCTAssertEqual(SpinSource.modeled.rawValue, "modeled")
        XCTAssertEqual(ConfidenceLevel.high.rawValue, "high")
    }

    func testShotResultConvenienceConversions() {
        let r = ShotResult(
            ballSpeedMS: Conversions.mphToMS(160),
            launchAngleDeg: 11, azimuthDeg: 0,
            spinRPM: 2600, spinSource: .modeled, spinAxisTiltDeg: 0,
            carryMeters: Conversions.yardsToMeters(250),
            confidence: .medium, fitRmsResidualMeters: 0.001, usedFrameCount: 8
        )
        XCTAssertEqual(r.ballSpeedMPH, 160, accuracy: 1e-6)
        XCTAssertEqual(r.carryYards, 250, accuracy: 1e-6)
    }
}
