# FieldProof — Defect and Cleanup Log

Things that work for the demo but should be reviewed or cleaned up later. Newest at the bottom.
Status: **open**, **deferred** (accepted for the demo), or **fixed** (with the commit or phase).

| # | Title | Area | Status | Raised |
|---|---|---|---|---|
| D1 | App Services auth model is messy; supervisor needs explicit channels | App Services | open | 2026-09-22, Phase 0 |
| D2 | App user passwords are bundled in the iOS app | iOS / security | open | 2026-09-22, Phase 0 |
| D3 | No swipe-back gesture on the report detail screen | iOS / UX | open | 2026-09-22, Phase 5 |
| D4 | Running the unit tests syncs the app to Capella | iOS / tests | open | 2026-09-22, Phase 5 |
| D5 | Dashboard never recovers from a failed first connection to Capella | dashboard | open | 2026-09-22, Phase 6 |

---

## D1 — App Services auth model is messy; supervisor needs explicit channels

**What happened.** The plan gave `supervisor` the `*` channel. In Phase 0 testing, `*` let the supervisor read every
document but not write any: the sync function calls `requireAccess("district.<id>")`, and `*` does not satisfy that
("sg missing channel access"). The fix was to list `district.valley` and `district.tuolumne` explicitly on both collections.
Also found along the way: the Capella Admin API cannot touch documents, and `_all_docs` is disabled on the Public API
(REFERENCE.md §3, §7).

**Why it feels messy.** Access is spread across three places: user channel grants (Capella UI), the sync function
(`appservices/*.js`), and which API and credential each component uses. The supervisor's rights are a hand-kept list
that must change whenever a district is added.

**What to understand** (to review together):
- Channels decide who can *read* a document. The sync function's `channel()` puts a document in a channel, and a user
  sees documents in channels they were granted.
- `requireAccess()`, `requireUser()`, and `requireRole()` decide who can *write*. They check the writing user
  against the new document. `*` is a read wildcard, not a grant of every named channel.
- Roles group channels. A user gets a role's channels.

**Options to clean it up.**
1. **Roles.** Create `district-valley`, `district-tuolumne`, and `supervisor` roles with channels; users get roles.
   Adding a district updates one role, not each user.
2. **Role check in the sync function.** `supervisor` keeps `*` for reads; the sync function allows writes if the user
   has the `supervisor` role, otherwise `requireAccess(ch)`. One place to read the rule; a few more lines on screen.
3. **Dynamic grants.** A `district` config document whose sync function calls `access(users, channel)`. Most flexible;
   most to explain.

Recommendation for a later pass: option 1 (roles), and write the model up in `docs/architecture/sync-and-app-services.md`.

## D2 — App user passwords are bundled in the iOS app

**What happened.** `Secrets.plist` holds the App Services URL and the passwords for `crew-valley`, `crew-tuolumne`,
and `supervisor`. It is git-ignored, but it is copied into the app bundle, so anyone with the `.ipa` can read every
user's password. The demo picks a user in Settings with no login.

**Why it is bad.** Shared, long-lived passwords; no per-person identity (the audit trail says `crew-valley`, not who);
no revocation short of changing the password in every install; and the supervisor password on a crew phone gives
every crew member supervisor access.

**How it is done in the real world.**
- **OpenID Connect (OIDC).** App Services supports OIDC providers (Okta, Entra ID, Auth0, Cognito, Google, and so on).
  The phone signs in with the provider (for example with `ASWebAuthenticationSession`), gets an ID token, and the
  replicator authenticates with it. App Services can create the user on first sign-in and map provider claims or groups
  to roles, so district access comes from the identity system. Tokens expire and can be revoked centrally.
- **Custom auth with sessions.** The company's own backend checks the person's credentials, then calls the App Services
  Admin API `POST /{db}/_session` to create a session for that user and returns the session to the phone. The phone
  uses a `SessionAuthenticator`. The admin credential lives only on that backend.
- **Per-person users**, not shared district accounts, with district rights granted through roles (see D1).
- **Storage on the device:** tokens in the Keychain, never in the bundle; Couchbase Lite database encryption for data
  at rest (enterprise enhancement already listed in PLAN §13).
- **Device management (MDM)** for company phones can push configuration and certificates.

Before this is fixed, look up the current Couchbase Lite Swift authenticators (`SessionAuthenticator`, OIDC support)
and the App Services OIDC configuration in the official docs, and add them to REFERENCE.md. None are verified yet.

Demo stance until then: keep `Secrets.plist`, and say it on stage: "for the demo we pick a user; in production this is
your identity provider via OIDC."

## D3 — No swipe-back gesture on the report detail screen

Each screen draws its own poster title, so the navigation bar is hidden (`docs/STYLE-GUIDE.md` §7). Hiding it also
disables SwiftUI's interactive pop, so the edge swipe does nothing on the detail screen; the chevron button in the
title row is the only way back. Nobody has stumbled on it in rehearsal, but it is not what an iPhone user expects.

Fix later: keep the bar hidden and re-enable the gesture with a small `UINavigationController` interaction-delegate
shim, or show a bar with a transparent background and a custom back button.

## D4 — Running the unit tests syncs the app to Capella

`FieldProofTests` uses the app as its test host, so `xcodebuild test` launches FieldProof, which starts the replicator
and syncs whatever is on the simulator. The tests themselves are pure (hash, geo box, document mapping) and touch no
network, but the run does, and it also terminates a running app mid-demo.

Fix later: skip `sync.start(...)` in `AppState.init` when `NSClassFromString("XCTestCase") != nil`, or give the tests
their own host-less target now that nothing in them needs the app bundle except `@testable import`.

## D5 — Dashboard never recovers from a failed first connection to Capella

**What happened.** Starting Phase 6, the cluster was slow to answer (it had been idle) and the first
`couchbase.connect` timed out. Every later request returned `502 {"error":"unambiguous timeout"}` **instantly**,
including after the cluster was demonstrably healthy — a SQL++ probe from the same machine succeeded while the
running server kept failing. Restarting the server fixed it.

**Why.** `dashboard/lib/couchbase.js` memoises the connection:

```js
clusterPromise ??= couchbase.connect(...)
```

A rejected promise is still a promise, so the failure is cached for the life of the process and never retried.

**Fix later.** Clear the cached promise when it rejects, so the next request reconnects:

```js
clusterPromise = couchbase.connect(...).catch((e) => { clusterPromise = undefined; throw e; });
```

Worth doing before a customer demo: the failure looks exactly like "Capella is down" when it is not, and the
recovery (restart the server) is not obvious from the error. Noted in `docs/demo-guide.md` under recovery.
