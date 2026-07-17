//
//  BracketNode.swift
//  FIFA2026WorldCup
//
//  Phase 2 — BracketEngine.
//
//  BracketNode is a CLASS by necessity (Objective 2.5.2 — reference type). Nodes
//  link to one another through parent/left/right, share identity, and mutate in
//  place; if they were structs the tree would be copied apart on every assignment
//  and a child could never reach its parent. Contrast with RoundScore, which is a
//  struct precisely because it has none of those needs.
//
//  The tree mirrors the 15 persisted Match records:
//      round 0 = Round of 16 → the 8 leaves (the only nodes seeded with real teams)
//      round 3 = Final       → the root
//  A node at (round r, slot s) is the child of (round r + 1, slot s / 2).
//

import Foundation

class BracketNode: Identifiable {
    let id = UUID()

    let round: Int
    let slot: Int

    var teamA: Team?
    var teamB: Team?

    /// Property observer (Objective 2.5.3): setting a pick immediately pushes it
    /// into the parent match. This single `didSet` is what makes predictions
    /// cascade all the way toward the champion without any caller doing the work.
    var predictedWinner: Team? {
        didSet { parent?.absorb(winner: predictedWinner, from: self) }
    }

    var actualWinner: Team?

    /// `weak` breaks the reference cycle: a parent owns its children strongly,
    /// children point back weakly. Without this the whole tree would leak.
    weak var parent: BracketNode?
    var left: BracketNode?
    var right: BracketNode?

    /// Back-reference to the persisted record this node mirrors, so Phase 4 can
    /// write picks through to SwiftData. Nil for trees built from teams alone
    /// (previews), which is why it stays Optional.
    var match: Match?

    init(
        round: Int,
        slot: Int,
        teamA: Team? = nil,
        teamB: Team? = nil,
        match: Match? = nil
    ) {
        self.round = round
        self.slot = slot
        self.teamA = teamA
        self.teamB = teamB
        self.match = match
    }

    /// Round-of-16 nodes are the leaves — they're the only ones with teams up front.
    var isLeaf: Bool { left == nil && right == nil }

    /// Both teams known, so this match can actually be predicted.
    var isReady: Bool { teamA != nil && teamB != nil }

    /// Seats a child's winner on the correct side of this match. Called from the
    /// child's `didSet`, never directly.
    func absorb(winner: Team?, from child: BracketNode) {
        if child === left {
            teamA = winner
        } else if child === right {
            teamB = winner
        } else {
            return   // not our child — ignore
        }

        // A pick for a team that is no longer standing in this match is stale, so
        // drop it. Clearing it re-fires this didSet on the way up, which invalidates
        // the rest of the path to the Final. That is what makes changing an early
        // pick correctly tear down everything that depended on it.
        guard let current = predictedWinner else { return }
        if current.id != teamA?.id && current.id != teamB?.id {
            predictedWinner = nil
        }
    }
}
