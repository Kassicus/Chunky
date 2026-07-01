// chunky/chunky/Features/ShotStoreEnvironment.swift
import SwiftUI

private struct ShotStoreKey: EnvironmentKey {
    static let defaultValue: ShotStore? = nil
}

extension EnvironmentValues {
    var shotStore: ShotStore? {
        get { self[ShotStoreKey.self] }
        set { self[ShotStoreKey.self] = newValue }
    }
}
