// chunky/chunky/DataStore/ClubType.swift
import Foundation

nonisolated enum ClubType: String, Codable, CaseIterable, Sendable {
    case driver, wood, hybrid, iron, wedge, putter
}

nonisolated enum CameraLens: String, Codable, CaseIterable, Sendable {
    case telephoto, wide
}
