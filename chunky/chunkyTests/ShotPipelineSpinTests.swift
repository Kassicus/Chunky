// chunky/chunkyTests/ShotPipelineSpinTests.swift
import XCTest
import CoreVideo
@testable import chunky

final class ShotPipelineSpinTests: XCTestCase {
    func testBlankBallFallsBackToModeledSpin() {
        // Reuse the plain moving-disk frames (a bright ball, no dark marking):
        // The disk has no dark marking, so SpinCore finds no marking angle →
        // returns nil → Metrics.computeShot uses modeled spin.
        let frames = ShotPipelineTests.syntheticImpactFrames()
        let capture = ImpactCapture(impactTime: 0, frames: frames)
        let scale = CalibrationScale(pixelsPerMeter: 500, imageUpUnit: Vec2(0, -1))
        let out = ShotPipeline().output(from: capture, calibration: scale,
                                        atmosphere: Atmosphere(), modeledSpinRPM: 6500)
        XCTAssertNotNil(out)
        XCTAssertEqual(out!.result.spinSource, .modeled)   // no marking → modeled fallback
        XCTAssertEqual(out!.result.spinRPM, 6500, accuracy: 1e-6)
    }
}
