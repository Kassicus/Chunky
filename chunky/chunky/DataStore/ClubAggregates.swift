// chunky/chunky/DataStore/ClubAggregates.swift
import Foundation

nonisolated struct ClubAggregates: Equatable {
    let shotCount: Int
    let meanCarryMeters: Double
    let medianCarryMeters: Double
    let carryStdDevMeters: Double
    let minCarryMeters: Double
    let maxCarryMeters: Double
    let meanBallSpeedMS: Double
    let meanLaunchAngleDeg: Double
    let meanSpinRPM: Double
    let meanClubSpeedMS: Double?
    let meanSmashFactor: Double?

    /// Aggregate over the non-excluded records. Returns nil if none remain.
    static func compute(from records: [ShotRecord]) -> ClubAggregates? {
        let kept = records.filter { !$0.isExcludedFromAverages }
        guard !kept.isEmpty else { return nil }
        let carries = kept.map(\.carryMeters)
        let clubSpeeds = kept.compactMap(\.clubSpeedMS)
        let smashes = kept.compactMap(\.smashFactor)
        return ClubAggregates(
            shotCount: kept.count,
            meanCarryMeters: Stats.mean(carries)!,
            medianCarryMeters: Stats.median(carries)!,
            carryStdDevMeters: Stats.standardDeviation(carries) ?? 0,
            minCarryMeters: Stats.minMax(carries)!.min,
            maxCarryMeters: Stats.minMax(carries)!.max,
            meanBallSpeedMS: Stats.mean(kept.map(\.ballSpeedMS))!,
            meanLaunchAngleDeg: Stats.mean(kept.map(\.launchAngleDeg))!,
            meanSpinRPM: Stats.mean(kept.map(\.spinRPM))!,
            meanClubSpeedMS: clubSpeeds.isEmpty ? nil : Stats.mean(clubSpeeds),
            meanSmashFactor: smashes.isEmpty ? nil : Stats.mean(smashes)
        )
    }
}
