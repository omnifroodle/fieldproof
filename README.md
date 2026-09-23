![FieldProof](docs/images/banner.png)

# FieldProof

An offline-first field logging and reporting demo for Couchbase. A crew member photographs a problem
(pothole, graffiti, downed tree, broken fixture). The phone captures GPS and heading, runs Apple's Vision
models on the device, hashes the photo for chain of custody, and **checks for duplicate reports nearby with
on-device vector search in Couchbase Lite** — all with no network. When the phone is back in range it syncs
through Capella App Services to a Capella cluster, and a supervisor dashboard shows the reports on a map.

The park-poster look is only a costume: the app is generic field reporting for public works, utilities,
facilities, construction, or inspections.

**The five beats the demo tells**

1. Works with no signal. 2. AI runs on the device. 3. Duplicate check before saving. 4. Trustworthy evidence
(SHA-256 at capture). 5. Syncs when back online, scoped per district by channel.

| | |
|---|---|
| iOS app | SwiftUI, Couchbase Lite Swift Enterprise 4.1.2 + Vector Search 2.0.0 |
| Sync | Capella App Services 4.1 (channels per district, one sync function per collection) |
| Backend | Capella cluster, bucket `demos`, scope `evidence`, collections `reports` and `photos` |
| Dashboard | Node + Express + Leaflet, no build step |

---

## 1. Prerequisites

- **macOS** with **Xcode 26 or newer** and an iOS 17+ simulator. Xcode 27.0 and the iOS 26.4 simulator were used.
- **Node 20+** (Node 26.5 was used). `npm install` must fetch a prebuilt `couchbase` binary; nothing should compile.
- A **Capella** account with a cluster, App Services, and your laptop's IP allowed.
- Optional: an **iPhone (iOS 17+)** for the camera. Everything else runs on the simulator in demo mode.

> **The simulator cannot run Apple's image AI.** Vision returns the same vector for every photo there
> (`docs/REFERENCE.md` §7.1). For the simulator, vectors and labels for the bundled samples are precomputed on
> your Mac by `scripts/embed-samples.swift` and shipped in the app; the capture screen says so. On a real iPhone
> everything runs live. Text recognition works in both places.

## 2. Capella setup (once, about 15 minutes)

1. **Cluster:** pick a bucket for the demo (this repo uses the existing `demos` bucket) and add your laptop's IP
   under Settings → Allowed IP addresses. Create a database credential with read/write on that bucket.
2. **Scope, collections, indexes:** copy `dashboard/.env.example` to `dashboard/.env`, fill in the cluster
   connection string and credential, then:
   ```bash
   cd dashboard && npm install && npm run setup
   ```
   This creates scope `evidence`, collections `reports` and `photos`, and three indexes, and prints the remaining
   manual steps. It is safe to run again.
3. **App Services:** create an App Service on the cluster, then an App Endpoint named `fieldproof` on the same
   bucket, scope `evidence`, linked to both collections. **Resume** the endpoint (new endpoints start Offline).
4. **Sync functions:** App Endpoint → Security → Access and Validation. Paste
   `appservices/sync-function-reports.js` into `reports` and `appservices/sync-function-photos.js` into `photos`.
5. **App users:** Security → App Users. Create three users and give each the channels below **on both collections**:

   | User | Channels |
   |---|---|
   | `crew-valley` | `district.valley` |
   | `crew-tuolumne` | `district.tuolumne` |
   | `supervisor` | `district.valley` **and** `district.tuolumne` |

   The supervisor needs both districts listed explicitly. The `*` channel allows reading everything but does not
   allow writing to a district (`docs/DEFECTS.md` D1).
6. **Connect:** copy the endpoint's public URL (`wss://<id>.apps.cloud.couchbase.com:4984/fieldproof`).
   No admin credential is needed anywhere: the dashboard and scripts act as the `supervisor` app user.

## 3. Secrets

Both files are git-ignored; only the `.example` files are committed.

```bash
cp ios/FieldProof/Config/Secrets.example.plist ios/FieldProof/Config/Secrets.plist
cp dashboard/.env.example dashboard/.env
```

