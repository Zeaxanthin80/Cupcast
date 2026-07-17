//
//  DebugStoreView.swift
//  FIFA2026WorldCup
//
//  ⚠️ TEMPORARY — Phase 1 verification only. Delete once the real Bracket
//  Overview screen lands in Phase 3. Reads the SwiftData store via @Query to
//  confirm seeding populated 16 teams and 15 matches.
//

import SwiftUI
import SwiftData

struct DebugStoreView: View {
    @Query(sort: \Team.seed) private var teams: [Team]
    @Query(sort: [SortDescriptor(\Match.round), SortDescriptor(\Match.slot)])
    private var matches: [Match]

    var body: some View {
        NavigationStack {
            List {
                Section("Teams (\(teams.count))") {
                    ForEach(teams) { team in
                        HStack {
                            Text("#\(team.seed)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .leading)
                            VStack(alignment: .leading) {
                                Text(team.name).fontWeight(.medium)
                                Text("Group \(team.group) · \(team.flagAssetName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Matches (\(matches.count))") {
                    ForEach(matches) { match in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(roundName(match.round)) · slot \(match.slot)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(match.teamA?.name ?? "TBD") vs \(match.teamB?.name ?? "TBD")")
                                .fontWeight(.medium)
                            if let date = match.matchDate {
                                Text(date, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Debug Store")
        }
    }

    private func roundName(_ round: Int) -> String {
        switch round {
        case 0: return "Round of 16"
        case 1: return "Quarterfinal"
        case 2: return "Semifinal"
        case 3: return "Final"
        default: return "Round \(round)"
        }
    }
}

#Preview {
    // In-memory container seeded for the preview, so no populated store is required.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)
    SeedData.seedIfNeeded(container.mainContext)
    return DebugStoreView()
        .modelContainer(container)
}
