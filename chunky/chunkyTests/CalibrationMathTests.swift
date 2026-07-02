// chunky/chunkyTests/CalibrationMathTests.swift
import XCTest
@testable import chunky

final class CalibrationMathTests: XCTestCase {
    // A 100px axis-aligned square (corners), representing a 0.3 m marker → 100/0.3 px/m.
    private let square = [Vec2(0,0), Vec2(100,0), Vec2(100,100), Vec2(0,100)]

    func testPixelsPerMeterFromMarker() {
        XCTAssertEqual(CalibrationMath.pixelsPerMeter(markerCornersPx: square, markerSideMeters: 0.3)!,
                       100.0 / 0.3, accuracy: 1e-6)
    }
    func testCornerOrderingIsRobustToInputOrder() {
        let shuffled = [Vec2(100,100), Vec2(0,0), Vec2(0,100), Vec2(100,0)]
        XCTAssertEqual(CalibrationMath.pixelsPerMeter(markerCornersPx: shuffled, markerSideMeters: 0.3)!,
                       100.0 / 0.3, accuracy: 1e-6)
    }
    func testImageUpFromGravity() {
        // Gravity points down in image (+y). Up = (0,-1).
        let up = CalibrationMath.imageUpUnit(imagePlaneGravity: Vec2(0, 1))
        XCTAssertEqual(up.x, 0, accuracy: 1e-9); XCTAssertEqual(up.y, -1, accuracy: 1e-9)
    }
    func testImageUpWithRoll() {
        let g = Vec2(0.6, 0.8)   // rolled gravity (unit)
        let up = CalibrationMath.imageUpUnit(imagePlaneGravity: g)
        XCTAssertEqual(up.x, -0.6, accuracy: 1e-9); XCTAssertEqual(up.y, -0.8, accuracy: 1e-9)
    }
    func testBuildsCalibrationScale() {
        let cal = CalibrationMath.calibrationScale(markerCornersPx: square, markerSideMeters: 0.3, imagePlaneGravity: Vec2(0,1))!
        XCTAssertEqual(cal.pixelsPerMeter, 100.0/0.3, accuracy: 1e-6)
        XCTAssertEqual(cal.imageUpUnit, Vec2(0,-1))
    }
    func testNilForWrongCornerCount() {
        XCTAssertNil(CalibrationMath.pixelsPerMeter(markerCornersPx: [Vec2(0,0), Vec2(1,1)], markerSideMeters: 0.3))
    }
}