`Secrets.plist` takes the public `wss://` URL and the three app-user passwords. `.env` takes the cluster
connection string and credential, plus `APPSERVICES_URL` (the same host, `https://…:4984`), `APPSERVICES_USER=supervisor`
and that user's password. Without `Secrets.plist` the app still runs; it just never syncs.

## 4. Run it

**iOS**

```bash
open ios/FieldProof.xcodeproj
```

Select an iPhone simulator and Run. For a device, set your team under Signing & Capabilities, then trust the
developer certificate on the phone (Settings → General → VPN & Device Management) the first time.

**Dashboard** (from `dashboard/`, needs `.env`)

```bash
npm install && npm start
```

Then open http://localhost:3000.

**Sample data.** In the app: Settings → Demo → **Load sample reports**. It writes 30 reports with photos, uploads
them as `supervisor`, then hands the phone back to the current user, which pulls only that user's districts
(Valley keeps 25). Measured over three runs: 13–19 seconds from tap to all 30 pins on the dashboard. Sync must be online.

**Reset between demos** (from `dashboard/`):

```bash
npm run reset        # deletes every report and photo; phones follow within seconds
```

## 5. The 5-minute demo

Have the dashboard open on a laptop and the phone (or simulator) mirrored. Start from a freshly seeded state:
`npm run reset`, then Load sample reports, and confirm the dashboard map shows 30 pins. Budget a minute for that
before the audience is watching. This script was rehearsed three times end to end on the simulator.

| Time | Do | Say |
|---|---|---|
| 0:00 | Dashboard: map of Yosemite Valley with 30 pins, colored by status. | "Every one of these came from a phone that was offline when the report was taken. Swap the park for a utility territory, a campus, or a highway district; the app does not change." |
| 0:30 | Phone: Settings → **Simulate offline** (or real airplane mode). Banner turns to OFFLINE. Close Settings. | "This phone now has no network at all." |
| 0:45 | **Report a problem** → pick `capture-pothole`. Watch "Reading the scene": Classify → Read text → Fingerprint. | "Apple's Vision models run on the phone: a label, any text in the photo, and a 768-number fingerprint of the image." |
| 1:15 | The review screen shows GPS, heading, time, the SHA-256, and what the AI found. | "The hash is computed here, at capture, over exactly the bytes we store." |
| 1:30 | **"Looks familiar"** appears: 2 open reports within 200 m, 98% alike, 34 m and 52 m away. Show `DuplicateCheckQuery.swift` on screen for 20 seconds. | "That is one SQL++ query on the phone: vector distance, a 200 m box, and a status filter. No network, no server." |
| 2:30 | Tap **Attach to existing**. Open the parent report; tap **Find similar**. | "The evidence is never dropped: the new photo is filed against the report it duplicates." |
| 3:15 | Settings → Simulate offline **off**. Banner: OFFLINE 2 → SYNCING → SYNCED. | "Two documents were waiting: the new capture and the updated original." (On a good connection this takes under a second, so the SYNCING state can flash past. The count before you flip the switch is the part to point at.) |
| 3:30 | Dashboard: the report now shows "+1 attached capture". | "Channels sent it to this district only. A Tuolumne crew never sees Valley data." |
| 4:00 | Dashboard → **Verify** → VERIFIED. Then in a terminal: `npm run tamper -- <report id>` and Verify again → MISMATCH. | "Even someone with valid access who swaps the photo is caught, because the hash was computed on the device at capture." |
| 4:30 | Dashboard: set the report to **In progress**. Watch the phone's list update by itself. | "The supervisor's change syncs straight back down to the crew." |
| 4:45 | Close. | "Same code path scales from 30 reports to 30,000: Couchbase Lite indexes the vectors, App Services scopes the data, Capella holds the system of record." |

Copy a report id for the tamper step from the dashboard detail page (the ID row), or:

```bash
curl -s localhost:3000/api/reports | head -c 200
```

