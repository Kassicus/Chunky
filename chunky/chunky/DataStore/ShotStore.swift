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

    /// Persists a new shot and returns it. Throws on SwiftData save failure so callers
    /// can surface errors rather than silently dropping data.
    @discardableResult
    func saveShot(_ result: ShotResult, to club: Club, session: Session?, rawTrackJSON: String?) throws -> Shot {
        let shot = Shot(
            timestamp: Date(), ballSpeedMS: result.ballSpeedMS, launchAngleDeg: result.launchAngleDeg,
            azimuthDeg: result.azimuthDeg, spinRPM: result.spinRPM, spinSource: result.spinSource,
            spinAxisTiltDeg: result.spinAxisTiltDeg, carryMeters: result.carryMeters,
            confidence: result.confidence, rawTrackJSON: rawTrackJSON)
        shot.club = club
        shot.session = session
        context.insert(shot)
        try context.save()
        return shot
    }

    // MARK: - Mutating helpers
    // These use assertionFailure on save errors: visible in debug builds, silent in release,
    // so a transient persistence hiccup does not crash the production app.

    func setExcluded(_ shot: Shot, _ excluded: Bool) {
        shot.isExcludedFromAverages = excluded
        do { try context.save() } catch { assertionFailure("ShotStore.setExcluded save failed: \(error)") }
    }

    func deleteShots(_ shots: [Shot]) {
        for s in shots { context.delete(s) }
        do { try context.save() } catch { assertionFailure("ShotStore.deleteShots save failed: \(error)") }
    }

    @discardableResult
    func addClub(name: String, type: ClubType, modeledSpinRPM: Double) -> Club {
        let maxOrder = (try? context.fetch(FetchDescriptor<Club>()))?.map(\.order).max() ?? -1
        let club = Club(name: name, type: type, order: maxOrder + 1, modeledSpinRPM: modeledSpinRPM)
        context.insert(club)
        do { try context.save() } catch { assertionFailure("ShotStore.addClub save failed: \(error)") }
        return club
    }

    func renameClub(_ club: Club, to name: String) {
        club.name = name
        do { try context.save() } catch { assertionFailure("ShotStore.renameClub save failed: \(error)") }
    }

    func reorderClubs(_ ordered: [Club]) {
        for (index, club) in ordered.enumerated() { club.order = index }
        do { try context.save() } catch { assertionFailure("ShotStore.reorderClubs save failed: \(error)") }
    }

    func removeClub(_ club: Club) {
        if club.shots.isEmpty {
            context.delete(club)
        } else {
            club.isArchived = true
        }
        do { try context.save() } catch { assertionFailure("ShotStore.removeClub save failed: \(error)") }
    }
}
