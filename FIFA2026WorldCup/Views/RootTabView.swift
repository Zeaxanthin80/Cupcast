//
//  RootTabView.swift
//  FIFA2026WorldCup
//
//  Phase 5 — top-level navigation.
//
//  The app's tab shell (Objective 3.5). CLAUDE.md specifies 6 screens but never
//  said how the flat ones are reached; this is that answer, matching Jose's mockup.
//  Each tab owns its own NavigationStack so pushes (Team detail, Phase 6) and the
//  Match-detail .sheet stay scoped to their tab.
//
//  Teams is intentionally absent until Phase 6 (its browser + detail land there),
//  so there is no placeholder tab — every tab here is fully functional.
//

import SwiftUI

struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { BracketOverviewView() }
                .tabItem { Label("Bracket", systemImage: "arrow.triangle.branch") }
                .tag(0)

            NavigationStack { PredictionsView() }
                .tabItem { Label("Picks", systemImage: "checklist") }
                .tag(1)

            NavigationStack { ScoreView() }
                .tabItem { Label("Score", systemImage: "chart.bar.fill") }
                .tag(2)
        }
        .tint(Theme.accentCyan)
        .preferredColorScheme(.dark)
    }
}
