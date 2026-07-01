// chunky/chunkyTests/CaptureFormatTests.swift
import XCTest
@testable import chunky

final class CaptureFormatTests: XCTestCase {
    private let formats = [
        CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 60),
        CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 240),
        CaptureFormatDescriptor(width: 3840, height: 2160, maxFrameRate: 120),
        CaptureFormatDescriptor(width: 1280, height: 720, maxFrameRate: 240),
    ]

    func testPrefers240At1080() {
        let best = CaptureFormatSelector.best(from: formats)!
        XCTAssertEqual(best, CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 240))
    }

    func testFallsBackToHighestFpsAt1080WhenNoTargetFps() {
        let f = [CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 120),
                 CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 60)]
        XCTAssertEqual(CaptureFormatSelector.best(from: f)!.maxFrameRate, 120)
    }

    func testFallsBackToHighestFpsOverallWhenNo1080() {
        let f = [CaptureFormatDescriptor(width: 1280, height: 720, maxFrameRate: 240),
                 CaptureFormatDescriptor(width: 3840, height: 2160, maxFrameRate: 120)]
        XCTAssertEqual(CaptureFormatSelector.best(from: f)!.height, 720)
    }

    func testNilOnEmpty() {
        XCTAssertNil(CaptureFormatSelector.best(from: []))
    }
}
