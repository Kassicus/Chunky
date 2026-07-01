// chunky/chunky/DataStore/ShotRecord.swift
import Foundation

/// Framework-free value projection of a persisted Shot, so filtering, aggregation,
/// and CSV export are unit-testable without SwiftData.
nonisolated struct ShotRecord: Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let clubID: UUID?
    let clubName: String
    let carryMeters: Double
    let ballSpeedMS: Double
    let launchAngleDeg: Double
    let spinRPM: Double
    let spinSource: SpinSource
    let clubSpeedMS: Double?
    let smashFactor: Double?
    let confidence: ConfidenceLevel
    let isExcludedFromAverages: Bool
}
