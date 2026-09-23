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

Phase: **6 (architecture and component docs) — complete 2026-09-22, plus a customer demo deck. Waiting for Matt.**
Update this line at the end of every phase. Keep a short "what works / what does not" list under it.

- `docs/architecture/` has the seven component documents from PLAN §13, each with a Mermaid diagram, "How FieldProof
  uses it", talking points, enhancements, and alternatives. Plus `docs/demo-guide.md` and `docs/style-as-built.md`.
- `docs/style-as-built.md` is the style **as built** with screenshots and a delta table against STYLE-GUIDE.md, not a
  copy of it (PLAN §13.9 asked for `style-guide.md`; on a case-insensitive filesystem that name overwrites
  STYLE-GUIDE.md, and a duplicate would go stale anyway).
- Screenshots in `docs/images/screens/` (15 JPEGs, 3.4 MB total) and a 30-second clip in `docs/images/video/`,
  captured from a live run on the simulator against Capella on 2026-09-22.
- Customer deck (18 slides, screenshots + the clip) published as a private Artifact; the link is in the Phase 6 report.
- New defect: D5, the dashboard caches a failed Capella connection and never retries (hit for real this phase).
- Corrected in the docs: on-device analysis is 257–323 ms (measured, REFERENCE §7), not "about a second".
- Tests: `npm test` 4/4, Swift 10/10. No source code changed this phase.
- Cluster left empty after the last reset. Node here is Homebrew 26.5 at `/opt/homebrew/bin`; prefix `PATH=/opt/homebrew/bin:$PATH` in bash.

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
