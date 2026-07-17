//
//  TeamDetailView.swift
//  FIFA2026WorldCup
//
//  Phase 6 — Team detail. Screen 6 of 6, pushed from the browser via
//  NavigationLink (Objective 3.5).
//
//  Flag, group, seed, and the team's match history through the predicted bracket:
//  engine.path(for:) walks the parent pointers from their R16 node upward, and
//  engine.predictedFinish(for:) says where the picks send them. Optional chaining
//  and switch over an enum with associated values do the narrative work
//  (Objectives 2.3 / 2.6). Tapping a path row opens the same MatchDetailView sheet
//  used everywhere else.
//

import SwiftUI
import SwiftData

struct TeamDetailView: View {
    let team: Team

    @Environment(BracketEngine.self) private var engine
    @State private var selectedNode: BracketNode?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                predictionCard
                pathSection
                blurb
            }
            .padding()
        }
        .bracketBackground()
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedNode) { node in
            MatchDetailView(node: node)
                .presentationDetents([.medium, .large])
                .presentationBackground(.black)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            FlagView(team: team, width: 92, height: 66)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 5)

            Text(team.name)
                .font(.largeTitle).expandedHeavy()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 8) {
                pill("Group \(team.group)")
                pill("Seed #\(team.seed)")
                pill(strengthLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(
                LinearGradient(
                    colors: [Theme.color(for: team).opacity(0.55), Theme.color(for: team).opacity(0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.cardStroke, lineWidth: 1))
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption).fontWeight(.heavy)
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(.black.opacity(0.28)))
    }

    /// Rough tier by seed, straight from the mockup.
    private var strengthLabel: String {
        switch team.seed {
        case ...4: return "Contender"
        case ...8: return "Dark horse"
        case ...12: return "Outsider"
        default: return "Underdog"
        }
    }

    // MARK: - Predicted finish

    private var predictionCard: some View {
        let isChampion = engine.predictedFinish(for: team) == .champion

        return HStack(spacing: 12) {
            finishIcon
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR PREDICTION")
                    .font(.caption2).fontWeight(.heavy).tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                Text(finishText)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isChampion ? Theme.gold.opacity(0.14) : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isChampion ? Theme.gold.opacity(0.4) : Theme.cardStroke, lineWidth: 1)
        )
    }

    /// The champion gets the real trophy image; the other outcomes stay emoji.
    @ViewBuilder
    private var finishIcon: some View {
        switch engine.predictedFinish(for: team) {
        case .champion:
            TrophyView(height: 38)
        case .noPrediction:
            Text("🤔").font(.system(size: 30))
        case .eliminated(let round):
            Text(round == BracketEngine.roundCount - 1 ? "🥈" : "🚪").font(.system(size: 30))
        case .advances(let round):
            Text(round == BracketEngine.roundCount - 1 ? "🥈" : "🎯").font(.system(size: 30))
        }
    }

    private var finishText: String {
        switch engine.predictedFinish(for: team) {
        case .noPrediction:
            return "No prediction yet"
        case .champion:
            return "Predicted Champion"
        case .eliminated(let round):
            return round == BracketEngine.roundCount - 1
                ? "Predicted Finalist"
                : "Predicted to exit in the \(BracketEngine.roundName(round))"
        case .advances(let round):
            return round == BracketEngine.roundCount - 1
                ? "Predicted to reach the Final"
                : "Predicted to reach the \(BracketEngine.roundName(round))"
        }
    }

    // MARK: - Path through the bracket (match history)

    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BRACKET PATH")
                .font(.caption2).fontWeight(.bold).tracking(1.0)
                .foregroundStyle(Theme.textSecondary)

            ForEach(engine.path(for: team)) { node in
                pathRow(node)
            }
        }
    }

    private func pathRow(_ node: BracketNode) -> some View {
        let opponent = node.teamA?.id == team.id ? node.teamB : node.teamA

        return Button {
            selectedNode = node
        } label: {
            HStack(spacing: 12) {
                FlagView(team: opponent, width: 30, height: 21)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(BracketEngine.roundName(node.round))
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Theme.textSecondary)
                        if let date = node.match?.matchDate {
                            Text("· \(date.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    Text("vs \(opponent?.name ?? "TBD")")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 4)

                statusMark(node)
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassCard { Color.clear })
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusMark(_ node: BracketNode) -> some View {
        if let picked = node.predictedWinner {
            Image(systemName: picked.id == team.id ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(picked.id == team.id ? Theme.pickTint : Theme.danger)
        } else {
            Text("—").foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Blurb

    private var blurb: some View {
        Text("\(team.name) enter the knockouts as the #\(team.seed) seed out of Group \(team.group). Every prediction you make for them cascades through the bracket toward the July 19 final at MetLife Stadium.")
            .font(.caption).fontWeight(.medium)
            .foregroundStyle(Theme.textSecondary)
            .lineSpacing(3)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassCard { Color.clear })
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)
    SeedData.seedIfNeeded(container.mainContext)

    let engine = BracketEngine()
    let matches = (try? container.mainContext.fetch(FetchDescriptor<Match>())) ?? []
    engine.buildBracket(from: matches)
    // Pick Argentina through to the title so the path + champion card show.
    for round in 0..<BracketEngine.roundCount {
        for node in engine.nodes(inRound: round) {
            guard let a = node.teamA, let b = node.teamB else { continue }
            engine.advanceWinner(for: node, to: a.seed < b.seed ? a : b)
        }
    }

    let argentina = (try? container.mainContext.fetch(FetchDescriptor<Team>()))?
        .first { $0.seed == 1 }

    return NavigationStack { TeamDetailView(team: argentina!) }
        .environment(engine)
        .modelContainer(container)
}
