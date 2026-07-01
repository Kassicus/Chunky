// chunky/chunky/Features/Averages/AveragesView.swift
import SwiftUI
import SwiftData

struct AveragesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.shotStore) private var injectedStore
    @Query(sort: \Club.order) private var clubs: [Club]
    @AppStorage("units") private var unitsRaw = Units.yards.rawValue

    private var units: Units { Units(rawValue: unitsRaw) ?? .yards }
    private var store: ShotStore { injectedStore ?? ShotStore(context: context) }

    /// Non-archived clubs with ≥1 non-excluded shot, sorted by mean carry descending.
    private func computeRows() -> [(club: Club, aggregates: ClubAggregates)] {
        clubs
            .filter { !$0.isArchived }
            .compactMap { club -> (Club, ClubAggregates)? in
                let records = club.shots.map { store.record(from: $0) }
                guard let agg = ClubAggregates.compute(from: records) else { return nil }
                return (club, agg)
            }
            .sorted { $0.1.meanCarryMeters > $1.1.meanCarryMeters }
    }

    var body: some View {
        // Memoize rows once per render pass — used by ladder, cards, and CSV export.
        let rows = computeRows()
        let ladderRungs = rows.map { (clubName: $0.club.name, carryMeters: $0.aggregates.meanCarryMeters) }
        let csvExport = CSVExport.clubAverages(rows.map { ($0.club.name, $0.aggregates) }, units: units)

        return ZStack {
            Theme.rangeDusk.ignoresSafeArea()
            if rows.isEmpty {
                emptyState
            } else {
                dashboardContent(rows: rows, ladderRungs: ladderRungs, csvExport: csvExport)
            }
        }
        .navigationTitle("Averages")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("", selection: $unitsRaw) {
                    Text("yd").tag(Units.yards.rawValue)
                    Text("m").tag(Units.meters.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 88)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: csvExport,
                    subject: Text("Club averages"),
                    message: Text("Exported from Chunky")
                ) {
                    Label("Share CSV", systemImage: "square.and.arrow.up")
                }
                .tint(Theme.chalk)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.mist)
            Text("No shots yet. Your yardages will show up here as you log them.")
                .font(Theme.body)
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Dashboard

    private func dashboardContent(
        rows: [(club: Club, aggregates: ClubAggregates)],
        ladderRungs: [(clubName: String, carryMeters: Double)],
        csvExport: String
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Signature gapping ladder
                VStack(alignment: .leading, spacing: 10) {
                    Text("GAPPING LADDER")
                        .font(Theme.eyebrow)
                        .kerning(1.5)
                        .foregroundStyle(Theme.mist)
                    GappingLadder(rungs: ladderRungs, units: units)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Per-club stat cards
                VStack(spacing: 12) {
                    ForEach(rows, id: \.club.id) { row in
                        ClubAverageCard(clubName: row.club.name,
                                        aggregates: row.aggregates,
                                        units: units)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Club average card

private struct ClubAverageCard: View {
    let clubName: String
    let aggregates: ClubAggregates
    let units: Units

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Eyebrow — club name
            Text(clubName.uppercased())
                .font(Theme.eyebrow)
                .kerning(1.2)
                .foregroundStyle(Theme.mist)

            // Hero: mean carry
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(units.carry(fromMeters: aggregates.meanCarryMeters).rounded()))")
                    .font(Theme.display(40))
                    .foregroundStyle(Theme.optic)
                Text(units.abbreviation)
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.mist)
                    .padding(.bottom, 6)
            }

            Rectangle()
                .fill(Theme.turfLine)
                .frame(height: 1)

            // Carry spread
            HStack(spacing: 20) {
                CardStat(
                    label: "MEDIAN",
                    value: "\(Int(units.carry(fromMeters: aggregates.medianCarryMeters).rounded())) \(units.abbreviation)"
                )
                CardStat(
                    label: "STD DEV",
                    value: "±\(Int(units.carry(fromMeters: aggregates.carryStdDevMeters).rounded())) \(units.abbreviation)"
                )
                CardStat(label: "n", value: "\(aggregates.shotCount)")
            }

            // Ball flight
            HStack(spacing: 20) {
                CardStat(
                    label: "BALL SPD",
                    value: "\(Int(Conversions.msToMPH(aggregates.meanBallSpeedMS).rounded())) mph"
                )
                CardStat(
                    label: "LAUNCH",
                    value: String(format: "%.1f°", aggregates.meanLaunchAngleDeg)
                )
                CardStat(
                    label: "SPIN",
                    value: "\(Int(aggregates.meanSpinRPM.rounded())) rpm"
                )
            }

            // Club delivery — shown only when measured data is present
            if aggregates.meanClubSpeedMS != nil || aggregates.meanSmashFactor != nil {
                HStack(spacing: 20) {
                    if let cs = aggregates.meanClubSpeedMS {
                        CardStat(
                            label: "CLUB SPD",
                            value: "\(Int(Conversions.msToMPH(cs).rounded())) mph"
                        )
                    }
                    if let sf = aggregates.meanSmashFactor {
                        CardStat(label: "SMASH", value: String(format: "%.2f", sf))
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.turf)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Stat label+value pair

private struct CardStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.eyebrow)
                .foregroundStyle(Theme.mist)
            Text(value)
                .font(Theme.number(15))
                .foregroundStyle(Theme.chalk)
        }
    }
}

