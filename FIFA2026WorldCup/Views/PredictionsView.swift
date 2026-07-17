//
//  PredictionsView.swift
//  FIFA2026WorldCup
//
//  Phase 5 — Predictions (the "Picks" tab). Screen 3 of 6.
//
//  A flat, per-round list of every match and the pick made for it (Objective 3.3 —
//  List/ForEach). Reads SwiftData directly with @Query (Objective 3.6): the pick and
//  result come straight off each persisted Match. The matchup itself is pulled from
//  the engine's node, because past the Round of 16 the teams exist only in the
//  in-memory tree — the same reason WinnerPicker takes a node.
//
//  Tapping a row opens the same MatchDetailView sheet the bracket uses, so picks are
//  editable from here too.
//

import SwiftUI
import SwiftData

struct PredictionsView: View {
    @Environment(BracketEngine.self) private var engine
    @Query(sort: [SortDescriptor(\Match.round), SortDescriptor(\Match.slot)])
    private var matches: [Match]

    @State private var selectedNode: BracketNode?

    private var predictedCount: Int {
        matches.filter { $0.predictedWinner != nil }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                progressHeader
                ForEach(0..<BracketEngine.roundCount, id: \.self) { round in
                    roundSection(round)
                }
            }
            .padding()
        }
        .bracketBackground()
        .navigationTitle("Your Picks")
        .sheet(item: $selectedNode) { node in
            MatchDetailView(node: node)
                .presentationDetents([.medium, .large])
                .presentationBackground(.black)
        }
    }

    // MARK: - Header with progress ring

    private var progressHeader: some View {
        HStack(spacing: 14) {
            Text("\(predictedCount)")
                .font(.system(size: 34)).expandedHeavy()
                .foregroundStyle(.white)
            Text("of 15 matches\npredicted so far")
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            ZStack {
                Circle().stroke(Theme.card, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: Double(predictedCount) / 15)
                    .stroke(Theme.accentGradient,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 46, height: 46)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassCard { Color.clear })
    }

    // MARK: - One round's matches

    private func roundSection(_ round: Int) -> some View {
        let roundMatches = matches.filter { $0.round == round }
        return VStack(alignment: .leading, spacing: 8) {
            Text(BracketEngine.roundName(round).uppercased())
                .font(.caption2).fontWeight(.bold).tracking(1.0)
                .foregroundStyle(Theme.textSecondary)

            ForEach(roundMatches) { match in
                predictionRow(match)
            }
        }
    }

    private func predictionRow(_ match: Match) -> some View {
        let node = engine.node(round: match.round, slot: match.slot)
        let teamA = node?.teamA ?? match.teamA
        let teamB = node?.teamB ?? match.teamB
        let pick = match.predictedWinner
        let actual = match.actualWinner

        return Button {
            if let node { selectedNode = node }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        matchupTeam(teamA)
                        Text("vs").font(.caption2).foregroundStyle(Theme.textTertiary)
                        matchupTeam(teamB)
                    }
                    Text(pick.map { "Your pick: \($0.name)" } ?? "No pick yet")
                        .font(.caption)
                        .foregroundStyle(pick == nil ? Theme.textTertiary : Theme.pickTint)
                }

                Spacer(minLength: 4)

                if let actual, let pick {
                    Image(systemName: pick.id == actual.id ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(pick.id == actual.id ? Theme.success : Theme.danger)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassCard { Color.clear })
        }
        .buttonStyle(.plain)
    }

    private func matchupTeam(_ team: Team?) -> some View {
        HStack(spacing: 4) {
            FlagView(team: team, width: 18, height: 13)
            Text(team?.name ?? "TBD")
                .font(.footnote).fontWeight(.semibold)
                .foregroundStyle(team == nil ? Theme.textTertiary : .white)
                .lineLimit(1)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)
    SeedData.seedIfNeeded(container.mainContext)

    let engine = BracketEngine()
    let matches = (try? container.mainContext.fetch(
        FetchDescriptor<Match>(sortBy: [SortDescriptor(\.round), SortDescriptor(\.slot)]))) ?? []
    engine.buildBracket(from: matches)
    // A couple of picks so the list isn't empty in the preview.
    if let n = engine.node(round: 0, slot: 0), let a = n.teamA { engine.advanceWinner(for: n, to: a) }
    if let n = engine.node(round: 0, slot: 2), let a = n.teamA { engine.advanceWinner(for: n, to: a) }
    engine.syncToStore()

    return NavigationStack { PredictionsView() }
        .environment(engine)
        .modelContainer(container)
}
