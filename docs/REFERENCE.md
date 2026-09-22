# FieldProof — Verified Reference (APIs, versions, sources)

Checked against official documentation on **2026-09-22**. When you (the implementing agent) discover that
something here is wrong or outdated, fix it here with the new source and date, then continue.

The rule: **only use APIs that appear in this file or in the official docs linked from it.** The
Couchbase agent skills (`couchbaselabs/agent-skills`) are useful for patterns, but Section 6 lists the
places where they disagree with the official docs; this file wins.

---

## 1. Couchbase Lite Swift (Enterprise Edition)

| Item | Value | Source |
|---|---|---|
| Current version | **4.1.2** (Sept 2026); 4.1.0 shipped June 2026 | https://docs.couchbase.com/couchbase-lite/current/swift/releasenotes.html |
| SPM URL (EE) | `https://github.com/couchbase/couchbase-lite-swift-ee.git`, product **`CouchbaseLiteSwift`** | https://docs.couchbase.com/couchbase-lite/current/swift/gs-install.html |
| SPM URL (CE, not used) | `https://github.com/couchbase/couchbase-lite-swift.git` (4.0+; 3.x used a different URL) | same |
| Minimum OS | iOS **15.0+**; macOS 14 and 15 supported; Mac Catalyst and Apple Silicon supported | https://docs.couchbase.com/couchbase-lite/current/swift/supported-os.html |
| Sync compatibility | CBL 4.x requires **Sync Gateway / App Services 4.0+**. CBL 4.x uses version vectors instead of revision trees; you cannot downgrade a 4.x database to 3.x. | https://docs.couchbase.com/couchbase-lite/current/swift/upgrade.html , https://docs.couchbase.com/couchbase-lite/current/swift/compatibility.html |
| 3.x → 4.x API changes | `replicator.resetCheckpoint()` removed → `replicator.start(reset: true)`; `Database.setLogLevel` removed → `Database.log.console.level/domain`; `db.compact()` → `db.performMaintenance(type: .compact)`; `DatabaseConfiguration`, `ReplicatorConfiguration`, `URLEndpointListenerConfiguration` are now structs (declare with `var`). | https://docs.couchbase.com/couchbase-lite/current/swift/upgrade.html |
| 4.1 new | MultipeerReplicator gains Bluetooth Low Energy with automatic Wi-Fi/BLE switching (iOS 15+); replication correlation ID property for matching Sync Gateway logs | https://docs.couchbase.com/couchbase-lite/current/cbl-whatsnew.html |
| Docs hub | https://docs.couchbase.com/couchbase-lite/current/swift/quickstart.html | |
| API reference | https://docs.couchbase.com/mobile/4.1.0/couchbase-lite-swift/ (browse from the docs hub if the path differs) | |

Core API shapes used by FieldProof (from the official Swift docs):

```swift
let db = try Database(name: "fieldproof")                       // var config = DatabaseConfiguration() if needed
let col = try db.createCollection(name: "reports", scope: "evidence")
var doc = MutableDocument(id: "report::…")
doc.setString(…, forKey:); doc.setBlob(Blob(contentType: "image/jpeg", data: data), forKey: "thumbnail")
doc.setArray(MutableArrayObject(data: floats.map { $0 as NSNumber }), forKey: "embedding")
try col.save(document: doc)
let q = try db.createQuery("SELECT … FROM evidence.reports WHERE …")   // scope.collection in FROM
let p = Parameters(); p.setValue(…, forName:); p.setArray(…, forName:); q.parameters = p
for r in try q.execute() { r.string(forKey:), r.double(forKey:) }
```

Also used from Phase 1 (checked against the 4.1.2 `.swiftinterface`, 2026-09-22):

