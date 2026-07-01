// chunky/chunky/CaptureKit/Core/CaptureConfiguration.swift
import Foundation

nonisolated struct CaptureConfiguration: Equatable, Sendable {
    enum Lens: String, Sendable, CaseIterable { case telephoto, wide }

    var lens: Lens = .telephoto
    var targetFPS: Double = 240
    var resolutionHeight: Int = 1080
    var shutterSeconds: Double = 1.0 / 2000
    var ringBufferSeconds: Double = 0.5
    var preRollSeconds: Double = 0.040
    var postRollSeconds: Double = 0.120

    var ringBufferCapacity: Int { Int((ringBufferSeconds * targetFPS).rounded()) }

    static let `default` = CaptureConfiguration()
}
