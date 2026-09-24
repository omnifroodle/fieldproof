# FieldProof — Implementation Plan (Agent Handoff)

Status: ready for implementation. Written 2026-09-22.
Companion files: [fieldproof-claude-code-prompt.md](fieldproof-claude-code-prompt.md) (original brief; its story beats and working rules still apply, its "ranger" persona does not, see Section 1),
[REFERENCE.md](REFERENCE.md) (verified API facts, versions, links), [STYLE-GUIDE.md](STYLE-GUIDE.md) (visual design).

---

## 0. How to use this document

You are the implementing agent. Read this whole file, then REFERENCE.md, then STYLE-GUIDE.md, before writing code.

Rules that override your defaults:

1. **Work phase by phase (Section 12).** At the end of each phase: build, run, write the phase report described there, and STOP. Wait for the human (Matt) to say "continue".
2. **Do not invent APIs.** Every Couchbase and Apple API you need is listed in REFERENCE.md with a source link. If something is not there, look it up in the official docs (links in REFERENCE.md) and add it to REFERENCE.md with the source before using it. Never use an API from memory or from a blog post older than 2025.
3. **Install the Couchbase agent skills first** (`/plugin install github:couchbaselabs/agent-skills`, or clone the repo and read `skills/mobile-vector-search-ios/SKILL.md`, `skills/mobile-sync-ios/SKILL.md`, `skills/app-services/SKILL.md`, `skills/server-querying-nodejs/SKILL.md`). Where a skill disagrees with REFERENCE.md, REFERENCE.md wins (it was checked against the official docs on 2026-09-22; the known disagreements are listed there).
4. **Ask for credentials, never guess or hard-code them.** All secrets live in git-ignored files (Section 4.4). If you are blocked on a credential, finish everything that does not need it, then stop and ask.
5. **Small codebase.** Target under 3,000 lines of Swift and under 800 lines of JavaScript. A few well-named files beat deep abstraction. No third-party Swift packages other than Couchbase Lite and the vector search extension. No JavaScript build step.
6. **Every place a Couchbase feature is used gets a 1–3 line comment written as a talking point** a presenter can read aloud. Example: `// Couchbase Lite stores the full report locally, so this save succeeds with no network.`
7. **Do not add features that are not in this plan.** If you think something is missing, write it in the phase report as a suggestion.
8. **Do not narrow scope silently.** If something is blocked, finish everything else and say exactly what was left out and why.

---

## 1. What we are building

FieldProof is a demo for Couchbase: an offline-first **field logging and reporting** app. The persona is generic on purpose: a field technician, inspector, or crew member in public works, utilities, facilities management, parks, construction, or insurance. They photograph a problem in the field (pothole, graffiti, downed tree, broken fixture), the phone captures GPS and heading, runs on-device AI (classification, OCR, image embedding), hashes the photo for chain of custody, and checks for duplicate reports nearby using **on-device vector search in Couchbase Lite**. Everything syncs through **Capella App Services** to a **Capella** cluster when connectivity returns, and a **supervisor dashboard** shows reports on a map with hash verification.

Persona and copy rule: never name a specific job in UI text, code identifiers, docs, or comments. Say "field crew", "crew member", "field technician", "inspector", or "supervisor". The **visual** theme is the American national park travel poster (STYLE-GUIDE.md) and the seed data is set in Yosemite Valley, but the app itself must read as usable by any industry that sends people into the field.

The five story beats (from the brief) that every feature must serve:

1. Works with no signal.
2. AI runs on the device.
3. Duplicate check before saving (headline moment).
4. Trustworthy evidence (SHA-256 at capture).
5. Syncs when back online, scoped per district by channel.

Non-goals: authentication UI, user management, production hardening, Android, offline map tiles, editing reports after creation (status changes happen on the dashboard only), push notifications, tests beyond the small set in Section 12.

Deliverables:

- `ios/` SwiftUI app (iPhone), Couchbase Lite Swift EE 4.1.x + Vector Search extension 2.0.x.
- `dashboard/` Node.js web app (Express, Leaflet, no build step).
- `scripts/` setup, reset, and tamper scripts (Node, ESM).
- `docs/` architecture and component docs with enhancements and alternatives (Section 13).
- A README that gets a new person from clone to running demo in under an hour, plus the demo script.
- National Park poster visual style throughout (STYLE-GUIDE.md).

---

## 2. Decisions already made

Do not re-litigate these. If one turns out to be impossible, stop and report.

