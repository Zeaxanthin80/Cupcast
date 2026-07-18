// Reports whether a PNG is really transparent, where its visible content sits,
// and what colours it actually uses — so "is this on-palette / does it need
// cropping" gets answered with numbers instead of eyeballing.

import Foundation
import CoreGraphics
import ImageIO

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height

var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

// 1. Alpha: is the transparency real, or is the "background" opaque black?
var transparent = 0, opaque = 0, partial = 0
for i in stride(from: 3, to: px.count, by: 4) {
    switch px[i] {
    case 0: transparent += 1
    case 255: opaque += 1
    default: partial += 1
    }
}
let total = w * h
print("size: \(w)x\(h)  (\(String(format: "%.2f", Double(w)/Double(h))):1)")
print(String(format: "alpha  fully transparent %.1f%%   fully opaque %.1f%%   partial %.1f%%",
             Double(transparent)/Double(total)*100,
             Double(opaque)/Double(total)*100,
             Double(partial)/Double(total)*100))

// 2. Visible content bounds — treat near-transparent AND near-black as empty,
//    so an opaque black background is measured the same as a clear one.
var minX = w, maxX = -1, minY = h, maxY = -1
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        let a = Int(px[i+3])
        let lum = Int(px[i]) + Int(px[i+1]) + Int(px[i+2])
        guard a > 24, lum > 40 else { continue }
        if x < minX { minX = x }; if x > maxX { maxX = x }
        if y < minY { minY = y }; if y > maxY { maxY = y }
    }
}
let cw = maxX - minX + 1, ch = maxY - minY + 1
print("content bounds: x \(minX)...\(maxX)  y \(minY)...\(maxY)  -> \(cw)x\(ch) (\(String(format: "%.2f", Double(cw)/Double(ch))):1)")
print(String(format: "wasted margin: %.0f%% of height, %.0f%% of width",
             (1 - Double(ch)/Double(h)) * 100, (1 - Double(cw)/Double(w)) * 100))

// 3. Dominant saturated colours, sampled across the artwork.
struct Hit { var r = 0, g = 0, b = 0, n = 0 }
var buckets = [Int: Hit]()
for y in stride(from: minY, through: max(minY, maxY), by: 2) {
    for x in stride(from: minX, through: max(minX, maxX), by: 2) {
        let i = (y * w + x) * 4
        guard px[i+3] > 200 else { continue }
        let r = Double(px[i]), g = Double(px[i+1]), b = Double(px[i+2])
        let mx = max(r, g, b), mn = min(r, g, b)
        guard mx > 90, (mx - mn) / max(mx, 1) > 0.30 else { continue }   // saturated only
        let key = (Int(r)/32)*64 + (Int(g)/32)*8 + Int(b)/32
        var hit = buckets[key] ?? Hit()
        hit.r += Int(r); hit.g += Int(g); hit.b += Int(b); hit.n += 1
        buckets[key] = hit
    }
}
print("\ntop colours in the artwork:")
for (_, hit) in buckets.sorted(by: { $0.value.n > $1.value.n }).prefix(6) {
    let r = hit.r/hit.n, g = hit.g/hit.n, b = hit.b/hit.n
    print(String(format: "  #%02X%02X%02X  (%.1f%% of sampled pixels)",
                 r, g, b, Double(hit.n)/Double(max(buckets.values.reduce(0){$0+$1.n},1))*100))
}

// 4. Distance from each theme anchor to the nearest colour actually used.
let theme: [(String, Int, Int, Int)] = [
    ("accentPink   #FF2D78", 0xFF, 0x2D, 0x78),
    ("accentPurple #7C3AED", 0x7C, 0x3A, 0xED),
    ("accentCyan   #22D3EE", 0x22, 0xD3, 0xEE),
    ("gold         #FBBF24", 0xFB, 0xBF, 0x24),
]
print("\nnearest match in artwork for each Theme colour:")
for (name, tr, tg, tb) in theme {
    var best = Double.greatestFiniteMagnitude
    var bestC = (0, 0, 0)
    for (_, hit) in buckets {
        let r = hit.r/hit.n, g = hit.g/hit.n, b = hit.b/hit.n
        let d = ((Double(r-tr))*(Double(r-tr)) + (Double(g-tg))*(Double(g-tg)) + (Double(b-tb))*(Double(b-tb))).squareRoot()
        if d < best { best = d; bestC = (r, g, b) }
    }
    let verdict = best < 60 ? "close" : best < 110 ? "loose" : "ABSENT"
    print(String(format: "  %@ -> #%02X%02X%02X  distance %.0f  [%@]",
                 name, bestC.0, bestC.1, bestC.2, best, verdict))
}
