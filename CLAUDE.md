# World Cup Bracket Predictor — Project Guide

## Context

School project for "App Development with Swift" course. Graded against a rubric and
against Certiport's "App Development with Swift" Objective Domains (Swift Programming
Language + View Building with SwiftUI sections). Theme: World Cup.

## Hard requirements (do not violate)

- SwiftUI only. **No UIKit** — no `UIViewControllerRepresentable`,
  `UIViewRepresentable`, or `import UIKit` unless there is truly no SwiftUI equivalent.
- A custom data structure implemented as **your own class** (not just a SwiftData
  model wrapper) — see `BracketNode` / `BracketEngine` below.
- Data persistence via **SwiftData** (`@Model`, `@Query`, `ModelContext`).
- Minimum 5 distinct screens. This plan has 6.
- App must be fully functional, visually coherent, and user-friendly — not a skeleton.
- Minimum deployment target: iOS 17 (required by SwiftData).

## App concept: Bracket Predictor & Score Challenge

A 16-team single-elimination World Cup knockout bracket. The user predicts a winner
for every match; predictions cascade automatically toward a champion. Once real
results are entered, the app scores the user's bracket, with points increasing per
round.

Bracket shape: Round of 16 (8 matches) → Quarterfinals (4) → Semifinals (2) →
Final (1) = 15 matches total, 4 rounds (round index 0–3).

## Architecture — three layers

1. **SwiftUI views** — 6 screens, every one a `struct` conforming to `View`. Read/write
   through `BracketEngine` for prediction logic; use `@Query` directly for simple
   list/browse screens.
2. **BracketEngine** (custom class, not persisted) — owns a binary tree of
   `BracketNode`s. This is the "custom data structure" requirement. Built at
   runtime from the persisted `Team`/`Match` data.
3. **SwiftData store** — two `@Model` classes, `Team` and `Match`, holding flat,
   query-friendly data.

## Structs vs classes — deliberate contrast (Objective 2.5.2)

This project must make the struct/class distinction **explicit and explainable**, not
incidental. Both are present by design:

- **Structs (value types)** — every SwiftUI view (`BracketOverviewView`,
  `MatchCardView`, `TeamRowView`, `WinnerPicker`, …) plus the `RoundScore` data model
  below. Chosen because they are copied, have no identity, and nothing needs to
  reference the same instance.
- **Classes (reference types)** — `Team`, `Match` (SwiftData requires classes),
  plus `BracketNode` and `BracketEngine`. Chosen because tree nodes link to each
  other (`parent`, `left`, `right`), share identity, and mutate in place.

`RoundScore` exists specifically to give a non-view struct data model for contrast:

```swift
struct RoundScore {
    let round: Int
    let correctPicks: Int
    let pointsEarned: Int
}
```

`calculateScore` returns `[RoundScore]`, which drives the Score Summary screen.

## SwiftData models

```swift
@Model
final class Team {
    var id: UUID
    var name: String
    var flagAssetName: String
    var seed: Int
    var group: String
}

@Model
final class Match {
    var id: UUID
    var round: Int              // 0 = Round of 16 ... 3 = Final
    var slot: Int               // position within round, encodes bracket shape
    var teamA: Team?
    var teamB: Team?
    var predictedWinner: Team?
    var actualWinner: Team?
    var matchDate: Date?
}
```

## Custom class: BracketNode + BracketEngine

`BracketNode` is your own Swift class (reference semantics required — nodes link to
each other) forming an in-memory binary tree mirroring the 15 `Match` records.
Since Phase 3 it is also `@Observable`, so SwiftUI redraws exactly the match cards
whose node the cascade mutates — the macro preserves `didSet`, verified against the
Phase 2 self-check harness before it was deleted. `BracketEngine` builds this tree
from persisted `Team`/`Match` data and owns the logic:

```swift
@Observable
class BracketNode {
    let id = UUID()
    var round: Int
    var teamA: Team?
    var teamB: Team?
    var predictedWinner: Team? {
        didSet { parent?.absorb(winner: predictedWinner, from: self) }
    }
    var actualWinner: Team?
    weak var parent: BracketNode?
    var left: BracketNode?
    var right: BracketNode?
}

@Observable
class BracketEngine {
    func buildBracket(from teams: [Team]) -> BracketNode { /* builds the tree */ }
    func advanceWinner(for node: BracketNode, to winner: Team) { /* propagates up */ }
    func calculateScore(pointsPerRound: [Int] = [1, 2, 4, 8]) -> [RoundScore] { /* … */ }
    func champion(of root: BracketNode) -> Team? { /* … */ }
}
```

