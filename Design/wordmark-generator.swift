// CUPCAST wordmark generator — elaborate treatment, app palette, transparent PNG.
//
//   swift wordmark.swift ball   out.png preview.png
//   swift wordmark.swift trophy out.png preview.png <trophy.png>
//
// Letterforms come from CoreText (SF Pro heavy, expanded), converted to CGPaths so
// every effect — chrome banding, inner bevels, outline, glow — is drawn into the
// glyph shapes. Palette is the app's Theme: pink FF2D78 -> purple 7C3AED -> cyan
// 22D3EE, gold FBBF24, navy 0B0F22. Output keeps a real alpha channel.

import Foundation
import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

// MARK: - Args

let args = CommandLine.arguments
guard args.count >= 4 else { print("usage: wordmark <ball|trophy> <out> <preview> [trophy.png]"); exit(1) }
let mode = args[1]
let outURL = URL(fileURLWithPath: args[2])
let previewURL = URL(fileURLWithPath: args[3])

// MARK: - Palette

let cs = CGColorSpaceCreateDeviceRGB()
func rgba(_ hex: UInt, _ a: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF)/255, green: Double((hex >> 8) & 0xFF)/255,
            blue: Double(hex & 0xFF)/255, alpha: a)
}
let pink: UInt = 0xFF2D78, purple: UInt = 0x7C3AED, cyan: UInt = 0x22D3EE
let gold: UInt = 0xFBBF24, navy: UInt = 0x0B0F22

// MARK: - Font: SF Pro heavy, expanded (fallback: slight affine stretch)

let fontSize: CGFloat = 300
let baseFont = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
let expandedDesc = baseFont.fontDescriptor.addingAttributes([
    .traits: [NSFontDescriptor.TraitKey.width: NSNumber(value: 0.30)]
])
let font = NSFont(descriptor: expandedDesc, size: fontSize) ?? baseFont

func advance(_ f: NSFont, _ s: String) -> CGFloat {
    let a = NSAttributedString(string: s, attributes: [.font: f])
    return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(a), nil, nil, nil))
}
// If the width trait did nothing, fake the expansion with a horizontal stretch.
let needsStretch = abs(advance(font, "M") - advance(baseFont, "M")) < 0.5
let stretchX: CGFloat = needsStretch ? 1.07 : 1.0

// MARK: - Text -> CGPath

func wordPath(_ s: String) -> (path: CGPath, width: CGFloat, glyphBoxes: [CGRect]) {
    let attr = NSAttributedString(string: s, attributes: [.font: font, .kern: 2])
    let line = CTLineCreateWithAttributedString(attr)
    let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    let path = CGMutablePath()
    var boxes: [CGRect] = []
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    for run in runs {
        let attrs = CTRunGetAttributes(run) as NSDictionary
        let runFont = attrs[kCTFontAttributeName as String] as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for i in 0..<count {
            guard let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }
            let t = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
            path.addPath(g, transform: t)
            boxes.append(g.boundingBoxOfPath.applying(t))
        }
    }
    return (path, width, boxes)
}

let capH = font.capHeight

// MARK: - Layout (baseline at y = 0, before shear)

var textPath = CGMutablePath()
var ballCenter: CGPoint? = nil
var ballDiameter: CGFloat = 0
var trophyRect: CGRect? = nil
var totalW: CGFloat = 0

if mode == "ball" {
    // The full word stays intact — the ball plugs into the P's bowl, so it can't
    // be misread as an extra letter O.
    let word = wordPath("CUPCAST")
    textPath.addPath(word.path)
    let pBox = word.glyphBoxes[2]              // the P
    ballDiameter = pBox.width * 0.58
    ballCenter = CGPoint(x: pBox.midX + pBox.width * 0.115, y: capH * 0.665)
    totalW = word.width
} else {
    let word = wordPath("CUPCAS")
    textPath.addPath(word.path)
    let trophyH = capH * 1.30
    let trophyW = trophyH * (591.0 / 1500.0)
    trophyRect = CGRect(x: word.width + capH * 0.05, y: -capH * 0.05,
                        width: trophyW, height: trophyH)
    totalW = word.width + capH * 0.05 + trophyW
}

