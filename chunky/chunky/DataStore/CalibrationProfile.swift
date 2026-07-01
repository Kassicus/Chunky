// chunky/chunky/DataStore/CalibrationProfile.swift
import Foundation
import SwiftData

@Model
final class CalibrationProfile {
    @Attribute(.unique) var id: UUID
    var lensRaw: String
    var pxPerMeter: Double
    var imageUpX: Double
    var imageUpY: Double
    var cameraDistanceM: Double
    var createdAt: Date

    var lens: CameraLens {
        get { CameraLens(rawValue: lensRaw) ?? .telephoto }
        set { lensRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), lens: CameraLens, pxPerMeter: Double, imageUpX: Double,
         imageUpY: Double, cameraDistanceM: Double, createdAt: Date = Date()) {
        self.id = id
        self.lensRaw = lens.rawValue
        self.pxPerMeter = pxPerMeter
        self.imageUpX = imageUpX
        self.imageUpY = imageUpY
        self.cameraDistanceM = cameraDistanceM
        self.createdAt = createdAt
    }
}
