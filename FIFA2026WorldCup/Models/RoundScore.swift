//
//  RoundScore.swift
//  FIFA2026WorldCup
//
//  Phase 1 — Data layer.
//
//  RoundScore is deliberately a `struct` (Objective 2.5.2 — value type). It has no
//  identity, is never mutated in place, and is only ever copied out of the engine to
//  drive the Score Summary screen. It exists to give the project a NON-view struct,
//  so the struct-vs-class contrast is explicit and explainable, not incidental.
//
//  Populated by BracketEngine.calculateScore(...) in Phase 2. Declared now so the
//  data layer is complete.
//

import Foundation

struct RoundScore {
    let round: Int          // 0 = Round of 16 ... 3 = Final
    let correctPicks: Int
    let pointsEarned: Int
}