// Sporty slant + optional stretch, applied about the baseline.
let shear: CGFloat = 0.105                     // ~6 degrees
var slant = CGAffineTransform(a: stretchX, b: 0, c: shear, d: 1, tx: 0, ty: 0)
let slantedText = textPath.copy(using: &slant)!
if var bc = ballCenter {
    ballCenter = CGPoint(x: bc.x * stretchX + bc.y * shear, y: bc.y)
}
if let tr = trophyRect {
    trophyRect = CGRect(x: tr.origin.x * stretchX + tr.origin.y * shear, y: tr.origin.y,
                        width: tr.width, height: tr.height)
}

// MARK: - Canvas sized to the artwork + glow padding

let bbox = slantedText.boundingBoxOfPath
    .union(trophyRect ?? slantedText.boundingBoxOfPath)
let pad: CGFloat = 150
let W = Int((bbox.width + (ballCenter != nil ? ballDiameter * 0.2 : 0) + pad * 2).rounded(.up))
let H = Int((max(bbox.height, capH * 1.5) + pad * 2).rounded(.up))
let origin = CGPoint(x: pad - bbox.minX, y: pad - bbox.minY)

guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                          space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
ctx.translateBy(x: origin.x, y: origin.y)

// MARK: - Effect helpers

func innerShadow(_ path: CGPath, color: CGColor, offset: CGSize, blur: CGFloat) {
    ctx.saveGState()
    // Even-odd so glyph counters (the holes in P, A, C…) stay holes regardless of
    // each contour's winding direction — nonzero was filling some of them solid.
    ctx.addPath(path); ctx.clip(using: .evenOdd)
    ctx.setShadow(offset: offset, blur: blur, color: color)
    let big = path.boundingBoxOfPath.insetBy(dx: -2000, dy: -2000)
    let inv = CGMutablePath()
    inv.addRect(big); inv.addPath(path)
    ctx.addPath(inv)
    ctx.setFillColor(rgba(0x000000))
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
}

// MARK: - 1) Outer glow (purple, like the app's title)

ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 90, color: rgba(purple, 0.85))
ctx.addPath(slantedText)
ctx.setFillColor(rgba(purple, 1))
ctx.fillPath(using: .evenOdd)
ctx.restoreGState()

// MARK: - 2) Outline: dark navy rim outside the letters

ctx.saveGState()
ctx.addPath(slantedText)
ctx.setStrokeColor(rgba(navy, 1))
ctx.setLineWidth(fontSize * 0.075)
ctx.setLineJoin(.round)
ctx.strokePath()
ctx.restoreGState()

// MARK: - 3) Chrome fill: app ramp left->right, banded vertically

ctx.saveGState()
ctx.addPath(slantedText); ctx.clip(using: .evenOdd)

let ramp = CGGradient(colorsSpace: cs,
                      colors: [rgba(pink), rgba(purple), rgba(cyan)] as CFArray,
                      locations: [0, 0.52, 1])!
ctx.drawLinearGradient(ramp,
                       start: CGPoint(x: bbox.minX, y: 0),
                       end: CGPoint(x: bbox.maxX, y: 0), options: [])

// gloss: white sheen over the top half
let gloss = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.62),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
] as CFArray, locations: [0, 0.7, 1])!
ctx.drawLinearGradient(gloss,
                       start: CGPoint(x: 0, y: capH),
                       end: CGPoint(x: 0, y: capH * 0.46), options: [])

// chrome horizon: a crisp darker seam just below the middle
let seam = CGGradient(colorsSpace: cs, colors: [
    rgba(navy, 0.0), rgba(navy, 0.34), rgba(navy, 0.0),
] as CFArray, locations: [0, 0.5, 1])!
ctx.drawLinearGradient(seam,
                       start: CGPoint(x: 0, y: capH * 0.55),
                       end: CGPoint(x: 0, y: capH * 0.38), options: [])