| Topic | Decision | Why |
|---|---|---|
| App name | FieldProof (repo folder is `fieldguide`; that is fine) | From the brief |
| iOS minimum | iOS 17.0 | Needed for Vision feature print revision 2 (768-dim vectors). Couchbase Lite 4.1 needs iOS 15+, so 17 is safe. |
| Xcode | Latest stable on the machine (Xcode 26.x expected) | |
| Couchbase Lite | Swift EE **4.1.2** via SPM (`couchbase-lite-swift-ee`) | Current release; EE required for vector search |
| Vector search | `CouchbaseLiteVectorSearch` **2.0.0** via SPM, enabled with `try Extension.enableVectorSearch()` before opening the database | Official docs |
| Sync backend | Capella App Services (4.1.x). Free tier is acceptable if Matt has no paid cluster. | CBL 4.x requires App Services / Sync Gateway 4.x; Capella runs 4.1.2 |
| Embedding model | Vision `VNGenerateImageFeaturePrintRequest`, revision **2** pinned explicitly, `imageCropAndScaleOption = .scaleFill` | Deterministic, built in, 768 floats, normalized |
| Vector index | dimensions 768, metric `.cosine`, centroids 8, encoding `.none`, not lazy | Tiny dataset; sqrt(N) rule; no compression needed |
| Classification | Vision `VNClassifyImageRequest`, keep top 5 labels with confidence ≥ 0.1 | Built in. Note: taxonomy has `graffiti`, `road`, `tree`, `bench`, `sign`, `fence`, `trash_can`, `concrete` but **no `pothole`**; the user picks the category, AI labels are supporting evidence. |
| OCR | Vision `VNRecognizeTextRequest`, `.accurate`, language correction on | Built in |
| Hashing | CryptoKit SHA-256 over the **stored** JPEG bytes (after resize/compression), hex lowercase | Verification compares the same bytes the server holds |
| Photo storage | Two documents per report: small `report` doc (metadata, embedding, thumbnail blob) in collection `reports`; large `photo` doc (full-res blob) in collection `photos` | Thumbnails effectively sync first; dashboard loads full-res lazily |
| Scope/collections | Bucket `fieldproof`, scope `evidence`, collections `reports` and `photos`. App Endpoint named `fieldproof`. | Readable keyspaces: `fieldproof.evidence.reports` |
| Persona | Generic field crew / inspector / supervisor. No job titles in UI, identifiers, or docs. | Reads across industries; the park theme is visual only |
| Districts / channels | Channel per district: `district.<districtId>`. Districts: `valley` (the crew member's) and `tuolumne` (the other one). | Shows channel scoping with two districts |
| App users | `crew-valley` (channel `district.valley`), `crew-tuolumne` (channel `district.tuolumne`), `supervisor` (channel `*`). Phone picks a user in Settings; no login screen. | Demo simplicity |
| Sync backend fallback | If the Capella free tier proves unusable (paused, IP allowlist trouble, or App Services unavailable), run **self-hosted Couchbase Server + Sync Gateway 4.1.x in Docker** (Section 4.5). Same sync functions, same app; only the URL and admin base change. | Matt wants a self-run option to have value on its own |
| Park | Yosemite Valley, California. Demo simulated location: Yosemite Village area, approx **37.7460, -119.5860** (fine to adjust). Seed reports clustered within ~1.5 km of it. Tuolumne reports near **37.8750, -119.3580**. | Recognizable, has roads and facilities |
| Dashboard stack | Node 20+ (or 22), Express, plain HTML/CSS/JS served statically, Leaflet 1.9.4 from CDN, CARTO basemap tiles (no key) | Minimal; polling every 3 s |
| Dashboard data access | Couchbase Node SDK 4.7.x for SQL++ queries on the cluster; App Services **Admin REST API** (port 4985, admin credential) for reading blob bytes and for scripts | Blobs are not readable cleanly via the SDK |
| Seeding | In-app: Settings → Demo → "Load sample reports" creates the seed reports on the device (embeddings computed by Vision on the device) and they sync up. A Node script resets the cluster. | One embedding code path; no macOS CLI to maintain |
| Offline simulation | In-app switch "Simulate offline" that stops the replicator, because the iOS Simulator has no airplane mode. Real airplane mode also works on a device. | Demo reliability |
| Duplicate threshold | Candidate if cosine distance < **0.35** AND within 200 m AND status != resolved. Tune in Phase 2 with the debug screen; record the final value in docs. | Starting point only |
| Secrets | `ios/FieldProof/Config/Secrets.plist` and `dashboard/.env`, both git-ignored, with `.example` templates committed | |
| Tests | A handful of XCTest unit tests and one Node test file (Section 12). No UI tests. | Demo project |

---

## 3. Repository layout

```
fieldguide/
├── README.md                      # setup + demo script (Phase 5)
├── .gitignore
├── docs/                          # this plan + architecture docs (Phase 6)
├── ios/
│   ├── FieldProof.xcodeproj
│   └── FieldProof/
│       ├── App/
│       │   ├── FieldProofApp.swift        # entry; enables vector search ext, opens DB, starts replicator
│       │   └── AppState.swift             # ObservableObject: current user, demo mode, sync status
│       ├── Data/
│       │   ├── DatabaseManager.swift      # open DB, create collections + indexes (vector index here)
│       │   ├── Report.swift               # Codable-ish model <-> MutableDocument mapping
│       │   ├── ReportRepository.swift     # save / list / fetch / attach-to-existing
│       │   ├── DuplicateCheckQuery.swift  # THE showcase SQL++ query, heavily commented
│       │   └── SyncManager.swift          # Replicator config, status publisher, offline toggle
│       ├── AI/
│       │   ├── ImageAnalyzer.swift        # classify + OCR + embedding in one pass (Vision)
│       │   ├── Embedding.swift            # feature print -> [Float], cosine distance helper
│       │   └── EvidenceHash.swift         # SHA-256 helper
│       ├── Capture/
│       │   ├── CaptureView.swift          # camera or sample picker, then metadata form
│       │   ├── CameraPicker.swift         # UIImagePickerController wrapper
│       │   ├── LocationService.swift      # CoreLocation lat/lon/heading/accuracy/altitude
│       │   └── DuplicateReviewView.swift  # "Looks similar to N open reports" sheet
│       ├── Browse/
│       │   ├── ReportListView.swift       # offline list, category/status filter
│       │   ├── ReportDetailView.swift     # photo, metadata, hash, "Find similar"
│       │   └── ReportMapView.swift        # MapKit map of local reports (optional, small)
│       ├── Settings/
│       │   └── SettingsView.swift         # user picker, demo mode, simulate offline, seed, reset
│       ├── Demo/
│       │   ├── SeedData.swift             # builds seed reports from Samples/manifest.json
│       │   └── Samples/                   # bundled sample photos + manifest.json + ATTRIBUTION.md
│       ├── Design/
│       │   ├── Theme.swift                # colors, fonts, spacing (STYLE-GUIDE.md tokens)
│       │   ├── PosterComponents.swift     # PosterHeader, Badge, StatusPill, SyncBanner
│       │   └── Fonts/                     # bundled OFL font files
│       ├── Config/
│       │   ├── Secrets.example.plist
│       │   └── Secrets.plist              # git-ignored
│       └── Resources/ (Assets.xcassets, Info.plist)
│   └── FieldProofTests/
├── dashboard/
│   ├── package.json
│   ├── .env.example
│   ├── server.js                  # Express: /api/reports, /api/reports/:id, /api/photo/:id, /api/verify/:id
│   ├── lib/couchbase.js           # SDK connect + queries (SQL++ in one place, commented)
│   ├── lib/appservices.js         # Admin REST helpers: get doc, get attachment, put attachment, delete
│   ├── public/
│   │   ├── index.html             # map + list
│   │   ├── report.html            # detail + hash verification
│   │   ├── app.js, report.js
│   │   └── styles.css             # poster theme
│   └── test/verify.test.js
├── scripts/
│   ├── setup-cluster.mjs          # creates indexes via SDK; prints checklist for manual Capella steps
│   ├── reset-demo.mjs             # deletes all report/photo docs via Admin REST
│   ├── tamper.mjs                 # replaces a photo attachment to demo hash mismatch
│   └── assets/tamper.jpg
└── appservices/
    ├── sync-function-reports.js   # paste into Capella UI (Security → Access and Validation)
    ├── sync-function-photos.js
    └── users.md                   # the three app users and their channels
```

---

## 4. Environment and accounts

### 4.1 What Matt provides (ask once, at the start of Phase 0)

- A Capella account with an operational cluster (free tier OK). Cluster connection string (`couchbases://cb.<id>.cloud.couchbase.com`), a database credential (username/password with read/write on bucket `fieldproof`), and the laptop's IP added to the cluster's allowed IP list.
- App Services enabled on that cluster, with an App Endpoint named `fieldproof` (Section 4.3 has the exact steps; the agent can walk Matt through them or Matt can grant Capella UI access).
- App Services public connection URL (`wss://<id>.apps.cloud.couchbase.com:4984/fieldproof`), the three app user passwords, and an Admin REST credential.
- Optional: a physical iPhone (iOS 17+) for the camera. The simulator works for everything else via demo mode.

### 4.2 Machine setup (agent verifies)

- macOS 14+, Xcode 26.x (or latest stable), iOS 17+ simulator installed.
- Node 20 or 22 LTS. `npm install couchbase` must succeed (prebuilt binary; if it tries to compile, stop and report).
- No CocoaPods, no Carthage.

### 4.3 Capella setup checklist (manual, in the Capella UI)

Write these into README as well. Order matters.

1. Cluster: create bucket `fieldproof` (memory 200 MB is fine), scope `evidence`, collections `reports` and `photos`.
2. Cluster → Settings → Allowed IP addresses: add the laptop IP (or 0.0.0.0/0 for the demo period).
3. Cluster → Settings → Database access: create credential with read/write on `fieldproof`.
4. Run `node scripts/setup-cluster.mjs` to create the query indexes (Section 10.2).
5. App Services: create an App Service linked to the cluster. Create App Endpoint `fieldproof` on bucket `fieldproof`, scope `evidence`, link collections `reports` and `photos`. Resume the endpoint when it shows Offline.
6. App Endpoint → Security → Access and Validation: paste `appservices/sync-function-reports.js` into `reports` and `sync-function-photos.js` into `photos`. Save.
7. App Endpoint → Security → App Users: create `crew-valley` (admin channels: `district.valley` on both collections), `crew-tuolumne` (`district.tuolumne`), `supervisor` (`*`).
8. App Endpoint → Connect: copy the Public Connection URL. Connect via Admin REST API → Allowed IP Addresses → add laptop IP; Manage Admin Credentials → create `admin` credential (apply to all endpoints). Note the Admin URL format `https://<id>.apps.cloud.couchbase.com:4985/`.
9. Free tier only: the cluster and App Services pause after 72 hours without activity. README must say "resume the cluster and endpoint 15 minutes before a demo."

### 4.4 Secrets files

`ios/FieldProof/Config/Secrets.plist` (git-ignored; `Secrets.example.plist` committed with placeholder values):

```
APP_SERVICES_URL      wss://<id>.apps.cloud.couchbase.com:4984/fieldproof
USER_CREW_VALLEY      <password>
USER_CREW_TUOLUMNE    <password>
USER_SUPERVISOR       <password>
```

`dashboard/.env` (git-ignored; `.env.example` committed):

```
CB_CONN_STR=couchbases://cb.<id>.cloud.couchbase.com
CB_USERNAME=
CB_PASSWORD=
CB_BUCKET=fieldproof
APPSERVICES_ADMIN_URL=https://<id>.apps.cloud.couchbase.com:4985
APPSERVICES_ENDPOINT=fieldproof
APPSERVICES_ADMIN_USER=admin
APPSERVICES_ADMIN_PASSWORD=
PORT=3000
```

`.gitignore` must include `Secrets.plist`, `.env`, `node_modules`, `xcuserdata`, `DerivedData`.

### 4.5 Fallback: self-hosted Couchbase Server + Sync Gateway (Docker)

Build this only if Phase 0 shows the free tier is not viable, or when Matt asks for it. It is also a legitimate deliverable on its own ("runs anywhere, no cloud account"), so keep it documented in README as "Option B" once it exists.

- `selfhosted/docker-compose.yml`: `couchbase:enterprise-7.6.x` (ports 8091-8097, 11210) and `couchbase/sync-gateway:4.1.x-enterprise` (ports 4984, 4985), on one Docker network.
- `selfhosted/init-server.sh`: waits for the server, runs `couchbase-cli cluster-init` (data, query, index services; 1 GB data quota), creates bucket `fieldproof`, scope `evidence`, collections `reports` and `photos`, an RBAC user `sg` with `mobile_sync_gateway` role, and the query indexes from Section 10.2.
- `selfhosted/sg-bootstrap.json`: bootstrap config pointing at `couchbase://couchbase-server` with the `sg` user, `use_tls_server: false`, admin interface on `0.0.0.0:4985`.
- `selfhosted/init-sg.sh`: `PUT http://localhost:4985/fieldproof/` with a database config that maps scope `evidence`, collections `reports` and `photos`, each with its sync function from `appservices/` inlined, `num_index_replicas: 0`, `enable_shared_bucket_access: true`; then creates the three users with `PUT /fieldproof/_user/<name>`.
- App: `APP_SERVICES_URL = ws://localhost:4984/fieldproof` on the simulator, or `ws://<mac-lan-ip>:4984/fieldproof` on a device (same Wi-Fi). Dashboard: `APPSERVICES_ADMIN_URL = http://localhost:4985`, `CB_CONN_STR = couchbase://localhost`, drop `configProfile: 'wanDevelopment'`.
- Verify every Sync Gateway config key against https://docs.couchbase.com/sync-gateway/current/get-started-prepare.html and the 4.x configuration reference before writing it; record what you used in REFERENCE.md.
- Everything else (sync functions, REST paths, keyspaces, scripts) is identical, which is itself a talking point: "App Services is managed Sync Gateway; the code does not know the difference."

---

## 5. Data model

Document IDs: `report::<uuid>` and `photo::<same uuid>`. Store the ISO-8601 UTC timestamp strings. All numbers are JSON numbers.

### 5.1 `evidence.reports` document

```json
{
  "type": "report",
  "id": "report::7f3c...",
  "district": "valley",
  "status": "open",
  "category": "pothole",
  "createdAt": "2026-09-22T17:04:11Z",
  "createdBy": "crew-valley",
  "deviceId": "A1B2-...",
  "location": { "lat": 37.7461, "lon": -119.5863, "accuracy": 5.0, "altitude": 1210.0, "heading": 184.0 },
  "aiLabels": [ { "label": "road", "confidence": 0.81 }, { "label": "concrete", "confidence": 0.44 } ],
  "ocrText": "NPS-4471",
  "notes": "Rear of Village Store lot, about 30 cm across.",
  "embedding": [0.0123, -0.0456, "... 768 floats"],
  "embeddingModel": "vision-featureprint-r2",
  "imageHash": "9f86d081...",
  "photoDocId": "photo::7f3c...",
  "thumbnail": { "@type": "blob", "content_type": "image/jpeg" },
  "relatedReportIds": [],
  "seed": true
}
```

Notes:

- `status` is one of `open`, `in_progress`, `resolved`. Only the dashboard changes it (a simple button in the detail page updates the doc through the Admin REST API so the change syncs down to phones).
- `thumbnail` is a Couchbase Lite `Blob`, JPEG, longest side 320 px, quality 0.7.
- `relatedReportIds` is filled on the parent report when a new capture is attached to it (see 5.3).
- `embeddingModel` lets a future model change coexist (docs enhancement talking point).
- `seed: true` marks seeded reports so the reset script and the in-app reset can find them.

### 5.2 `evidence.photos` document

```json
{
  "type": "photo",
  "id": "photo::7f3c...",
  "reportId": "report::7f3c...",
  "district": "valley",
  "createdAt": "2026-09-22T17:04:11Z",
  "imageHash": "9f86d081...",
  "byteLength": 412887,
  "photo": { "@type": "blob", "content_type": "image/jpeg" }
}
```

Full-resolution photo: longest side 1600 px, JPEG quality 0.8. `imageHash` = SHA-256 of exactly these bytes, also copied into the report doc. `district` is duplicated so the sync function can route the photo to the same channel.

### 5.3 Attaching to an existing report

When the user chooses "Attach to existing" in the duplicate review:

- Still create the `report` and `photo` docs for the new capture (evidence is never dropped), but set the new report's `status` to `open`, `relatedReportIds: [<parentId>]`, and `attachedTo: <parentId>`.
- Update the parent report locally: append the new id to `relatedReportIds`. This edit syncs up; the dashboard shows the parent with "+1 attached capture" and hides attached captures from the map as separate pins.

---

## 6. Sync design (App Services)

### 6.1 Sync functions

`appservices/sync-function-reports.js`:

```javascript
// Runs inside Capella App Services on every write to evidence.reports.
// Talking point: one small JavaScript function decides who can see and write each document.
function (doc, oldDoc, meta) {
  if (doc._deleted) { return; }                       // tombstones keep the old channel
  if (!doc.district) { throw({ forbidden: "district is required" }); }
  if (doc.type !== "report") { throw({ forbidden: "wrong type for reports collection" }); }
  if (oldDoc && oldDoc.district !== doc.district) {
    throw({ forbidden: "district cannot change" });
  }
  var ch = "district." + doc.district;
  requireAccess(ch);   // the writing user must already have access to that district
  channel(ch);         // route the document to that district's channel
}
```

`sync-function-photos.js` is identical except `doc.type !== "photo"`.

### 6.2 Users and channels

See Section 2. The supervisor user exists so the dashboard could sync if it were a CBL client (it is not; it uses the SDK). It is also useful for debugging with the Public REST API.

### 6.3 Replicator (phone)

- `URLEndpoint(url: APP_SERVICES_URL)`, `BasicAuthenticator` with the selected user.
- Both collections in one `ReplicatorConfiguration`, `.pushAndPull`, `continuous = true`. Do **not** set `channels` on the collection config; the user's admin channels already scope the pull. (Mention in docs that client-side channel filters are an option.)
- `SyncManager` publishes: `activity` (stopped/offline/connecting/idle/busy), `pendingCount` (from `replicator.pendingDocumentIds(collection: reports)` re-read on every change event), `lastError`, and `simulatedOffline`.
- "Simulate offline" = `replicator.stop()`; turning it off = `replicator.start()`. Switching user = stop, rebuild config, start.
- Log replicator at `.info` in debug builds so the presenter can show the console if asked.

### 6.4 Conflicts

Default conflict resolution (last write wins by version vector) is fine. Documents are written once by one device; the only concurrent edit is `relatedReportIds` on a parent, which is acceptable to lose in a demo. State this in docs and list a custom `ConflictResolver` as an enhancement.

---

## 7. On-device AI pipeline

`ImageAnalyzer.analyze(image: UIImage) async throws -> AnalysisResult` runs three Vision requests on one `VNImageRequestHandler` (CGImage, orientation from the UIImage):

1. `VNClassifyImageRequest` → top 5 `(identifier, confidence)` with confidence ≥ 0.1.
2. `VNRecognizeTextRequest` (`recognitionLevel = .accurate`, `usesLanguageCorrection = true`) → joined top candidates, newline separated, max 500 chars.
3. `VNGenerateImageFeaturePrintRequest` with `revision = VNGenerateImageFeaturePrintRequestRevision2` and `imageCropAndScaleOption = .scaleFill` → `VNFeaturePrintObservation`. Convert `data` to `[Float]` using `elementCount` and `elementType` (assert `.float`). **On first run, log `elementCount` and stop Phase 0 if it is not 768.**

Determinism: always analyze the exact bytes that will be stored (decode the stored full-res JPEG back into a CGImage, then analyze). Then the same stored photo always yields the same vector, and the seeded near-duplicates behave predictably.

`Embedding.cosineDistance(a, b)` = `1 - dot(a, b)` after normalizing both (feature prints are already unit length, normalize anyway). Use it for the exact display value; the vector index does the approximate search.

Run analysis on a background task; show a poster-style "Reading the scene…" progress state in the capture flow. Typical time is well under a second on a modern iPhone.

Optional stretch (only after Phase 5 is accepted): Speech framework voice note → `notes`. Do not start it unless asked.

---

## 8. The duplicate check (showcase)

File: `ios/FieldProof/Data/DuplicateCheckQuery.swift`. This file will be shown on screen; keep it under 120 lines with a comment on every clause.

Inputs: query embedding `[Float]`, `lat`, `lon`, `radiusMeters = 200`, `maxDistance = 0.35`, `excludeId: String?`, `limit = 5`.

Bounding box prefilter (Swift, before the query):

```
dLat = radius / 111_320
dLon = radius / (111_320 * cos(lat * .pi / 180))
```

Query (single SQL++ string, bound with `Parameters`):

```sql
SELECT META().id AS id,
       category, status, createdAt, notes,
       location.lat AS lat, location.lon AS lon,
       APPROX_VECTOR_DISTANCE(embedding, $queryVector) AS distance
FROM evidence.reports
WHERE type = 'report'
  AND status != 'resolved'                            -- only open work is a duplicate candidate
  AND attachedTo IS MISSING                            -- attached captures are not parents
  AND location.lat BETWEEN $minLat AND $maxLat         -- cheap geo prefilter (~200 m box)
  AND location.lon BETWEEN $minLon AND $maxLon
  AND META().id != $excludeId
  AND APPROX_VECTOR_DISTANCE(embedding, $queryVector) < $maxDistance
ORDER BY APPROX_VECTOR_DISTANCE(embedding, $queryVector)
LIMIT $limit
```

Rules:

- `$queryVector` is bound with `parameters.setArray(MutableArrayObject(data: floats.map { $0 as NSNumber }), forName: "queryVector")`. Pass `excludeId` as an empty string when nil.
- The metric is set on the index (`.cosine`), so the function's optional metric argument is omitted. Distance returned is `1 - cosine similarity` (0 = identical).
- Do not select the `thumbnail` blob in the query. Load each candidate's document by id afterward to get the thumbnail and the exact `Embedding.cosineDistance` for display.
- After the query, compute the exact haversine distance in meters for display ("38 m away") and drop anything outside the radius (the box is slightly larger than the circle).
- Display similarity as a percentage: `max(0, (1 - distance)) * 100`, rounded.
- Vector index created once in `DatabaseManager`: name `idx_reports_embedding`, expression `embedding`, dimensions 768, centroids 8, metric `.cosine`, encoding `.none`. Also create a value index on `(type, status, location.lat, location.lon)`.
- Untrained index note for docs: with fewer vectors than the training size, Couchbase Lite does a full scan and may log a warning. Results are still correct. This is a talking point ("same query scales to thousands of reports without changing code"), not a bug.

The same function powers "Find similar" from any report's detail view (pass that report's embedding and id as `excludeId`, and use a larger radius of 2,000 m, with `status` filter removed).

