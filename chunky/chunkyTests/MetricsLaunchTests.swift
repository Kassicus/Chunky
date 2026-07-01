// chunky/chunkyTests/MetricsLaunchTests.swift
import XCTest
@testable import chunky

final class MetricsLaunchTests: XCTestCase {
    // Build a synthetic constant-velocity track for a launch of v0 (m/s) at angle
    // (deg) above horizontal, imaged with the given calibration (no roll unless
    // upUnit is tilted). Pixel = pxPerMeter * (horiz_m * horizUnit + up_m * upUnit).
    private func syntheticTrack(v0: Double, angleDeg: Double, calibration: CalibrationScale,
                                frames: Int = 10, fps: Double = 240) -> [TrackPoint] {
        let theta = angleDeg * .pi / 180
        let vHoriz = v0 * cos(theta)
        let vUp = v0 * sin(theta)
        let up = calibration.imageUpUnit
        let horiz = calibration.imageHorizontalUnit
        let s = calibration.pixelsPerMeter
        return (0..<frames).map { i in
            let t = Double(i) / fps
            let pixel = s * ((vHoriz * t) * horiz + (vUp * t) * up)
            return TrackPoint(timeSeconds: t, pixel: pixel)
        }
    }

    func testRecoversSpeedAndAngleUpright() {
        let cal = CalibrationScale(pixelsPerMeter: 100, imageUpUnit: Vec2(0, 1))
        let track = syntheticTrack(v0: 70, angleDeg: 14, calibration: cal)
        let m = Metrics.measureLaunch(track: track, calibration: cal)!
        XCTAssertEqual(m.ballSpeedMS, 70, accuracy: 1e-6)
        XCTAssertEqual(m.launchAngleDeg, 14, accuracy: 1e-6)
        XCTAssertEqual(m.azimuthDeg, 0, accuracy: 1e-12)
        XCTAssertEqual(m.fitRmsResidualMeters, 0, accuracy: 1e-9)
        XCTAssertEqual(m.usedFrameCount, 8) // capped at maxFitFrames
    }

    func testRecoversAngleWithRolledCalibration() {
        // Camera rolled ~37°: up unit is (0.6, 0.8). Attitude correction must still
        // recover the true launch angle.
        let cal = CalibrationScale(pixelsPerMeter: 120, imageUpUnit: Vec2(0.6, 0.8))
        let track = syntheticTrack(v0: 55, angleDeg: 20, calibration: cal)
        let m = Metrics.measureLaunch(track: track, calibration: cal)!
        XCTAssertEqual(m.ballSpeedMS, 55, accuracy: 1e-6)
        XCTAssertEqual(m.launchAngleDeg, 20, accuracy: 1e-6)
    }

    func testHorizontalDirectionSignIndependent() {
        // Ball moving right-to-left (negative horizontal) yields the same angle/speed.
        let cal = CalibrationScale(pixelsPerMeter: 100, imageUpUnit: Vec2(0, 1))
        let track = syntheticTrack(v0: 60, angleDeg: 10, calibration: cal).map {
            TrackPoint(timeSeconds: $0.timeSeconds, pixel: Vec2(-$0.pixel.x, $0.pixel.y))
        }
        let m = Metrics.measureLaunch(track: track, calibration: cal)!
        XCTAssertEqual(m.ballSpeedMS, 60, accuracy: 1e-6)
        XCTAssertEqual(m.launchAngleDeg, 10, accuracy: 1e-6)
    }

    func testTooShortTrackReturnsNil() {
        let cal = CalibrationScale(pixelsPerMeter: 100, imageUpUnit: Vec2(0, 1))
        XCTAssertNil(Metrics.measureLaunch(track: [TrackPoint(timeSeconds: 0, pixel: .zero)], calibration: cal))
    }
}
