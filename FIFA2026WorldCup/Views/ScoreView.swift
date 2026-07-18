//
//  ScoreView.swift
//  FIFA2026WorldCup
//
//  Phase 5 — Score summary (the "Score" tab). Screen 4 of 6.
//
//  Drives entirely off BracketEngine.calculateScore() → [RoundScore] (Objective 2.4
//  default parameter; 2.5.2 RoundScore is a value-type struct). Two states, keyed on
//  whether official results are in: an empty "reveal" state, and the scored
//  breakdown with a per-round bar for each RoundScore.
//
//  "Results" are a labelled DEMONSTRATION outcome (see BracketEngine.demoActual…) —
//  the real 2026 knockouts haven't been played. Revealing/hiding writes actualWinner
//  through to SwiftData so the score, and the ✓/✗ marks across the app, persist.
//

import SwiftUI
import SwiftData

struct ScoreView: View {
    @Environment(BracketEngine.self) private var engine
    @Environment(\.modelContext) private var modelContext
    @Query private var teams: [Team]
    @Query private var matches: [Match]

    private var resultsIn: Bool {
        matches.contains { $0.actualWinner != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if resultsIn { scoredState } else { emptyState }
            }
            .padding()
        }
        .bracketBackground()
        .navigationTitle("Score")
    }

    // MARK: - Scored state

    private var scoredState: some View {
        let scores = engine.calculateScore()
        let total = engine.totalPoints()
        let maxPoints = engine.maxPossiblePoints()
        let correct = scores.reduce(0) { $0 + $1.correctPicks }

        return VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("YOUR BRACKET SCORE")
                    .font(.caption2).fontWeight(.heavy).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(total)").font(.system(size: 60)).expandedHeavy()
                        .foregroundStyle(.white)
                    Text("/ \(maxPoints)").font(.title3).fontWeight(.heavy)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text("\(correct) of 15 winners called correctly")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.accentGradient))

            ForEach(scores, id: \.round) { score in
                RoundScoreBar(score: score)
            }

            Button {
                withAnimation { hideResults() }
            } label: {
                Text("Hide official results")
                    .font(.subheadline).fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.cardStroke, lineWidth: 1))
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            TrophyView(height: 196)
            Text("Results aren't in yet")
                .font(.title2).expandedHeavy().foregroundStyle(.white)
            Text("Make your picks on the bracket, then reveal the demo tournament outcome to see how you scored.")
                .font(.subheadline).fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: 280)

            Button {
                withAnimation { revealResults() }
            } label: {
                Text("Reveal official results →")
                    .font(.subheadline).fontWeight(.heavy)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accentGradient))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            Text("Scoring: R16 +1 · QF +2 · SF +4 · Final +8 per correct pick")
                .font(.caption2).fontWeight(.medium)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func revealResults() {
        engine.revealDemoResults(teams: teams)
        save()
    }

    private func hideResults() {
        engine.clearResults()
        save()
    }

    private func save() {
        do { try modelContext.save() }
        catch { print("ScoreView: save failed — \(error)") }
    }
}

/// One round's row on the score breakdown: label, progress bar, correct count,
/// points earned. A small extracted subview (Objective 3.4).
struct RoundScoreBar: View {
    let score: RoundScore

    private var total: Int { BracketEngine.slotCount(inRound: score.round) }
    private var pointsPerPick: Int { [1, 2, 4, 8][safe: score.round] ?? 0 }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(BracketEngine.roundName(score.round))
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                Spacer()
                Text("+\(pointsPerPick) per pick")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.card)
                        Capsule().fill(Theme.accentGradient)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 8)

                Text("\(score.correctPicks)/\(total)")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(Theme.textSecondary)
                Text("+\(score.pointsEarned)")
                    .font(.subheadline).expandedHeavy().foregroundStyle(.white)
                    .frame(minWidth: 42, alignment: .trailing)
            }
        }
        .padding(13)
        .background(GlassCard { Color.clear })
    }

    private var fraction: CGFloat {
        total == 0 ? 0 : CGFloat(score.correctPicks) / CGFloat(total)
    }
}

#Preview("Empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)
    SeedData.seedIfNeeded(container.mainContext)

    let engine = BracketEngine()
    let matches = (try? container.mainContext.fetch(FetchDescriptor<Match>())) ?? []
    engine.buildBracket(from: matches)

    return NavigationStack { ScoreView() }
        .environment(engine)
        .modelContainer(container)
}

#Preview("Scored") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)
    SeedData.seedIfNeeded(container.mainContext)

    let engine = BracketEngine()
    let teams = (try? container.mainContext.fetch(FetchDescriptor<Team>())) ?? []
    let matches = (try? container.mainContext.fetch(FetchDescriptor<Match>())) ?? []
    engine.buildBracket(from: matches)
    // Predict every favorite, then reveal, so the breakdown shows real numbers.
    for round in 0..<BracketEngine.roundCount {
        for node in engine.nodes(inRound: round) {
            guard let a = node.teamA, let b = node.teamB else { continue }
            engine.advanceWinner(for: node, to: a.seed < b.seed ? a : b)
        }
    }
    engine.revealDemoResults(teams: teams)
    try? container.mainContext.save()

    return NavigationStack { ScoreView() }
        .environment(engine)
        .modelContainer(container)
}
