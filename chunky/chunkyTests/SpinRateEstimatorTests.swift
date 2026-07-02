// chunky/chunkyTests/SpinRateEstimatorTests.swift
import XCTest
@testable import chunky

final class SpinRateEstimatorTests: XCTestCase {
    // Build angle samples for a constant rpm at a given fps (no noise).
    private func angles(rpm: Double, fps: Double, count: Int, start: Double = 0.1) -> [Timestamped<Double>] {
        let radPerFrame = rpm * 2 * .pi / 60.0 / fps
        return (0..<count).map { i in
            Timestamped(timeSeconds: start + Double(i)/fps,
                        value: atan2(sin(Double(i)*radPerFrame), cos(Double(i)*radPerFrame))) // wrapped
        }
    }

    func testRecoversModerateRPMNoAliasing() {
        // 3000 rpm @ 240 fps → 0.21 rev/frame (< half rev, no aliasing)
        let a = angles(rpm: 3000, fps: 240, count: 8)
        let e = SpinRateEstimator().estimate(angles: a, modeledPriorRPM: 2600)
        XCTAssertNotNil(e)
        XCTAssertEqual(e!.rpm, 3000, accuracy: 60)   // within 2%
        XCTAssertGreaterThan(e!.confidence, 0.8)
    }

    func testResolvesAliasingWithPrior() {
        // 9000 rpm @ 240 fps → 0.625 rev/frame (aliased); prior near truth resolves it
        let a = angles(rpm: 9000, fps: 240, count: 8)
        let e = SpinRateEstimator().estimate(angles: a, modeledPriorRPM: 9000)
        XCTAssertEqual(e!.rpm, 9000, accuracy: 200)
        XCTAssertGreaterThan(e!.confidence, 0.8)
    }

    func testImplausibleRPMZeroConfidence() {
        let a = angles(rpm: 40000, fps: 240, count: 8)   // absurd
        let e = SpinRateEstimator().estimate(angles: a, modeledPriorRPM: 40000)
        XCTAssertEqual(e!.confidence, 0, accuracy: 1e-9)
    }

    func testTooFewSamplesReturnsNil() {
        XCTAssertNil(SpinRateEstimator().estimate(angles: Array(angles(rpm: 3000, fps: 240, count: 2).prefix(2)),
                                                  modeledPriorRPM: 2600))
    }
}