---

## 9. Evidence integrity

- `EvidenceHash.sha256Hex(data)` using CryptoKit.
- Detail view shows the first and last 8 hex chars with a copy button and a "Recompute" action that hashes the local blob and shows a green VERIFIED or red MISMATCH badge.
- Dashboard `GET /api/verify/:reportId`: fetches the photo attachment bytes via the Admin REST API, hashes with Node `crypto`, compares to the report's `imageHash`, returns `{ verified, expected, actual, byteLength }`.
- `scripts/tamper.mjs <reportId>`: GETs `photo::<id>` from the Admin REST API to read `_rev`, then `PUT /{endpoint}.evidence.photos/photo::<id>/photo?rev=<rev>` with `Content-Type: image/jpeg` and the bytes of `scripts/assets/tamper.jpg`. Prints before/after hashes. The dashboard now shows MISMATCH for that report; the phone, after syncing, also shows MISMATCH on Recompute. `scripts/reset-demo.mjs` undoes it.

---

## 10. Dashboard

### 10.1 Pages

- `/` map (Leaflet, CARTO Positron tiles, poster tint via CSS filter per STYLE-GUIDE) with one pin per parent report colored by status, a side list sorted by newest, filter chips for district and status, and a small "last update HH:MM:SS" indicator. Polls `/api/reports` every 3 s and animates new pins (a brief pulse).
- `/report.html?id=…` detail: full photo (`/api/photo/:id` proxies the attachment bytes), metadata, AI labels, OCR text, hash panel with "Verify" button calling `/api/verify/:id`, attached captures (thumbnails), and status buttons (Open / In progress / Resolved) which call `POST /api/reports/:id/status` (Admin REST `PUT` of the doc with updated status; keep `_rev`).

