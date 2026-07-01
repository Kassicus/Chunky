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

    private static let rungHeight: CGFloat = 30

    private var maxCarry: Double { rungs.first?.carryMeters ?? 1 }

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(rungs.enumerated()), id: \.offset) { idx, rung in
                    let isLongest = idx == 0
                    let fraction = rung.carryMeters / max(maxCarry, 1)
                    let barWidth = availableWidth * CGFloat(fraction)

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
                        Rectangle()
                            .fill(isLongest ? Theme.optic : Theme.turfLine)
                            .frame(width: barWidth, height: isLongest ? 3 : 1)
                    }
                }
            }
        }
        .frame(height: CGFloat(max(rungs.count, 1)) * Self.rungHeight)
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
