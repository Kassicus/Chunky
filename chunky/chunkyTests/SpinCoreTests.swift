// chunky/chunkyTests/SpinCoreTests.swift
import XCTest
@testable import chunky

final class SpinCoreTests: XCTestCase {
    /// A white ball with an off-center dark mark that ROTATES about the frame
    /// center at `rpm`, rendered at `fps`. Ball fills the frame (center = size/2).
    private func rotatingFrames(size: Int, rpm: Double, fps: Double, count: Int) -> (frames: [Timestamped<GrayImage>], track: [TrackPoint]) {
        let c = Double(size)/2.0
        // ballR = size/3 so crop half (ballR*1.15) < c → ox > 0, avoiding clamp offset.
        // markOrbit = ballR*0.5, markR = ballR*0.25 keeps mark fully inside inner disk
        // (innerRadiusRatio 0.85): orbit + markR = 0.75*ballR < 0.85*ballR = rIn.
        // markR must satisfy pi*markR^2 / pi*rIn^2 >= 0.045 for strength>=0.3.
        let ballR = Double(size) / 3.0
        let markOrbit = ballR * 0.5, markR = max(3, Int(ballR * 0.25))
        let radPerFrame = rpm * 2 * .pi / 60.0 / fps
        var frames: [Timestamped<GrayImage>] = []
        var track: [TrackPoint] = []
        for i in 0..<count {
            let ang = Double(i) * radPerFrame
            let mx = Int((c + markOrbit * cos(ang)).rounded())
            let my = Int((c + markOrbit * sin(ang)).rounded())
            var px = [UInt8](repeating: 255, count: size*size)
            for y in 0..<size { for x in 0..<size {
                let dx = x - mx, dy = y - my
                if dx*dx + dy*dy <= markR*markR { px[y*size + x] = 0 }
            }}
            let t = 0.1 + Double(i)/fps
            frames.append(Timestamped(timeSeconds: t, value: GrayImage(width: size, height: size, pixels: px)))
            track.append(TrackPoint(timeSeconds: t, pixel: Vec2(c, c), radiusPx: ballR, confidence: 0.9))
        }
        return (frames, track)
    }

    func testMeasuresRotatingMarking() {
        let (frames, track) = rotatingFrames(size: 60, rpm: 3000, fps: 240, count: 8)
        let spin = SpinCore().measure(ballFrames: frames, track: track, modeledSpinRPM: 2600)
        XCTAssertNotNil(spin)
        XCTAssertEqual(spin!.rpm, 3000, accuracy: 300)       // within ~10%
        XCTAssertGreaterThan(spin!.confidence, 0.4)
        XCTAssertEqual(spin!.axisTiltDeg, 0, accuracy: 1e-9) // single-camera → backspin-dominant
    }

    func testBlankBallYieldsNilOrZeroConfidence() {
        let c = 30.0
        let frames = (0..<8).map { i in
            Timestamped(timeSeconds: 0.1 + Double(i)/240.0, value: GrayImage.filled(width: 60, height: 60, value: 255))
        }
        let track = (0..<8).map { i in
            TrackPoint(timeSeconds: 0.1 + Double(i)/240.0, pixel: Vec2(c, c), radiusPx: 28, confidence: 0.9)
        }
        let spin = SpinCore().measure(ballFrames: frames, track: track, modeledSpinRPM: 2600)
        XCTAssertTrue(spin == nil || spin!.confidence < 0.5) // no marking → falls back to modeled
    }
}
