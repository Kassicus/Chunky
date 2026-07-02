// chunky/chunkyTests/CalibrationManualTests.swift
import XCTest
@testable import chunky

final class CalibrationManualTests: XCTestCase {
    func testPixelsPerMeterFromTwoPoints() {
        // 200 px apart, 0.5 m reference → 400 px/m
        let ppm = CalibrationMath.pixelsPerMeter(pointA: Vec2(0, 0), pointB: Vec2(200, 0), knownLengthMeters: 0.5)
        XCTAssertEqual(ppm!, 400, accuracy: 1e-9)
    }

    func testZeroLengthReturnsNil() {
        XCTAssertNil(CalibrationMath.pixelsPerMeter(pointA: Vec2(0, 0), pointB: Vec2(200, 0), knownLengthMeters: 0))
    }

    func testCoincidentPointsReturnNil() {
        XCTAssertNil(CalibrationMath.pixelsPerMeter(pointA: Vec2(5, 5), pointB: Vec2(5, 5), knownLengthMeters: 1))
    }

    func testManualScaleUsesGravityForUp() {
        // gravity down (0,+1) → imageUpUnit ≈ (0,-1)
        let scale = CalibrationMath.calibrationScale(pointA: Vec2(0, 0), pointB: Vec2(100, 0),
                                                     knownLengthMeters: 0.5, imagePlaneGravity: Vec2(0, 1))
        XCTAssertEqual(scale!.pixelsPerMeter, 200, accuracy: 1e-9)
        XCTAssertEqual(scale!.imageUpUnit.x, 0, accuracy: 1e-9)
        XCTAssertEqual(scale!.imageUpUnit.y, -1, accuracy: 1e-9)
    }
}