### 10.2 Server

- `lib/couchbase.js`: connect with `configProfile: 'wanDevelopment'`; queries against `` `fieldproof`.evidence.reports `` with named parameters and `scanConsistency: RequestPlus` for the list. One exported function per query. SQL++ text lives here with comments.
- Indexes created by `scripts/setup-cluster.mjs` (the primary index is a dev convenience; the docs explain why you would not ship it):

```sql
CREATE INDEX idx_reports_list ON `fieldproof`.evidence.reports(district, status, createdAt) WHERE type = "report";
CREATE INDEX idx_photos_report ON `fieldproof`.evidence.photos(reportId);
CREATE PRIMARY INDEX ON `fieldproof`.evidence.reports;
```
- `lib/appservices.js`: `getDoc(keyspace, id)`, `putDoc(keyspace, id, body, rev)`, `getAttachment(keyspace, id, name)`, `putAttachment(...)`, `deleteDoc(keyspace, id, rev)`, `allDocs(keyspace)` using `fetch` with Basic auth against port 4985. Keyspace helper: `${APPSERVICES_ENDPOINT}.evidence.${collection}`.
- Thumbnails on the map list: `/api/thumbnail/:id` proxies the `thumbnail` attachment from the report doc; cache in memory by `id + rev`.

---

## 11. Seed data and demo mode

