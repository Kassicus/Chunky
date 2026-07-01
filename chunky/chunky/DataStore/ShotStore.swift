// chunky/chunky/DataStore/ShotStore.swift
import Foundation
import SwiftData

@MainActor
struct ShotStore {
    let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func record(from shot: Shot) -> ShotRecord {
        ShotRecord(
            id: shot.id, timestamp: shot.timestamp, clubID: shot.club?.id,
            clubName: shot.club?.name ?? "—", carryMeters: shot.carryMeters,
            ballSpeedMS: shot.ballSpeedMS, launchAngleDeg: shot.launchAngleDeg,
            spinRPM: shot.spinRPM, spinSource: shot.spinSource,
            clubSpeedMS: shot.clubSpeedMS, smashFactor: shot.smashFactor,
            confidence: shot.confidence, isExcludedFromAverages: shot.isExcludedFromAverages)
    }

    @discardableResult
    func saveShot(_ result: ShotResult, to club: Club, session: Session?, rawTrackJSON: String?) -> Shot {
        let shot = Shot(
            timestamp: Date(), ballSpeedMS: result.ballSpeedMS, launchAngleDeg: result.launchAngleDeg,
            azimuthDeg: result.azimuthDeg, spinRPM: result.spinRPM, spinSource: result.spinSource,
            spinAxisTiltDeg: result.spinAxisTiltDeg, carryMeters: result.carryMeters,
            confidence: result.confidence, rawTrackJSON: rawTrackJSON)
        shot.club = club
        shot.session = session
        context.insert(shot)
        try? context.save()
        return shot
    }

    func setExcluded(_ shot: Shot, _ excluded: Bool) {
        shot.isExcludedFromAverages = excluded
        try? context.save()
    }

    func deleteShots(_ shots: [Shot]) {
        for s in shots { context.delete(s) }
        try? context.save()
    }

    @discardableResult
    func addClub(name: String, type: ClubType, modeledSpinRPM: Double) -> Club {
        let maxOrder = (try? context.fetch(FetchDescriptor<Club>()))?.map(\.order).max() ?? -1
        let club = Club(name: name, type: type, order: maxOrder + 1, modeledSpinRPM: modeledSpinRPM)
        context.insert(club)
        try? context.save()
        return club
    }

    func renameClub(_ club: Club, to name: String) {
        club.name = name
        try? context.save()
    }

    func reorderClubs(_ ordered: [Club]) {
        for (index, club) in ordered.enumerated() { club.order = index }
        try? context.save()
    }

    func removeClub(_ club: Club) {
        if club.shots.isEmpty {
            context.delete(club)
        } else {
            club.isArchived = true
        }
        try? context.save()
    }
}