// depth: darken toward the foot
let foot = CGGradient(colorsSpace: cs, colors: [
    rgba(navy, 0.0), rgba(navy, 0.42),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(foot,
                       start: CGPoint(x: 0, y: capH * 0.40),
                       end: CGPoint(x: 0, y: -capH * 0.02), options: [])
ctx.restoreGState()

// MARK: - 4) Bevels: light from upper-left, dark from lower-right

innerShadow(slantedText, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.95),
            offset: CGSize(width: fontSize * 0.016, height: -fontSize * 0.016), blur: fontSize * 0.03)
innerShadow(slantedText, color: rgba(navy, 0.9),
            offset: CGSize(width: -fontSize * 0.014, height: fontSize * 0.014), blur: fontSize * 0.035)

// MARK: - 5) The themed object

// -- 5a. Soccer ball (vector truncated icosahedron, same construction as the icon)

struct V3 { var x, y, z: Double }
func -(a: V3, b: V3) -> V3 { V3(x: a.x-b.x, y: a.y-b.y, z: a.z-b.z) }
func +(a: V3, b: V3) -> V3 { V3(x: a.x+b.x, y: a.y+b.y, z: a.z+b.z) }
func *(a: V3, s: Double) -> V3 { V3(x: a.x*s, y: a.y*s, z: a.z*s) }
func dot(_ a: V3, _ b: V3) -> Double { a.x*b.x + a.y*b.y + a.z*b.z }
func len(_ a: V3) -> Double { dot(a, a).squareRoot() }
func norm(_ a: V3) -> V3 { a * (1 / len(a)) }
func cross(_ a: V3, _ b: V3) -> V3 {
    V3(x: a.y*b.z - a.z*b.y, y: a.z*b.x - a.x*b.z, z: a.x*b.y - a.y*b.x)
}

func drawBall(center: CGPoint, diameter: CGFloat) {
    let r = diameter / 2
    let rect = CGRect(x: center.x - r, y: center.y - r, width: diameter, height: diameter)

    // drop shadow behind the ball so it pops off the letters
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -diameter * 0.05),
                  blur: diameter * 0.16, color: rgba(navy, 0.75))
    ctx.setFillColor(rgba(0x14161C))
    ctx.fillEllipse(in: rect)
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addEllipse(in: rect); ctx.clip()

    let phi = (1 + 5.0.squareRoot()) / 2
    var ico: [V3] = []
    for s1 in [-1.0, 1.0] { for s2 in [-1.0, 1.0] {
        ico.append(V3(x: 0, y: s1, z: s2 * phi))
        ico.append(V3(x: s1, y: s2 * phi, z: 0))
        ico.append(V3(x: s1 * phi, y: 0, z: s2))
    } }
    let edge = 2.0
    func neighbors(_ i: Int) -> [Int] {
        (0..<ico.count).filter { $0 != i && abs(len(ico[$0] - ico[i]) - edge) < 1e-6 }
    }
    var triangles: [[Int]] = []
    for a in 0..<ico.count {
        let na = neighbors(a)
        for b in na where b > a {
            for c in na where c > b && abs(len(ico[c] - ico[b]) - edge) < 1e-6 {
                triangles.append([a, b, c])
            }
        }
    }
    func ordered(_ pts: [V3]) -> [V3] {
        var c = V3(x: 0, y: 0, z: 0); for p in pts { c = c + p }
        c = norm(c * (1 / Double(pts.count)))
        let u = norm(abs(c.z) < 0.9 ? cross(c, V3(x: 0, y: 0, z: 1)) : cross(c, V3(x: 1, y: 0, z: 0)))
        let v = cross(c, u)
        return pts.sorted { atan2(dot($0, v), dot($0, u)) < atan2(dot($1, v), dot($1, u)) }
    }
    var pentagons: [[V3]] = [], hexagons: [[V3]] = []
    for i in 0..<ico.count {
        let vi = ico[i]
        pentagons.append(ordered(neighbors(i).map { vi + (ico[$0] - vi) * (1.0/3.0) }).map(norm))
    }
    for t in triangles {
        let (a, b, c) = (ico[t[0]], ico[t[1]], ico[t[2]])
        var pts: [V3] = []
        for (p, q) in [(a, b), (b, c), (c, a)] {
            pts.append(p + (q - p) * (1.0/3.0)); pts.append(p + (q - p) * (2.0/3.0))
        }
        hexagons.append(ordered(pts).map(norm))
    }

    var w = norm(V3(x: 0, y: 1, z: phi))
    let tilt = 0.30
    w = norm(V3(x: w.x + tilt * 0.35, y: w.y - tilt, z: w.z))
    let u = norm(cross(w, V3(x: 0, y: 1, z: 0)))
    let v = cross(w, u)
    let over = 1.05
    func proj(_ p: V3) -> CGPoint {
        CGPoint(x: center.x + dot(p, u) * r * over, y: center.y + dot(p, v) * r * over)
    }
    struct Face { let pts: [V3]; let dark: Bool; let depth: Double }
    var faces: [Face] = []
    for p in pentagons { var c = V3(x:0,y:0,z:0); for q in p { c = c + q }
        faces.append(Face(pts: p, dark: true, depth: dot(norm(c), w))) }
    for h in hexagons { var c = V3(x:0,y:0,z:0); for q in h { c = c + q }
        faces.append(Face(pts: h, dark: false, depth: dot(norm(c), w))) }
    for f in faces.filter({ $0.depth > 0 }).sorted(by: { $0.depth < $1.depth }) {
        let p = CGMutablePath()
        p.addLines(between: f.pts.map(proj)); p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(f.dark ? rgba(0x14161C) : rgba(0xFCFCFD))
        ctx.fillPath()
        ctx.addPath(p)
        ctx.setStrokeColor(rgba(0x17191E, 0.55))
        ctx.setLineWidth(diameter * 0.004)
        ctx.strokePath()
    }
    let shade = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0, green: 0, blue: 0, alpha: 0),
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.06),
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.42),
    ] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawRadialGradient(shade,
        startCenter: CGPoint(x: center.x - r * 0.22, y: center.y + r * 0.22), startRadius: 0,
        endCenter: center, endRadius: r, options: [.drawsAfterEndLocation])
    let hi = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.42),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0),
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(hi,
        startCenter: CGPoint(x: center.x - r * 0.34, y: center.y + r * 0.36), startRadius: 0,
        endCenter: CGPoint(x: center.x - r * 0.34, y: center.y + r * 0.36), endRadius: r * 0.72,
        options: [])
    ctx.restoreGState()
}

