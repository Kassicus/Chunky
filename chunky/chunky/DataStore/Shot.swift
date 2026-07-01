// chunky/chunky/DataStore/Shot.swift
import Foundation
import SwiftData

@Model
final class Shot {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var ballSpeedMS: Double
    var launchAngleDeg: Double
    var azimuthDeg: Double
    var spinRPM: Double
    var spinSourceRaw: String
    var spinAxisTiltDeg: Double
    var clubSpeedMS: Double?
    var smashFactor: Double?
    var carryMeters: Double
    var confidenceRaw: String
    var isExcludedFromAverages: Bool
    var rawTrackJSON: String?
    var videoClipURL: URL?
    var club: Club?
    var session: Session?

    var spinSource: SpinSource {
        get { SpinSource(rawValue: spinSourceRaw) ?? .modeled }
        set { spinSourceRaw = newValue.rawValue }
    }
    var confidence: ConfidenceLevel {
        get { ConfidenceLevel(rawValue: confidenceRaw) ?? .low }
        set { confidenceRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), timestamp: Date, ballSpeedMS: Double, launchAngleDeg: Double,
         azimuthDeg: Double, spinRPM: Double, spinSource: SpinSource, spinAxisTiltDeg: Double,
         clubSpeedMS: Double? = nil, smashFactor: Double? = nil, carryMeters: Double,
         confidence: ConfidenceLevel, isExcludedFromAverages: Bool = false,
         rawTrackJSON: String? = nil, videoClipURL: URL? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.ballSpeedMS = ballSpeedMS
        self.launchAngleDeg = launchAngleDeg
        self.azimuthDeg = azimuthDeg
        self.spinRPM = spinRPM
        self.spinSourceRaw = spinSource.rawValue
        self.spinAxisTiltDeg = spinAxisTiltDeg
        self.clubSpeedMS = clubSpeedMS
        self.smashFactor = smashFactor
        self.carryMeters = carryMeters
        self.confidenceRaw = confidence.rawValue
        self.isExcludedFromAverages = isExcludedFromAverages
        self.rawTrackJSON = rawTrackJSON
        self.videoClipURL = videoClipURL
    }
}
