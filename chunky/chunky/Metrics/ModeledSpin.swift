// chunky/chunky/Metrics/ModeledSpin.swift
import Foundation

/// Per-club modeled backspin (rpm), used when measured spin is unavailable or
/// low-confidence (spec §3.3). MVP: a per-club base value; v0/θ refinement is a
/// future enhancement. `.standard` is the in-code default; `modeled_spin.json`
/// ships the same values for later runtime override.
nonisolated struct ModeledSpinTable {
    struct Entry: Codable, Equatable {
        let club: String
        let baseRPM: Double
    }

    let entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries
    }

    init(data: Data) throws {
        self.init(entries: try JSONDecoder().decode([Entry].self, from: data))
    }

    /// Modeled backspin for a club key; nil if the club is unknown.
    func spinRPM(forClub club: String) -> Double? {
        entries.first { $0.club == club }?.baseRPM
    }

    static let standard = ModeledSpinTable(entries: [
        Entry(club: "Driver", baseRPM: 2600),
        Entry(club: "3-Wood", baseRPM: 3400),
        Entry(club: "5-Iron", baseRPM: 5000),
        Entry(club: "7-Iron", baseRPM: 6500),
        Entry(club: "9-Iron", baseRPM: 8000),
        Entry(club: "PW", baseRPM: 9000),
    ])
}
