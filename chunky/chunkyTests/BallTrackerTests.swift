// chunky/chunkyTests/BallTrackerTests.swift
import XCTest
@testable import chunky

final class BallTrackerTests: XCTestCase {
    private func frame(_ t: Double, _ cands: (Double, Double, Double)...) -> Timestamped<[BallCandidate]> {
        Timestamped(timeSeconds: t, value: cands.map { BallCandidate(center: Vec2($0.0, $0.1), radiusPx: 5, confidence: $0.2) })
    }

    func testFollowsConstantVelocityBall() {
        // Ball moves +10px/frame in x; each frame also has a spurious far candidate.
        let frames = (0..<6).map { i -> Timestamped<[BallCandidate]> in
            let x = 10.0 + Double(i) * 10
            return frame(Double(i) / 240.0, (x, 20, 0.9), (300, 300, 0.8))
        }
        let track = BallTracker().track(frames)
        XCTAssertEqual(track.count, 6)
        XCTAssertEqual(track.first!.pixel.x, 10, accuracy: 1e-6)
        XCTAssertEqual(track.last!.pixel.x, 60, accuracy: 1e-6)   // ignored the far spurious ones
        XCTAssertEqual(track.map(\.timeSeconds), (0..<6).map { Double($0)/240.0 })
    }

    func testSkipsOcclusionFrame() {
        var frames = [frame(0, (10,20,0.9)), frame(1.0/240, (20,20,0.9))]
        frames.append(Timestamped(timeSeconds: 2.0/240, value: []))       // occluded
        frames.append(frame(3.0/240, (40,20,0.9)))
        let track = BallTracker().track(frames)
        XCTAssertEqual(track.count, 3)   // the empty frame is skipped
        XCTAssertEqual(track.last!.pixel.x, 40, accuracy: 1e-6)
    }

    func testEmptyInputYieldsEmptyTrack() {
        XCTAssertTrue(BallTracker().track([]).isEmpty)
    }
}
