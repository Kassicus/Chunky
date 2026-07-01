// chunky/chunkyTests/MetricsShotTests.swift
import XCTest
@testable import chunky

final class MetricsShotTests: XCTestCase {
    private let cal = CalibrationScale(pixelsPerMeter: 100, imageUpUnit: Vec2(0, 1))

    private func syntheticTrack(v0: Double, angleDeg: Double, frames: Int = 10, fps: Double = 240) -> [TrackPoint] {
        let theta = angleDeg * .pi / 180
        let vHoriz = v0 * cos(theta)
        let vUp = v0 * sin(theta)
        let up = cal.imageUpUnit, horiz = cal.imageHorizontalUnit, s = cal.pixelsPerMeter
        return (0..<frames).map { i in
            let t = Double(i) / fps
            return TrackPoint(timeSeconds: t, pixel: s * ((vHoriz * t) * horiz + (vUp * t) * up))
        }
    }

    func testUsesModeledSpinWhenNoMeasurement() {
        let track = syntheticTrack(v0: 70, angleDeg: 12)
        let r = Metrics.computeShot(track: track, calibration: cal, atmosphere: Atmosphere(),
                                    modeledSpinRPM: 2600)!
        XCTAssertEqual(r.spinSource, .modeled)
        XCTAssertEqual(r.spinRPM, 2600, accuracy: 1e-9)
        XCTAssertEqual(r.spinAxisTiltDeg, 0, accuracy: 1e-12)
    }

    func testUsesMeasuredSpinWhenConfident() {
        let track = syntheticTrack(v0: 70, angleDeg: 12)
        let measured = MeasuredSpin(rpm: 3100, axisTiltDeg: 2, confidence: 0.8)
        let r = Metrics.computeShot(track: track, calibration: cal, atmosphere: Atmosphere(),
                                    modeledSpinRPM: 2600, measuredSpin: measured)!
        XCTAssertEqual(r.spinSource, .measured)
        XCTAssertEqual(r.spinRPM, 3100, accuracy: 1e-9)
        XCTAssertEqual(r.spinAxisTiltDeg, 2, accuracy: 1e-9)
    }

    func testFallsBackWhenMeasuredSpinLowConfidence() {
        let track = syntheticTrack(v0: 70, angleDeg: 12)
        let measured = MeasuredSpin(rpm: 3100, confidence: 0.2) // below threshold 0.5
        let r = Metrics.computeShot(track: track, calibration: cal, atmosphere: Atmosphere(),
                                    modeledSpinRPM: 2600, measuredSpin: measured)!
        XCTAssertEqual(r.spinSource, .modeled)
        XCTAssertEqual(r.spinRPM, 2600, accuracy: 1e-9)
    }

    func testCarryMatchesDirectBallisticsCall() {
        // computeShot must integrate with exactly the measured launch conditions.
        let track = syntheticTrack(v0: 74.66, angleDeg: 10.9) // ~driver ball speed
        let atm = Atmosphere()
        let r = Metrics.computeShot(track: track, calibration: cal, atmosphere: atm,
                                    modeledSpinRPM: 2686)!
        let expected = Ballistics.integrate(
            launch: LaunchConditions(speedMS: r.ballSpeedMS, launchAngleDeg: r.launchAngleDeg,
                                     azimuthDeg: 0, spinRPM: 2686, spinAxisTiltDeg: 0),
            airDensityKgM3: atm.airDensityKgM3
        ).carryMeters
        XCTAssertEqual(r.carryMeters, expected, accuracy: 1e-6)
        XCTAssertGreaterThan(r.carryYards, 230) // sanity: plausible driver carry
        XCTAssertLessThan(r.carryYards, 320)
    }

    func testConfidenceHighWithMeasuredAndCleanTrack() {
        let track = syntheticTrack(v0: 70, angleDeg: 12) // 8 fit frames, ~0 residual
        let r = Metrics.computeShot(track: track, calibration: cal, atmosphere: Atmosphere(),
                                    modeledSpinRPM: 2600,
                                    measuredSpin: MeasuredSpin(rpm: 3000, confidence: 0.9))!
        XCTAssertEqual(r.confidence, .high)
    }

    func testConfidenceMediumWithModeledAndCleanTrack() {
        let track = syntheticTrack(v0: 70, angleDeg: 12)
        let r = Metrics.computeShot(track: track, calibration: cal, atmosphere: Atmosphere(),
                                    modeledSpinRPM: 2600)!
        XCTAssertEqual(r.confidence, .medium)
    }

    func testConfidenceLowWithTooFewFrames() {
        let track = syntheticTrack(v0: 70, angleDeg: 12, frames: 2)
        let r = Metrics.computeShot(track: track, calibration: cal, atmosphere: Atmosphere(),
                                    modeledSpinRPM: 2600,
                                    measuredSpin: MeasuredSpin(rpm: 3000, confidence: 0.9))!
        XCTAssertEqual(r.confidence, .low)
    }

    func testConfidenceLevelFunctionDirectly() {
        XCTAssertEqual(Metrics.confidenceLevel(spinSource: .measured, frameCount: 8, fitRmsResidualMeters: 0.0), .high)
        XCTAssertEqual(Metrics.confidenceLevel(spinSource: .modeled, frameCount: 8, fitRmsResidualMeters: 0.0), .medium)
        XCTAssertEqual(Metrics.confidenceLevel(spinSource: .measured, frameCount: 2, fitRmsResidualMeters: 0.0), .low)
        XCTAssertEqual(Metrics.confidenceLevel(spinSource: .modeled, frameCount: 4, fitRmsResidualMeters: 0.10), .low)
    }
}
