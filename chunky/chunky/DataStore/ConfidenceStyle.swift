// chunky/chunky/DataStore/ConfidenceStyle.swift
import Foundation

/// Maps a confidence level to a short display label and a palette token name.
/// Kept UI-framework-free so it is unit-testable; Theme turns the token into a Color.
nonisolated enum ConfidenceStyle {
    static func label(_ c: ConfidenceLevel) -> String {
        switch c { case .high: "High"; case .medium: "Med"; case .low: "Low" }
    }
    static func token(_ c: ConfidenceLevel) -> String {
        switch c { case .high: "chalk"; case .medium: "amber"; case .low: "mist" }
    }
}
