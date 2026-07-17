//
//  Theme.swift
//  FIFA2026WorldCup
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
    static let cardStroke = Color.white.opacity(0.09)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.32)

    /// Winner-pick highlight — cyan, the mockup's "active" color.
    static let pickTint = accentCyan
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
