// chunky/chunky/DataStore/Stats.swift
import Foundation

nonisolated enum Stats {
    static func mean(_ xs: [Double]) -> Double? {
        xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }

    static func median(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        let s = xs.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    /// Sample (n−1) standard deviation. Requires at least two values.
    static func standardDeviation(_ xs: [Double]) -> Double? {
        guard xs.count >= 2, let m = mean(xs) else { return nil }
        let sumSq = xs.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (sumSq / Double(xs.count - 1)).squareRoot()
    }

    static func minMax(_ xs: [Double]) -> (min: Double, max: Double)? {
        guard let lo = xs.min(), let hi = xs.max() else { return nil }
        return (lo, hi)
    }
}