### 11.1 Sample photos

`ios/FieldProof/Demo/Samples/` holds roughly 24 JPEGs (each ≤ 1600 px, ≤ 600 KB) plus `manifest.json` and `ATTRIBUTION.md`.

Sourcing rules (agent): use only public-domain or CC0 images (Wikimedia Commons with a PD/CC0 license filter, or U.S. National Park Service photos, which are public domain as U.S. government works). Record the source URL and license per file in `ATTRIBUTION.md`. If a suitable image cannot be found for a category, stop and ask Matt for photos rather than using a non-free image.

Near-duplicates: from one pothole photo `pothole-01.jpg`, generate `pothole-01b.jpg` (crop to 92%, re-encode) and `pothole-01c.jpg` (rotate 3°, brightness +8%) with `sips` or ImageMagick, and keep the generation script in `scripts/make-variants.sh`. These three seeded reports are placed within 60 m of the demo location. A fourth variant `capture-pothole.jpg` (crop 88%, slight color shift) is NOT seeded; it is the photo the presenter "captures" in the demo, so the duplicate check reliably fires.

Minimum set: 5 potholes (3 near-dups + 2 different), 4 graffiti, 4 trees, 4 fixtures, 3 other, 3 capture photos (pothole variant, a fresh graffiti, a fresh sign with readable text for the OCR beat), plus `tamper.jpg` in `scripts/assets`.

### 11.2 `manifest.json`

One entry per seeded report: `file`, `category`, `district`, `status`, `lat`, `lon`, `heading`, `notes`, `ocrHint` (optional, not used for OCR, just for notes), `createdDaysAgo`, `createdBy`. 25 in `valley`, 5 in `tuolumne`. Status mix: ~60 % open, 25 % in_progress, 15 % resolved (at least one resolved near-duplicate to show the status filter excludes it).

### 11.3 In-app seeding

Settings → Demo → "Load sample reports": for each manifest entry, run the same `ReportRepository.create(...)` path used by capture (resize, hash, analyze with Vision, save report + photo docs). Show progress. Idempotent: skip entries whose deterministic id (`report::seed-<file basename>`) already exists. Requires the phone to be signed in as a user who has access to the district being seeded; the seeder therefore runs as `supervisor` regardless of the selected user (temporarily switch, then switch back), or simply seeds only the current user's district plus the tuolumne set when signed in as supervisor. Choose the first: seed as supervisor.

