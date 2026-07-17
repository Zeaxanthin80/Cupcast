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
    @State private var engine: BracketEngine

    init() {
        do {
            let container = try ModelContainer(for: Team.self, Match.self)
            SeedData.seedIfNeeded(container.mainContext)

            // Build the in-memory tree once, up front, so every tab has a ready
            // engine no matter which one the user opens first — replaying any
            // persisted picks (and revealed results) from the store.
            let engine = BracketEngine()
            let matches = (try? container.mainContext.fetch(
                FetchDescriptor<Match>(sortBy: [SortDescriptor(\.round), SortDescriptor(\.slot)]))) ?? []
            engine.buildBracket(from: matches)

            self.container = container
            _engine = State(initialValue: engine)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
        .environment(engine)
    }
}
