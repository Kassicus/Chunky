//
//  chunkyApp.swift
//  chunky
//
//  Created by Kason Suchow on 7/1/26.
//

import SwiftUI
import SwiftData

@main
struct chunkyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Club.self,
            Shot.self,
            Session.self,
            CalibrationProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
