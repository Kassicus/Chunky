// chunky/chunky/Features/Settings/AppSettings.swift
import Foundation
import Observation

/// App-wide user preferences (units, environment, lens default, debug overlay),
/// persisted to `UserDefaults`. Injected into the SwiftUI environment.
@Observable
@MainActor
final class AppSettings {
    private let defaults: UserDefaults

    private enum Key {
        static let units = "settings.units"
        static let temperatureC = "settings.temperatureC"
        static let altitudeM = "settings.altitudeM"
        static let humidity = "settings.humidity"
        static let lens = "settings.lens"
        static let debugOverlay = "settings.debugOverlay"
    }

    // MARK: - Stored properties (enables @Observable change-tracking)

    var units: Units {
        didSet { defaults.set(units.rawValue, forKey: Key.units) }
    }

    var temperatureC: Double {
        didSet { defaults.set(temperatureC, forKey: Key.temperatureC) }
    }

    var altitudeM: Double {
        didSet { defaults.set(altitudeM, forKey: Key.altitudeM) }
    }

    var humidity: Double {
        didSet { defaults.set(humidity, forKey: Key.humidity) }
    }

    var lens: CameraLens {
        didSet { defaults.set(lens.rawValue, forKey: Key.lens) }
    }

    var debugOverlayEnabled: Bool {
        didSet { defaults.set(debugOverlayEnabled, forKey: Key.debugOverlay) }
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Seed from persisted UserDefaults, falling back to design defaults.
        units = Units(rawValue: defaults.string(forKey: Key.units) ?? "") ?? .yards
        temperatureC = (defaults.object(forKey: Key.temperatureC) as? Double) ?? 15
        altitudeM = (defaults.object(forKey: Key.altitudeM) as? Double) ?? 0
        humidity = (defaults.object(forKey: Key.humidity) as? Double) ?? 0
        lens = CameraLens(rawValue: defaults.string(forKey: Key.lens) ?? "") ?? .telephoto
        debugOverlayEnabled = defaults.object(forKey: Key.debugOverlay) != nil
            ? defaults.bool(forKey: Key.debugOverlay)
            : false
    }

    // MARK: - Derived

    var atmosphere: Atmosphere {
        Atmosphere(temperatureC: temperatureC, altitudeM: altitudeM, relativeHumidity: humidity)
    }

    var captureLens: CaptureConfiguration.Lens {
        lens == .telephoto ? .telephoto : .wide
    }
}
