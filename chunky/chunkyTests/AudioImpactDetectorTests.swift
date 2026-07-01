// chunky/chunkyTests/AudioImpactDetectorTests.swift
import XCTest
@testable import chunky

final class AudioImpactDetectorTests: XCTestCase {
    func testDetectsSpikeAfterQuietBaseline() {
        var d = AudioImpactDetector()
        var detections: [Double] = []
        // 0.5 s of quiet (energy ~0.02) at 1 kHz frames, then a spike at t=0.5
        var t = 0.0
        for _ in 0..<500 { if d.process(energy: 0.02, time: t) { detections.append(t) }; t += 0.001 }
        _ = d.process(energy: 0.02, time: t) // keep baseline low
        let spikeTime = t
        if d.process(energy: 1.0, time: spikeTime) { detections.append(spikeTime) }
        XCTAssertEqual(detections.count, 1)
        XCTAssertEqual(detections.first!, spikeTime, accuracy: 1e-9)
    }

    func testRefractorySuppressesDoubleFire() {
        var d = AudioImpactDetector(refractorySeconds: 0.20)
        _ = d.process(energy: 0.02, time: 0.0)      // seed baseline
        for _ in 0..<50 { _ = d.process(energy: 0.02, time: 0.0) }
        let first = d.process(energy: 1.0, time: 1.000)   // detect
        let second = d.process(energy: 1.0, time: 1.100)  // within 0.2 s → suppressed
        let third = d.process(energy: 1.0, time: 1.300)   // after refractory → detect
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertTrue(third)
    }

    func testIgnoresBelowFloorAndBelowRatio() {
        var d = AudioImpactDetector(energyRatioThreshold: 4.0, absoluteFloor: 0.01)
        _ = d.process(energy: 0.02, time: 0.0)
        // 3× baseline but still tiny / not 4× → no detect
        XCTAssertFalse(d.process(energy: 0.05, time: 0.1))
        // below absolute floor even if ratio high vs a near-zero baseline
        var d2 = AudioImpactDetector(absoluteFloor: 0.5)
        _ = d2.process(energy: 0.001, time: 0.0)
        XCTAssertFalse(d2.process(energy: 0.004, time: 0.1))
    }
}
