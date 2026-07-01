import Foundation

nonisolated enum Conversions {
    static let mphPerMS = 2.2369362920544
    static let metersPerYard = 0.9144

    static func mphToMS(_ mph: Double) -> Double { mph / mphPerMS }
    static func msToMPH(_ ms: Double) -> Double { ms * mphPerMS }
    static func yardsToMeters(_ yd: Double) -> Double { yd * metersPerYard }
    static func metersToYards(_ m: Double) -> Double { m / metersPerYard }
    static func rpmToRadPerSec(_ rpm: Double) -> Double { rpm * 2 * .pi / 60 }
    static func degToRad(_ deg: Double) -> Double { deg * .pi / 180 }
}