| API | Use | Source |
|---|---|---|
| `Blob(contentType:data:)`, `blob.content`, `doc.setBlob(_:forKey:)`, `doc.blob(forKey:)` | Thumbnail in the report doc, full photo in the photo doc | https://docs.couchbase.com/couchbase-lite/current/swift/blob.html |
| `database.inBatch(using:)` | Save report + photo docs together | https://docs.couchbase.com/couchbase-lite/current/swift/document.html (Batch operations) |
| `query.addChangeListener { change in change.results }` → `ListenerToken.remove()` | Live report list. Observed: the listener fires once right away with the current results, then on every change. | https://docs.couchbase.com/couchbase-lite/current/swift/query-live.html |
| `database.collection(name:scope:)`, `collection.document(id:)`, `doc.toMutable()` | Read and update | https://docs.couchbase.com/couchbase-lite/current/swift/document.html |
| `doc.removeValue(forKey:)`, `doc.contains(key:)` | Leave `embedding`/`attachedTo` out when empty | same |
| `database.close()`, `Database.delete(withName:inDirectory:)` | Settings → Reset local data (live query tokens removed first) | https://docs.couchbase.com/couchbase-lite/current/swift/database.html |

## 2. Couchbase Lite Vector Search extension

| Item | Value | Source |
|---|---|---|
| Version | **2.0.0** (required for CBL 4.0+) | https://docs.couchbase.com/couchbase-lite/current/swift/gs-install.html |
| SPM URL | `https://github.com/couchbase/couchbase-lite-vector-search-spm.git`, product **`CouchbaseLiteVectorSearch`** | same |
| Enable | `try Extension.enableVectorSearch()` — **must run before opening any database** | same |
| CocoaPods (not used) | `pod 'CouchbaseLiteVectorSearch', '2.0.0'` | same |
| Edition | Enterprise Edition only | https://docs.couchbase.com/couchbase-lite/current/swift/vector-search.html |
| Architectures | 64-bit only; Intel needs AVX2. Apple Silicon simulators are arm64 and expected to work; **verify in Phase 0**. | https://docs.couchbase.com/couchbase-lite/current/swift/gs-prereqs.html |
| Index config | `var config = VectorIndexConfiguration(expression: "embedding", dimensions: 768, centroids: 8)`; optional `config.metric = .cosine` (also `.euclidean`, `.dot`; default squared Euclidean), `config.encoding = .none` (default is scalar quantizer; product quantizer available), `config.numProbes`, `config.minTrainingSize`, `config.maxTrainingSize`, `config.isLazy` | https://docs.couchbase.com/couchbase-lite/current/swift/working-with-vector-search.html |
| Limits | dimensions 2–4096; centroids 1–64000 | same |
| Create index | `try collection.createIndex(withName: "idx_reports_embedding", config: config)` | same |
| Query function | `APPROX_VECTOR_DISTANCE(vector-expr, target-vector, [metric], [nprobes], [accurate])`; only `accurate = false` is supported; use it in `WHERE … < x`, `ORDER BY`, and/or `SELECT`. Cosine metric returns `1 − cosine similarity`. | same |
| Parameter binding | `parameters.setArray(MutableArrayObject(data: floats.map { $0 as NSNumber }), forName: "queryVector")` | couchbaselabs skill + official Parameters API |
| Training | Index trains on the first query once the vector count meets the minimum training size (defaults are 0, meaning computed from centroids and encoding). Before training, queries do a **full scan** (correct results, slower). Guideline: centroids ≈ √(document count). | https://docs.couchbase.com/couchbase-lite/current/swift/vector-search.html |
| Hybrid | Vector distance can be combined with normal SQL++ predicates and `MATCH()` full-text search in one query | same |

## 3. Capella App Services

