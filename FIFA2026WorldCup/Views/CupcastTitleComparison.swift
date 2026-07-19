//
//  CupcastTitleComparison.swift
//  FIFA2026WorldCup
//
//  ⚠️ DESIGN HARNESS — not part of the shipping UI. Nothing in the app navigates
//  here; it exists so the two CUPCAST title treatments can be judged inside the
//  real bracket screen instead of in isolation. Safe to delete once the call is
//  made (and delete `cupcast_wordmark.imageset` too if `.text` wins, since that
//  asset is otherwise unused).
//
//  The three candidates:
//    .text    CupcastTitle         — live SwiftUI text on Theme.accentGradient.
//                                    Scales with Dynamic Type, sharp at any size,
//                                    no asset, and carries the tagline.
//    .image   CupcastWordmarkImage — 3D chrome artwork, black keyed out to real
//                                    transparency. ~3.9:1, about 540 KB.
//    .banner  CupcastBannerImage   — wide streaked lockup with a trophy in the U,
//                                    a star in the A, and a ball at each end.
//                                    ~6.8:1, about 870 KB; already genuinely
//                                    semi-transparent, so it needed no cleanup.
//
//  Both rasters measured close to the app palette (each accent within ~30 of its
//  Theme value), so the choice is about form and legibility, not colour.
//
//  Use the Xcode canvas: the previews below show them isolated, at several sizes,
//  and in the full bracket screen.
//

import SwiftUI
import SwiftData

struct CupcastTitleComparison: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                sectionLabel("1 · SwiftUI text — CupcastTitle")
                CupcastTitle()

                Divider().overlay(Theme.cardStroke)

                sectionLabel("2 · 3D chrome — CupcastWordmarkImage")
                CupcastWordmarkImage()

                Divider().overlay(Theme.cardStroke)

                sectionLabel("3 · Wide banner — CupcastBannerImage")
                CupcastBannerImage()

                Divider().overlay(Theme.cardStroke)

                sectionLabel("3D chrome at a range of heights")
                sizeLadder([72, 54, 40, 28]) { CupcastWordmarkImage(height: $0) }

                Divider().overlay(Theme.cardStroke)

                sectionLabel("Banner at a range of heights")
                sizeLadder([72, 54, 40, 28]) { CupcastBannerImage(height: $0) }

                Divider().overlay(Theme.cardStroke)

                sectionLabel("SwiftUI text at a range of sizes")
                sizeLadder([44, 34, 26, 18]) {
                    CupcastTitle(size: $0, showsTagline: false)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .bracketBackground()
        .navigationTitle("Title comparison")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2).fontWeight(.bold).tracking(1.1)
            .foregroundStyle(Theme.textSecondary)
    }

    /// One candidate rendered down a ladder of sizes, each labelled — the quickest
    /// way to see where a treatment stops being legible.
    private func sizeLadder<V: View>(
        _ sizes: [Int],
        @ViewBuilder content: @escaping (CGFloat) -> V
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(sizes, id: \.self) { s in
                HStack(spacing: 12) {
                    Text("\(s)pt")
                        .font(.caption2).monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 34, alignment: .trailing)
                    content(CGFloat(s))
                }
            }
        }
    }
}

// MARK: - Shared preview scaffolding

/// Builds an in-memory store plus an engine with a full set of favorite picks, so
/// the bracket previews below show a decided champion (and therefore the trophy).
@MainActor
private func previewEnvironment() -> (ModelContainer, BracketEngine) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)
    SeedData.seedIfNeeded(container.mainContext)

    let engine = BracketEngine()
    let matches = (try? container.mainContext.fetch(
        FetchDescriptor<Match>(sortBy: [SortDescriptor(\.round), SortDescriptor(\.slot)]))) ?? []
    engine.buildBracket(from: matches)
    for round in 0..<BracketEngine.roundCount {
        for node in engine.nodes(inRound: round) {
            guard let a = node.teamA, let b = node.teamB else { continue }
            engine.advanceWinner(for: node, to: a.seed < b.seed ? a : b)
        }
    }
    return (container, engine)
}

#Preview("Side by side") {
    let (container, engine) = previewEnvironment()
    return NavigationStack { CupcastTitleComparison() }
        .environment(engine)
        .modelContainer(container)
}

#Preview("Bracket — 3D chrome title") {
    let (container, engine) = previewEnvironment()
    return NavigationStack { BracketOverviewView(titleStyle: .image) }
        .environment(engine)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("Bracket — banner title") {
    let (container, engine) = previewEnvironment()
    return NavigationStack { BracketOverviewView(titleStyle: .banner) }
        .environment(engine)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("Bracket — SwiftUI title") {
    let (container, engine) = previewEnvironment()
    return NavigationStack { BracketOverviewView(titleStyle: .text) }
        .environment(engine)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
