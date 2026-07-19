//
//  BracketConnector.swift
//  Cupcast
//
//  Phase 3 — Bracket overview.
//
//  The lines joining each pair of matches to the match they feed. A custom Shape —
//  pure SwiftUI drawing, no UIKit. The geometry leans on RoundColumnView's
//  invariant that all columns share one height with matches centered in equal
//  slices: for pair i of n, the children sit at the centers of slices 2i and 2i+1,
//  and the parent at their midpoint. So the shape needs nothing but pairCount.
//

import SwiftUI

struct BracketConnector: Shape {
    /// Number of parent matches to the right of this gap (pairs to the left).
    let pairCount: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let slice = rect.height / CGFloat(pairCount * 2)
        let xMid = rect.midX

        for pair in 0..<pairCount {
            let yTop = slice * (CGFloat(pair * 2) + 0.5)
            let yBottom = slice * (CGFloat(pair * 2) + 1.5)
            let yParent = (yTop + yBottom) / 2

            path.move(to: CGPoint(x: rect.minX, y: yTop))         // from upper child
            path.addLine(to: CGPoint(x: xMid, y: yTop))
            path.addLine(to: CGPoint(x: xMid, y: yBottom))        // down the spine
            path.addLine(to: CGPoint(x: rect.minX, y: yBottom))   // to lower child

            path.move(to: CGPoint(x: xMid, y: yParent))           // out to the parent
            path.addLine(to: CGPoint(x: rect.maxX, y: yParent))
        }

        return path
    }
}

/// The connector as a laid-out column, sized to sit between two RoundColumnViews.
struct BracketConnectorColumn: View {
    let pairCount: Int
    let matchAreaHeight: CGFloat
    let headerHeight: CGFloat

    var body: some View {
        BracketConnector(pairCount: pairCount)
            .stroke(Theme.connectorStroke, lineWidth: 1.5)
            .frame(width: 24, height: matchAreaHeight)
            .padding(.top, headerHeight)   // skip past the round-name header row
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    BracketConnectorColumn(pairCount: 4, matchAreaHeight: 672, headerHeight: 28)
        .padding()
}
