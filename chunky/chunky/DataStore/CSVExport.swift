// chunky/chunky/DataStore/CSVExport.swift
import Foundation

nonisolated enum CSVExport {
    nonisolated(unsafe) private static let isoFormatter = ISO8601DateFormatter()

    private static func field(_ s: String) -> String {
        (s.contains(",") || s.contains("\"") || s.contains("\n"))
            ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
            : s
    }
    /// Whole-number format for integer-valued quantities (carry, spin, speed).
    private static func num(_ x: Double) -> String { String(Int(x.rounded())) }
    /// One-decimal format for angles.
    private static func dec1(_ x: Double) -> String { String(format: "%.1f", x) }
    /// Two-decimal format for dimensionless ratios (smash factor).
    private static func dec2(_ x: Double) -> String { String(format: "%.2f", x) }

    static func shots(_ records: [ShotRecord], units: Units) -> String {
        let u = units.abbreviation
        var lines = ["timestamp,club,carry_\(u),ball_speed_mph,launch_deg,spin_rpm,spin_source,confidence,excluded,club_speed_mph,smash"]
        for r in records {
            let cols = [
                isoFormatter.string(from: r.timestamp),
                field(r.clubName),
                num(units.carry(fromMeters: r.carryMeters)),
                num(Conversions.msToMPH(r.ballSpeedMS)),
                dec1(r.launchAngleDeg),
                num(r.spinRPM),
                r.spinSource.rawValue,
                r.confidence.rawValue,
                r.isExcludedFromAverages ? "yes" : "no",
                r.clubSpeedMS.map { num(Conversions.msToMPH($0)) } ?? "",
                r.smashFactor.map { dec2($0) } ?? "",
            ]
            lines.append(cols.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func clubAverages(_ rows: [(clubName: String, aggregates: ClubAggregates)], units: Units) -> String {
        let u = units.abbreviation
        var lines = ["club,shots,mean_carry_\(u),median_carry_\(u),stddev_\(u),min_\(u),max_\(u),mean_ball_mph,mean_launch_deg,mean_spin_rpm,mean_club_speed_mph,mean_smash"]
        for row in rows {
            let a = row.aggregates
            let cols = [
                field(row.clubName),
                String(a.shotCount),
                num(units.carry(fromMeters: a.meanCarryMeters)),
                num(units.carry(fromMeters: a.medianCarryMeters)),
                num(units.carry(fromMeters: a.carryStdDevMeters)),
                num(units.carry(fromMeters: a.minCarryMeters)),
                num(units.carry(fromMeters: a.maxCarryMeters)),
                num(Conversions.msToMPH(a.meanBallSpeedMS)),
                dec1(a.meanLaunchAngleDeg),
                num(a.meanSpinRPM),
                a.meanClubSpeedMS.map { num(Conversions.msToMPH($0)) } ?? "",
                a.meanSmashFactor.map { dec2($0) } ?? "",
            ]
            lines.append(cols.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