| Item | Value | Source |
|---|---|---|
| Version | App Services **4.1.2** (Sept 2026); 4.0 GA Oct 2025 (bidirectional XDCR between App Services clusters); CBL 4.x clients supported | https://docs.couchbase.com/app-services/release-notes/release-notes.html |
| Free tier | App Services are **included in the Capella free tier** (guided onboarding). Cluster and linked App Services pause after 72 h of inactivity; state is preserved. | https://docs.couchbase.com/app-services/get-started/configuring-app-services.html , https://www.couchbase.com/blog/free-tier-capella-dev-available/ |
| App Endpoint | Created per bucket + scope; link up to 250 collections; endpoints may share a scope but not a collection; new endpoints start **Offline** and must be **Resumed** | https://docs.couchbase.com/cloud/app-services/deployment/creating-an-app-endpoint.html |
| Public URL | `wss://<id>.apps.cloud.couchbase.com:4984/<endpoint>` (copy from App Endpoint → Connect). Public REST: same host, `https`, path `/<endpoint>.<scope>.<collection>/<docid>` | https://docs.couchbase.com/app-services/get-started/configuring-app-services.html |
| Admin REST (Capella) | `https://<id>.apps.cloud.couchbase.com:4985/…`, Basic auth with an Admin Credential; caller IP must be on the Admin API allowed list. **In Capella it covers only sessions, users (`/{db}/_user/{name}`), and roles (`/{db}/_role/…`). There are no document, attachment, `_all_docs`, `_changes`, or config endpoints.** Verified 2026-09-22: `GET /fieldproof/_user/` → 200; `GET /fieldproof.evidence.reports/_all_docs` and `PUT …/{docid}` → 403. | https://docs.couchbase.com/cloud/app-services/references/rest_api_admin.html , live probe |
| Admin user endpoints | `GET/PUT/DELETE/HEAD /{db}/_user/{name}` (`password`, `admin_channels`, per-collection `collection_access`), `/{db}/_role/…` | same |
| Public REST (use for documents) | `https://<id>.apps.cloud.couchbase.com:4984/…`, Basic auth as an **app user** (or `POST /{db}/_session`). The `supervisor` user (channel `*`) sees every district. | https://docs.couchbase.com/app-services/references/rest_api_public.html |
| Document REST (public) | `POST /{keyspace}/`, `GET/PUT/DELETE/HEAD /{keyspace}/{docid}` with `rev` query param or `If-Match`; `GET/POST /{keyspace}/_all_docs`, `POST /{keyspace}/_bulk_docs`, `POST /{keyspace}/_bulk_get`; keyspace is `db.scope.collection` | same |
| Attachment REST (public) | `GET/PUT/HEAD/DELETE /{keyspace}/{docid}/{attach}`; PUT takes `rev` and a `Content-Type` header | same |
| Changes feed (public) | `/{keyspace}/_changes` with `feed=longpoll`, `since`, channel filters (GET or POST) | same |
| Sync function | `function (doc, oldDoc, meta) { … }` per collection under Security → Access and Validation. Helpers: `channel()`, `access()`, `role()`, `requireUser()`, `requireRole()`, `requireAccess()`, `requireAdmin()`, `throw({forbidden: "…"})`. Default for non-default collections: `channel(collectionName)`. `doc._deleted` is true on tombstones. | https://docs.couchbase.com/cloud/app-services/deployment/access-control-data-validation.html |
| Users/roles UI | Security → App Roles (admin channels per collection, `*` for all) and Security → App Users (password, roles, channels) | https://docs.couchbase.com/app-services/get-started/configuring-app-services.html |

Replicator (official Swift replication docs, CBL 4.x):

```swift
let target = URLEndpoint(url: URL(string: "wss://…/fieldproof")!)
let collConfig = CollectionConfiguration(collection: reports)   // optional: .channels, .pushFilter, .pullFilter
var config = ReplicatorConfiguration(collections: [collConfig, CollectionConfiguration(collection: photos)], target: target)
config.authenticator = BasicAuthenticator(username: "crew-valley", password: "…")
config.replicatorType = .pushAndPull
config.continuous = true
config.enableAutoPurge = true   // default; docs removed locally when channel access is lost
let replicator = Replicator(config: config)
let token = replicator.addChangeListener { change in
    change.status.activity      // .stopped, .offline, .connecting, .idle, .busy
    change.status.progress.completed / .total
    change.status.error
}
replicator.addDocumentReplicationListener { rep in rep.isPush; rep.documents.map { ($0.id, $0.error) } }
replicator.start()                 // replicator.start(reset: true) forces a full resync
try replicator.pendingDocumentIds(collection: reports)      // Set<String>
try replicator.isDocumentPending(docID, collection: reports)
```
Source: https://docs.couchbase.com/couchbase-lite/current/swift/replication.html