"Reset local data": stop replicator, delete the database, recreate, restart. "Reset cluster" is the Node script (`npm run reset` in `dashboard/` or `node scripts/reset-demo.mjs`) which lists all docs in both keyspaces via Admin REST `_all_docs` and deletes them; tombstones sync down to phones.

### 11.4 Demo mode

Settings → Demo mode ON:

- Capture button opens a sample picker (grid of the three capture photos plus any sample) instead of the camera.
- Location service returns the simulated location plus ±15 m jitter and a fixed heading, with `accuracy: 8`.
- Works on the simulator. On a device, demo mode can still be used when there is no good pothole nearby.

---

## 12. Phases

Each phase ends with a **phase report** in the chat: what works, how it was verified (commands run, screenshots taken with the simulator tool if available), what is not done, questions. Then stop.

### Phase 0 — Spike and environment (half a day)

Goal: prove the risky pieces before building anything.

1. Create the Xcode project (SwiftUI, iOS 17 minimum, bundle id `com.couchbase.demo.fieldproof` or as Matt prefers). Add SPM dependencies: `https://github.com/couchbase/couchbase-lite-swift-ee.git` (from 4.1.2) product `CouchbaseLiteSwift`, and `https://github.com/couchbase/couchbase-lite-vector-search-spm.git` (exact 2.0.0) product `CouchbaseLiteVectorSearch`.
2. In `FieldProofApp.init`: `try Extension.enableVectorSearch()`, open a database, create scope/collections, create the 768-dim vector index. Run on the simulator and on a device if available. Log success.
3. Run `ImageAnalyzer` on a bundled test image; log classification labels, OCR text, and `elementCount`. Confirm 768 and `.float`.
4. Insert three documents with embeddings and run the duplicate query. Confirm it executes and returns ordered distances.
5. `dashboard/`: `npm init`, install `couchbase` and `express`, connect to Capella, run `SELECT 1`. Run `scripts/setup-cluster.mjs`.
6. Confirm App Services endpoint is reachable: `curl` the public URL root and an Admin REST `_user` list.

Acceptance: all six steps logged as passing, or a precise list of what failed. Record actual versions used in REFERENCE.md.

### Phase 1 — Local capture (1–2 days)

- Design tokens and poster components (`Theme.swift`, `PosterComponents.swift`, fonts bundled) so later phases do not need restyling.
- Capture flow: camera (device) or sample picker (demo mode) → resize/encode → hash → metadata form (category picker, notes) → save report + photo docs.
- Location service with permission prompt and simulated mode.
- Report list (newest first, category and status chips) and detail view (photo, metadata, hash with recompute).
- Settings: user picker (no sync yet, just stored), demo mode, reset local data, load sample reports (AI fields empty until Phase 2, so seed can run now and be re-run later; make the seeder overwrite when `embedding` is missing).
- Tests: `EvidenceHashTests` (known vector), `GeoBoxTests` (bounding box math), `ReportMappingTests` (doc round trip).

Acceptance: fresh install on simulator, load samples, capture a demo photo with airplane-mode-equivalent (no network needed anyway), see it in the list and detail with hash.

### Phase 2 — On-device AI and duplicate check (1–2 days)

- `ImageAnalyzer` integrated into capture and seeding. Show labels, OCR, and hash on the review screen before saving.
- Vector index and `DuplicateCheckQuery`.
- Duplicate review sheet: "Looks similar to 2 open reports within 200 m" with thumbnails, similarity %, distance in meters, age, and buttons "Attach to existing" / "File as new".
- "Find similar" on detail view.
- Debug screen (Settings → Developer): shows the last query's raw distances so the threshold can be tuned. Record the final threshold in the phase report and in docs.

Acceptance: with samples loaded and demo mode on, capturing `capture-pothole.jpg` shows the three seeded near-duplicates (minus the resolved one) with the highest similarity first; capturing the graffiti sample shows no pothole candidates.

### Phase 3 — Sync (1 day)

- `SyncManager` with replicator, user switching, simulate-offline, status + pending count.
- Sync banner component in the app (OFFLINE / SYNCING n / SYNCED) always visible at the top of the list view.
- Verify channel scoping: sign in as `crew-valley`, confirm tuolumne reports are absent; as `supervisor`, present.
- Verify the two-doc design: after "Simulate offline" off, watch the report doc arrive on the server before the photo doc (check the Admin REST `_changes` feed or timestamps in dashboard logs in Phase 4).

Acceptance: capture offline, pending count increments, go online, count drains to 0, docs visible via Admin REST GET.

### Phase 4 — Dashboard (1–2 days)

- Server and pages as in Section 10, styled per STYLE-GUIDE.
- Hash verification endpoint and UI, status change buttons.
- `scripts/tamper.mjs` and `scripts/reset-demo.mjs`.
- `test/verify.test.js`: hash comparison logic with fixture bytes (no network).

Acceptance: end-to-end run of the demo script (Section 14) on the simulator with the dashboard open, including tamper and reset.

### Phase 5 — Demo polish and README (1 day)

- README: prerequisites, Capella checklist (4.3), secrets, build and run, seeding, the demo script with timings, troubleshooting (IP allowlist, endpoint paused, index not built, 401 vs 403).
- Rehearse the demo script three times from a reset state; fix anything flaky. Every step must work within 5 minutes total.
- Final pass on poster styling, empty states, and loading states.

Acceptance: Matt can run the full demo from the README without asking questions.

### Phase 6 — Architecture and component docs (1 day)

Write the documents in Section 13. Each includes at least one Mermaid diagram, "How FieldProof uses it", "Talking points", "Possible enhancements", and "Alternatives and trade-offs".

### Phase 7 — Optional stretch (only if Matt asks)

- Voice notes via Speech framework.
- On-device summary with Apple Foundation Models (iOS 26, iPhone 15 Pro+): generate a one-sentence report title from category, labels, OCR, and notes, guarded by `#available` and `SystemLanguageModel.default.availability`.
- Dashboard live updates via the App Services `_changes` longpoll feed instead of polling.

---

## 13. Documentation deliverables (Phase 6)

All under `docs/`. Audience: a Couchbase solutions engineer who will present this and a developer who will fork it. Keep each under ~1,500 words, diagrams in Mermaid, code snippets short and copied from the real code.

