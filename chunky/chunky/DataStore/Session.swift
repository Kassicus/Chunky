// chunky/chunky/DataStore/Session.swift
import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var date: Date
    var location: String
    var lensRaw: String
    var temperatureC: Double
    var altitudeM: Double
    var humidity: Double
    var calibrationProfileId: UUID?
    @Relationship(deleteRule: .cascade, inverse: \Shot.session) var shots: [Shot] = []

    var lens: CameraLens {
        get { CameraLens(rawValue: lensRaw) ?? .telephoto }
        set { lensRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date, location: String = "", lens: CameraLens,
         temperatureC: Double, altitudeM: Double, humidity: Double,
         calibrationProfileId: UUID? = nil) {
        self.id = id
        self.date = date
        self.location = location
        self.lensRaw = lens.rawValue
        self.temperatureC = temperatureC
        self.altitudeM = altitudeM
        self.humidity = humidity
        self.calibrationProfileId = calibrationProfileId
    }
}
