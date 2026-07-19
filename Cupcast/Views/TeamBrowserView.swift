//
//  TeamBrowserView.swift
//  Cupcast
//
//  Phase 6 — Team browser (the "Teams" tab). Screen 5 of 6.
//
//  A two-column LazyVGrid of all 16 teams (Objective 3.3 — iterative views), read
//  straight from SwiftData with @Query sorted by seed (Objective 3.6). Each card is
//  a NavigationLink pushing TeamDetailView (Objective 3.5 — the project's
//  NavigationLink anchor), tinted with the team's national color from Theme.
//

import SwiftUI
import SwiftData

struct TeamBrowserView: View {
    @Query(sort: \Team.seed) private var teams: [Team]

    private let columns = [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 11) {
                ForEach(teams) { team in
                    NavigationLink(value: team) {
                        TeamCardView(team: team)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .bracketBackground()
        .navigationTitle("16 Teams")
        .navigationDestination(for: Team.self) { team in
            TeamDetailView(team: team)
        }
    }
}

/// One team's tile in the browser grid (Objective 3.4 — extracted subview).
struct TeamCardView: View {
    let team: Team

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                FlagView(team: team, width: 42, height: 30)
                Spacer()
                Text("#\(team.seed)")
                    .font(.caption2).fontWeight(.heavy).monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.25)))
            }

            Text(team.name)
                .font(.callout).expandedHeavy()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 12)

            Text("Group \(team.group)")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16).fill(
                LinearGradient(
                    colors: [Theme.color(for: team).opacity(0.32), Color.white.opacity(0.03)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardStroke, lineWidth: 1)
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)
    SeedData.seedIfNeeded(container.mainContext)

    let engine = BracketEngine()
    let matches = (try? container.mainContext.fetch(FetchDescriptor<Match>())) ?? []
    engine.buildBracket(from: matches)

    return NavigationStack { TeamBrowserView() }
        .environment(engine)
        .modelContainer(container)
}
