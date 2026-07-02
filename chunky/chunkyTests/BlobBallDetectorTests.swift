// chunky/chunkyTests/BlobBallDetectorTests.swift
import XCTest
@testable import chunky

final class BlobBallDetectorTests: XCTestCase {
    // Rasterize a filled bright disk of radius r at (cx,cy) on a dark field.
    private func disk(w: Int, h: Int, cx: Double, cy: Double, r: Double) -> GrayImage {
        var p = [UInt8](repeating: 0, count: w*h)
        for y in 0..<h { for x in 0..<w {
            let dx = Double(x)-cx, dy = Double(y)-cy
            if dx*dx+dy*dy <= r*r { p[y*w+x] = 255 }
        } }
        return GrayImage(width: w, height: h, pixels: p)
    }

    func testDetectsDiskCenterAndRadius() {
        let det = BlobBallDetector()
        let cands = det.detect(in: disk(w: 60, h: 60, cx: 30, cy: 25, r: 8))
        XCTAssertGreaterThanOrEqual(cands.count, 1)
        let best = cands.first!
        XCTAssertEqual(best.center.x, 30, accuracy: 1.0)
        XCTAssertEqual(best.center.y, 25, accuracy: 1.0)
        XCTAssertEqual(best.radiusPx, 8, accuracy: 1.5)   // area-based radius ≈ r
        XCTAssertGreaterThan(best.confidence, 0.6)
    }

    func testRejectsThinLine() {
        // A 1px-tall bright bar is not round → filtered out or very low confidence.
        var p = [UInt8](repeating: 0, count: 60*60)
        for x in 5..<55 { p[30*60 + x] = 255 }
        let cands = BlobBallDetector().detect(in: GrayImage(width: 60, height: 60, pixels: p))
        XCTAssertTrue(cands.allSatisfy { $0.confidence < 0.6 } || cands.isEmpty)
    }

    func testTwoBallsGiveTwoCandidates() {
        var img = disk(w: 80, h: 40, cx: 20, cy: 20, r: 6).pixels
        let img2 = disk(w: 80, h: 40, cx: 60, cy: 20, r: 6).pixels
        for i in 0..<img.count { img[i] = max(img[i], img2[i]) }
        let cands = BlobBallDetector().detect(in: GrayImage(width: 80, height: 40, pixels: img))
        XCTAssertEqual(cands.filter { $0.confidence >= 0.6 }.count, 2)
    }
}
