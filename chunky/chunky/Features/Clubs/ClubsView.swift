// chunky/chunky/Features/Clubs/ClubsView.swift
import SwiftUI
import SwiftData

struct ClubsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.shotStore) private var injectedStore
    @Query(sort: \Club.order) private var clubs: [Club]
    @State private var showingAdd = false

    private var store: ShotStore { injectedStore ?? ShotStore(context: context) }
    private var activeClubs: [Club] { clubs.filter { !$0.isArchived } }

    var body: some View {
        List {
            if activeClubs.isEmpty {
                Text("No clubs yet. Add your first club to start logging shots.")
                    .font(Theme.body).foregroundStyle(Theme.mist)
                    .listRowBackground(Theme.turf)
            }
            ForEach(activeClubs) { club in
                ClubRow(club: club, store: store)
                    .listRowBackground(Theme.turf)
            }
            .onMove { indices, newOffset in
                var reordered = activeClubs
                reordered.move(fromOffsets: indices, toOffset: newOffset)
                store.reorderClubs(reordered)
            }
            .onDelete { indices in
                indices.map { activeClubs[$0] }.forEach(store.removeClub)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.rangeDusk)
        .navigationTitle("Clubs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarLeading) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add")
            }
        }
        .sheet(isPresented: $showingAdd) { AddClubSheet(store: store) }
    }
}

private struct ClubRow: View {
    @Bindable var club: Club
    let store: ShotStore
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $club.name).font(Theme.number(17)).foregroundStyle(Theme.chalk)
                Text(club.type.rawValue.uppercased()).font(Theme.eyebrow).kerning(1.2).foregroundStyle(Theme.mist)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(club.modeledSpinRPM))").font(Theme.number(15)).foregroundStyle(Theme.mist)
                Text("rpm model").font(Theme.eyebrow).foregroundStyle(Theme.mist)
            }
        }
    }
}

private struct AddClubSheet: View {
    let store: ShotStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type: ClubType = .iron
    @State private var spin = 6500.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. 7-Iron)", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(ClubType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Stepper("Modeled spin: \(Int(spin)) rpm", value: $spin, in: 1500...11000, step: 100)
            }
            .navigationTitle("Add club")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addClub(name: name.isEmpty ? "New club" : name, type: type, modeledSpinRPM: spin)
                        dismiss()
                    }.disabled(name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

#Preview {
    NavigationStack { ClubsView() }
        .modelContainer(for: [Club.self, Shot.self, Session.self, CalibrationProfile.self], inMemory: true)
}
