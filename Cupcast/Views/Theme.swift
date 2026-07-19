//
//  Theme.swift
//  Cupcast
//
//  Phase 5 — shared visual language.
//
//  One home for the dark palette, accent gradient, and glassy-card constants the
//  whole app draws from, imported from Jose's claude.ai/design mockup. Centralizing
//  it here (rather than sprinkling hex values through views) keeps every screen
//  coherent and gives Phase 6 the same tokens to finish Teams/Team detail with.
//
//  All SwiftUI — no UIKit. The Archivo Expanded look is approximated with SF Pro at
//  heavy weight + expanded width (.fontWidth), so nothing depends on bundled fonts.
//

import SwiftUI

extension Color {
    /// 0xRRGGBB literal → Color. Handy for pasting the mockup's hex values verbatim.
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum Theme {
    
    // MARK: Accent (the pink → purple → cyan gradient the mockup runs everywhere)
    
    static let accentPink = Color(hex: 0xFF2D78)
    static let accentPurple = Color(hex: 0x7C3AED)
    static let accentCyan = Color(hex: 0x22D3EE)
    
    static let accentGradient = LinearGradient(
        colors: [accentPink, accentPurple, accentCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: Semantic
    
    static let gold = Color(hex: 0xFBBF24)
    static let success = Color(hex: 0x4ADE80)
    static let danger = Color(hex: 0xFB7185)
    
    // MARK: Surfaces & text (white at varying opacity, on the dark background)
    
    static let card = Color.white.opacity(0.05)
    static let cardStroke = Color.white.opacity(0.1)
    static let connectorStroke = Color.white.opacity(0.3)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.32)
    
    /// Winner-pick highlight — cyan, the mockup's "active" color.
    static let pickTint = accentCyan
    
    // MARK: Per-team national colors (from the mockup's TEAMS table)
    //
    // View-layer flavor only — deliberately NOT on the SwiftData Team model, which
    // CLAUDE.md fixes exactly. Keyed by flagAssetName, the team's stable string id.
    
    static let teamColors: [String: Color] = [
        "flag_argentina": Color(hex: 0x75AADB),
        "flag_france": Color(hex: 0x3B5BA7),
        "flag_england": Color(hex: 0xC8102E),
        "flag_brazil": Color(hex: 0x1DA64A),
        "flag_portugal": Color(hex: 0xC8102E),
        "flag_spain": Color(hex: 0xC60B1E),
        "flag_belgium": Color(hex: 0xC8102E),
        "flag_morocco": Color(hex: 0xB01E28),
        "flag_usa": Color(hex: 0x4A5AA0),
        "flag_mexico": Color(hex: 0x1DA64A),
        "flag_switzerland": Color(hex: 0xD52B1E),
        "flag_colombia": Color(hex: 0xE0B700),
        "flag_canada": Color(hex: 0xD80621),
        "flag_norway": Color(hex: 0xBA0C2F),
        "flag_egypt": Color(hex: 0xCE1126),
        "flag_paraguay": Color(hex: 0x3B6AB8),
    ]
    
    static func color(for team: Team?) -> Color {
        guard let team else { return accentPurple }
        return teamColors[team.flagAssetName] ?? accentPurple
    }
}

/// The layered dark background: a base vertical gradient with two off-screen color
/// glows, mirroring the mockup's radial-gradient stack.
struct BracketBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x070A16), Color(hex: 0x0B0F22), Color(hex: 0x090613)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(hex: 0x1B2450).opacity(0.9), .clear],
                center: UnitPoint(x: 0.2, y: -0.1),
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [Color(hex: 0x3A1147).opacity(0.8), .clear],
                center: UnitPoint(x: 1.1, y: 0.15),
                startRadius: 0,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Places the dark gradient behind a screen's content.
    func bracketBackground() -> some View {
        background(BracketBackground())
    }
    
    /// The Archivo-Expanded-ish display look: heavy weight, expanded width.
    func expandedHeavy() -> some View {
        fontWeight(.heavy).fontWidth(.expanded)
    }
}

