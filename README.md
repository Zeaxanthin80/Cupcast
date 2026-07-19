<p align="center">
  <img src="Design/cupcast-wordmark-3d-1246x320.png" alt="Cupcast" width="520">
</p>

<p align="center"><strong>2026 Prediction Bracket</strong></p>

Cupcast is a World Cup bracket predictor. Pick a winner for all 15 knockout
matches, watch each pick cascade toward a champion, then reveal the tournament
outcome to see how you scored.

Built with SwiftUI and SwiftData for *App Development with Swift*.

---

## Using the app

The app opens on the bracket with all 16 teams seeded into the Round of 16.

**1. Make a pick.** Tap any match card. A sheet opens showing both teams — tap
one, then **Confirm Pick**. Only matches with both teams known are tappable.

**2. Watch it cascade.** Your winner is immediately seated in the next round, so
the Quarterfinal it feeds fills in as soon as you decide. Keep picking until the
Final decides a champion, who appears in the banner at the top with the trophy.

Change your mind at any point and the bracket corrects itself: if you flip an
early pick, any later pick that depended on that team is cleared automatically,
so the bracket can never contradict itself.

**3. Check your progress.** The **Picks** tab lists all 15 matches by round with
the pick you made for each, and shows how many of the 15 you've decided. Tap any
row to edit that pick without returning to the bracket.

**4. Browse the teams.** The **Teams** tab shows all 16. Tap one for its group,
seed, predicted finish, and its full path through your bracket.

**5. Score your bracket.** The **Score** tab starts empty. Tap **Reveal official
results** and the app scores every pick, broken down by round:

| Round        | Points per correct pick |
| ------------ | ----------------------- |
| Round of 16  | 1                       |
| Quarterfinal | 2                       |
| Semifinal    | 4                       |
| Final        | 8                       |

A perfect bracket scores **32**. Correct picks turn green across the app, wrong
ones red. **Hide official results** (or the back arrow) returns to your
predictions.

> The results are a clearly-labelled **demo outcome** — the real 2026 knockout
> rounds haven't been played yet.

Your picks are saved with SwiftData and survive relaunching the app.

---

## Requirements

- iOS 17 or later
- Xcode 26
- Open `Cupcast.xcodeproj` and run — no setup or dependencies

---

## How it's built

Three layers:

| Layer            | What it does                                                                    |
| ---------------- | ------------------------------------------------------------------------------- |
| **SwiftData**    | `Team` and `Match` — flat, query-friendly persistence                            |
| **BracketEngine**| A binary tree of `BracketNode`s built at runtime; owns all prediction logic      |
| **SwiftUI**      | Six screens, each a `View` struct, reading the engine and the store              |

The engine is the custom data structure: 15 nodes linked by `parent`/`left`/
`right`, mirroring the persisted matches. Picks propagate through a `didSet`
property observer rather than manual bookkeeping.

## Objective Domain coverage

| Domain item                                              | Where it lives                                                                                              |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 2.1 Basic types, casting, constants/variables            | [`Team`](Cupcast/Models/Team.swift), [`Match`](Cupcast/Models/Match.swift) properties; `let` vs `var` throughout |
| 2.2 Arrays, Dictionaries                                 | 16-`Team` array seeding the tree; `[Int: Team]` seed lookup in [`SeedData`](Cupcast/Resources/SeedData.swift) |
| 2.3 Control flow, guard, ranges                          | `for round in 0..<roundCount` building the tree; `guard let` early returns in [`BracketEngine`](Cupcast/Logic/BracketEngine.swift) |
| 2.4 Functions, param naming, defaults                    | `advanceWinner(for:to:)`, `calculateScore(pointsPerRound: [1,2,4,8])` in [`BracketEngine`](Cupcast/Logic/BracketEngine.swift) |
| 2.5 Structs vs classes, initializers, property observers | [`RoundScore`](Cupcast/Models/RoundScore.swift) + views as structs vs [`BracketNode`](Cupcast/Logic/BracketNode.swift)/`BracketEngine` as classes; `didSet` cascades each pick |
| 2.6 Optionals, binding, chaining                         | `teamA`/`predictedWinner`/`actualWinner` are `Optional`; `if let`/`guard let` throughout |
| 2.7 Scope, shadowing                                     | Local vs instance state inside [`BracketEngine`](Cupcast/Logic/BracketEngine.swift) methods |
| 3.1–3.2 Layout, multiple views                           | [`MatchCardView`](Cupcast/Views/MatchCardView.swift); one `View` struct per screen |
| 3.3 List views                                           | [`PredictionsView`](Cupcast/Views/PredictionsView.swift) list; [`TeamBrowserView`](Cupcast/Views/TeamBrowserView.swift) grid |
| 3.4 Extract subviews                                     | [`MatchCardView`](Cupcast/Views/MatchCardView.swift), [`TeamCardView`](Cupcast/Views/TeamBrowserView.swift), [`RoundColumnView`](Cupcast/Views/RoundColumnView.swift), [`WinnerPicker`](Cupcast/Views/WinnerPicker.swift) |
| 3.5 NavigationStack, Links, Sheets                       | `NavigationStack` per tab in [`RootTabView`](Cupcast/Views/RootTabView.swift); `NavigationLink` → [`TeamDetailView`](Cupcast/Views/TeamDetailView.swift); `.sheet` → [`MatchDetailView`](Cupcast/Views/MatchDetailView.swift) |
| 3.6 @State / @Binding / @Environment / Observable        | `@State pickedWinner` in [`MatchDetailView`](Cupcast/Views/MatchDetailView.swift) passed as `@Binding` to [`WinnerPicker`](Cupcast/Views/WinnerPicker.swift); `@Environment(BracketEngine.self)`; `@Query`; `@Observable` on the engine and nodes |

### Screens

| Screen           | File                                                                 |
| ---------------- | -------------------------------------------------------------------- |
| Bracket overview | [`BracketOverviewView`](Cupcast/Views/BracketOverviewView.swift)      |
| Match detail     | [`MatchDetailView`](Cupcast/Views/MatchDetailView.swift)              |
| Predictions      | [`PredictionsView`](Cupcast/Views/PredictionsView.swift)              |
| Score summary    | [`ScoreView`](Cupcast/Views/ScoreView.swift)                          |
| Team browser     | [`TeamBrowserView`](Cupcast/Views/TeamBrowserView.swift)              |
| Team detail      | [`TeamDetailView`](Cupcast/Views/TeamDetailView.swift)                |

Built entirely in SwiftUI — no UIKit. `Design/` holds source artwork and the
scripts that generated the app icon and wordmark; it sits outside the app target,
so nothing there ships in the bundle.
