// chunky/chunky/CaptureKit/Core/Timestamped.swift
import Foundation

/// A value stamped with a capture time in seconds.
nonisolated struct Timestamped<Value> {
    let timeSeconds: Double
    let value: Value
}

extension Timestamped: Sendable where Value: Sendable {}
extension Timestamped: Equatable where Value: Equatable {}

/// Extracts the impact frame window from a time-ordered buffer.
nonisolated enum ImpactWindow {
    static func slice<T>(_ frames: [Timestamped<T>],
                         impactTime: Double,
                         preRoll: Double = 0.040,
                         postRoll: Double = 0.120) -> [Timestamped<T>] {
        let lower = impactTime - preRoll
        let upper = impactTime + postRoll
        return frames.filter { $0.timeSeconds >= lower && $0.timeSeconds <= upper }
    }
}
