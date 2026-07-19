//
//  MatchCardView.swift
//  Cupcast
//
//  Phase 3 — Bracket overview. Restyled for the dark theme in Phase 5.
//
//  One match in the bracket: two team slots stacked in a glassy card. Reads its
//  BracketNode directly — the node is @Observable, so when the cascade seats a
//  team here (or tears a pick down), exactly this card redraws. Once official
//  results are revealed the same card shows ✓ / ✗ / ● marks.
//
//  Extracted subview per Objective 3.4; TeamSlotView is extracted again below.
//

import SwiftUI

/// How a team row should read once results are in.
enum SlotResult {
    case none          // no results revealed yet
    case correctPick   // user picked this team and it won
    case wrongPick     // user picked this team and it lost
    case actualWinner  // this team won but the user didn't pick it
    case alsoRan       // neither picked nor the winner
}

struct MatchCardView: View {
    let node: BracketNode

    static let width: CGFloat = 240 //168

    var body: some View {
        VStack(spacing: 2) {
            TeamSlotView(team: node.teamA,
                         isPicked: isPicked(node.teamA),
                         result: result(for: node.teamA))
            Divider().overlay(Theme.cardStroke)
            TeamSlotView(team: node.teamB,
                         isPicked: isPicked(node.teamB),
                         result: result(for: node.teamB))
        }
        .frame(width: Self.width)
        .background(
            RoundedRectangle(cornerRadius: 13).fill(Theme.card)
        )
        
        .overlay(
            RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.cardStroke, lineWidth: 1)
        )
        
        .clipShape(RoundedRectangle(cornerRadius: 13))
        
       //.padding(.vertical, 24)
    }

    private func isPicked(_ team: Team?) -> Bool {
        guard let team, let picked = node.predictedWinner else { return false }
        return picked.id == team.id
    }

    private func result(for team: Team?) -> SlotResult {
        guard let team, node.actualWinner != nil else { return .none }
        let didWin = node.actualWinner?.id == team.id
        let didPick = isPicked(team)
        switch (didPick, didWin) {
        case (true, true): return .correctPick
        case (true, false): return .wrongPick
        case (false, true): return .actualWinner
        case (false, false): return .alsoRan
        }
    }
}

/// One team's row inside a match card. `team` is nil until the cascade fills the
/// slot, so the empty state ("TBD") is part of the design, not an error.
struct TeamSlotView: View {
    let team: Team?
    let isPicked: Bool
    var result: SlotResult = .none

    var body: some View {
        HStack(spacing: 8) {
            FlagView(team: team)

            if let team {
                Text(team.name)
                    .font(.footnote)
                    .fontWeight(nameBold ? .semibold : .regular)
                    .foregroundStyle(nameColor)
                    .lineLimit(1)

                Spacer(minLength: 2)

                trailingMark(for: team)
            } else {
                Text("TBD")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 2)
            }
        }
        .padding(.horizontal,12) //8
        .padding(.vertical, 7) //7
        
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if let bar = accentBar {
                Rectangle().fill(bar).frame(width: 3)
            }
        }
    }

    @ViewBuilder
    private func trailingMark(for team: Team) -> some View {
        switch result {
        case .correctPick:
            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.success)
        case .wrongPick:
            Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(Theme.danger)
        case .actualWinner:
            Image(systemName: "circle.fill").font(.system(size: 8)).foregroundStyle(Theme.gold)
        case .none:
            if isPicked {
                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.pickTint)
            } else {
                Text("\(team.seed)").font(.caption2).monospacedDigit().foregroundStyle(Theme.textTertiary)
            }
        case .alsoRan:
            Text("\(team.seed)").font(.caption2).monospacedDigit().foregroundStyle(Theme.textTertiary)
        }
    }

    private var nameBold: Bool {
        isPicked || result == .correctPick || result == .actualWinner
    }

    private var nameColor: Color {
        switch result {
        case .correctPick, .actualWinner: return .white
        case .wrongPick, .alsoRan: return Theme.textSecondary
        case .none: return isPicked ? .white : Theme.textSecondary
        }
    }

    private var rowBackground: Color {
        switch result {
        case .correctPick: return Theme.success.opacity(0.18)
        case .wrongPick: return Theme.danger.opacity(0.15)
        case .none: return isPicked ? Theme.pickTint.opacity(0.16) : .clear
        default: return .clear
        }
    }

    private var accentBar: Color? {
        switch result {
        case .correctPick: return Theme.success
        case .wrongPick: return Theme.danger
        case .none: return isPicked ? Theme.pickTint : nil
        default: return nil
        }
    }
}

#Preview("Card states", traits: .sizeThatFitsLayout) {
    let teams = SeedData.makeTeams()
    let engine = BracketEngine()
    engine.buildBracket(from: teams)

    let picked = engine.node(round: 0, slot: 0)!
    engine.advanceWinner(for: picked, to: picked.teamA!)

    return VStack(spacing: 12)  { //12
        MatchCardView(node: picked)                            // has a pick
        MatchCardView(node: engine.node(round: 0, slot: 1)!)   // no pick yet
        MatchCardView(node: engine.node(round: 2, slot: 0)!)   // both TBD
    }
    .padding()
    .bracketBackground()
}
