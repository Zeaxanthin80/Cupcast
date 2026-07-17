//
//  SeedData.swift
//  FIFA2026WorldCup
//
//  Phase 1 — Data layer.
//
//  Factory for the initial store: 16 teams + the 15 matches that define the
//  Round of 16 → Final bracket shape. `seedIfNeeded` runs once at launch and
//  no-ops if the store already holds teams, so predictions survive relaunch.
//

import Foundation
import SwiftData

enum SeedData {

    /// Inserts the 16 teams and 15 matches exactly once. Idempotent: if any Team
    /// already exists, seeding is skipped so user predictions aren't wiped.
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<Team>())
        guard (existing?.isEmpty ?? true) else { return }

        let teams = makeTeams()
        for team in teams { context.insert(team) }

        let matches = makeMatches(for: teams)
        for match in matches { context.insert(match) }

        do {
            try context.save()
        } catch {
            // Non-fatal: log so the debug view still renders whatever inserted.
            print("SeedData: save failed — \(error)")
        }
    }

    // MARK: - Teams

    /// The 16 Round-of-16 teams. Seed = rough FIFA strength (1 strongest).
    /// Groups A–H (2 teams each) are arranged so no group-mates meet in the R16.
    static func makeTeams() -> [Team] {
        [
            Team(name: "Argentina",   flagAssetName: "flag_argentina",   seed: 1,  group: "A"),
            Team(name: "France",      flagAssetName: "flag_france",      seed: 2,  group: "H"),
            Team(name: "England",     flagAssetName: "flag_england",     seed: 3,  group: "B"),
            Team(name: "Brazil",      flagAssetName: "flag_brazil",      seed: 4,  group: "G"),
            Team(name: "Portugal",    flagAssetName: "flag_portugal",    seed: 5,  group: "E"),
            Team(name: "Spain",       flagAssetName: "flag_spain",       seed: 6,  group: "D"),
            Team(name: "Belgium",     flagAssetName: "flag_belgium",     seed: 7,  group: "F"),
            Team(name: "Morocco",     flagAssetName: "flag_morocco",     seed: 8,  group: "C"),
            Team(name: "USA",         flagAssetName: "flag_usa",         seed: 9,  group: "D"),
            Team(name: "Mexico",      flagAssetName: "flag_mexico",      seed: 10, group: "E"),
            Team(name: "Switzerland", flagAssetName: "flag_switzerland", seed: 11, group: "C"),
            Team(name: "Colombia",    flagAssetName: "flag_colombia",    seed: 12, group: "F"),
            Team(name: "Canada",      flagAssetName: "flag_canada",      seed: 13, group: "H"),
            Team(name: "Norway",      flagAssetName: "flag_norway",      seed: 14, group: "A"),
            Team(name: "Egypt",       flagAssetName: "flag_egypt",       seed: 15, group: "G"),
            Team(name: "Paraguay",    flagAssetName: "flag_paraguay",    seed: 16, group: "B"),
        ]
    }

    // MARK: - Matches

    /// Builds the 15-match knockout tree. Round of 16 (round 0) is fully populated
    /// with real matchups by seed; later rounds start empty (teams are TBD until the
    /// BracketEngine cascades predictions in Phase 2).
    static func makeMatches(for teams: [Team]) -> [Match] {
        // Look teams up by seed so the R16 pairings read clearly (Objective 2.2 —
        // dictionary keyed by an Int, built from the array).
        let bySeed = Dictionary(uniqueKeysWithValues: teams.map { ($0.seed, $0) })

        // Round of 16 pairings (teamA seed, teamB seed), slot order left→right in the
        // bracket. Arranged so seeds 1 and 2 can only meet in the Final.
        let r16Pairings: [(Int, Int)] = [
            (1, 16),   // slot 0
            (8, 9),    // slot 1
            (5, 12),   // slot 2
            (4, 13),   // slot 3
            (3, 14),   // slot 4
            (6, 11),   // slot 5
            (7, 10),   // slot 6
            (2, 15),   // slot 7
        ]

        var matches: [Match] = []

        // Round 0 — Round of 16 (8 matches, teams assigned).
        for (slot, pairing) in r16Pairings.enumerated() {
            matches.append(
                Match(
                    round: 0,
                    slot: slot,
                    teamA: bySeed[pairing.0],
                    teamB: bySeed[pairing.1],
                    matchDate: r16Dates[slot]
                )
            )
        }

        // Rounds 1–3 — Quarterfinals (4), Semifinals (2), Final (1). Empty shells.
        let laterRounds: [(round: Int, slots: Int, dates: [Date?])] = [
            (round: 1, slots: 4, dates: quarterfinalDates),
            (round: 2, slots: 2, dates: semifinalDates),
            (round: 3, slots: 1, dates: [finalDate]),
        ]
        for stage in laterRounds {
            for slot in 0..<stage.slots {
                matches.append(
                    Match(round: stage.round, slot: slot, matchDate: stage.dates[slot])
                )
            }
        }

        return matches   // 8 + 4 + 2 + 1 = 15
    }

    // MARK: - Plausible 2026 knockout dates (flavor; the Final is July 19, 2026)

    private static let r16Dates: [Date?] = [
        date(2026, 6, 28), date(2026, 6, 28), date(2026, 6, 29), date(2026, 6, 29),
        date(2026, 6, 30), date(2026, 6, 30), date(2026, 7, 1),  date(2026, 7, 1),
    ]
    private static let quarterfinalDates: [Date?] = [
        date(2026, 7, 4), date(2026, 7, 4), date(2026, 7, 5), date(2026, 7, 5),
    ]
    private static let semifinalDates: [Date?] = [
        date(2026, 7, 8), date(2026, 7, 9),
    ]
    private static let finalDate: Date? = date(2026, 7, 19)

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }
}
