// chunky/chunky/CaptureKit/Device/CaptureProtocols.swift
import CoreVideo

protocol FrameReceiver: AnyObject, Sendable {
    func receiveFrame(_ pixelBuffer: CVPixelBuffer, at timeSeconds: Double)
}

enum CaptureSetupError: Error, Equatable {
    case noCamera
    case noSuitableFormat
    case configurationFailed(String)
}

enum CaptureMediaKind: Sendable, Equatable { case camera, microphone }

enum CaptureStatus: Sendable, Equatable {
    case idle
    case running
    case needsMoreLight
    case unauthorized(CaptureMediaKind)
    case failed(String)
}
