# FieldProof — working agreement for coding agents

FieldProof is a Couchbase demo: an offline-first field logging and reporting app (iOS, SwiftUI,
Couchbase Lite EE with on-device vector search) that syncs through Capella App Services to a Capella
cluster, plus a small Node.js supervisor dashboard. It exists to tell a clear 5-minute story to a
customer, with code a Couchbase engineer can walk through on screen.

Read these before doing anything, in this order:

1. `docs/PLAN.md` — the plan. Phases, decisions, data model, the showcase query, acceptance criteria.
2. `docs/REFERENCE.md` — the only approved API surface, with versions and sources.
3. `docs/STYLE-GUIDE.md` — the park-poster visual system.

`docs/fieldproof-claude-code-prompt.md` is the original brief. Do not edit it.

`docs/DEFECTS.md` is Matt's cleanup log. Add to it when Matt asks, or when you knowingly accept a shortcut; never fix
an entry without being asked.

## Current status

Phase: **2 (AI + duplicate check) — complete 2026-09-22, waiting for Matt's go-ahead on Phase 3.**
Update this line at the end of every phase. Keep a short "what works / what does not" list under it.

- Works (simulator, observed): seeding with analysis; capture → READING THE SCENE → LOOKS FAMILIAR sheet (capture-pothole:
  2 open reports, 98 %, 39 m / 75 m; resolved 01c excluded) → attach (parent shows +1 attached); graffiti capture: no
  candidates; Find similar (2 km, any status); Settings → Developer shows exact distances. 10 unit tests pass.
- Threshold 0.15 (REFERENCE.md §7.2). Simulator uses `Demo/Samples/analysis.json` from `scripts/embed-samples.swift`.
- Device: Matt ran the flow; phone DB copied: 30 live embeddings within 2.1e-4 of the Mac precompute, labels identical.
- Swift ~2,500 lines of ~3,000.
- Device run: phone must be unlocked; `xcrun devicectl device process launch --console --device 00008130-00044CDE1422001C com.couchbase.demo.fieldproof`.
- Node here is Homebrew 26.5 at `/opt/homebrew/bin`; prefix `PATH=/opt/homebrew/bin:$PATH` in bash.

## Non-negotiable rules

- **Phase gates.** Finish a phase, build and run it, write the phase report (PLAN.md §12), then stop
  and wait for Matt. Never start the next phase on your own.
- **No invented APIs.** If a Couchbase or Apple API is not in `docs/REFERENCE.md`, look it up in the
  official docs linked there, add it with a source and date, then use it. Blog posts and memory do not count.
  When the `couchbaselabs/agent-skills` plugin disagrees with REFERENCE.md, REFERENCE.md wins.
- **Secrets never touch git.** `ios/FieldProof/Config/Secrets.plist` and `dashboard/.env` are ignored;
  only the `.example` files are committed. If you need a credential, finish everything else, then ask.
- **Persona is generic.** Field crew, crew member, technician, inspector, supervisor. No job titles
  ("ranger", "officer") in UI text, identifiers, comments, or docs. The park theme is visual only.
- **Small and readable.** Under ~3,000 lines of Swift, under ~800 of JavaScript, no JS build step,
  no Swift dependencies beyond `CouchbaseLiteSwift` and `CouchbaseLiteVectorSearch`.
- **Talking-point comments.** Every use of a Couchbase feature gets a 1–3 line comment a presenter can
  read aloud. `DuplicateCheckQuery.swift` is shown on screen; keep it under 120 lines with a comment per clause.
- **Scope is the plan.** No extra features. If something seems missing, say so in the phase report.
  If something is blocked, finish everything else and state exactly what was left out.

## Verification before claiming done

- iOS: build for the simulator and run it; drive the flow with the simulator tool and take a screenshot
  of the result. If a device is connected, also build for the device.
- Dashboard: `npm test` and a real request against the running server.
- Phase reports say what was actually run and what was observed, not what should happen.
- Failures are reported with output. "Done" means built, run, and observed.

## Environment

- macOS, fish shell (`/opt/homebrew/bin/fish`); write commands that work in fish or run them via `bash -c`.
- Xcode: latest stable installed. iOS 17+ simulators. Node 20/22 LTS.
- The simulator has no camera and no airplane mode; use demo mode and the in-app "Simulate offline" switch.
- Capella free tier pauses after 72 idle hours; resume the cluster and App Endpoint before testing sync.
- Not a git repository yet: run `git init` at the start of Phase 0 **after** writing `.gitignore`.
  Commit at the end of each phase with a message that names the phase.

## Layout (see PLAN.md §3)

`ios/` SwiftUI app · `dashboard/` Express + Leaflet · `scripts/` setup, reset, tamper ·
`appservices/` sync functions and users · `selfhosted/` Docker fallback (only if needed) · `docs/` plan and architecture docs.

## Style

- Swift: one type per file, files named after the type, `// MARK:` sections, no force unwraps outside
  app startup, async/await over callbacks.
- JavaScript: ESM, `node:` imports, `fetch` for REST, no TypeScript, no framework beyond Express.
- Docs: Markdown with Mermaid diagrams. Short sentences. Each architecture doc has "How FieldProof uses it",
  "Talking points", "Possible enhancements", and "Alternatives and trade-offs".