## 6. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Banner stays OFFLINE, Settings shows `replicator: offline` | Capella free tier pauses after 72 idle hours. Resume the cluster **and** the App Endpoint, then wait a minute. Do this 15 minutes before a demo. |
| `Settings → replicator: … error: … 401` | Wrong password in `Secrets.plist` for the selected user. |
| Reports save but never sync; error mentions `403` or channel access | The app user lacks that district's channel on **both** collections (§2.5), or the sync function is missing on one collection. |
| Dashboard: "Cannot reach Capella" | `.env` cluster credential, or your IP is not on the cluster's allowed list. |
| Dashboard map is blank | The tile server is unreachable; the pins and list still work. Tiles come from OpenStreetMap and need internet. |
| `npm run setup` fails with "bucket not found" | `CB_BUCKET` in `.env` does not exist on the cluster. Create it in the Capella UI first. |
| Photo shows in the app but `Verify` says 404 on the dashboard | The photo document has not synced yet. Reports arrive before photos by design; wait a few seconds. |
| Load sample reports says "Turn off Simulate offline first" | Samples upload as `supervisor`; the phone must be online for that. |
| Duplicate check finds nothing on the simulator | The photo is not one of the bundled samples, so there is no precomputed vector. Use a sample, or run on a device. |
| Changed a sample photo | Rerun `swift scripts/embed-samples.swift` so the precomputed vectors match the new bytes. |

## 7. Layout

```
ios/FieldProof/        SwiftUI app
  Data/                Report model, repository, DuplicateCheckQuery (the showcase query), SyncManager
  AI/                  ImageAnalyzer (Vision), EvidenceHash, Embedding
  Capture/             capture flow, camera, sample picker, location, duplicate review
  Browse/              list, detail, similar reports
  Settings/            user picker, demo mode, sync, reset, developer screen
  Demo/Samples/        33 CC0 / public-domain photos, manifest.json, analysis.json, ATTRIBUTION.md
dashboard/             Express server, lib/couchbase.js (SQL++), lib/appservices.js (REST), public/ (map + detail)
scripts/               setup-cluster, reset-demo, tamper, embed-samples, make-variants
appservices/           the two sync functions to paste into Capella
docs/                  PLAN.md, REFERENCE.md (verified APIs + findings), STYLE-GUIDE.md, DEFECTS.md
  architecture/        one document per component: overview, couchbase-lite, vector-search-on-device,
                       on-device-ai, sync-and-app-services, evidence-integrity, dashboard-and-capella
  demo-guide.md        the presenter's copy of the 5-minute script, with recovery moves
  style-as-built.md    the poster style as built, with screenshots
  images/screens/      screenshots · images/video/ a 30-second clip of the offline capture
```

## 8. Going deeper

| Document | What it covers |
|---|---|
| [docs/architecture/overview.md](docs/architecture/overview.md) | The system, the data flow, the document model, the five beats mapped to code |
| [docs/architecture/couchbase-lite.md](docs/architecture/couchbase-lite.md) | The embedded database: collections, blobs, batches, indexes, change listeners |
| [docs/architecture/vector-search-on-device.md](docs/architecture/vector-search-on-device.md) | The index, the query, and how the 0.15 threshold was measured |
| [docs/architecture/on-device-ai.md](docs/architecture/on-device-ai.md) | Vision on the phone, and what it costs to run AI at the edge instead of in the cloud |
| [docs/architecture/sync-and-app-services.md](docs/architecture/sync-and-app-services.md) | Channels, the sync function, users, the two REST APIs |
| [docs/architecture/evidence-integrity.md](docs/architecture/evidence-integrity.md) | Hashing at capture, verification, and what tampering looks like |
| [docs/architecture/dashboard-and-capella.md](docs/architecture/dashboard-and-capella.md) | SQL++, indexes, consistency, and why two data paths |
| [docs/demo-guide.md](docs/demo-guide.md) | The presenter's script: what to click, what to say, what to do when it breaks |
| [docs/style-as-built.md](docs/style-as-built.md) | The poster style as built, with screenshots |

---

Sample photos are public domain or CC0 with attribution in `ios/FieldProof/Demo/Samples/ATTRIBUTION.md`.
Bundled fonts are SIL Open Font License; see `ios/FieldProof/Design/Fonts/FONTS.md`.