## Property wrappers — required usage (Objective 3.6)

Target is iOS 17, so use the **modern Observation framework**. Do NOT use
`ObservableObject` / `@Published` / `@ObservedObject` / `@EnvironmentObject`.

| Older pattern (course materials may show this)   | Use this instead                                |
| ------------------------------------------------ | ----------------------------------------------- |
| `class M: ObservableObject { @Published var x }` | `@Observable class M { var x }`                 |
| `@ObservedObject var model` in a view            | plain property, or `@State` if the view owns it |
| `@EnvironmentObject var model`                   | `@Environment(M.self) var model`                |

Note: `@ObservedObject` and `@Observable` are not the same thing — `@ObservedObject`
is a wrapper placed on a _view property_, `@Observable` is a macro placed on the
_class declaration_. The certification's 3.6 wording says "Observable", matching the
modern approach.

Concrete homes for each required wrapper:

- **`@State`** — `MatchDetailView` owns `pickedWinner`; also selected match, sheet
  presentation flags.
- **`@Binding`** — `MatchDetailView` passes `$pickedWinner` down to a `WinnerPicker`
  child view, which reads _and writes_ the parent's value. This is the anchor example
  of "child edits parent data":

  ```swift
  struct MatchDetailView: View {
      let node: BracketNode
      @State private var pickedWinner: Team?
      var body: some View {
          WinnerPicker(node: node, selection: $pickedWinner)
      }
  }

  struct WinnerPicker: View {
      let node: BracketNode
      @Binding var selection: Team?
      var body: some View { /* tap a team → sets selection → parent updates */ }
  }
  ```

  `WinnerPicker` takes the `BracketNode`, not the persisted `Match`, on purpose:
  for every round after the Round of 16 the matchup exists only in memory,
  cascaded into the node — the store's `Match` rows carry teams for round 0 only.

- **`@Environment`** — `@Environment(\.modelContext)` for SwiftData writes;
  `@Environment(BracketEngine.self)` for the shared engine.
- **`@Query`** — team browser and predictions list read SwiftData directly.
- **`@Observable`** — on `BracketEngine`, injected at the app root via
  `.environment(engine)`; also on `BracketNode` (since Phase 3), which is what lets
  match cards redraw when the cascade mutates a node.

## Screens (6)

Top-level navigation is a `TabView` (`Views/RootTabView.swift`): Bracket / Teams /
Picks / Score, each tab its own `NavigationStack`. Match detail is a `.sheet` from
the bracket (the 3.5 anchor — kept as a sheet, not a push); team detail is a
`NavigationLink` push inside the Teams tab.

1. **Bracket overview** — scrollable tree view of all 16 teams collapsing toward
   a champion. Visual centerpiece. Built from `BracketEngine`'s tree.
2. **Match detail** — tap a match, see both teams, pick a winner via `WinnerPicker`
   child view (`@State` + `@Binding`). Feeds `BracketNode.predictedWinner`.
3. **Predictions** — flat `List` of every pick made so far, editable.
4. **Score summary** — score broken down by round from `[RoundScore]`.
5. **Team browser** — grid or list of all 16 teams.
6. **Team detail** — pushed from team browser via `NavigationLink`; flag, group,
   seed, match history.

## Objective Domain coverage (map every implementation choice back to these)

| Domain item                                              | Where it lives                                                                                                |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 2.1 Basic types, casting, constants/variables            | `Team`/`Match` properties; `let` vs `var` throughout                                                          |
| 2.2 Arrays, Dictionaries                                 | Array of 16 `Team`s seeding the tree; dictionary lookups by `id`                                              |
| 2.3 Control flow, Guard, ranges                          | `for round in 0..<4` building the tree; `guard let winner = ...`                                              |
| 2.4 Functions, param naming, defaults                    | `advanceWinner(for:to:)`, `calculateScore(pointsPerRound:)`                                                   |
| 2.5 Structs vs classes, initializers, property observers | `RoundScore`/views as structs vs `BracketNode`/`BracketEngine` as classes; `didSet` auto-advances the bracket |
| 2.6 Optionals, binding, chaining                         | `teamA`/`predictedWinner`/`actualWinner` are `Optional`; `if let`/`guard let`                                 |
| 2.7 Scope, shadowing                                     | Local vs instance vars inside engine methods                                                                  |
| 3.1–3.2 Layout, multiple views                           | `MatchCardView`, one `View` struct per screen                                                                 |
| 3.3 List views                                           | Predictions list, team browser                                                                                |
| 3.4 Extract subviews                                     | `MatchCardView`, `TeamCardView`, `RoundColumnView`, `WinnerPicker`                                            |
| 3.5 NavigationStack, Links, Sheets                       | Root `NavigationStack`, `NavigationLink` to team detail, `.sheet` for prediction picker                       |
| 3.6 @State/@Binding/@Environment/Observable              | See "Property wrappers" section above                                                                         |

