//
//  Team.swift
//  Cupcast
//
//  Phase 1 — Data layer.
//
//  A `Team` is a persisted SwiftData model, so it MUST be a `class`
//  (Objective 2.5.2 — SwiftData requires reference types). Flat, query-friendly
//  data: no relationships live here, keeping the model unambiguous for @Query.
//

import Foundation
import SwiftData

@Model
final class Team {
    var id: UUID
    var name: String
    var flagAssetName: String   // e.g. "flag_argentina" — matches an Assets.xcassets image
    var seed: Int               // 1 = strongest ... 16 = weakest (bracket seeding)
    var group: String           // group-stage letter, e.g. "A"

    init(
        id: UUID = UUID(),
        name: String,
        flagAssetName: String,
        seed: Int,
        group: String
    ) {
        self.id = id
        self.name = name
        self.flagAssetName = flagAssetName
        self.seed = seed
        self.group = group
    }
}
