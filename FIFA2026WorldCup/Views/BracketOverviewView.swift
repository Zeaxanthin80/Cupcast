//
//  BracketOverviewView.swift
//  FIFA2026WorldCup
//
//  Phase 3 — Bracket overview. Screen 1 of 6, the visual centerpiece.
//
//  Four round columns joined by connector lines, scrolling both ways, with a
//  champion banner on top. Reads the shared BracketEngine from the environment
//  (Objective 3.6) and builds its tree from the store's matches on first
//  appearance. Match cards render engine state only — picking winners is
//  Phase 4's job (Match detail + WinnerPicker).
//

import SwiftUI
import SwiftData

struct BracketOverviewView: View {
    @Environment(BracketEngine.self) private var engine
    @Query(sort: [SortDescriptor(\Match.round), SortDescriptor(\Match.slot)])
    private var matches: [Match]

    /// The match whose sheet is open (Objective 3.5 — .sheet(item:)). BracketNode
    /// is Identifiable, which is what item-based presentation needs.
    @State private var selectedNode: BracketNode?

    // Shared layout constants — one height for every column is the invariant the
    // whole bracket geometry hangs on (see RoundColumnView / BracketConnector).
    private let headerHeight: CGFloat = 28
    private let matchAreaHeight: CGFloat = 672   // 8 slots × 84pt

    var body: some View {
        Group {
            if engine.root == nil {
                ProgressView("Building bracket…")
            } else {
                bracket
            }
        }
        .bracketBackground()
        .navigationTitle("The Bracket")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedNode) { node in
            MatchDetailView(node: node)
                .presentationDetents([.medium, .large])
                .presentationBackground(.black)
        }
        // Build once the store's matches are available. Keyed on the count so the
        // guard re-runs if the query delivers after first render.
        .task(id: matches.count) {
            guard engine.root == nil, !matches.isEmpty else { return }
            engine.buildBracket(from: matches)
        }
    }

    private var bracket: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                championBanner

                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<BracketEngine.roundCount, id: \.self) { round in
                        RoundColumnView(
                            round: round,
                            nodes: engine.nodes(inRound: round),
                            matchAreaHeight: matchAreaHeight,
                            headerHeight: headerHeight,
                            onSelect: { selectedNode = $0 }
                        )

                        if round + 1 < BracketEngine.roundCount {
                            BracketConnectorColumn(
                                pairCount: BracketEngine.slotCount(inRound: round + 1),
                                matchAreaHeight: matchAreaHeight,
                                headerHeight: headerHeight
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var championBanner: some View {
        let champion = engine.root.flatMap { engine.champion(of: $0) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("YOUR PREDICTED CHAMPION")
                .font(.caption2).fontWeight(.bold).tracking(1.4)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 12) {
                FlagView(team: champion, width: 46, height: 33)

                if let champion {
                    Text(champion.name)
                        .font(.title2).expandedHeavy()
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.gold)
                } else {
                    Text("Not decided yet")
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(
                champion == nil
                ? AnyShapeStyle(Theme.card)
                : AnyShapeStyle(LinearGradient(
                    colors: [Theme.gold.opacity(0.22), Theme.accentPurple.opacity(0.22)],
                    startPoint: .leading, endPoint: .trailing))
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(champion == nil ? Theme.cardStroke : Theme.gold.opacity(0.4), lineWidth: 1)
        )
        .frame(width: 520)
    }
}

// MARK: - Previews (no populated store required, per CLAUDE.md conventions)

#Preview("With picks") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)

    let engine = BracketEngine()
    engine.buildBracket(from: SeedData.makeTeams())

    // Walk a full set of picks in: every favorite by seed, champion Argentina.
    for round in 0..<BracketEngine.roundCount {
        for node in engine.nodes(inRound: round) {
            guard let teamA = node.teamA, let teamB = node.teamB else { continue }
            engine.advanceWinner(for: node, to: teamA.seed < teamB.seed ? teamA : teamB)
        }
    }

    return NavigationStack { BracketOverviewView() }
        .environment(engine)
        .modelContainer(container)
}

#Preview("Fresh — no picks") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)

    let engine = BracketEngine()
    engine.buildBracket(from: SeedData.makeTeams())

    return NavigationStack { BracketOverviewView() }
        .environment(engine)
        .modelContainer(container)
}
