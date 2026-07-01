// chunky/chunky/Metrics/ShotResult.swift
import Foundation

nonisolated enum SpinSource: String, Equatable {
    case measured
    case modeled
}

nonisolated enum ConfidenceLevel: String, Equatable {
    case high
    case medium
    case low
}

/// Measured spin input from SpinCore (Plan 7). Absent/low-confidence → Metrics
/// falls back to modeled spin.
nonisolated struct MeasuredSpin: Equatable {
    let rpm: Double
    let axisTiltDeg: Double
    let confidence: Double

    init(rpm: Double, axisTiltDeg: Double = 0, confidence: Double) {
        self.rpm = rpm
        self.axisTiltDeg = axisTiltDeg
        self.confidence = confidence
    }
}

/// Computed per-shot result (value type; distinct from the SwiftData `Shot`
/// model in Plan 3). Holds the metrics, confidence, and fit-quality summaries
/// (`fitRmsResidualMeters`, `usedFrameCount`). The raw track needed to
/// re-compute carry later (spec §9/§10) is NOT stored here — the caller/DataStore
/// persists it, since it already holds the original `track`/`calibration`/`atmosphere`
/// inputs it passed to `Metrics.computeShot`.
nonisolated struct ShotResult: Equatable {
    let ballSpeedMS: Double
    let launchAngleDeg: Double
    let azimuthDeg: Double
    let spinRPM: Double
    let spinSource: SpinSource
    let spinAxisTiltDeg: Double
    let carryMeters: Double
    let confidence: ConfidenceLevel
    let fitRmsResidualMeters: Double
    let usedFrameCount: Int

    var ballSpeedMPH: Double { Conversions.msToMPH(ballSpeedMS) }
    var carryYards: Double { Conversions.metersToYards(carryMeters) }
}