if let c = ballCenter {
    drawBall(center: c, diameter: ballDiameter)
}

// -- 5b. Trophy as the final T

if let tr = trophyRect {
    guard args.count >= 5,
          let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[4]) as CFURL, nil),
          let trophy = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        print("trophy source missing"); exit(1)
    }
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 60, color: rgba(gold, 0.75))
    ctx.interpolationQuality = .high
    ctx.draw(trophy, in: tr)
    ctx.restoreGState()
}

// MARK: - Export raw (transparent)

guard let img = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)

// MARK: - Preview: on the app's dark background, full size + in-app title size

let pW = W + 80, pH = H + 260
guard let pctx = CGContext(data: nil, width: pW, height: pH, bitsPerComponent: 8, bytesPerRow: 0,
                           space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }
let bg = CGGradient(colorsSpace: cs,
                    colors: [rgba(0x090613), rgba(0x0B0F22), rgba(0x070A16)] as CFArray,
                    locations: [0, 0.4, 1])!
pctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(pH)), end: CGPoint(x: CGFloat(pW), y: 0), options: [])
let glow1 = CGGradient(colorsSpace: cs, colors: [rgba(0x1B2450, 0.9), rgba(0x1B2450, 0)] as CFArray, locations: [0, 1])!
pctx.drawRadialGradient(glow1, startCenter: CGPoint(x: CGFloat(pW) * 0.2, y: CGFloat(pH) * 1.05),
                        startRadius: 0, endCenter: CGPoint(x: CGFloat(pW) * 0.2, y: CGFloat(pH) * 1.05),
                        endRadius: CGFloat(pW) * 0.6, options: [])
pctx.interpolationQuality = .high
// full size
pctx.draw(img, in: CGRect(x: 40, y: 220, width: CGFloat(W), height: CGFloat(H)))
// in-app title size: the wordmark box scaled to ~44pt cap height (88px @2x)
let scale = 150.0 / CGFloat(H)
pctx.draw(img, in: CGRect(x: 40, y: 40, width: CGFloat(W) * scale, height: 150))

guard let pimg = pctx.makeImage(),
      let pdest = CGImageDestinationCreateWithURL(previewURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(pdest, pimg, nil)
CGImageDestinationFinalize(pdest)

print("wrote \(outURL.lastPathComponent) (\(W)x\(H), alpha) + \(previewURL.lastPathComponent)")
