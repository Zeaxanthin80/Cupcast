//
//  BracketEngine.swift
//  Cupcast
//
//  Phase 2 — BracketEngine.
//
//  Owns the in-memory binary tree of BracketNodes. This is the project's custom
//  data structure: it is built at runtime from the persisted Team/Match data and is
//  never itself persisted.
//
//  `@Observable` (the modern Observation framework, iOS 17+) rather than
//  ObservableObject/@Published — see the property-wrapper table in CLAUDE.md.
//  Injected at the app root with `.environment(engine)` and read back out with
//  `@Environment(BracketEngine.self)`.
//

import Foundation
import Observation

@Observable
final class BracketEngine {

    // MARK: - Canonical bracket shape
    //
    // Single source of truth for the tournament's shape. SeedData builds the
    // persisted matches from this, and buildBracket(from:) rebuilds the same shape
    // in memory, so the two can never drift apart.

    static let roundCount = 4

    /// Round-of-16 matchups by seed, in slot order (left→right in the bracket).
    /// Arranged so seeds 1 and 2 can only ever meet in the Final.
    static let r16SeedPairings: [(teamA: Int, teamB: Int)] = [
        (1, 16),   // slot 0
        (8, 9),    // slot 1
        (5, 12),   // slot 2
        (4, 13),   // slot 3
        (3, 14),   // slot 4
        (6, 11),   // slot 5
        (7, 10),   // slot 6
        (2, 15),   // slot 7
    ]

    /// 8, 4, 2, 1 for rounds 0...3 — each round is half the size of the one below.
    static func slotCount(inRound round: Int) -> Int {
        1 << (roundCount - 1 - round)
    }

    static func roundName(_ round: Int) -> String {
        switch round {
        case 0: return "Round of 16"
        case 1: return "Quarterfinal"
        case 2: return "Semifinal"
        case 3: return "Final"
        default: return "Round \(round)"
        }
    }

    // MARK: - State

    /// The Final. Nil until a bracket is built.
    private(set) var root: BracketNode?

    /// Every node, flat, for lookups and scoring. 15 once built.
    private(set) var allNodes: [BracketNode] = []

    // MARK: - Building the tree

