// chunky/chunky/Features/RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { AveragesView() }
                .tabItem { Label("Averages", systemImage: "chart.bar.fill") }
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "list.bullet") }
            NavigationStack { ClubsView() }
                .tabItem { Label("Clubs", systemImage: "bag.fill") }
        }
        .tint(Theme.optic)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Club.self, Shot.self, Session.self, CalibrationProfile.self], inMemory: true)
}