### Self-hosted fallback (Sync Gateway in Docker)

| Item | Value | Source |
|---|---|---|
| Sync Gateway | 4.1.x Enterprise image `couchbase/sync-gateway:<version>-enterprise`; ports 4984 public, 4985 admin. Persistent config: bootstrap file + database config via `PUT /{db}/` on the admin port with `scopes.<scope>.collections.<name>.sync` per collection. | https://docs.couchbase.com/sync-gateway/current/get-started-prepare.html , https://docs.couchbase.com/sync-gateway/current/configuration-overview.html |
| Couchbase Server | 7.6.x (App Services 4.0 requires Server 7.6.0+; use the same floor). Docker image `couchbase:enterprise-7.6.x`. Sync Gateway needs an RBAC user with the `mobile_sync_gateway` role. | https://docs.couchbase.com/app-services/release-notes/release-notes.html , https://docs.couchbase.com/sync-gateway/current/get-started-prepare.html |
| Plain WebSocket | Couchbase Lite accepts `ws://` for development targets; use `wss://` only for the cloud endpoint. | https://docs.couchbase.com/couchbase-lite/current/swift/replication.html |

Verify exact config keys in the 4.x configuration reference before writing `selfhosted/`; record the final JSON here.

## 4. Couchbase Capella and Node.js SDK

| Item | Value | Source |
|---|---|---|
| Node SDK | `couchbase` **4.7.x** on npm (4.7.1 current); native module with prebuilt binaries; tested on Node LTS; ESM and CommonJS both fine | https://www.npmjs.com/package/couchbase , https://docs.couchbase.com/nodejs-sdk/current/hello-world/start-using-sdk.html |
| Connect | `await couchbase.connect('couchbases://cb.<id>.cloud.couchbase.com', { username, password, configProfile: 'wanDevelopment' })`, then `cluster.bucket('fieldproof').scope('evidence').collection('reports')` | same |
| Query | `await cluster.query(sql, { parameters: { CITY: 'Reno' } })` → `result.rows`; also `scope.query(...)`. Scan consistency: `scanConsistency: couchbase.QueryScanConsistency.RequestPlus` | https://docs.couchbase.com/nodejs-sdk/current/howtos/n1ql-queries-with-sdk.html |
| Capella access | Cluster → Allowed IP addresses must include the dashboard host; Database credentials with bucket read/write | https://docs.couchbase.com/cloud/get-started/create-account.html |
| Blobs on the server | CBL blobs sync as Sync Gateway attachments; read them through the App Services **Public** REST attachment endpoint as `supervisor` (the Capella Admin API has no attachment endpoints), not through the SDK | design decision, see PLAN.md §10, §16 |
| Capella AI Services | Model Service (hosted LLMs/embeddings), Vectorization Service (auto-embeddings on write), Unstructured Data Service, Agent Catalog, AI Functions; rebranded "AI Data Plane" in 2026 | https://www.couchbase.com/blog/ai-services-expedite-agent-development/ , https://docs.couchbase.com/ai/build/vectorization-service/data-processing.html |
| Server-side vector search | Couchbase Search service vector indexes on the cluster (for the cross-district dedup enhancement) | https://www.couchbase.com/products/vector-search/ |

## 5. Apple frameworks

