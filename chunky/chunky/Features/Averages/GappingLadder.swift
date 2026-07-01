// chunky/chunky/Features/Averages/GappingLadder.swift
import SwiftUI

/// Vertical gapping ladder: each rung's bar width is proportional to mean carry,
/// normalized to the longest club. Pass rungs sorted descending by carryMeters.
/// The longest club's rung is highlighted in Theme.optic; all others use
/// Theme.turfLine for the bar and Theme.mist / Theme.chalk for the label text.
struct GappingLadder: View {
    /// (clubName, carryMeters) sorted descending — longest club first.
    let rungs: [(clubName: String, carryMeters: Double)]
    let units: Units

    private var maxCarry: Double { rungs.first?.carryMeters ?? 1 }

    var body: some View {
        // VStack (not GeometryReader) as the outer container so height is natural.
        // Each bar gets its own GeometryReader clamped to the bar's stroke height,
        // giving the available width without inflating vertical space.
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rungs.enumerated()), id: \.element.clubName) { idx, rung in
                let isLongest = idx == 0
                let fraction = CGFloat(rung.carryMeters / max(maxCarry, 1))
                let barHeight: CGFloat = isLongest ? 3 : 1

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(rung.clubName)
                            .font(Theme.eyebrow)
                            .kerning(0.8)
                            .foregroundStyle(isLongest ? Theme.optic : Theme.mist)
                        Spacer()
                        Text(units.formattedCarry(fromMeters: rung.carryMeters))
                            .font(Theme.number(12))
                            .foregroundStyle(isLongest ? Theme.optic : Theme.chalk)
                    }
                    // GeometryReader is constrained to the bar's stroke height so
                    // it doesn't add unwanted vertical space; width drives bar length.
                    GeometryReader { geo in
                        Rectangle()
                            .fill(isLongest ? Theme.optic : Theme.turfLine)
                            .frame(width: geo.size.width * fraction, height: barHeight)
                    }
                    .frame(height: barHeight)
                }
            }
        }
    }
}

#Preview("Gapping Ladder") {
    GappingLadder(
        rungs: [
            (clubName: "Driver", carryMeters: 219),
            (clubName: "3-Wood", carryMeters: 196),
            (clubName: "5-Iron", carryMeters: 172),
            (clubName: "7-Iron", carryMeters: 155),
            (clubName: "PW", carryMeters: 131),
        ],
        units: .yards
    )
    .padding(20)
    .background(Theme.rangeDusk)
}
