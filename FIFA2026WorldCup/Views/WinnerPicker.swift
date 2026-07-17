//
//  WinnerPicker.swift
//  FIFA2026WorldCup
//
//  Phase 4 — Match detail. Restyled for the dark theme in Phase 5.
//
//  THE @Binding anchor example (Objective 3.6): this child view does not own the
//  selection — it reads AND WRITES its parent's @State through the binding. Tapping
//  a team here mutates MatchDetailView's `pickedWinner`, and the parent's UI
//  (the "Your pick" line, the Confirm button) reacts immediately.
//
//  It takes the BracketNode rather than the persisted Match deliberately: for any
//  round after the Round of 16 the matchup exists only in memory, cascaded into
//  the node by earlier picks — the store's Match rows carry teams for round 0 only.
//

import SwiftUI

struct WinnerPicker: View {
    let node: BracketNode
    @Binding var selection: Team?

    var body: some View {
        HStack(spacing: 10) {
            TeamPickButton(
                team: node.teamA,
                isSelected: isSelected(node.teamA),
                action: { selection = node.teamA }
            )

            Text("VS")
                .font(.subheadline).expandedHeavy()
                .foregroundStyle(Theme.textTertiary)

            TeamPickButton(
                team: node.teamB,
                isSelected: isSelected(node.teamB),
                action: { selection = node.teamB }
            )
        }
    }

    private func isSelected(_ team: Team?) -> Bool {
        guard let team, let selection else { return false }
        return selection.id == team.id
    }
}

/// One tappable team tile. Extracted (Objective 3.4) so WinnerPicker's body reads
/// as "two choices and a vs", not sixty lines of styling.
struct TeamPickButton: View {
    let team: Team?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                FlagView(team: team, width: 64, height: 46)

                if let team {
                    Text(team.name)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Seed #\(team.seed) · Grp \(team.group)")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(isSelected ? "✓ YOUR PICK" : "TAP TO PICK")
                        .font(.caption2).fontWeight(.heavy)
                        .foregroundStyle(isSelected ? Theme.pickTint : Theme.textTertiary)
                        .padding(.top, 2)
                } else {
                    Text("TBD")
                        .font(.subheadline).italic()
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.vertical, 18)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Theme.pickTint.opacity(0.18) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Theme.pickTint : Theme.cardStroke,
                                  lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Theme.pickTint.opacity(0.35) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(team == nil)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var selection: Team?

    let engine = BracketEngine()
    engine.buildBracket(from: SeedData.makeTeams())

    return WinnerPicker(node: engine.node(round: 0, slot: 0)!, selection: $selection)
        .padding()
        .bracketBackground()
}
