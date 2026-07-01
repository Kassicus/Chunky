// chunky/chunkyTests/MetricsInputTypesTests.swift
import XCTest
@testable import chunky

final class MetricsInputTypesTests: XCTestCase {
    func testTrackPointDefaults() {
        let p = TrackPoint(timeSeconds: 0.5, pixel: Vec2(10, 20))
        XCTAssertEqual(p.radiusPx, 0, accuracy: 1e-12)
        XCTAssertEqual(p.confidence, 1, accuracy: 1e-12)
    }

    func testCalibrationNormalizesUpAndDerivesHorizontal() {
        let cal = CalibrationScale(pixelsPerMeter: 100, imageUpUnit: Vec2(0, 5))
        XCTAssertEqual(cal.imageUpUnit.magnitude, 1, accuracy: 1e-12)   // normalized
        XCTAssertEqual(cal.imageUpUnit, Vec2(0, 1))
        XCTAssertEqual(cal.imageHorizontalUnit, Vec2(1, 0))
        XCTAssertEqual(cal.imageUpUnit.dot(cal.imageHorizontalUnit), 0, accuracy: 1e-12)
    }

    func testEnvironmentDefaultsToSeaLevelStandard() {
        let env = Environment()
        XCTAssertEqual(env.airDensityKgM3, 1.225, accuracy: 0.001)
    }

    func testEnvironmentAltitudeThinsAir() {
        let sea = Environment(temperatureC: 15, altitudeM: 0)
        let denver = Environment(temperatureC: 15, altitudeM: 1609)
        XCTAssertLessThan(denver.airDensityKgM3, sea.airDensityKgM3)
    }
}
