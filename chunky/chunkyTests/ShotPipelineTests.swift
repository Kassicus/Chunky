// chunky/chunkyTests/ShotPipelineTests.swift
import XCTest
import CoreVideo
@testable import chunky

final class ShotPipelineTests: XCTestCase {
    // Pure path: a clean constant-velocity track yields a ShotResult + JSON.
    func testOutputFromTrackProducesResultAndJSON() {
        // Ball moving up-and-right at a constant image velocity over 6 frames.
        var track: [TrackPoint] = []
        for i in 0..<6 {
            let t = Double(i) * 0.004
            track.append(TrackPoint(timeSeconds: t, pixel: Vec2(100 + Double(i) * 30, 400 - Double(i) * 20),
                                    radiusPx: 6, confidence: 0.9))
        }
        let scale = CalibrationScale(pixelsPerMeter: 500, imageUpUnit: Vec2(0, -1))
        let out = ShotPipeline().output(track: track, calibration: scale,
                                        atmosphere: Atmosphere(), modeledSpinRPM: 2600)
        XCTAssertNotNil(out)
        XCTAssertGreaterThan(out!.result.ballSpeedMS, 0)
        XCTAssertEqual(out!.trackPointCount, 6)
        XCTAssertEqual(ShotTrackCodec.decode(out!.rawTrackJSON)?.count, 6)
    }

    func testTooShortTrackReturnsNil() {
        let scale = CalibrationScale(pixelsPerMeter: 500, imageUpUnit: Vec2(0, -1))
        let out = ShotPipeline().output(track: [], calibration: scale,
                                        atmosphere: Atmosphere(), modeledSpinRPM: 2600)
        XCTAssertNil(out)
    }

    // End-to-end path: synthetic pixel buffers with a moving bright disk.
    func testOutputFromImpactCaptureRunsFullChain() {
        let frames = Self.syntheticImpactFrames()
        let capture = ImpactCapture(impactTime: 0, frames: frames)
        let scale = CalibrationScale(pixelsPerMeter: 500, imageUpUnit: Vec2(0, -1))
        let out = ShotPipeline().output(from: capture, calibration: scale,
                                        atmosphere: Atmosphere(), modeledSpinRPM: 6500)
        // The detector must find the disk in enough frames to fit a launch.
        XCTAssertNotNil(out, "full capture→track→result chain should produce a result")
        XCTAssertGreaterThanOrEqual(out!.trackPointCount, 4)
    }

    /// Builds 6 in-memory 32BGRA buffers, each with a bright filled disk that
    /// translates by (+28, -22) px per frame.
    ///
    /// Geometry tuning: frame is 240×180. Starting center (60, 150), step (+28, -22).
    ///   Frame 0: (60,150), Frame 1: (88,128), Frame 2: (116,106),
    ///   Frame 3: (144,84), Frame 4: (172,62), Frame 5: (200,40).
    /// Disk radius 6 stays fully inside [0..239]×[0..179] for all 6 frames.
    /// BallTracker gate = 40 px; inter-frame step ≈ 35.6 px — within gate.
    /// PixelBufferGray reads the G channel (offset +1 in BGRA); disk G = 255,
    /// background G = 0. BlobBallDetector threshold = 180 — disk always detected.
    static func syntheticImpactFrames() -> [Timestamped<CVPixelBuffer>] {
        let w = 240, h = 180
        let radius = 6
        let startCX = 60, startCY = 150
        let stepX = 28, stepY = -22
        var frames: [Timestamped<CVPixelBuffer>] = []

        for i in 0..<6 {
            var pb: CVPixelBuffer?
            let attrs: [String: Any] = [kCVPixelBufferCGImageCompatibilityKey as String: true]
            CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                                attrs as CFDictionary, &pb)
            let buffer = pb!
            CVPixelBufferLockBaseAddress(buffer, [])
            let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let bpr = CVPixelBufferGetBytesPerRow(buffer)

            // Background = dark (all channels 0, alpha 255).
            for y in 0..<h {
                for x in 0..<w {
                    let o = y * bpr + x * 4
                    base[o] = 0; base[o+1] = 0; base[o+2] = 0; base[o+3] = 255
                }
            }

            // Bright filled disk; G channel (offset +1) = 255 so PixelBufferGray sees 255.
            let cx = startCX + i * stepX
            let cy = startCY + i * stepY
            for dy in -radius...radius {
                for dx in -radius...radius {
                    if dx*dx + dy*dy > radius*radius { continue }
                    let x = cx + dx, y = cy + dy
                    guard x >= 0, x < w, y >= 0, y < h else { continue }
                    let o = y * bpr + x * 4
                    // BGRA: B=255, G=255, R=255, A=255 — PixelBufferGray reads G (o+1).
                    base[o] = 255; base[o+1] = 255; base[o+2] = 255; base[o+3] = 255
                }
            }

            CVPixelBufferUnlockBaseAddress(buffer, [])
            frames.append(Timestamped(timeSeconds: Double(i) * 0.004, value: buffer))
        }
        return frames
    }
}
