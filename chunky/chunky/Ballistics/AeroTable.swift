// chunky/chunky/Ballistics/AeroTable.swift
import Foundation

/// Drag (Cd) and lift (Cl) coefficients as functions of spin ratio S = ω·r/|v|.
/// Values are linearly interpolated from a table sorted ascending by spin ratio;
/// queries outside the table clamp to the nearest endpoint.
nonisolated struct AeroTable {
    struct Entry: Codable, Equatable {
        let spinRatio: Double
        let cd: Double
        let cl: Double
    }

    let entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries.sorted { $0.spinRatio < $1.spinRatio }
    }

    init(data: Data) throws {
        let decoded = try JSONDecoder().decode([Entry].self, from: data)
        self.init(entries: decoded)
    }

    func coefficients(spinRatio S: Double) -> (cd: Double, cl: Double) {
        guard let first = entries.first, let last = entries.last else {
            return (0.25, 0.0)
        }
        if S <= first.spinRatio { return (first.cd, first.cl) }
        if S >= last.spinRatio { return (last.cd, last.cl) }
        for i in 1..<entries.count {
            let hi = entries[i]
            if S <= hi.spinRatio {
                let lo = entries[i - 1]
                let t = (S - lo.spinRatio) / (hi.spinRatio - lo.spinRatio)
                return (lo.cd + t * (hi.cd - lo.cd), lo.cl + t * (hi.cl - lo.cl))
            }
        }
        return (last.cd, last.cl)
    }

    /// Default table (approximate published golf-ball wind-tunnel values, spec §3.2).
    /// This is the calibration surface validated by BallisticsReferenceCarryTests.
    static let standard = AeroTable(entries: [
        Entry(spinRatio: 0.00, cd: 0.250, cl: 0.000),
        Entry(spinRatio: 0.05, cd: 0.255, cl: 0.100),
        Entry(spinRatio: 0.10, cd: 0.260, cl: 0.160),
        Entry(spinRatio: 0.15, cd: 0.270, cl: 0.210),
        Entry(spinRatio: 0.20, cd: 0.280, cl: 0.240),
        Entry(spinRatio: 0.25, cd: 0.290, cl: 0.260),
        Entry(spinRatio: 0.30, cd: 0.300, cl: 0.280),
        Entry(spinRatio: 0.40, cd: 0.320, cl: 0.310),
        Entry(spinRatio: 0.50, cd: 0.340, cl: 0.330),
    ])
}