| Item | Value | Source |
|---|---|---|
| `VNGenerateImageFeaturePrintRequest` | iOS 13+. Revision 2 (`VNGenerateImageFeaturePrintRequestRevision2`) is iOS 17+/macOS 14+ and yields a **normalized float vector of length 768** (revision 1 yields 2048). Result `VNFeaturePrintObservation` has `data: Data`, `elementCount: Int`, `elementType: VNElementType` (`.float`), `computeDistance(_:to:)`. Feature prints from different revisions are not comparable. | https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequestrevision2 , https://developer.apple.com/documentation/vision/vnfeatureprintobservation , https://github.com/missingems/MTGImageHash (768 confirmed in practice) |
| Newer Swift API (optional) | iOS 18+: `ImageFeaturePrintRequest` / `FeaturePrintObservation` (async `perform`). Not required; the VN* API is used because the docs and samples are more complete. | https://developer.apple.com/documentation/vision/imagefeatureprintrequest |
| `VNClassifyImageRequest` | Built-in multi-label classifier, ~1,303 identifiers (`VNClassifyImageRequest.knownClassifications(forRevision:)`). Present: `road`, `dirt_road`, `graffiti`, `tree`, `bench`, `sign`, `lamp`, `light`, `fence`, `trash_can`, `water`, `path`, `rock`, `concrete`, `plant`, `grass`, `park`, `forest`, `building`, `door`, `window`, `pipe`. **Absent:** `pothole`, `asphalt`, `pavement`, `mural`, `crack`, `damage`. | https://gist.github.com/ktustanowski/56c0d7541813868fed4aceb60ab5d149 , https://developer.apple.com/documentation/vision/vnclassifyimagerequest |
| `VNRecognizeTextRequest` | `recognitionLevel = .accurate`, `usesLanguageCorrection = true`; results `VNRecognizedTextObservation.topCandidates(1)` | https://developer.apple.com/documentation/vision/vnrecognizetextrequest |
| CryptoKit | `SHA256.hash(data:)` → `.compactMap { String(format: "%02x", $0) }.joined()` | https://developer.apple.com/documentation/cryptokit/sha256 |
| Foundation Models (stretch) | iOS 26+, on-device ~3B model; `LanguageModelSession().respond(to:)`; check `SystemLanguageModel.default.availability`; needs iPhone 15 Pro or newer / M-series | https://developer.apple.com/documentation/foundationmodels |
| Simulator | No camera; no airplane mode. Use demo mode (bundled photos, simulated location) and the in-app "Simulate offline" switch. | design decision |

## 6. Where the couchbaselabs agent skills disagree with the official docs

The skills at https://github.com/couchbaselabs/agent-skills (install: `/plugin install github:couchbaselabs/agent-skills`) are good for patterns. Known discrepancies as of 2026-09-22:

| Skill says | Official docs say (use this) |
|---|---|
| `mobile-vector-search-ios`: package `couchbase-lite-ios-ee`, target `CouchbaseLiteSwift-EE-VectorSearch`, enable with `VectorSearch.enable()` | Packages `couchbase-lite-swift-ee` (product `CouchbaseLiteSwift`) + `couchbase-lite-vector-search-spm` 2.0.0 (product `CouchbaseLiteVectorSearch`); enable with `try Extension.enableVectorSearch()` |
| `mobile-vector-search-ios`: metric enum `.dotProduct` | `.dot` (per the working-with-vector-search page); verify against the 4.1 API reference when compiling |
| `app-services`: "free tier unsupported"; Admin API is the Cloud Management API | Free tier includes App Services; the App Services Admin REST API is on port 4985 with an Admin Credential and IP allowlist. (The Capella Management API also exists for provisioning, but is not needed here.) |
| `mobile-sync-ios`: `ReplicatorConfiguration(target:)` then `addCollection(...)`, `replicator.pendingDocumentIDs()` | Prefer the documented `ReplicatorConfiguration(collections:target:)` form and `pendingDocumentIds(collection:)`. If the `addCollection` form compiles in 4.1.2, either is fine. |

## 7. Things to verify at runtime in Phase 0 (and record here)

