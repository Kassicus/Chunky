// chunky/chunky/Ballistics/BallModel.swift
import Foundation

nonisolated struct BallModel {
    var mass: Double        // kg
    var diameter: Double    // m
    var area: Double { Double.pi * (diameter / 2) * (diameter / 2) }

    static let standard = BallModel(mass: 0.04593, diameter: 0.04267)
}
