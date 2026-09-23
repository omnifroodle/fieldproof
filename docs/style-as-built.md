# Park poster style — as built

[`STYLE-GUIDE.md`](STYLE-GUIDE.md) is the specification written before the code. This document is what was
actually built, with screenshots, and an honest list of where the build differs from the spec. When they
disagree, this file describes the app you will see on stage.

(PLAN §13 calls this file `style-guide.md`. On a case-insensitive filesystem — macOS by default — that name
is the same file as `STYLE-GUIDE.md` and silently overwrites the specification, so it is `style-as-built.md`.)

The theme is a costume. The product is generic field reporting; nothing in the UI names a job.

---

## 1. Tokens, as shipped

`ios/FieldProof/Design/Theme.swift` and `dashboard/public/styles.css` carry the same nine colours, the same
names, and the same values.

| Token | Hex | Where you see it |
|---|---|---|
| `paper` | `#F3E9D2` | Every background |
| `paperDeep` | `#E6D8B8` | Cards, list rows, panels |
| `pine` | `#1F3D2B` | Primary text, SYNCED banner, resolved status |
| `pineLight` | `#3E6B4E` | Secondary text, metadata lines |
| `sienna` | `#C4552D` | Primary buttons, OPEN status, MISMATCH stamp |
| `mustard` | `#D9A441` | OFFLINE banner, IN PROGRESS status, the sun |
| `sky` | `#7A9EAB` | SYNCING banner |
| `charcoal` | `#2B2B2B` | Outlines and icon strokes |
| `chalk` | `#FBF7EE` | Text on dark fills |

Type: **Bebas Neue** for poster titles and big numbers, **Oswald** for headings, labels and buttons,
**Source Serif 4** for body and notes, **JetBrains Mono** for hashes and document ids. All four are SIL Open
Font License, bundled in the app (`Design/Fonts/`) and loaded from Google Fonts on the dashboard. Every custom
font is declared with `relativeTo:` so Dynamic Type still scales it.

Spacing 4 / 8 / 12 / 16 / 24 / 32. Radius 6 for chips, 10 for cards. Cards are `paperDeep` with a 2 pt
`charcoal` outline and a hard offset shadow — no blur, like ink on paper.

---

## 2. The components, on screen

### Header, banner, filters — pinned

![Report list](images/screens/list-offline.jpg)

`PosterHeader` (flat mountains, mustard sun, Bebas title, Oswald sub-line), `SyncBanner`, and the filter chips
sit **outside** the scroll view. The audience can always see whether the phone is offline, and the list never
scrolls under the status bar.

The banner's copy carries the count, which is the part to point at before going back online:

| State | Copy | Colour |
|---|---|---|
| Offline, nothing pending | `OFFLINE · REPORTS SAFE ON DEVICE` | charcoal on mustard |
| Offline, 2 pending | `OFFLINE · 2 REPORTS SAFE ON DEVICE` | charcoal on mustard |
| Syncing | `SYNCING · 2 REPORTS ON THE TRAIL` | chalk on sky |
| Synced | `SYNCED · ALL REPORTS FILED` | chalk on pine |
| Error | `SYNC PAUSED · CHECK CONNECTION` | chalk on sienna |

### The duplicate sheet

![Looks familiar](images/screens/duplicate-check.jpg)

"LOOKS FAMILIAR" in Bebas, the similarity as a large sienna number, the first candidate outlined as the default,
and a `PosterDivider` — a thin rule with a mustard diamond — above the two actions. The green line under the
subtitle does the explaining: *Found on this phone with a vector search. No network needed.*

### Evidence on the review screen

![Review](images/screens/review-evidence.jpg)

Monospace for the hash and ids; labelled rows in Oswald; serif for anything a person wrote. The simulator's
limitation is printed on the card rather than hidden.

### The stamps

| | |
|---|---|
| ![Verified](images/screens/verify-verified.jpg) | ![Mismatch](images/screens/verify-mismatch.jpg) |

`VerifiedBadge` is a double-outlined circle with the word rotated −8°, pine for VERIFIED and sienna for MISMATCH,
on both the phone and the dashboard.

### The dashboard

![Dashboard](images/screens/dashboard-map.jpg)

Same palette, same fonts, two columns with the map framed like a poster in a mat. Status colours on the pins
match the status pills in the app, so a pin and a row are obviously the same thing.

---

## 3. Where the build differs from the spec

| Spec (`STYLE-GUIDE.md`) | As built | Why |
|---|---|---|
| CARTO Positron tiles | OpenStreetMap tiles (`tile.openstreetmap.org`), same warm CSS filter | CARTO now requires an API key; the spec says not to use keyed tiles. |
| Paper grain overlay (noise texture) | Not built | It was the first thing on the "skip if it costs time" list, and flat colour reads better on a projector. |
| Sync copy "SYNCING · 2 REPORTS ON THE TRAIL" | Kept, and the offline state gained a count as well | The count is the thing the presenter points at. |
| Navigation bar hidden, each screen draws its title | Built as specified — and it disables the edge-swipe back gesture | Logged as `DEFECTS.md` D3. The chevron works; the swipe does not. |
| Category glyph set as SVGs | SF Symbols in `CategoryIcon.swift`, same stroke weight | Fewer assets, identical look, and they scale with Dynamic Type. |
| "Under 400 lines of CSS" | 99 lines | The token approach did the work. |

---

## 4. Rules that held up

- **Legibility first.** Sienna never carries small body text; `pine` on `paper` passes contrast everywhere.
- **Evidence photographs are never filtered.** The poster treatment stops at the frame. What is inside the frame
  is what the camera saw — a rule the hashing story depends on.
- **One strong header per screen**, then quiet cards. Ornament on every element would have made the data harder
  to read from the back of a room.
- **Nothing animates longer than 800 ms**, and the only animations are the banner's colour change and a pin pulse.
- **No job titles anywhere** — in UI copy, identifiers, comments or these documents.

---

## 5. Assets

| Asset | Path |
|---|---|
| App icon (1024) | `ios/FieldProof/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` |
| README banner | `docs/images/banner.png` |
| Fonts (4, OFL) | `ios/FieldProof/Design/Fonts/` with `FONTS.md` |
| Screenshots | `docs/images/screens/` |
| Demo clip | `docs/images/video/capture-flow.mp4` |

Sample photographs are public domain or CC0, credited in `ios/FieldProof/Demo/Samples/ATTRIBUTION.md`.
