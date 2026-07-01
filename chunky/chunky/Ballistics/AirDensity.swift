// chunky/chunky/Ballistics/AirDensity.swift
import Foundation

/// Air density from temperature, altitude, and humidity using the International
/// Standard Atmosphere for pressure and the ideal gas law for density.
nonisolated enum AirDensity {
    static let seaLevelPressurePa = 101325.0
    static let seaLevelTempK = 288.15
    static let lapseRateKPerM = 0.0065
    static let gravity = 9.80665
    static let molarMassDryAir = 0.0289644          // kg/mol
    static let universalGasConstant = 8.31446       // J/(mol·K)
    static let gasConstantDryAir = 287.058          // J/(kg·K)
    static let gasConstantWaterVapor = 461.495      // J/(kg·K)

    /// ISA tropospheric pressure (Pa) at altitude (m).
    static func pressure(altitudeM: Double) -> Double {
        let exponent = gravity * molarMassDryAir / (universalGasConstant * lapseRateKPerM)
        let base = 1.0 - (lapseRateKPerM * altitudeM) / seaLevelTempK
        return seaLevelPressurePa * pow(base, exponent)
    }

    /// Air density (kg/m³). `relativeHumidity` is 0…1.
    static func density(temperatureC: Double, altitudeM: Double, relativeHumidity: Double = 0) -> Double {
        let tempK = temperatureC + 273.15
        let totalPressure = pressure(altitudeM: altitudeM)
        // Tetens saturation vapor pressure (Pa).
        let satVaporPa = 610.78 * pow(10.0, (7.5 * temperatureC) / (temperatureC + 237.3))
        let vaporPa = max(0, min(1, relativeHumidity)) * satVaporPa
        let dryPa = totalPressure - vaporPa
        return dryPa / (gasConstantDryAir * tempK)
            + vaporPa / (gasConstantWaterVapor * tempK)
    }
}
