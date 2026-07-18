# Design sources

Source artwork kept for regeneration. **Not part of the app target** — this folder
sits beside `FIFA2026WorldCup/`, not inside it, so Xcode's file-system-synchronized
group never picks it up and nothing here ships in the app bundle.

## cupcast-wordmark-2374x618.png  +  wordmark-generator.swift

The elaborate CUPCAST wordmark: chrome/bevel lettering in the app's own palette
(pink → purple → cyan, navy outline, purple glow) with the drawn soccer ball
tucked into the P's bowl. True transparent PNG (real alpha). For marketing,
README headers, and similar — the in-app title stays `CupcastTitle` in
`Views/Theme.swift`, which is deliberately SwiftUI text (Dynamic Type, no asset).

`wordmark-generator.swift` regenerates it from scratch (CoreText letterforms +
CoreGraphics effects; the ball is the same truncated-icosahedron construction as
the app icon — all original geometry, no stock art):

    swift wordmark-generator.swift ball out.png preview.png

A `trophy` mode also exists (trophy standing in as the final T) but was rejected:
without a crossbar the trophy reads as an exclamation mark — "CUPCAS!".

## cupcast-banner-1408x768.png

A wide CUPCAST promo banner (stadium, world map, bracket lines, flag badges).
Kept for reference or future marketing use — it is **not** the in-app title.

The title on the Bracket screen is `CupcastTitle` in `Views/Theme.swift`, drawn in
SwiftUI so it inherits `Theme.accentGradient` and stays sharp at any size. This
banner was not used for it: it is a full-bleed opaque scene rather than a wordmark,
its royal-blue/gold palette is absent from the app (which runs pink → purple →
cyan plus gold), its tagline is unreadable at title size, its flag badges and
bracket shape do not match the app's actual 16 teams, and it renders FIFA
prominently as branding.

## trophy-source-591x1500.png

The full-resolution transparent World Cup trophy, 591×1500 with a real alpha
channel.

The shipped asset (`FIFA2026WorldCup/Assets.xcassets/trophy.imageset/trophy.png`)
is a 236×600 downscale of this file — fine for its on-screen sizes (30–96pt), but
too small to enlarge later without going soft. Keep this file if the trophy ever
needs to be re-exported bigger.

Provenance: derived from a clean photo of the trophy on a white background by
keying out the background with a border-seeded flood fill — only near-white pixels
connected to the image edge were removed, so the trophy's own bright specular
highlights survived intact (a plain white-to-transparent threshold would have
punched holes through them). Boundary pixels carry partial alpha for a soft edge.

The original white-background JPEG it came from was never committed, so this
transparent version is the only surviving source.
