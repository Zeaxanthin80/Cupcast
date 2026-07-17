//
//  MatchCardView.swift
//  FIFA2026WorldCup
//
//  Phase 3 — Bracket overview.
//
//  One match in the bracket: two team slots stacked in a card. Reads its
//  BracketNode directly — the node is @Observable, so when the cascade seats a
//  team here (or tears a pick down), exactly this card redraws.
//
//  Extracted subview per Objective 3.4; TeamSlotView is extracted again below
//  rather than inlining two near-identical HStacks.
//

import SwiftUI

struct MatchCardView: View {
    let node: BracketNode

    static let width: CGFloat = 164

    var body: some View {
        VStack(spacing: 0) {
            TeamSlotView(team: node.teamA, isPicked: isPicked(node.teamA))
            Divider()
            TeamSlotView(team: node.teamB, isPicked: isPicked(node.teamB))
        }
        .frame(width: Self.width)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func isPicked(_ team: Team?) -> Bool {
        guard let team, let picked = node.predictedWinner else { return false }
        return picked.id == team.id
    }
}

/// One team's row inside a match card. `team` is nil until the cascade fills the
/// slot, so the empty state ("TBD") is part of the design, not an error.
struct TeamSlotView: View {
    let team: Team?
    let isPicked: Bool

    var body: some View {
        HStack(spacing: 6) {
            FlagView(team: team)

            if let team {
                Text(team.name)
                    .font(.footnote)
                    .fontWeight(isPicked ? .semibold : .regular)
                    .lineLimit(1)

                Spacer(minLength: 2)

                if isPicked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                } else {
                    Text("\(team.seed)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("TBD")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isPicked ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}

#Preview("Picked, unpicked, empty", traits: .sizeThatFitsLayout) {
    let teams = SeedData.makeTeams()
    let engine = BracketEngine()
    engine.buildBracket(from: teams)

    let picked = engine.node(round: 0, slot: 0)!
    engine.advanceWinner(for: picked, to: picked.teamA!)

    return VStack(spacing: 12) {
        MatchCardView(node: picked)                            // has a pick
        MatchCardView(node: engine.node(round: 0, slot: 1)!)   // no pick yet
        MatchCardView(node: engine.node(round: 2, slot: 0)!)   // both TBD
    }
    .padding()
}