1. `architecture/overview.md` — system diagram (phone ⇄ App Services ⇄ Capella ⇄ dashboard), data flow for capture → sync → dashboard, document model, sequence diagram of the duplicate check, and the five story beats mapped to components.
2. `architecture/couchbase-lite.md` — embedded database, scopes/collections, blobs, SQL++ on device, indexes, version vectors in 4.x, EE vs CE. Enhancements: encryption at rest, lazy vector index, peer-to-peer/multipeer replicator (Wi-Fi/BLE in 4.1) for crew-to-crew sync without any network. Alternatives: SQLite + custom sync, Realm (Atlas Device Sync ended Sept 2025), PowerSync, Ditto, ObjectBox, Firebase Firestore offline mode; trade-off table.
3. `architecture/vector-search-on-device.md` — the index config, centroids/training, metrics, the query, hybrid prefilters, threshold tuning method and the chosen number, why the box-then-ANN pattern works, scaling notes. Enhancements: server-side Couchbase vector search (Search service) for cross-district dedup, Capella AI Services vectorization for images uploaded from other sources, text embeddings for notes (hybrid FTS + vector), CLIP-style models via Core ML for text-to-image search. Alternatives: brute-force cosine in Swift (fine below ~5k vectors, then why the index matters), sqlite-vec, cloud vector DBs (requires connectivity, defeats beat 1).
4. `architecture/on-device-ai.md` — Vision classification, OCR, feature prints (revision 2, 768-dim, normalized), determinism, performance, privacy. Enhancements: custom Core ML classifier trained on pothole/graffiti data with Create ML, Foundation Models summarization, Speech notes, Android parity with ML Kit / TFLite. Alternatives: cloud vision APIs (latency, cost, privacy, connectivity), open-source embedding models via Core ML (DINOv2, CLIP) with dimension implications for the index.
5. `architecture/sync-and-app-services.md` — replication protocol, channels, sync function, users/roles, Admin vs Public REST, conflict handling, the two-document photo strategy, auto-purge on access loss. Enhancements: OIDC login, per-user channels, delta sync, XDCR between regions, push filters for full-res photos on cellular. Alternatives: self-hosted Sync Gateway, custom REST + queue.
6. `architecture/evidence-integrity.md` — hashing at capture, verification on server and phone, what tampering looks like. Enhancements: sign the hash with a Secure Enclave key (device attestation), anchor hashes in an append-only ledger doc, C2PA content credentials, EXIF preservation policy. Alternatives: server-side hashing only (weaker), perceptual hashes (different purpose).
7. `architecture/dashboard-and-capella.md` — Capella cluster, SDK connection, SQL++ and indexes, why Admin REST for blobs, polling vs changes feed. Enhancements: Capella Columnar analytics for trends, Eventing to notify on new reports, Capella AI Services for report summarization, MapLibre with offline tiles. Alternatives: reading blobs directly from the bucket, GraphQL layer.
8. `demo-guide.md` — the 5-minute script with what to say at each step, what to click, what could go wrong and the recovery move, plus the tamper finale.
9. `style-guide.md` — copy of STYLE-GUIDE.md as finalized, with screenshots.

---

## 14. Demo script (build toward this exactly)

Total 5 minutes. Presenter has the dashboard open on a laptop and the phone (or simulator) mirrored.

1. (0:00) Dashboard: map of the Valley district with ~25 pins. "Every one of these came from a phone that was offline when the report was taken. Swap the park for a utility territory, a campus, or a highway district; the app does not change."
2. (0:30) Phone: Settings → Simulate offline (or airplane mode). Banner turns to OFFLINE.
3. (0:45) Capture → pick the pothole sample → "Reading the scene…" → review screen shows GPS, heading, timestamp, labels (`road`, `concrete`…), OCR (if any), hash prefix.
4. (1:30) Duplicate sheet appears: "Looks similar to 2 open reports within 200 m", thumbnails, 91 % and 87 %, 38 m and 52 m. Show the query file on screen for 20 seconds. Tap "Attach to existing".
5. (2:30) Browse list offline; open a report; tap "Find similar".
6. (3:15) Turn Simulate offline off. Banner: SYNCING 2 → SYNCED. Dashboard pin pulses within a few seconds; detail shows "+1 attached capture".
7. (4:00) Dashboard detail → Verify → VERIFIED. Run `node scripts/tamper.mjs <id>` → Verify → MISMATCH. "The hash was computed on the device at capture, so the server cannot silently alter evidence."
8. (4:45) Close: "Same code path scales from 30 reports to 30,000: Couchbase Lite indexes the vectors, App Services scopes the data, Capella holds the system of record."

---

## 15. Decisions from Matt (2026-09-22)

1. Capella: **free tier** if viable. Self-hosted Couchbase Server + Sync Gateway in Docker (Section 4.5) is a valued fallback and may be built as "Option B" after Phase 5 if the free tier works, or immediately if it does not.
2. Physical iPhone: **yes**, available for the camera beat. Everything must still run on the simulator in demo mode.
3. Sample photos: **agent sources public-domain images and records attribution.** If a category cannot be sourced under a free license, stop and ask; Matt will supply photos.
4. Park and districts: **Yosemite Valley / Tuolumne** as the visual and seed-data setting. Persona is a generic field crew; see Section 1.
5. Bundle identifier and Apple team: **`com.couchbase.demo.fieldproof`, personal team** (ask before the first device build if the team name matters).
6. Dashboard: **Node.js.**
7. Stretch items (voice notes, Foundation Models summary): **Phase 7, only on request.**

---

## Appendix A — Code skeletons (verify they compile; adapt names, keep structure)

### A.1 App startup

```swift
import CouchbaseLiteSwift
import CouchbaseLiteVectorSearch   // package product; the API surface is on CouchbaseLiteSwift.Extension

@main struct FieldProofApp: App {
    @StateObject private var state: AppState
    init() {
        // Talking point: the vector search extension is loaded once, before the database opens.
        try! Extension.enableVectorSearch()
        let db = try! DatabaseManager.open()
        _state = StateObject(wrappedValue: AppState(db: db))
    }
    var body: some Scene { WindowGroup { RootView().environmentObject(state) } }
}
```

### A.2 Collections and indexes

```swift
enum DatabaseManager {
    static func open() throws -> Database {
        let db = try Database(name: "fieldproof")
        // Talking point: scopes and collections on the device mirror the ones in Capella.
        let reports = try db.createCollection(name: "reports", scope: "evidence")
        _ = try db.createCollection(name: "photos", scope: "evidence")

        // Talking point: a vector index on the phone. 768 dims from Apple's Vision feature print.
        var v = VectorIndexConfiguration(expression: "embedding", dimensions: 768, centroids: 8)
        v.metric = .cosine
        v.encoding = .none
        try reports.createIndex(withName: "idx_reports_embedding", config: v)

        let geo = ValueIndexConfiguration(["type", "status", "location.lat", "location.lon"])
        try reports.createIndex(withName: "idx_reports_geo", config: geo)
        return db
    }
}
```

