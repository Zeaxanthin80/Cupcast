//
//  DebugEngineView.swift
//  FIFA2026WorldCup
//
//  ⚠️ TEMPORARY — Phase 2 verification only. Delete alongside DebugStoreView when
//  the real Bracket Overview screen lands in Phase 3.
//
//  Exercises BracketEngine against the live store and reports pass/fail. Every
//  check builds its own throwaway engine and only ever mutates in-memory nodes, so
//  running this never writes to SwiftData.
//

import SwiftUI
import SwiftData

/// A struct — it's an inert value describing one result, copied straight into the
/// list. Same reasoning as RoundScore.
struct DebugCheck: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let detail: String
}

struct DebugEngineView: View {
    @Query(sort: [SortDescriptor(\Match.round), SortDescriptor(\Match.slot)])
    private var matches: [Match]
    @Query(sort: \Team.seed) private var teams: [Team]

    var body: some View {
        let checks = runChecks()
        let passed = checks.filter(\.passed).count

        return List {
            Section("Result") {
                HStack {
                    Image(systemName: passed == checks.count
                          ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(passed == checks.count ? .green : .red)
                    Text("\(passed) / \(checks.count) checks passing")
                        .fontWeight(.semibold)
                }
            }

            Section("Self-checks") {
                ForEach(checks) { check in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: check.passed
                              ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(check.passed ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.name).fontWeight(.medium)
                            Text(check.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Engine Checks")
    }

    // MARK: - Checks

    private func runChecks() -> [DebugCheck] {
        guard !matches.isEmpty else {
            return [DebugCheck(name: "Store populated", passed: false,
                               detail: "No matches in the store to build from.")]
        }

        var checks: [DebugCheck] = []
        let engine = BracketEngine()
        let root = engine.buildBracket(from: matches)

        // 1 — shape
        checks.append(DebugCheck(
            name: "Tree has 15 nodes",
            passed: engine.allNodes.count == 15,
            detail: "Found \(engine.allNodes.count) (8 + 4 + 2 + 1)."
        ))

        // 2 — root is the Final
        checks.append(DebugCheck(
            name: "Root is the Final",
            passed: root.round == 3 && root.slot == 0 && root.parent == nil,
            detail: "round \(root.round), slot \(root.slot), parent: \(root.parent == nil ? "none" : "unexpected")."
        ))

        // 3 — leaves
        let leaves = engine.allNodes.filter(\.isLeaf)
        checks.append(DebugCheck(
            name: "8 leaves, all Round of 16",
            passed: leaves.count == 8 && leaves.allSatisfy { $0.round == 0 },
            detail: "\(leaves.count) leaves; rounds: \(Set(leaves.map(\.round)).sorted())."
        ))

        // 4 — per-round counts
        let counts = (0..<BracketEngine.roundCount).map { engine.nodes(inRound: $0).count }
        checks.append(DebugCheck(
            name: "Rounds sized 8/4/2/1",
            passed: counts == [8, 4, 2, 1],
            detail: "Got \(counts)."
        ))

        // 5 — parent/child wiring is mutually consistent
        let linkedOK = engine.allNodes.allSatisfy { node in
            guard let parent = node.parent else { return node === root }
            return parent.left === node || parent.right === node
        }
        checks.append(DebugCheck(
            name: "Parent/child links consistent",
            passed: linkedOK,
            detail: "Every non-root node is its parent's left or right child."
        ))

        // 6 — a node at (r, s) feeds (r+1, s/2)
        let feedsOK = engine.allNodes
            .filter { $0.round < 3 }
            .allSatisfy { $0.parent?.slot == $0.slot / 2 }
        checks.append(DebugCheck(
            name: "Node (r, s) feeds (r+1, s/2)",
            passed: feedsOK,
            detail: "Slot math matches the persisted bracket shape."
        ))

        // 7 — leaves seeded, later rounds empty
        let leavesSeeded = engine.nodes(inRound: 0).allSatisfy(\.isReady)
        let upperEmpty = engine.allNodes
            .filter { $0.round > 0 }
            .allSatisfy { $0.teamA == nil && $0.teamB == nil }
        checks.append(DebugCheck(
            name: "R16 seeded, later rounds start empty",
            passed: leavesSeeded && upperEmpty,
            detail: "Later rounds fill only by cascade, never from the store."
        ))

        checks.append(cascadeCheck())
        checks.append(invalidationCheck())
        checks.append(championCheck())
        checks.append(perfectScoreCheck())
        checks.append(noResultsScoreCheck())
        checks.append(partialScoreCheck())
        checks.append(previewTreeCheck())

        return checks
    }

    /// Picking an R16 winner should seat that team in the quarterfinal above it.
    private func cascadeCheck() -> DebugCheck {
        let engine = BracketEngine()
        engine.buildBracket(from: matches)

        guard let r16 = engine.node(round: 0, slot: 0),
              let qf = engine.node(round: 1, slot: 0),
              let winner = r16.teamA else {
            return DebugCheck(name: "Cascade fills the next round", passed: false,
                              detail: "Couldn't reach the nodes.")
        }

        engine.advanceWinner(for: r16, to: winner)
        let ok = qf.teamA?.id == winner.id
        return DebugCheck(
            name: "Cascade fills the next round",
            passed: ok,
            detail: "\(winner.name) won R16 slot 0 → QF slot 0 teamA is \(qf.teamA?.name ?? "nil")."
        )
    }

    /// Changing an early pick must invalidate the later pick that depended on it.
    private func invalidationCheck() -> DebugCheck {
        let engine = BracketEngine()
        engine.buildBracket(from: matches)

        guard let r16a = engine.node(round: 0, slot: 0),
              let r16b = engine.node(round: 0, slot: 1),
              let qf = engine.node(round: 1, slot: 0),
              let sf = engine.node(round: 2, slot: 0),
              let first = r16a.teamA, let second = r16b.teamA,
              let replacement = r16a.teamB else {
            return DebugCheck(name: "Changing a pick invalidates upstream", passed: false,
                              detail: "Couldn't reach the nodes.")
        }

        // Build a path to the semifinal, then pull the rug out from under it.
        engine.advanceWinner(for: r16a, to: first)
        engine.advanceWinner(for: r16b, to: second)
        engine.advanceWinner(for: qf, to: first)
        let reachedSF = sf.teamA?.id == first.id

        engine.advanceWinner(for: r16a, to: replacement)

        let qfCleared = qf.predictedWinner == nil
        let sfCleared = sf.teamA == nil
        return DebugCheck(
            name: "Changing a pick invalidates upstream",
            passed: reachedSF && qfCleared && sfCleared,
            detail: "\(first.name) → SF, then R16 flipped to \(replacement.name); QF pick cleared: \(qfCleared), SF slot cleared: \(sfCleared)."
        )
    }

    /// champion(of:) should be whoever is picked to win the Final.
    private func championCheck() -> DebugCheck {
        let engine = BracketEngine()
        let root = engine.buildBracket(from: matches)
        pickTeamAThroughout(engine)

        let champ = engine.champion(of: root)
        return DebugCheck(
            name: "champion(of:) returns the Final's pick",
            passed: champ != nil && champ?.id == root.predictedWinner?.id,
            detail: "Predicted champion: \(champ?.name ?? "nil")."
        )
    }

    /// A fully correct bracket: 8×1 + 4×2 + 2×4 + 1×8 = 32.
    private func perfectScoreCheck() -> DebugCheck {
        let engine = BracketEngine()
        engine.buildBracket(from: matches)
        pickTeamAThroughout(engine)

        // Mirror every prediction as the real result.
        for node in engine.allNodes { node.actualWinner = node.predictedWinner }

        let scores = engine.calculateScore()
        let total = engine.totalPoints()
        let perRound = scores.map(\.pointsEarned)
        return DebugCheck(
            name: "Perfect bracket scores 32",
            passed: total == 32 && perRound == [8, 8, 8, 8],
            detail: "Per round \(perRound) = \(total). (8×1, 4×2, 2×4, 1×8)"
        )
    }

    /// No real results yet → nothing scores, rather than everything scoring wrong.
    private func noResultsScoreCheck() -> DebugCheck {
        let engine = BracketEngine()
        engine.buildBracket(from: matches)
        pickTeamAThroughout(engine)

        let total = engine.totalPoints()
        let correct = engine.calculateScore().map(\.correctPicks)
        return DebugCheck(
            name: "Unplayed matches score 0",
            passed: total == 0 && correct == [0, 0, 0, 0],
            detail: "Full bracket predicted, no actual results entered → \(total) points."
        )
    }

    /// Wrong picks must not score, and the round weighting must be respected.
    private func partialScoreCheck() -> DebugCheck {
        let engine = BracketEngine()
        engine.buildBracket(from: matches)
        pickTeamAThroughout(engine)

        // Right on exactly two R16 matches, wrong everywhere else.
        for node in engine.allNodes { node.actualWinner = nil }
        let r16 = engine.nodes(inRound: 0)
        r16[0].actualWinner = r16[0].predictedWinner            // correct
        r16[1].actualWinner = r16[1].predictedWinner            // correct
        r16[2].actualWinner = r16[2].teamB                      // wrong (picked teamA)

        // One correct Final pick is worth 8 on its own.
        if let final = engine.root { final.actualWinner = final.predictedWinner }

        let scores = engine.calculateScore()
        let expected = 2 * 1 + 8
        let total = engine.totalPoints()
        return DebugCheck(
            name: "Partial bracket weights rounds correctly",
            passed: total == expected && scores[0].correctPicks == 2,
            detail: "2 correct R16 (2×1) + correct Final (1×8) = \(total), expected \(expected)."
        )
    }

    /// The preview path (teams only, no store) must build the same R16 as the store.
    private func previewTreeCheck() -> DebugCheck {
        guard teams.count == 16 else {
            return DebugCheck(name: "buildBracket(from: teams) matches the store",
                              passed: false, detail: "Expected 16 teams, found \(teams.count).")
        }

        let fromTeams = BracketEngine()
        fromTeams.buildBracket(from: teams)
        let fromStore = BracketEngine()
        fromStore.buildBracket(from: matches)

        let a = fromTeams.nodes(inRound: 0).map { "\($0.teamA?.name ?? "-")/\($0.teamB?.name ?? "-")" }
        let b = fromStore.nodes(inRound: 0).map { "\($0.teamA?.name ?? "-")/\($0.teamB?.name ?? "-")" }
        return DebugCheck(
            name: "buildBracket(from: teams) matches the store",
            passed: a == b && fromTeams.allNodes.count == 15,
            detail: a == b ? "Both paths produce identical R16 pairings."
                           : "Diverged: \(a.first ?? "-") vs \(b.first ?? "-")."
        )
    }

    // MARK: - Helper

    /// Predicts teamA at every match, round by round, so the cascade has filled in
    /// each round's teams before that round is picked.
    private func pickTeamAThroughout(_ engine: BracketEngine) {
        for round in 0..<BracketEngine.roundCount {
            for node in engine.nodes(inRound: round) {
                guard let teamA = node.teamA else { continue }
                engine.advanceWinner(for: node, to: teamA)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)
    SeedData.seedIfNeeded(container.mainContext)
    return NavigationStack { DebugEngineView() }
        .modelContainer(container)
}