/// The World Cup trophy image, sized by height (it's a tall, narrow photo, so the
/// width follows from the aspect ratio). Extracted so the asset name and treatment
/// live in one place — the champion banner, Score empty state, and Team detail all
/// draw the same trophy.
struct TrophyView: View {
    var height: CGFloat = 30
    
    var body: some View {
        Image("trophy")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .shadow(color: Theme.gold.opacity(0.35), radius: height * 0.15)
            .accessibilityLabel("World Cup trophy")
    }
}

/// The app's stylized wordmark — "CUPCAST" over a small tagline.
///
/// Drawn entirely in SwiftUI rather than shipped as an image, so it inherits the
/// app's own palette, stays sharp at any size, scales with Dynamic Type, and adds
/// no asset to maintain. The gradient fill is the same `Theme.accentGradient` used
/// by the Score hero and the primary buttons, which is what keeps the title
/// visually part of the app instead of pasted on top of it.
///
/// `.overlay(...).mask(...)` is the SwiftUI idiom for gradient-filled text: the
/// gradient is drawn over the layout and then clipped to the glyph shapes.
struct CupcastTitle: View {
    var size: CGFloat = 34
    var showsTagline: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("CUPCAST")
                .font(.system(size: size))
                .expandedHeavy()
                .tracking(size * 0.02)
                .foregroundStyle(.clear)                 // the mask supplies the fill
                .overlay { Theme.accentGradient }
                .mask {
                    Text("CUPCAST")
                        .font(.system(size: size))
                        .expandedHeavy()
                        .tracking(size * 0.02)
                }
                .shadow(color: Theme.accentPurple.opacity(0.55), radius: size * 0.28)
            
            if showsTagline {
                Text("2026 PREDICTION BRACKET")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .tracking(size * 0.055)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cupcast — 2026 prediction bracket")
    }
}

/// The wordmark as artwork: Jose's 3D chrome lettering with the ball set into the
/// P, cleaned to real transparency so it sits on the gradient with no box.
///
/// Sized by height like TrophyView, since it's a wide image and the width should
/// follow its aspect (roughly 3.9:1). Contrast with `CupcastTitle`, which draws the
/// same wordmark in live text — see `CupcastTitleStyle` for how the bracket screen
/// chooses between them.
struct CupcastWordmarkImage: View {
    var height: CGFloat = 54
    
    var body: some View {
        Image("cupcast_wordmark")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("Cupcast")
    }
}

/// The wide banner lockup: CUPCAST with a trophy in the U, a star in the A, and a
/// ball at each end, over light streaks.
///
/// Very wide (about 6.8:1), so a height of ~54 makes it span a phone's width. Its
/// streaked background is genuinely semi-transparent — 29% of the file is fully
/// clear and 47% partial — so it blends into the gradient instead of sitting in a
/// box, which is what makes it usable directly.
struct CupcastBannerImage: View {
    var height: CGFloat = 82
    var showsTagline: Bool = true
    
    var body: some View {
        VStack(spacing: height * 0.05) {
            Image("cupcast_wordmark")
                .resizable()
                .scaledToFit()
                .frame(height: height)
            
            if showsTagline {
                // Sized off the banner height so the pair stays proportional at
                // any scale, and matched to CupcastTitle's tagline treatment.
                Text("2026 PREDICTION BRACKET")
                    .font(.system(size: height * 0.17, weight: .bold))
                    .tracking(height * 0.036)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 16)
            }
        }
      //  .border(.white.opacity(0.2), width: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cupcast — 2026 prediction bracket")
    }
}

/// Which treatment the bracket screen uses for its title.
///
/// Exists so the candidates can be compared in the real screen rather than in
/// isolation — see `CupcastTitleComparison`. `.text` is the shipping default: it
/// scales with Dynamic Type and stays sharp at any size.
enum CupcastTitleStyle {
    case text      // CupcastTitle — live SwiftUI text
    case image     // CupcastWordmarkImage — the 3D chrome artwork
    case banner    // CupcastBannerImage — the wide streaked lockup
}

/// A reusable glassy card surface (Objective 3.4 — extracted, reused everywhere).
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 15
    @ViewBuilder var content: Content
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
            )
    }
}
