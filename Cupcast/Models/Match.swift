//
//  Match.swift
//  Cupcast
//
//  Phase 1 — Data layer.
//
//  A `Match` is a persisted SwiftData model (a `class`, per SwiftData).
//  `round` + `slot` encode the position in the knockout tree:
//    round 0 = Round of 16 (slots 0...7)
//    round 1 = Quarterfinals (slots 0...3)
//    round 2 = Semifinals    (slots 0...1)
//    round 3 = Final          (slot 0)
//  A match at (round r, slot s) feeds the winner into (round r+1, slot s / 2).
//
//  teamA / teamB / predictedWinner / actualWinner are all Optional (Objective 2.6):
//  later-round matches have no teams yet until predictions cascade in (Phase 2+).
//

import Foundation
import SwiftData

@Model
final class Match {
    var id: UUID
    var round: Int              // 0 = Round of 16 ... 3 = Final
    var slot: Int               // position within round, encodes bracket shape

    // Multiple to-one references to Team. Team declares no inverse, so SwiftData
    // does not attempt to disambiguate an inverse across these four relationships.
    var teamA: Team?
    var teamB: Team?
    var predictedWinner: Team?
    var actualWinner: Team?

    var matchDate: Date?

    init(
        id: UUID = UUID(),
        round: Int,
        slot: Int,
        teamA: Team? = nil,
        teamB: Team? = nil,
        predictedWinner: Team? = nil,
        actualWinner: Team? = nil,
        matchDate: Date? = nil
    ) {
        self.id = id
        self.round = round
        self.slot = slot
        self.teamA = teamA
        self.teamB = teamB
        self.predictedWinner = predictedWinner
        self.actualWinner = actualWinner
        self.matchDate = matchDate
    }
}
