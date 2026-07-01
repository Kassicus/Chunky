// chunky/chunky/DataStore/Units.swift
import Foundation

nonisolated enum Units: String, CaseIterable, Codable {
    case yards
    case meters

    var abbreviation: String { self == .yards ? "yd" : "m" }

    func carry(fromMeters meters: Double) -> Double {
        self == .yards ? Conversions.metersToYards(meters) : meters
    }

    func formattedCarry(fromMeters meters: Double) -> String {
        "\(Int(carry(fromMeters: meters).rounded())) \(abbreviation)"
    }
}