Environment used (2026-09-22): macOS 27.0 (Apple Silicon), Xcode 27.0 (27A266a), iOS 26.4 simulator (iPhone 17 Pro), iPhone 15 Pro Max (iPhone16,2, A17 Pro), Node 26.5.0 (Homebrew), couchbase 4.7.1, express 5.2.1.

- [x] `Extension.enableVectorSearch()` succeeds on the iOS 26.4 Simulator (Apple Silicon) and on the iPhone 15 Pro Max.
- [x] Device: `elementCount == 768`, `.float`, deterministic, norm 1.0003 (normalize before use), 257–323 ms per full analysis. Default compute (Neural Engine) works; pinning to CPU or GPU on the device **fails** ("Loading espresso Network, error -2"), so the CPU pin is simulator-only. Device query distances equal exact cosine (0.0070 / 0.3296 / 0.3788 on the spike scenes).
- [x] **Mac vs device, same JPEG bytes** (`Demo/Samples/phase0-test.jpg`): cosine distance **2.4e-6**, max per-element difference 5.2e-4 (normalized). Per-element differs by more than 1e-4, but the difference is negligible for cosine matching. Precomputing sample vectors on the Mac is valid.
- [ ] **Simulator cannot produce real vectors** (see 7.1). Decision (Matt, 2026-09-22): precompute vectors and labels for bundled samples on the Mac; the simulator uses them, devices run live.
- [x] Compiles in 4.1.2 (checked against the binary `.swiftinterface`): `VectorIndexConfiguration(expression:dimensions:centroids:)` with `var metric: DistanceMetric`, `encoding: VectorEncoding`, `numProbes`, `minTrainingSize`, `maxTrainingSize`, `isLazy`. `DistanceMetric` cases: `.euclideanSquared`, `.cosine`, `.euclidean`, `.dot`. `VectorEncoding`: `.none`, `.scalarQuantizer(type:)`, `.productQuantizer(subquantizers:bits:)`. `ReplicatorConfiguration(collections: [CollectionConfiguration], target:)`; **there is no `addCollection(s)`**. `CollectionConfiguration(collection:)` has `channels`, `pushFilter`, `pullFilter`, `conflictResolver`, `documentIDs`. `replicator.pendingDocumentIds(collection:)` exists.
- [x] `FROM evidence.reports` is accepted by `database.createQuery`.
- [x] Public REST, 2026-09-22 (probe as app users): writes return `rev` like `1-7077bb…` plus a `cv` version vector (`18d7adfb…@…`). `?rev=<rev>` works on PUT, attachment PUT, and DELETE; a stale rev gives 409. Attachment bytes round-trip exactly (SHA-256 equal); `_attachments.photo` has `content_type`, `digest` (sha1), `length`. Documents written through App Services are visible to SQL++ in `demos`.evidence.reports.
- [x] Sync function and channels: missing district, wrong type, and district change → 403; `crew-tuolumne` can't write or read valley docs (403).
- [x] **`_all_docs` is disabled on the Capella Public API** ("public access to _all_docs is disabled for this database"). `_changes` works. Scripts list doc ids with SDK SQL++ instead.
- [x] **The `*` channel grants read of everything but does NOT satisfy `requireAccess("district.x")`** ("sg missing channel access"). A user who must write to a district needs that channel explicitly.
- [x] App Services reachable: `GET https://<host>:4984/` → 200, Sync Gateway 4.1.1 EE; `GET /fieldproof/` without auth → 401; Admin `_user` list → `crew-tuolumne`, `crew-valley`, `supervisor`. The free tier includes the Admin API.
- [x] `npm install couchbase@4.7` installs a prebuilt binary on Node 26.5 (no compile). npm 11 prints an `allow-scripts` warning for the package's install script; the binding loads without it.

### 7.1 Findings that change the plan (2026-09-22)