    /// Builds the tree from persisted matches and replays any saved predictions.
    /// This is the real path, used once the store is populated.
    @discardableResult
    func buildBracket(from matches: [Match]) -> BracketNode {
        var byRound: [[BracketNode]] = []

        for round in 0..<Self.roundCount {
            // Dictionary keyed by slot (Objective 2.2) so the shape below drives the
            // build, not whatever order the fetch happened to return.
            let bySlot = Dictionary(
                matches.filter { $0.round == round }.map { ($0.slot, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            let nodes = (0..<Self.slotCount(inRound: round)).map { slot -> BracketNode in
                let match = bySlot[slot]
                // Only the leaves get teams up front; later rounds fill by cascade.
                let node = BracketNode(
                    round: round,
                    slot: slot,
                    teamA: round == 0 ? match?.teamA : nil,
                    teamB: round == 0 ? match?.teamB : nil,
                    match: match
                )
                node.actualWinner = match?.actualWinner
                return node
            }
            byRound.append(nodes)
        }

        let root = link(byRound)
        replayPersistedPredictions(byRound)
        return root
    }

    /// Builds the same tree from teams alone, pairing by seed. No store required,
    /// so SwiftUI previews can show a real bracket (Objective 2.2 — the array of 16
    /// teams seeding the tree).
    @discardableResult
    func buildBracket(from teams: [Team]) -> BracketNode {
        let bySeed = Dictionary(uniqueKeysWithValues: teams.map { ($0.seed, $0) })

        let leaves = Self.r16SeedPairings.enumerated().map { slot, pairing in
            BracketNode(
                round: 0,
                slot: slot,
                teamA: bySeed[pairing.teamA],
                teamB: bySeed[pairing.teamB]
            )
        }

        var byRound: [[BracketNode]] = [leaves]
        for round in 1..<Self.roundCount {
            byRound.append(
                (0..<Self.slotCount(inRound: round)).map { BracketNode(round: round, slot: $0) }
            )
        }

        return link(byRound)
    }

    /// Wires parent/child links between adjacent rounds and records the result.
    /// A node at (round r, slot s) feeds the winner into (round r + 1, slot s / 2),
    /// so slot s of round r+1 is fed by slots 2s and 2s+1 below it.
    @discardableResult
    private func link(_ byRound: [[BracketNode]]) -> BracketNode {
        for round in 1..<Self.roundCount {
            for (slot, node) in byRound[round].enumerated() {
                let left = byRound[round - 1][slot * 2]
                let right = byRound[round - 1][slot * 2 + 1]

                node.left = left
                node.right = right
                left.parent = node
                right.parent = node
            }
        }

        let root = byRound[Self.roundCount - 1][0]
        self.root = root
        self.allNodes = byRound.flatMap { $0 }
        return root
    }

    /// Re-applies saved picks from the bottom up, so each round's teams are already
    /// in place (via cascade) before that round's own pick is replayed.
    private func replayPersistedPredictions(_ byRound: [[BracketNode]]) {
        for round in 0..<Self.roundCount {
            for node in byRound[round] {
                guard let picked = node.match?.predictedWinner else { continue }
                advanceWinner(for: node, to: picked)
            }
        }
    }

    // MARK: - Predicting

    /// Records a pick and lets it propagate. The actual propagation is the `didSet`
    /// on BracketNode.predictedWinner — this method's job is to refuse picks for a
    /// team that isn't in the match (Objective 2.3 — guard).
    func advanceWinner(for node: BracketNode, to winner: Team) {
        guard winner.id == node.teamA?.id || winner.id == node.teamB?.id else { return }
        node.predictedWinner = winner
    }

    /// Clears a pick, which cascades upward and invalidates anything downstream.
    func clearPrediction(for node: BracketNode) {
        node.predictedWinner = nil
    }

    /// The predicted champion: whoever is picked to win the Final.
    func champion(of root: BracketNode) -> Team? {
        root.predictedWinner
    }

    /// Mirrors every node's pick AND actual result onto its persisted Match. Called
    /// after any pick or result change; one didSet can invalidate picks far up the
    /// tree, so syncing the whole tree (15 writes) is the simple way to guarantee
    /// store == tree. The caller owns the actual save — SwiftData writes happen in
    /// views through @Environment(\.modelContext), per the project conventions.
    func syncToStore() {
        for node in allNodes {
            node.match?.predictedWinner = node.predictedWinner
            node.match?.actualWinner = node.actualWinner
        }
    }

    // MARK: - Lookups

    func nodes(inRound round: Int) -> [BracketNode] {
        allNodes.filter { $0.round == round }.sorted { $0.slot < $1.slot }
    }

    func node(round: Int, slot: Int) -> BracketNode? {
        allNodes.first { $0.round == round && $0.slot == slot }
    }

    /// The team's Round-of-16 match — every team's entry point into the tree.
    func r16Node(for team: Team) -> BracketNode? {
        nodes(inRound: 0).first { $0.teamA?.id == team.id || $0.teamB?.id == team.id }
    }

    /// The team's matches through the predicted bracket, in round order: their R16
    /// match, then each later match they're picked to reach. A walk up the parent
    /// pointers — the reference-semantics payoff of BracketNode being a class.
    func path(for team: Team) -> [BracketNode] {
        guard var node = r16Node(for: team) else { return [] }
        var result = [node]
        while node.predictedWinner?.id == team.id, let parent = node.parent {
            node = parent
            result.append(node)
        }
        return result
    }

    /// Where the user's picks say this team's tournament ends.
    enum PredictedFinish: Equatable {
        case noPrediction                // their R16 match has no pick yet
        case eliminated(inRound: Int)    // picked to lose that round's match
        case advances(toRound: Int)      // picked into this round; no pick there yet
        case champion                    // picked to win the Final
    }

    /// Follows the picks from the team's R16 match upward until they lose, the
    /// picks run out, or they win the Final (Objective 2.3 — while + guard).
    func predictedFinish(for team: Team) -> PredictedFinish {
        guard var node = r16Node(for: team) else { return .noPrediction }

        while true {
            guard let picked = node.predictedWinner else {
                return node.round == 0 ? .noPrediction : .advances(toRound: node.round)
            }
            guard picked.id == team.id else {
                return .eliminated(inRound: node.round)
            }
            guard let parent = node.parent else { return .champion }
            node = parent
        }
    }

    // MARK: - Scoring

    /// Scores the bracket round by round. Later rounds are worth more, which is the
    /// point of the default [1, 2, 4, 8] (Objective 2.4 — default parameter value).
    /// A match only scores once its real result is known; unplayed matches are
    /// simply skipped rather than counted wrong.
    func calculateScore(pointsPerRound: [Int] = [1, 2, 4, 8]) -> [RoundScore] {
        (0..<Self.roundCount).map { round in
            let points = round < pointsPerRound.count ? pointsPerRound[round] : 0

            let correct = nodes(inRound: round).reduce(into: 0) { total, node in
                guard let predicted = node.predictedWinner,
                      let actual = node.actualWinner else { return }
                if predicted.id == actual.id { total += 1 }
            }

            return RoundScore(
                round: round,
                correctPicks: correct,
                pointsEarned: correct * points
            )
        }
    }

    /// Convenience for the Score Summary screen in Phase 5.
    func totalPoints(pointsPerRound: [Int] = [1, 2, 4, 8]) -> Int {
        calculateScore(pointsPerRound: pointsPerRound)
            .reduce(0) { $0 + $1.pointsEarned }
    }

    /// The most a bracket could score: every slot correct, weighted per round.
    /// 8×1 + 4×2 + 2×4 + 1×8 = 32 with the default weights.
    func maxPossiblePoints(pointsPerRound: [Int] = [1, 2, 4, 8]) -> Int {
        (0..<Self.roundCount).reduce(0) { total, round in
            let points = round < pointsPerRound.count ? pointsPerRound[round] : 0
            return total + Self.slotCount(inRound: round) * points
        }
    }

    // MARK: - Official results (demo)
    //
    // CLAUDE.md's concept scores the bracket "once real results are entered" but
    // never said how they get in. The mockup answers with a "reveal official
    // results" toggle over a fixed outcome table, so that is what this is: a
    // DEMONSTRATION outcome (the real 2026 knockouts haven't happened), one winning
    // seed per match slot, matching the mockup's ACTUALS exactly.

    static let demoActualWinnerSeeds: [String: Int] = [
        "0-0": 1, "0-1": 9, "0-2": 5, "0-3": 4, "0-4": 3, "0-5": 6, "0-6": 10, "0-7": 2,
        "1-0": 1, "1-1": 4, "1-2": 3, "1-3": 2,
        "2-0": 1, "2-1": 2,
        "3-0": 1,
    ]

    /// True once any actual result is present — the Score screen derives its
    /// "results in" state from this rather than a separate persisted flag.
    var resultsRevealed: Bool {
        allNodes.contains { $0.actualWinner != nil }
    }

    /// Stamps the demo outcome onto every node (and mirrors it to the store). The
    /// caller saves. Actuals are keyed by slot, independent of the user's bracket,
    /// so scoring asks the clean question "did you pick this slot's real winner?"
    func revealDemoResults(teams: [Team]) {
        let bySeed = Dictionary(uniqueKeysWithValues: teams.map { ($0.seed, $0) })
        for node in allNodes {
            let key = "\(node.round)-\(node.slot)"
            node.actualWinner = Self.demoActualWinnerSeeds[key].flatMap { bySeed[$0] }
        }
        syncToStore()
    }

    /// Clears all actual results (and mirrors that to the store). The caller saves.
    func clearResults() {
        for node in allNodes { node.actualWinner = nil }
        syncToStore()
    }
}
