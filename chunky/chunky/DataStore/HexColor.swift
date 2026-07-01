// chunky/chunky/DataStore/HexColor.swift
import Foundation

nonisolated enum HexColor {
    static func rgba(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double)? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        guard let value = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        let r = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255.0
        let g = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255.0
        let b = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255.0
        let a = hasAlpha ? Double(value & 0xFF) / 255.0 : 1.0
        return (r, g, b, a)
    }
}
