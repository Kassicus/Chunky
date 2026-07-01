// chunky/chunkyTests/BallModelTests.swift
import XCTest
@testable import chunky

final class BallModelTests: XCTestCase {
    func testStandardConstants() {
        let b = BallModel.standard
        XCTAssertEqual(b.mass, 0.04593, accuracy: 1e-12)
        XCTAssertEqual(b.diameter, 0.04267, accuracy: 1e-12)
    }

    func testArea() {
        let b = BallModel.standard
        let expected = Double.pi * (0.04267 / 2) * (0.04267 / 2)
        XCTAssertEqual(b.area, expected, accuracy: 1e-15)
    }

    func testLaunchConditionsDefaults() {
        let lc = LaunchConditions(speedMS: 70, launchAngleDeg: 12, spinRPM: 2600)
        XCTAssertEqual(lc.azimuthDeg, 0, accuracy: 1e-12)
        XCTAssertEqual(lc.spinAxisTiltDeg, 0, accuracy: 1e-12)
    }
}