// MARK: - Preview (in-memory, seeded: 4 clubs, multiple shots per club, one excluded per club)

#Preview("Averages — seeded") {
    let schema = Schema([Club.self, Shot.self, Session.self, CalibrationProfile.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext

    let driver = Club(name: "Driver", type: .driver, order: 0, modeledSpinRPM: 2500)
    let wood   = Club(name: "3-Wood", type: .wood,   order: 1, modeledSpinRPM: 3200)
    let iron   = Club(name: "7-Iron", type: .iron,   order: 2, modeledSpinRPM: 6500)
    let wedge  = Club(name: "PW",     type: .wedge,  order: 3, modeledSpinRPM: 8800)
    ctx.insert(driver); ctx.insert(wood); ctx.insert(iron); ctx.insert(wedge)

    // Driver — 3 normal shots (with club speed + smash), 1 excluded
    for carry in [219.0, 223.0, 215.0] {
        let s = Shot(timestamp: .now, ballSpeedMS: 74.5, launchAngleDeg: 11.2,
                     azimuthDeg: 0, spinRPM: 2550, spinSource: .measured,
                     spinAxisTiltDeg: 0, clubSpeedMS: 50.8, smashFactor: 1.46,
                     carryMeters: carry, confidence: .high)
        s.club = driver; ctx.insert(s)
    }
    let dExcluded = Shot(timestamp: .now, ballSpeedMS: 60.0, launchAngleDeg: 8.0,
                         azimuthDeg: 5, spinRPM: 2800, spinSource: .modeled,
                         spinAxisTiltDeg: 0, carryMeters: 180, confidence: .low,
                         isExcludedFromAverages: true)
    dExcluded.club = driver; ctx.insert(dExcluded)

    // 3-Wood — 3 normal shots
    for carry in [196.0, 200.0, 193.0] {
        let s = Shot(timestamp: .now, ballSpeedMS: 68.1, launchAngleDeg: 12.0,
                     azimuthDeg: 0, spinRPM: 3100, spinSource: .modeled,
                     spinAxisTiltDeg: 0, carryMeters: carry, confidence: .high)
        s.club = wood; ctx.insert(s)
    }

    // 7-Iron — 3 normal shots, 1 excluded
    for carry in [155.0, 158.0, 152.0] {
        let s = Shot(timestamp: .now, ballSpeedMS: 57.2, launchAngleDeg: 16.5,
                     azimuthDeg: 0, spinRPM: 6400, spinSource: .modeled,
                     spinAxisTiltDeg: 0, carryMeters: carry, confidence: .medium)
        s.club = iron; ctx.insert(s)
    }
    let iExcluded = Shot(timestamp: .now, ballSpeedMS: 48.0, launchAngleDeg: 14.0,
                         azimuthDeg: 3, spinRPM: 7200, spinSource: .modeled,
                         spinAxisTiltDeg: 0, carryMeters: 130, confidence: .low,
                         isExcludedFromAverages: true)
    iExcluded.club = iron; ctx.insert(iExcluded)

    // PW — 3 normal shots
    for carry in [131.0, 128.0, 134.0] {
        let s = Shot(timestamp: .now, ballSpeedMS: 48.5, launchAngleDeg: 22.0,
                     azimuthDeg: 0, spinRPM: 8600, spinSource: .modeled,
                     spinAxisTiltDeg: 0, carryMeters: carry, confidence: .high)
        s.club = wedge; ctx.insert(s)
    }

    try? ctx.save()

    return NavigationStack { AveragesView() }
        .modelContainer(container)
}
