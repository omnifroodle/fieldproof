# FieldProof — Visual Style Guide: "Park Poster"

The look is the 1930s–40s WPA National Parks travel poster: flat shapes, a limited warm palette, heavy
condensed type, thick outlines, and copy that sounds like a trailhead sign. It should feel like a tool a
field crew would trust, not a costume. Apply it to the iOS app, the dashboard, and the README badges.

The theme is visual only. The product is generic field logging and reporting for any industry (public
works, utilities, facilities, parks, construction, inspections). Do not put job titles, badges, hats,
or agency-style insignia anywhere; mountains, sun, trees, and trail-sign typography carry the look.

Priorities: legibility first, then poster feel. Anything that hurts readability in sunlight loses.

---

## 1. Palette

| Token | Hex | Use |
|---|---|---|
| `paper` | `#F3E9D2` | App and page background (cream) |
| `paperDeep` | `#E6D8B8` | Cards, list rows, inset panels |
| `pine` | `#1F3D2B` | Primary text on paper, headers, resolved status |
| `pineLight` | `#3E6B4E` | Secondary buttons, map water/forest tint |
| `sienna` | `#C4552D` | Primary action, open status, alerts |
| `mustard` | `#D9A441` | In-progress status, highlights, badges |
| `sky` | `#7A9EAB` | Info, sync "connecting", links on paper |
| `charcoal` | `#2B2B2B` | Outlines, icon strokes, text on mustard |
| `chalk` | `#FBF7EE` | Text on pine/sienna, poster highlights |

Status mapping: open = `sienna`, in_progress = `mustard`, resolved = `pine`. Sync banner: offline = `charcoal` on `mustard`; syncing = `chalk` on `sky`; synced = `chalk` on `pine`; error = `chalk` on `sienna`.

Dark mode: not required for the demo. The app forces light appearance (`.preferredColorScheme(.light)`) and the dashboard declares `color-scheme: light`. Say so in docs; a dark "night shift" theme is an enhancement.

## 2. Typography

All fonts are SIL Open Font License from Google Fonts. Bundle the TTFs in the iOS app (`Design/Fonts/`, registered in Info.plist `UIAppFonts`) and load from Google Fonts on the dashboard (`<link>` in the head; no self-hosting needed for a demo).

| Role | Font | Notes |
|---|---|---|
| Display / poster titles | **Bebas Neue** (Regular) | All caps, tight tracking, used for screen titles and the big status words |
| Headings, labels, buttons | **Oswald** (500, 600) | Condensed gothic, close to WPA lettering; sentence case or caps with +4% tracking |
| Body, metadata, notes | **Source Serif 4** (400, 600) | Readable serif; use for notes, OCR text, descriptions |
| Monospace (hashes, ids) | **JetBrains Mono** or system monospaced | Hash prefixes, document ids |

Sizes (iOS points / web px): display 34, title 24, heading 18, body 16, caption 13. Minimum 13 anywhere. Line height 1.35 for body.

## 3. Shapes and surfaces

- Corner radius 6 (small chips) and 10 (cards). No pill buttons except status pills (fully rounded).
- Cards: `paperDeep` fill with a **2 pt `charcoal` outline** and a 3 pt offset solid shadow in `charcoal` at 15% opacity (poster print feel, no blur).
- Subtle paper grain: an SVG `feTurbulence` noise overlay at 4–6% opacity on the web body; on iOS a bundled 512×512 noise PNG tiled at 5% opacity over `paper`. Skip if it costs more than a couple of hours.
- Dividers: a "sunburst" rule (thin line with a small diamond in the middle) between sections. One reusable `PosterDivider` view / CSS class.
- Icons: SF Symbols on iOS with `.bold` weight and `charcoal` tint inside a `paperDeep` circle with outline; on web, inline SVG with the same stroke width (2). Category glyphs: pothole = `road.lanes` (or `exclamationmark.triangle`), graffiti = `paintbrush`, tree = `tree`, fixture = `lightbulb`, other = `questionmark.circle`.

## 4. Signature components

**PosterHeader** (top of the list, dashboard hero): layered flat mountains (three polygons in `pineLight`, `pine`, `charcoal`), a `mustard` sun disc, cream sky, and the title "FIELDPROOF" in Bebas Neue with a sub-line in Oswald: "VALLEY DISTRICT · FIELD REPORTS". Draw it once as an SVG asset (`Assets/poster-header.svg`) and reuse it as the app splash and README banner. Keep it under 3 KB of path data; simple polygons only.

