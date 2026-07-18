// Keys a black background out of artwork, drops stray specks, and crops tight.
//
//   swift keyblack.swift in.png out.png
//
// Border-seeded flood fill rather than "dark -> transparent": only black that is
// CONNECTED TO THE EDGE is removed, so the ball's dark pentagons and the letters'
// dark bevels — which are enclosed by bright pixels — survive. Glow edges get
// partial alpha so they fade out instead of ending on a hard line.
//
// After keying, connected components are measured and anything far smaller than
// the main artwork (e.g. the decorative sparkle) is dropped, then the result is
// cropped to what remains plus a small margin.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let inURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])

let src = CGImageSourceCreateWithURL(inURL as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height

var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

/// 1.0 = definitely background (black), 0.0 = definitely artwork.
func bgScore(_ i: Int) -> Double {
    let mx = Double(max(px[i*4], max(px[i*4+1], px[i*4+2]))) / 255
    // black up to 0.05, fully artwork by 0.20 — the ramp keeps glow edges soft.
    return min(max((0.20 - mx) / 0.15, 0), 1)
}

var alpha = [Double](repeating: 1, count: w * h)
var visited = [Bool](repeating: false, count: w * h)
var queue: [Int] = []

for x in 0..<w {
    for y in [0, h - 1] {
        let i = y * w + x
        if bgScore(i) > 0.5 && !visited[i] { visited[i] = true; queue.append(i) }
    }
}
for y in 0..<h {
    for x in [0, w - 1] {
        let i = y * w + x
        if bgScore(i) > 0.5 && !visited[i] { visited[i] = true; queue.append(i) }
    }
}

var head = 0
while head < queue.count {
    let i = queue[head]; head += 1
    let s = bgScore(i)
    alpha[i] = 1 - s
    if s < 0.5 { continue }
    let x = i % w, y = i / w
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        let nx = x + dx, ny = y + dy
        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
        let n = ny * w + nx
        if !visited[n] && bgScore(n) > 0.10 { visited[n] = true; queue.append(n) }
    }
}

// Drop stray specks: label connected regions of visible pixels, keep only those
// comparable in size to the largest (the wordmark itself).
var label = [Int](repeating: -1, count: w * h)
var sizes: [Int] = []
for start in 0..<(w * h) where label[start] == -1 && alpha[start] > 0.35 {
    let id = sizes.count
    var count = 0
    var stack = [start]
    label[start] = id
    while let cur = stack.popLast() {
        count += 1
        let x = cur % w, y = cur / w
        for (dx, dy) in [(1,0), (-1,0), (0,1), (0,-1), (1,1), (1,-1), (-1,1), (-1,-1)] {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
            let n = ny * w + nx
            if label[n] == -1 && alpha[n] > 0.35 { label[n] = id; stack.append(n) }
        }
    }
    sizes.append(count)
}
let biggest = sizes.max() ?? 0
let keep = Set(sizes.indices.filter { Double(sizes[$0]) >= Double(biggest) * 0.02 })
var dropped = 0
for i in 0..<(w * h) {
    let l = label[i]
    if l >= 0 && !keep.contains(l) { alpha[i] = 0; dropped += 1 }
    else if l == -1 && alpha[i] > 0 && alpha[i] <= 0.35 {
        // faint halo not attached to anything kept: let it fade out
        var attached = false
        let x = i % w, y = i / w
        for (dx, dy) in [(1,0), (-1,0), (0,1), (0,-1)] {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
            if keep.contains(label[ny * w + nx]) { attached = true; break }
        }
        if !attached { alpha[i] = min(alpha[i], 0.35) }
    }
}

// Apply alpha (premultiplied to match the context's format).
for i in 0..<(w * h) {
    let a = alpha[i]
    for c in 0..<3 { px[i*4+c] = UInt8((Double(px[i*4+c]) * a).rounded()) }
    px[i*4+3] = UInt8((a * 255).rounded())
}

// Crop to what survived, plus a small breathing margin.
//
// The threshold deliberately ignores the diffuse outer halo: this artwork carries
// a glow at only 15-30% alpha spreading well past the letters, which is invisible
// on a dark background but would otherwise pad the asset by ~30% of its height and
// make the wordmark render small inside its own box.
let cropAlpha = CommandLine.arguments.count > 3 ? Double(CommandLine.arguments[3])! : 0.25
var minX = w, maxX = -1, minY = h, maxY = -1
for y in 0..<h {
    for x in 0..<w {
        guard alpha[y * w + x] > cropAlpha else { continue }
        if x < minX { minX = x }; if x > maxX { maxX = x }
        if y < minY { minY = y }; if y > maxY { maxY = y }
    }
}
let margin = 12
minX = max(0, minX - margin); minY = max(0, minY - margin)
maxX = min(w - 1, maxX + margin); maxY = min(h - 1, maxY + margin)
let cw = maxX - minX + 1, chh = maxY - minY + 1

let full = ctx.makeImage()!
let cropped = full.cropping(to: CGRect(x: minX, y: minY, width: cw, height: chh))!

let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, cropped, nil)
CGImageDestinationFinalize(dest)

print("regions found: \(sizes.count), kept \(keep.count), speck pixels dropped: \(dropped)")
print("cropped \(w)x\(h) -> \(cw)x\(chh)  (\(String(format: "%.2f", Double(cw)/Double(chh))):1)")
