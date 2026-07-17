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

    // The shared engine, injected app-wide via .environment (Objective 3.6);
    // screens read it back with @Environment(BracketEngine.self).
    @State private var engine = BracketEngine()

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
            NavigationStack {
                BracketOverviewView()
            }
        }
        .modelContainer(container)
        .environment(engine)
    }
}