**SyncBanner**: full-width strip under the header. Text is uppercase Oswald 600 with a leading SF Symbol. Copy:
- Offline: "OFFLINE · REPORTS SAFE ON DEVICE"
- Syncing: "SYNCING · 2 REPORTS ON THE TRAIL"
- Synced: "SYNCED · ALL REPORTS FILED"
- Error: "SYNC PAUSED · CHECK CONNECTION"

**StatusPill**: uppercase Oswald 600 caption, filled with the status color, `chalk` or `charcoal` text per contrast.

**Badge** (hash verification): a circular "stamp" with a double outline in `pine` reading "VERIFIED" (rotated −8°), or in `sienna` reading "MISMATCH". Use it on the dashboard detail page and the phone detail view.

**DuplicateReview sheet**: title "LOOKS FAMILIAR", subtitle "2 open reports within 200 m look like this one." Candidate rows with a thumbnail in a poster frame (2 pt outline), similarity as a big Bebas number ("91%"), distance in meters, age. Buttons: "ATTACH TO EXISTING" (sienna, primary) and "FILE AS NEW" (outline).

**Capture progress**: "READING THE SCENE" with a three-step trail: Classify → Read text → Fingerprint, each step turning `pine` when done.

**Empty state**: mountain silhouette with "NO REPORTS ON THIS TRAIL YET".

## 5. Map styling (dashboard)

- Leaflet 1.9.4 with CARTO Positron tiles (`https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png`, attribution required: "© OpenStreetMap contributors © CARTO"). Apply `filter: sepia(0.35) saturate(0.85) hue-rotate(-8deg) contrast(1.05)` to the tile pane to warm it toward the palette. Do not use tiles that need an API key.
- Pins: custom `L.divIcon` SVG teardrop, 28×36, filled with the status color, 2 px `charcoal` outline, white inner dot. New pins pulse once (CSS keyframe scaling 1 → 1.3 → 1 over 800 ms).
- Popup: card style above, thumbnail 96 px, category, age, "Open report" link.
- Map framed by a 3 px `charcoal` border with a `paperDeep` mat, like a poster in a frame.

## 6. Copy voice

Short, declarative, trail-sign tone. Uppercase for headers and status words; sentence case for body. Examples: "Photograph the problem." "We check for duplicates before you file." "Reports stay on the device until you are back in range." Avoid exclamation marks and cute puns in functional UI.

## 7. iOS implementation notes

- `Theme.swift`: `enum Palette { static let paper = Color(hex: 0xF3E9D2) … }`, `enum Type { static func display(_ size: CGFloat) -> Font { .custom("BebasNeue-Regular", size: size) } … }`, spacing scale 4/8/12/16/24/32.
- `PosterComponents.swift`: `PosterHeader`, `SyncBanner`, `StatusPill`, `VerifiedBadge`, `PosterCard { content }`, `PosterButton(style: .primary | .outline)`, `PosterDivider`.
- Use `.buttonStyle(PosterButtonStyle())` everywhere; no default blue buttons anywhere in the app.
- Navigation bar: hidden; each screen draws its own poster title.

## 8. Web implementation notes

- `styles.css` defines the tokens as CSS custom properties on `:root`, the same names as above.
- Layout: two columns on desktop (map 60 %, list 40 %), stacked on narrow screens with a 16 px gutter.
- No CSS framework. Under 400 lines of CSS.

## 9. Assets to produce

- `poster-header.svg` (hero), `app-icon` (1024 px: mountains + sun + "FP" monogram), `noise.png`, category glyph SVGs (5), pin SVG, `verified.svg` / `mismatch.svg` stamps.
- README banner: the hero SVG exported to PNG at 1600×500.

## 10. Do and don't

- Do keep contrast ≥ 4.5:1 for text (pine on paper passes; sienna on paper passes for 18 pt+ only, so never use sienna for small body text).
- Do use real photos in poster frames; don't filter or posterize the evidence photos themselves (they are evidence).
- Don't add ornamental frames on every element; one strong header and consistent cards carry the look.
- Don't animate anything longer than 800 ms.
