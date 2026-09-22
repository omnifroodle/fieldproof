# Claude Code Prompt: FieldProof Demo App

> **Note (2026-09-22):** superseded in two places by [PLAN.md](PLAN.md). The persona is now a generic
> field crew / inspector / supervisor rather than a park ranger (PLAN.md §1), and Couchbase Lite has moved
> to 4.1.x with App Services 4.x (REFERENCE.md). The story beats, demo flow, and working rules below still apply.

Copy everything below the line into Claude Code (plan mode recommended for the first pass).

---

## Goal

Build **FieldProof**, a demo app for Couchbase. It is an offline-first evidence collection tool for park rangers, facilities managers, and public works crews. They photograph an issue (pothole, graffiti, downed tree, broken fixture), the phone captures rich metadata and runs on-device AI, and everything syncs to the cloud when connectivity returns.

This is a **sales and customer demo, not a production app**. Optimize for a clear story, a reliable 5-minute live demo, and code that a Couchbase engineer can walk through and explain. Prefer simple and readable over clever or complete. Do not add features that are not listed here.

## The story the demo must tell

Every feature should serve one of these beats. If it doesn't, leave it out.

1. **Works with no signal.** A ranger is deep in a park with no coverage. Capture, search, and review all work fully offline because the data lives in Couchbase Lite on the device.
2. **AI on the device.** The phone classifies the photo, reads any text in it (asset tags, signs), and generates an image embedding. No cloud call required.
3. **Stops duplicate reports before they happen.** Before saving, the app runs a local vector search: "This looks similar to 2 open reports within 200 meters." The user can attach to an existing report instead of filing a new one. This is the headline moment.
4. **Trustworthy evidence.** Each photo is SHA-256 hashed at capture and the hash is stored with the record, giving a tamper-evident chain of custody.
5. **Syncs when back online.** Reconnect and the supervisor dashboard updates live. Crews only receive data for their own district.

## Demo script (build toward this exact flow)

1. Show the supervisor dashboard with existing reports on a map.
2. On the phone, turn on airplane mode.
3. Capture a photo of a pothole. Show auto-captured GPS, heading, timestamp, classification label, OCR text, and hash.
4. The duplicate check fires and shows similar nearby open reports with thumbnails and similarity scores. Choose "attach to existing" or "file new."
5. Browse and search reports offline, including "find similar" from any photo.
6. Turn airplane mode off. The dashboard updates within seconds.
7. Optional: tamper with an image on the server side and show the dashboard flagging the hash mismatch.

## Architecture

- **Mobile app:** iOS, SwiftUI, Couchbase Lite Swift (Enterprise Edition, with the vector search extension).
- **Sync:** Couchbase Capella App Services (Sync Gateway). Use channels to scope data by district.
- **Backend:** Couchbase Capella cluster.
- **Supervisor dashboard:** a small web app (Node.js or Python, your choice, keep it minimal) using the Couchbase SDK. Show a map with report pins (Leaflet), a report detail view with the photo, and live updates (polling is fine).

### On-device capabilities to use (built-in frameworks only, no third-party ML)

- Camera capture (AVFoundation or UIImagePickerController, whichever is simpler)
- Location and heading (CoreLocation)
- Classification: Vision `VNClassifyImageRequest`
- OCR: Vision `VNRecognizeTextRequest`
- Image embeddings: Vision `VNGenerateImageFeaturePrintRequest` (verify the output dimension for the target iOS version and use it for the vector index)
- Voice notes to text: Speech framework (stretch goal, do last)
- Hashing: CryptoKit SHA-256

## Data model

One document per report in a `reports` collection:

- `type`, `id`, `district`, `status` (open / in_progress / resolved)
- `createdAt`, `createdBy`, `deviceId`
- `location`: lat, lon, accuracy, altitude, heading
- `category`: user-selected (pothole, graffiti, tree, fixture, other)
- `aiLabels`: top classification labels with confidence
- `ocrText`
- `notes`
- `embedding`: array of floats from the feature print
- `imageHash`: SHA-256 of the original image bytes
- `photo`: Couchbase Lite blob (full resolution) and `thumbnail`: blob (small JPEG)
- `relatedReportIds`: when a new capture is attached to an existing report

Keep embedding generation deterministic so the same photo always produces the same vector.

## Key query: the duplicate check

This query is the Couchbase showcase. Make it a single, readable SQL++ query in Couchbase Lite that combines:

- vector similarity on `embedding` using `APPROX_VECTOR_DISTANCE`
- a latitude/longitude bounding box prefilter for roughly 200 meters
- `status != "resolved"`

Then compute exact distance in Swift for display. Put the query in its own clearly named file with comments explaining each clause, because I will show this code on screen.

## Build in phases

Stop at the end of each phase, summarize what works, and wait for me before continuing.

1. **Local capture.** Project setup, Couchbase Lite integration, capture a photo with metadata and hash, save it, and list reports offline.
2. **On-device AI.** Classification, OCR, embeddings, vector index, and the duplicate check UI.
3. **Sync.** App Services configuration, district channels, and sync status indicator in the app (online/offline, pending changes count).
4. **Dashboard.** Map, detail view, live updates, and hash verification.
5. **Demo polish.** Seed data script, demo mode, README with setup steps and the demo script.

## Demo reliability requirements

- **Seed data:** a script that loads 20 to 30 realistic reports clustered in one park, with photos, so the map and duplicate check look good immediately. Include at least 3 near-duplicate potholes.
- **Demo mode:** since the simulator has no camera, allow picking from a bundled set of sample photos, and allow a fixed simulated location near the seeded reports.
- **Thumbnails sync first.** Keep full-resolution images from slowing sync during the demo.
- **Visible sync state.** The app must clearly show offline, syncing, and synced so the audience sees what is happening.

## Working rules

- Before writing code that uses Couchbase Lite vector search, App Services, or the Couchbase SDK, check the current official Couchbase documentation for the exact API names, package names, and version requirements. These APIs change and I don't want code based on outdated examples.
- Ask me for Capella and App Services credentials and endpoints when you need them. Never hard-code secrets; use a config file excluded from git.
- Keep the codebase small. Favor a few well-named files over deep abstraction.
- Add short comments where Couchbase features are used, written so they double as talking points.
- Start by proposing the project structure and phase 1 plan, and list any questions before you write code.
