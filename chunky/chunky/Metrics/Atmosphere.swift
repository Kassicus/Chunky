// chunky/chunky/Metrics/Atmosphere.swift
import Foundation

/// Atmospheric inputs for the ballistics air-density term.
nonisolated struct Atmosphere {
    let temperatureC: Double
    let altitudeM: Double
    let relativeHumidity: Double

    init(temperatureC: Double = 15, altitudeM: Double = 0, relativeHumidity: Double = 0) {
        self.temperatureC = temperatureC
        self.altitudeM = altitudeM
        self.relativeHumidity = relativeHumidity
    }

    var airDensityKgM3: Double {
        AirDensity.density(temperatureC: temperatureC, altitudeM: altitudeM, relativeHumidity: relativeHumidity)
    }
}