## Conventions

- File layout: `Models/` (SwiftData `@Model` classes + `RoundScore`), `Logic/`
  (`BracketNode`, `BracketEngine`), `Views/` (one file per screen + subviews),
  `Resources/` (flag assets, seed data JSON).
- Seed the 16 teams with sample/preview data for SwiftUI previews — don't require
  a populated store to preview a view.
- **Flag images are Jose's job, not Claude's.** Seed `flagAssetName` with real asset
  names in the form `flag_<country>`, lowercase (e.g. `flag_argentina`); Jose adds
  the matching PNGs to `Assets.xcassets` himself. Never generate placeholder images,
  never invent a different naming scheme, and don't treat a missing PNG as a bug to
  fix. Views that show flags must degrade gracefully when an asset is absent, so
  previews and the simulator still render before the images land.
- **App icon** — `AppIcon.appiconset` holds a single opaque 1024×1024 `AppIcon.png`:
  a soccer ball drawn programmatically (truncated icosahedron) over the app's own
  dark background colors. One entry covers all appearances; the light/dark/tinted
  slots were deliberately removed. It must stay opaque with no pre-rounded corners —
  iOS applies the mask. Not a missing or placeholder asset; don't regenerate it.
- Prefer `guard let` for early returns over nested `if let`.
- Keep view bodies small; extract subviews per 3.4 rather than writing long
  single-view bodies.

## Build plan — work in phases, one at a time

**IMPORTANT: Do not build the whole app in one pass.** Complete one phase, stop, and
wait for review before starting the next. Each phase ends with a build that compiles
and runs in the simulator, and a git commit.

**Where the project stands is tracked inline below. The first phase not marked
COMPLETE is the next one to build — never assume a phase needs redoing because some
other note mentions it.** Mark a phase COMPLETE as part of that phase's own commit.
A commit can't contain its own SHA, so backfill SHAs later or just leave them off —
`git log` is the authority, these are only a convenience.

- **Phase 1 — Data layer.** ✅ COMPLETE — commit `856770d`. `Team`, `Match`,
  `RoundScore`. `ModelContainer` wired in the app entry point. Seed data for 16
  teams + 15 matches. Note: `Views/DebugStoreView.swift` was a throwaway
  verification screen from this phase — deleted in Phase 3 as planned.
  _Done when:_ app launches, store populates, data verifiable via a temporary
  debug list.
- **Phase 2 — BracketEngine.** ✅ COMPLETE. `BracketNode`, tree construction,
  `advanceWinner`, `champion`, `calculateScore`. No UI work. The canonical bracket
  shape (`r16SeedPairings`, `slotCount(inRound:)`, `roundName`) lives on
  `BracketEngine` as statics and `SeedData` builds from it — define the shape there
  and nowhere else. `Views/DebugEngineView.swift` was throwaway verification from
  this phase; deleted with `DebugStoreView` in Phase 3.
  _Done when:_ engine builds a correct 15-node tree and scoring returns correct
  `[RoundScore]` values, verified via `#Preview` or a debug harness view.
- **Phase 3 — Bracket overview screen.** ✅ COMPLETE. The visual centerpiece.
  `RoundColumnView` and `MatchCardView` extracted as subviews, plus `TeamSlotView`,
  `FlagView`, and `BracketConnector` (a custom `Shape`). App root is now
  `NavigationStack { BracketOverviewView() }` with the engine injected via
  `.environment`. Layout invariant: every round column shares one total height with
  cards centered in equal slices — the connector geometry depends on it, so don't
  give columns independent heights. `FlagView` layers the asset image over a
  placeholder in a `ZStack`; missing PNGs show the placeholder (no UIKit existence
  check), so console "No image named…" warnings are expected until the flags land.
  _Done when:_ all 4 rounds render and reflect engine state.
