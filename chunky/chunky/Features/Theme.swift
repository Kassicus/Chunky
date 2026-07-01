// chunky/chunky/Features/Theme.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let c = HexColor.rgba(hex) ?? (1, 0, 1, 1) // magenta = missing token, caught in preview
        self = Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}

enum Theme {
    static let rangeDusk = Color(hex: "#0C1E16")
    static let turf = Color(hex: "#16382A")
    static let turfLine = Color(hex: "#23503C")
    static let chalk = Color(hex: "#F1ECDB")
    static let mist = Color(hex: "#8AA396")
    static let optic = Color(hex: "#DDF24A")
    static let flag = Color(hex: "#E4572E")
    static let amber = Color(hex: "#E8B84B")

    static func confidenceColor(_ c: ConfidenceLevel) -> Color {
        switch ConfidenceStyle.token(c) {
        case "chalk": chalk
        case "amber": amber
        default: mist
        }
    }

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold).monospacedDigit() }
    static let eyebrow = Font.system(.caption, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        Text("164").font(Theme.display(48)).foregroundStyle(Theme.optic)
        Text("CARRY").font(Theme.eyebrow).kerning(1.5).foregroundStyle(Theme.mist)
        ForEach([ConfidenceLevel.high, .medium, .low], id: \.self) { c in
            Text(ConfidenceStyle.label(c)).font(Theme.number(15)).foregroundStyle(Theme.confidenceColor(c))
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.rangeDusk)
}
