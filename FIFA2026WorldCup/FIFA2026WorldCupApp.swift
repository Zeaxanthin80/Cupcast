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
            // TEMP (Phase 1): verify the store populates. Replaced by the real
            // Bracket Overview screen in Phase 3.
            DebugStoreView()
        }
        .modelContainer(container)
    }
}