- **Phase 4 — Match detail + WinnerPicker.** ✅ COMPLETE. `@State`/`@Binding`
  pattern. Picks persist and cascade up the tree. Bracket cards are buttons
  presenting `MatchDetailView` via `.sheet(item:)` (disabled until both teams are
  known). Persistence path: Confirm → `engine.advanceWinner` (didSet cascade) →
  `engine.syncPredictionsToStore()` mirrors all 15 nodes onto their `Match` rows →
  `modelContext.save()` in the view. Relaunch replay was already built in Phase 2
  (`replayPersistedPredictions`, bottom-up). Flag PNGs landed before this phase;
  imagesets were renamed to the `flag_<country>` convention in commit `de683d6`.
  _Done when:_ picking a winner updates the bracket overview and survives relaunch.
- **Phase 5 — Predictions + Score summary.** ✅ COMPLETE. `@Query` list, editing,
  score breakdown, plus the tab shell and the dark restyle imported from Jose's
  claude.ai/design mockup. The app root is now `RootTabView` — a `TabView` with three
  tabs (Bracket / Picks / Score); the Teams tab is added in Phase 6 so no placeholder
  ships. Shared visual language lives in `Views/Theme.swift` (dark palette, accent
  gradient, `BracketBackground`, `GlassCard`, `.expandedHeavy()`); all pure SwiftUI,
  SF Pro approximates Archivo Expanded, real PNG flags kept. The engine is now built
  once at app launch (in `CupcastApp.init`) so any tab works first.
  "Official results" are a **labelled demo outcome** (`BracketEngine.demoActualWinnerSeeds`,
  matching the mockup's `ACTUALS`) revealed/hidden from the Score screen; the real
  2026 knockouts haven't happened. `syncPredictionsToStore` became `syncToStore`
  (mirrors both `predictedWinner` and `actualWinner`).
  _Done when:_ entering actual results produces a correct score by round.
- **Phase 6 — Team browser + Team detail + polish.** ✅ COMPLETE. Grid/list,
  `NavigationLink`, visual consistency pass, empty states. `TeamBrowserView` is a
  two-column `LazyVGrid` of `TeamCardView`s (named CardView, not RowView — it's a
  grid tile); each card is a `NavigationLink(value:)` resolved by
  `navigationDestination(for: Team.self)` — the project's 3.5 push anchor.
  `TeamDetailView` shows the color hero, the predicted finish
  (`BracketEngine.predictedFinish(for:)`, an enum with associated values), and the
  team's match history as `engine.path(for:)` — both are parent-pointer walks up
  the tree. Rows open the shared `MatchDetailView` sheet. Per-team national colors
  live in `Theme.teamColors` keyed by `flagAssetName` — view-layer only, the
  SwiftData `Team` model is untouched. Teams tab added to `RootTabView` (slot 2).
  _Done when:_ all 6 screens navigable and coherent.

## Version control — how this repo actually works

- **Commit directly to `main`. No feature branches, no pull requests.** Each phase
  ends with one commit on `main`, made after the phase has been reported and
  reviewed. Keep unrelated housekeeping in its own commit.
- **Claude Code cannot push — do not try.** This project's GitHub credential lives
  in Xcode's own account store (a Bearer token in the login keychain under
  `Xcode-SCM-Token-…`, account `Zeaxanthin80`). The git CLI can't read it: there is
  no `github.com` entry for the `osxkeychain` helper, no `gh` CLI, and no SSH key,
  so command-line `git push` fails with `could not read Username`.
- **Division of labor:** Claude commits locally; Jose pushes from Xcode
  (Source Control → Push…). Do not work around this by installing `gh`, creating a
  personal access token, or reading the Xcode token out of the keychain.
- Using the git CLI does **not** conflict with Xcode's source control. Both act on
  the same `.git` directory; only the credential stores are separate and independent.
- `.gitignore` excludes `build/`, `DerivedData/`, and `xcuserdata/`. Never commit
  Xcode derived data — one `xcodebuild -derivedDataPath build` run produces ~76MB
  across ~1,900 files.

## Working notes for Claude Code

- Read this file at the start of every session before making changes.
- **Build one phase at a time. Stop at each phase boundary and report what changed
  before continuing.**
- Confirm before restructuring the architecture described here — ask first if a
  change would affect the objective-domain mapping above.
- After each phase, state which objective-domain items that phase satisfied.
- **This file holds standing rules only — never paste a one-off session prompt into
  it.** A future session cannot tell a historical request from a live order, so a
  leftover "implement Phase 1" reads as an instruction to redo finished work. If a
  prompt contains something durable, write it down as a rule (see the flag-asset
  convention) and record progress in the build plan instead.
