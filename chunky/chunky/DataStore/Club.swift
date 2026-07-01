// chunky/chunky/DataStore/Club.swift
import Foundation
import SwiftData

@Model
final class Club {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var order: Int
    var notes: String
    var isArchived: Bool
    var modeledSpinRPM: Double
    @Relationship(deleteRule: .nullify, inverse: \Shot.club) var shots: [Shot] = []

    var type: ClubType {
        get { ClubType(rawValue: typeRaw) ?? .iron }
        set { typeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), name: String, type: ClubType, order: Int,
         notes: String = "", isArchived: Bool = false, modeledSpinRPM: Double) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.order = order
        self.notes = notes
        self.isArchived = isArchived
        self.modeledSpinRPM = modeledSpinRPM
    }
}
