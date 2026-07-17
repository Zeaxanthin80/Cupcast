//
//  FlagView.swift
//  FIFA2026WorldCup
//
//  Phase 3 — Bracket overview.
//
//  Shows a team's flag from Assets.xcassets, degrading gracefully while the PNGs
//  haven't been added yet (per the flag convention in CLAUDE.md: Jose supplies the
//  images; views must render without them).
//
//  SwiftUI has no API to ask whether an asset exists — that would take
//  UIImage(named:), which is UIKit and off-limits. So instead the placeholder sits
//  UNDER the Image in a ZStack: a missing asset draws nothing, letting the
//  placeholder show through; once the PNG lands, the image covers it. No UIKit,
//  no code change when the assets arrive.
//

import SwiftUI

struct FlagView: View {
    let team: Team?
    // Defaults are the bracket-card size; MatchDetailView passes larger ones.
    var width: CGFloat = 21
    var height: CGFloat = 15

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: height * 0.2)
                .fill(.quaternary)

            if let team {
                Text(team.name.prefix(1))
                    .font(.system(size: height * 0.6, weight: .bold))
                    .foregroundStyle(.secondary)

                Image(team.flagAssetName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.2))
    }
}

#Preview("Card size, detail size, empty", traits: .sizeThatFitsLayout) {
    HStack(spacing: 12) {
        FlagView(team: SeedData.makeTeams().first)
        FlagView(team: SeedData.makeTeams().first, width: 63, height: 45)
        FlagView(team: nil)
    }
    .padding()
}