### A.3 Feature print to floats

```swift
func featurePrint(_ cg: CGImage, orientation: CGImagePropertyOrientation) throws -> [Float] {
    let req = VNGenerateImageFeaturePrintRequest()
    req.revision = VNGenerateImageFeaturePrintRequestRevision2   // pin the model so vectors stay comparable
    req.imageCropAndScaleOption = .scaleFill
    try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([req])
    guard let obs = req.results?.first as? VNFeaturePrintObservation, obs.elementType == .float else {
        throw AnalyzerError.noFeaturePrint
    }
    return obs.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }  // count == obs.elementCount (768)
}
```

### A.4 Replicator

```swift
let target = URLEndpoint(url: URL(string: Secrets.appServicesURL)!)
var config = ReplicatorConfiguration(target: target)
config.addCollections([reports, photos])            // one replicator, both collections
config.replicatorType = .pushAndPull
config.continuous = true
config.authenticator = BasicAuthenticator(username: user.name, password: user.password)   // e.g. crew-valley
let replicator = Replicator(config: config)
token = replicator.addChangeListener { change in
    // Talking point: the app shows exactly what the replicator is doing: offline, busy, idle.
    self.activity = change.status.activity
    self.pendingCount = (try? replicator.pendingDocumentIds(collection: reports).count) ?? 0
    self.lastError = change.status.error
}
replicator.start()
```

(If `addCollections` does not exist in 4.1.2, use `ReplicatorConfiguration(collections: [CollectionConfiguration(collection: reports), CollectionConfiguration(collection: photos)], target: target)` as shown in the official replication docs.)

### A.5 Dashboard hash verify

```javascript
import { createHash } from 'node:crypto';
export async function verifyReport(id) {
  const report = await appservices.getDoc(keyspace('reports'), id);
  const bytes  = await appservices.getAttachment(keyspace('photos'), report.photoDocId, 'photo');
  const actual = createHash('sha256').update(bytes).digest('hex');
  return { verified: actual === report.imageHash, expected: report.imageHash, actual, byteLength: bytes.length };
}
```

## 16. Decisions from Matt during Phase 0 (2026-09-22)

1. **Bucket:** use the existing **`demos`** bucket on Matt's Capella cluster, not a new `fieldproof` bucket. Scope stays
   `evidence` with collections `reports` and `photos`, so device keyspaces and the App Endpoint mapping are unchanged.
   Server keyspaces are `` `demos`.evidence.reports `` and `` `demos`.evidence.photos ``; `CB_BUCKET=demos`.
   `scripts/setup-cluster.mjs` creates the scope and collections with SQL++ (`CREATE SCOPE … IF NOT EXISTS`).
2. **Simulator AI:** Vision cannot run on the iOS 26.4 simulator (REFERENCE.md §7.1). Sample-photo vectors and labels
   are precomputed on the Mac with the same Vision model and bundled; the simulator uses them, devices run live.
   Mac and device vectors for identical JPEG bytes differ by cosine distance 2.4e-6.
3. **Apple team:** Personal Team `8R6V8R27NM`; test device iPhone 15 Pro Max.
4. **No admin credential anywhere in the app (supersedes §2 "Dashboard data access", §9, §10.2 `lib/appservices.js`, §11.3 reset).**
   The Capella App Services Admin API only manages sessions, users, and roles (REFERENCE.md §3), and giving the dashboard
   a sync-function-bypassing key was an antipattern. Instead:
   - Dashboard queries: Couchbase Node SDK with a database credential (read access on the bucket).
   - Photo/thumbnail bytes, status changes, `tamper.mjs`, `reset-demo.mjs`: App Services **Public REST** (port 4984) as the
     `supervisor` app user (channel `*`), so every write goes through the sync function like a phone's.
   - `lib/appservices.js` targets `APPSERVICES_URL` (4984) with `APPSERVICES_USER`/`APPSERVICES_PASSWORD`.
   - Users and channels are created once in the Capella UI; the admin credential can be deleted after setup.
   - Demo line for the tamper beat: "even someone with valid access who swaps the photo is caught, because the hash was
     computed on the device at capture."
5. **Duplicate threshold 0.15** (not 0.35), measured in Phase 2; see REFERENCE.md §7.2.
6. **Simulator AI in practice:** `ImageAnalyzer` uses `Demo/Samples/analysis.json` (keyed by SHA-256) for labels and embeddings on the
   simulator only, and runs OCR live. The review screen says so. Rerun `swift scripts/embed-samples.swift` after changing samples.

## 17. Roadmap (not scheduled; Matt decides when)

### 17.1 Review the Capella AI Data Plane (paid tier)

FieldProof deliberately runs on the Capella free tier with a plain phone app. The paid **Capella AI Data Plane**
(REFERENCE.md §4) could make parts of it simpler or stronger. The docs and the product page already carry short
asides marked "Capella AI Data Plane (paid)"; this item is the review that turns them into tested claims.

What to evaluate, in order of likely payoff:

1. **AI Functions in SQL++** on the dashboard: `ai_summary` for a weekly digest per district, `ai_classification` to
   triage notes, `ai_masked` to strip names and phone numbers from notes before a report is shared outside the
   organisation, and `ai_summary` / `ai_completion` as a server-side fallback summary for phones without Apple
   Intelligence.
2. **The Couchbase MCP Server** in read-only mode, so a supervisor can ask an assistant questions about the reports
   ("open potholes in Valley older than a week") in plain language.
3. **Data Processing Service** workflows to vectorize photographs that arrive from other channels (email, a web
   portal, a contractor's S3 upload).
4. **Model Service** for a hosted embedding model or LLM that stays inside Capella.

Questions the review must answer:

- **Vector compatibility.** The phone's vectors come from Vision feature print revision 2. A server-side model
  produces different vectors that cannot be compared with them. Either one model runs on both sides, or the
  server keeps its own index and the duplicate check stays per-model. The docs list text embedding models only;
  confirm whether any hosted model embeds images.
- **Where the AI runs, and what it costs.** On-device inference is free per call and works offline. Every AI
  Data Plane call is a server-side charge and needs connectivity. Keep capture on the phone; use the AI Data Plane
  only for work that is genuinely global.
- **Requirements.** AI Functions need a paid cluster on Couchbase Server 8.0+, Developer Pro or Enterprise support,
  and multiple availability zones. Price the smallest cluster that meets them.
- **Demo shape.** Whether this becomes an optional sixth beat on a paid cluster, with the free-tier demo unchanged.

Deliverable: a `docs/architecture/capella-ai-data-plane.md` note in the usual four sections, measured results for
whatever is tried, and updated asides.
