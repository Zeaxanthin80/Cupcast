//
//  WinnerPicker.swift
//  FIFA2026WorldCup
//
//  Phase 4 — Match detail.
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
        HStack(spacing: 12) {
            TeamPickButton(
                team: node.teamA,
                isSelected: isSelected(node.teamA),
                action: { selection = node.teamA }
            )

            Text("vs")
                .font(.headline)
                .foregroundStyle(.secondary)

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
                FlagView(team: team, width: 63, height: 45)

                if let team {
                    Text(team.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Group \(team.group) · Seed \(team.seed)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("TBD")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .padding(6)
                }
            }
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
}
