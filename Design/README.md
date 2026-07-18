# Design sources

Source artwork kept for regeneration. **Not part of the app target** — this folder
sits beside `FIFA2026WorldCup/`, not inside it, so Xcode's file-system-synchronized
group never picks it up and nothing here ships in the app bundle.

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
