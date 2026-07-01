// chunky/chunky/DataStore/ShotFilter.swift
import Foundation

nonisolated struct ShotFilter {
    var clubID: UUID?
    var confidence: ConfidenceLevel?
    var includeExcluded: Bool
    var dateRange: ClosedRange<Date>?

    init(clubID: UUID? = nil, confidence: ConfidenceLevel? = nil,
         includeExcluded: Bool = true, dateRange: ClosedRange<Date>? = nil) {
        self.clubID = clubID
        self.confidence = confidence
        self.includeExcluded = includeExcluded
        self.dateRange = dateRange
    }

    func apply(to records: [ShotRecord]) -> [ShotRecord] {
        records.filter { r in
            if let clubID, r.clubID != clubID { return false }
            if let confidence, r.confidence != confidence { return false }
            if !includeExcluded && r.isExcludedFromAverages { return false }
            if let dateRange, !dateRange.contains(r.timestamp) { return false }
            return true
        }
    }
}

nonisolated enum ShotSort {
    case newest, oldest, longestCarry, shortestCarry

    func sort(_ records: [ShotRecord]) -> [ShotRecord] {
        switch self {
        case .newest: records.sorted { $0.timestamp > $1.timestamp }
        case .oldest: records.sorted { $0.timestamp < $1.timestamp }
        case .longestCarry: records.sorted { $0.carryMeters > $1.carryMeters }
        case .shortestCarry: records.sorted { $0.carryMeters < $1.carryMeters }
        }
    }
}
