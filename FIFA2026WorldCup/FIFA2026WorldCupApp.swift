//
//  FIFA2026WorldCupApp.swift
//  FIFA2026WorldCup
//
//  Created by user on 7/12/26.
//

import SwiftUI
import SwiftData

@main
struct FIFA2026WorldCupApp: App {
    // The SwiftData container is created once and seeded on first launch.
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Team.self, Match.self)
            SeedData.seedIfNeeded(container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // TEMP (Phases 1–2): verify the store populates and the engine behaves.
            // This whole TabView, DebugStoreView, and DebugEngineView all get
            // deleted when the real Bracket Overview screen lands in Phase 3.
            TabView {
                NavigationStack { DebugEngineView() }
                    .tabItem { Label("Engine", systemImage: "checklist") }

                DebugStoreView()
                    .tabItem { Label("Store", systemImage: "cylinder.split.1x2") }
            }
        }
        .modelContainer(container)
    }
}