| Finding | Evidence | Consequence |
|---|---|---|
| **`APPROX_VECTOR_DISTANCE` needs the metric argument.** Omitting it fails with "in 3rd argument to APPROX_VECTOR_DISTANCE, euclidean2 does not match the index's metric, cosine". The docs say the index metric is used by default; 4.1.2 does not do that. Allowed strings: `"EUCLIDEAN_SQUARED"`, `"L2_SQUARED"`, `"EUCLIDEAN"`, `"L2"`, `"COSINE"`, `"DOT"`. | Simulator run; https://docs.couchbase.com/couchbase-lite/current/swift/working-with-vector-search.html | Query passes `'COSINE'` explicitly in every call. |
| **SQL `--` comments are rejected** by `createQuery` ("N1QL syntax error"). | Simulator run | Clause comments live in Swift next to the SQL string, not inside it. |
| **`$limit` is not a valid parameter name** (`limit` is a keyword; syntax error at `LIMIT $limit`). | Simulator run | Parameter renamed `$maxResults`. |
| **`CouchbaseLiteVectorSearch` has no Swift module** (the xcframework has no `Modules/`). `import CouchbaseLiteVectorSearch` does not compile. It is loaded at runtime by `Extension.enableVectorSearch()`; linking and embedding it via SPM is enough. The package zip also contains a `Build -> .` symlink, which makes SPM print a long "multiple potential binary artifacts" warning. Harmless. | Artifact inspection | Do not import it (PLAN Appendix A.1 is wrong on this line). |
| **Logging API in 4.x** is `LogSinks.console = ConsoleLogSink(level: .info, domains: .all)` (not `Database.log.console`). | https://docs.couchbase.com/couchbase-lite/current/swift/new-logging-api.html , `.swiftinterface` | Used in `DatabaseManager`. |
| **Vision ML models do not work on the iOS 26.4 Simulator.** By default `VNGenerateImageFeaturePrintRequest` and `VNClassifyImageRequest` fail with "Failed to create espresso context". Pinning to the CPU with `VNRequest.setComputeDevice(_:for:)` (iOS 17+, `MLComputeDevice.cpu`, stages from `supportedComputeStageDevices`) makes them run, but **every image returns the same feature print** (cosine distance 0.0000 between a road and a forest scene) and nonsense labels (`night_sky`, `moon`). The simulated GPU (`MLGPUComputeDevice "Apple iOS simulator GPU"`) also fails. `VNRecognizeTextRequest` (OCR) works on the simulator. On macOS 27, the same revision-2 feature print gives distinct vectors (distances 0.23–0.41 for the same test scenes). | Simulator probe in `Demo/Phase0Spike.swift`; macOS check with a Vision CLI; https://developer.apple.com/documentation/vision/vnrequest/setcomputedevice(_:for:) | Needs a decision from Matt: see the Phase 0 report. |

### 7.2 Duplicate threshold (Phase 2, 2026-09-22)

Measured with Vision feature print revision 2 on the bundled samples (`scripts/embed-samples.swift`, cosine distance):

| Pair | Distance |
|---|---|
| `capture-pothole` vs `pothole-01` / `pothole-01b` (crops, hue shift) | 0.019 / 0.020 |
| `pothole-01` vs `pothole-01c` (3° rotation, +8% brightness) | 0.092 (capture vs 01c: 0.102) |
| Closest different subjects, same category (two fallen trees) | 0.124 |
| Different potholes | 0.18–0.31 |
| Other captures vs anything (graffiti, sign) | 0.23 and up |

**Chosen: 0.15** (`DuplicateCheckQuery.defaultMaxDistance`), with the 200 m geo box. The plan's starting value 0.35 matched different
potholes. Re-check with real re-photographs on a device (Settings → Developer → Last duplicate check) before a customer demo.

Classification note: `VNClassifyImageRequest` has no pavement labels; close-up potholes score under 0.1 on everything
(top guesses include `liquid`, `water`, and at 0.057 `alligator_crocodile`). The 0.1 cutoff stays; the crew member picks the category.
