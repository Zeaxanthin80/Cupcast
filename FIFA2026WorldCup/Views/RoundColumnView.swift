//
//  RoundColumnView.swift
//  FIFA2026WorldCup
//
//  Phase 3 — Bracket overview.
//
//  One round of the bracket as a vertical column: header plus that round's match
//  cards. Every column gets the SAME total height, and each card is centered in an
//  equal flexible slice of it — so a parent's center always sits exactly midway
//  between its two children's centers, which is what makes the connector geometry
//  in BracketConnector line up without any per-node math here.
//

import SwiftUI

struct RoundColumnView: View {
    let round: Int
    let nodes: [BracketNode]
    let matchAreaHeight: CGFloat
    let headerHeight: CGFloat
    /// Called with the tapped node. Cards for undecided matchups (a team still
    /// TBD) aren't tappable — there is nothing to pick yet.
    var onSelect: (BracketNode) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            Text(BracketEngine.roundName(round))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(height: headerHeight)

            VStack(spacing: 0) {
                ForEach(nodes) { node in
                    Button {
                        onSelect(node)
                    } label: {
                        MatchCardView(node: node)
                    }
                    .buttonStyle(.plain)
                    .disabled(!node.isReady)
                    .frame(maxHeight: .infinity)   // equal slice per match
                }
            }
            .frame(width: MatchCardView.width, height: matchAreaHeight)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let engine = BracketEngine()
    engine.buildBracket(from: SeedData.makeTeams())

    return RoundColumnView(
        round: 1,
        nodes: engine.nodes(inRound: 1),
        matchAreaHeight: 672,
        headerHeight: 28
    )
    .padding()
}
