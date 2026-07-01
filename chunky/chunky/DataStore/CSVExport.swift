// chunky/chunky/DataStore/CSVExport.swift
import Foundation

nonisolated enum CSVExport {
    private static func field(_ s: String) -> String {
        (s.contains(",") || s.contains("\"") || s.contains("\n"))
            ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
            : s
    }
    private static func num(_ x: Double) -> String { String(Int(x.rounded())) }

    static func shots(_ records: [ShotRecord], units: Units) -> String {
        let u = units.abbreviation
        var lines = ["timestamp,club,carry_\(u),ball_speed_mph,launch_deg,spin_rpm,spin_source,confidence,excluded"]
        for r in records {
            let cols = [
                ISO8601DateFormatter().string(from: r.timestamp),
                field(r.clubName),
                num(units.carry(fromMeters: r.carryMeters)),
                num(Conversions.msToMPH(r.ballSpeedMS)),
                num(r.launchAngleDeg),
                num(r.spinRPM),
                r.spinSource.rawValue,
                r.confidence.rawValue,
                r.isExcludedFromAverages ? "yes" : "no",
            ]
            lines.append(cols.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func clubAverages(_ rows: [(clubName: String, aggregates: ClubAggregates)], units: Units) -> String {
        let u = units.abbreviation
        var lines = ["club,shots,mean_carry_\(u),median_carry_\(u),stddev_\(u),min_\(u),max_\(u),mean_ball_mph,mean_launch_deg,mean_spin_rpm"]
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
                num(a.meanLaunchAngleDeg),
                num(a.meanSpinRPM),
            ]
            lines.append(cols.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
