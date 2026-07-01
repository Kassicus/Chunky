// chunky/chunkyTests/ImpactWindowTests.swift
import XCTest
@testable import chunky

final class ImpactWindowTests: XCTestCase {
    private func frames(count: Int, fps: Double) -> [Timestamped<Int>] {
        (0..<count).map { Timestamped(timeSeconds: Double($0) / fps, value: $0) }
    }

    func testSliceAroundImpact() {
        let fs = frames(count: 240, fps: 240) // 1 second at 240 fps, t = 0…0.9958
        let win = ImpactWindow.slice(fs, impactTime: 0.5) // [0.46, 0.62]
        XCTAssertEqual(win.first!.timeSeconds, 0.46, accuracy: 1.0 / 240 + 1e-9)
        XCTAssertEqual(win.last!.timeSeconds, 0.62, accuracy: 1.0 / 240 + 1e-9)
        // ~0.160 s * 240 fps ≈ 38–39 frames
        XCTAssertGreaterThanOrEqual(win.count, 37)
        XCTAssertLessThanOrEqual(win.count, 40)
    }

    func testCustomRollBounds() {
        let fs = frames(count: 100, fps: 100)
        let win = ImpactWindow.slice(fs, impactTime: 0.50, preRoll: 0.10, postRoll: 0.10)
        for f in win { XCTAssertTrue(f.timeSeconds >= 0.40 - 1e-9 && f.timeSeconds <= 0.60 + 1e-9) }
        XCTAssertTrue(win.contains { $0.value == 50 })
    }

    func testEmptyWhenNoFramesInRange() {
        let fs = frames(count: 10, fps: 10) // 0…0.9
        XCTAssertTrue(ImpactWindow.slice(fs, impactTime: 5.0).isEmpty)
    }
}
