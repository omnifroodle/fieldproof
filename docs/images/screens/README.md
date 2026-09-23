# Screenshots

Captured on 2026-09-22 from a live run: iPhone 17 Pro simulator (iOS 26.4) against Capella, 30 seeded
reports, signed in as `crew-valley`. Phone shots are 800 px wide, dashboard shots 1400 px, all JPEG q90.
The dashboard was photographed in Safari on an iPad Pro 13" simulator so the desktop layout shows;
Safari's own chrome is cropped off.

| File | What it shows |
|---|---|
| `list-offline.jpg` | Report list, OFFLINE banner, 25 reports (Valley only) |
| `list-offline-pending.jpg` | The same list after an offline capture: "OFFLINE · 2 REPORTS SAFE ON DEVICE" |
| `list-synced.jpg` | The list with the SYNCED banner |
| `list-synced-after.jpg` | Synced, filtered to Pothole, after the attach |
| `list-pothole-filter.jpg` | Category filter applied, with the "+1 attached" row |
| `demo-camera.jpg` | The sample picker used instead of the camera on the simulator |
| `review-evidence.jpg` | Review screen: GPS, heading, time, SHA-256, and what the models found |
| `duplicate-check.jpg` | "LOOKS FAMILIAR": 2 open reports within 200 m, 98% alike |
| `report-detail.jpg` | A report with an attached capture and its on-device labels |
| `find-similar.jpg` | "Find similar" at 2 km, resolved work included |
| `settings-user-and-sync.jpg` | User picker, simulate-offline, demo mode, local report count |
| `dashboard-map.jpg` | Supervisor dashboard: map and list |
| `dashboard-detail.jpg` | Dashboard report detail with the evidence hash card |
| `verify-verified.jpg` | Verify → VERIFIED |
| `verify-mismatch.jpg` | After `npm run tamper` → MISMATCH, with the server's bytes and hash |

`../video/capture-flow.mp4` is the offline capture through to the duplicate check, sped up 3×.
