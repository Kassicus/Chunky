// chunky/chunky/CaptureKit/Core/CaptureFormat.swift
import Foundation

/// A device-agnostic description of a capture format, so selection logic is
/// testable without AVFoundation. The device layer maps AVCaptureDevice.Format
/// to this and back.
nonisolated struct CaptureFormatDescriptor: Equatable, Sendable {
    let width: Int
    let height: Int
    let maxFrameRate: Double
}

nonisolated enum CaptureFormatSelector {
    static func best(from formats: [CaptureFormatDescriptor],
                     targetFPS: Double = 240,
                     targetHeight: Int = 1080) -> CaptureFormatDescriptor? {
        let byFps: (CaptureFormatDescriptor, CaptureFormatDescriptor) -> Bool = { $0.maxFrameRate < $1.maxFrameRate }
        let atTargetFps = formats.filter { $0.height == targetHeight && $0.maxFrameRate >= targetFPS }
        if let best = atTargetFps.max(by: byFps) { return best }
        let atHeight = formats.filter { $0.height == targetHeight }
        if let best = atHeight.max(by: byFps) { return best }
        return formats.max(by: byFps)
    }
}
