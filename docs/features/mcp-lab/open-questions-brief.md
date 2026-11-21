# Brief: Resolve MCP Lab open questions

_Hand-off brief for an AI agent. Written 2026-11-15. Self-contained: read this first, then the files in §2._

> **Historical hand-off:** the original decisions below were completed. The 2026-11-16 high-priority review in specification §6.7 supersedes A4/A5 and the S1 readiness claim. Do not rerun this brief as an outstanding task. Q13 remains owner input for S2.

## 1. Your task

API Caffeine has 14 open product/engineering questions for its new **MCP Lab** feature, plus 4
assumptions made in the S1 acceptance criteria. For each one:

1. Read the background and the linked requirements.
2. Pick a decision (the recommendation below, or a better option if you find one), with a 1–3 sentence reason.
3. Record it in the repo docs (see §6 for exactly where and how).

**Priority:** the questions in §4.1 block coding of slice S1, so resolve those first.
**Escalate, don't decide:** anything marked **[OWNER INPUT]** needs a fact only the project
owner has (for example a domain name). Write your recommendation and leave the question open with
"Waiting for owner: <what is needed>".

## 2. Project context

**API Caffeine** is a desktop API client (in the style of Postman or Insomnia) built with
**Flutter**, desktop first (Windows, macOS, Linux).
- **Stack:** Riverpod, go_router, Dio, Supabase (Postgres + Auth), freezed / json_serializable, and `flutter_secure_storage` for device-only secrets.
- **Architecture:** a modular monolith. Each module is in `lib/modules/<name>/` and exposes a single public API file. Shared code is in `lib/core/`.
- **Errors:** infrastructure errors are mapped to a sealed `Failure` type (`lib/core/error/failure.dart`). Repositories return `Result<T>`.

**MCP Lab** is a new module (`lib/modules/mcp_lab/`, not built yet). It is a client for
testing **Model Context Protocol (MCP)** servers, modelled on the official MCP Inspector:
- It connects to servers over **stdio** (it launches a local command) or **Streamable HTTP** (a URL). SSE is a deprecated legacy transport.
- It supports two protocol "eras": `legacy` (`initialize` handshake) and `modern` (spec 2026-07-28, `server/discover`). `legacy` is the default.
- It lists and calls tools, reads resources, and renders prompts.
- It shows the raw JSON-RPC transcript, HTTP traffic, and the server's stderr.
- The server catalog is stored in Supabase per workspace. Secret values stay on the device in OS secure storage; Supabase stores only a placeholder.
- It uses the `mcp_dart` package (decided).

**Release slices** (spec §4.1):
- **S1:** core lab: stdio + HTTP, both eras, tools / resources / prompts, monitors, Supabase catalog, failure model.
- **S2:** OAuth for remote servers.
- **S3:** interactions: subscriptions, elicitation, sampling, tasks, logs.
- **S4:** API Caffeine integration: `{{variables}}`, saved calls, import/export.

**Decisions already made (do not reopen):**
1. Use the `mcp_dart` library.
2. Store the catalog in Supabase, scoped to the workspace.
3. Secret values stay on the device only; Supabase gets a placeholder `""`. This rule is app-wide and already implemented for environments in `lib/modules/environments/services/environment_service.dart` with `lib/core/secrets/secret_store.dart`.

### Files to read

| File | Why |
|---|---|
| `agents.md` | Project rules (architecture, packages, UI, Supabase). Binding. |
| `docs/features/mcp-lab/feature-specification.md` | The spec. Requirements in §7–§8, open questions in §12, release slices in §4.1, failure model in §6.6, persistence in §6.4 |
| `docs/features/mcp-lab/s1-acceptance-criteria.md` | 90 Given/When/Then checks for S1; its "Open points" table lists what depends on these questions |
| `docs/features/mcp-lab/gap-review.md` | Why each spec requirement exists (research against the MCP 2026-07-28 spec and Inspector) |
| `docs/IMPLEMENTATION_PLAN.md` §Phase 8 | The plan; "Before S1" lists the decisions still needed |
| `docs/PRD.md` §10 | Product-level open questions |
| `lib/core/error/failure.dart`, `lib/core/network/network_settings.dart` | Current code relevant to Q15, Q6 and Q12 |

## 3. Constraints on your decisions

- Follow `agents.md`. In particular: there is no new package without a reason; the KISS principle; Supabase holds the anon key only; secrets never reach Supabase.
- Prefer the official MCP spec 2026-07-28 and the MCP Inspector's behaviour when a question is about protocol behaviour.
- Don't change Dart code. This is a docs-only task.
- Keep the spec's style: short sentences, tables, and requirement IDs (`FR-…`, `NFR-…`, `Q…`).

## 4. Questions

Each question lists: the background, the options, a recommendation (from the previous agent), and the affected requirements.

### 4.1 Blocks the start of S1

**Q16: macOS distribution**
- **Background:** the macOS App Sandbox (required for the Mac App Store) blocks launching arbitrary binaries, so stdio servers can't run. An OAuth loopback listener also needs the `com.apple.security.network.server` entitlement.
- **Options:**
  - (a) A notarized build outside the App Store, without the sandbox: stdio works.
  - (b) A sandboxed App Store build: HTTP servers only; the UI says stdio is unavailable.
  - (c) Ship both.
- **Recommendation:** (a). stdio is the main MCP Lab use case, and Windows and Linux have no such limit.
- **Affects:** NFR-CMP-06, AC-NFR-CMP-06.1 (applies only for b or c), the macOS entitlements in `macos/Runner/*.entitlements`.

**Q14: CI fixture runtime**
- **Background:** integration tests need real MCP servers over stdio and HTTP. The S1 criteria define the fixtures `fx-basic`, `fx-schema`, `fx-content`, `fx-errors`, `fx-noisy`, `fx-crash` and `fx-hang`.
- **Options:**
  - (a) Dart fixtures built on the server side of `mcp_dart`.
  - (b) The Inspector's Node "composable" test servers (MIT license, but CI then needs Node).
- **Recommendation:** (a). CI needs no Node, it is the same library as the app, and the fixtures can answer as either era.
- **Affects:** NFR-MNT-02, NFR-DOC-02, the fixture table in the S1 criteria.

**Q15: where the error `code` lives**
- **Background:** the core `Failure` is sealed and has no machine-readable code. MCP Lab needs stable codes such as `unreachable`, `auth_required`, `tool_error`, `tool_not_found`, `invalid_params`, `rate_limited`, `protocol_version_unsupported`, `process_exited` and `store_unavailable` (spec §6.6).
- **Options:**
  - (a) Module-local `McpFailure` types that carry a `code` and map to the core `Failure` kinds.
  - (b) Add `code` to the core `Failure` for every module.
- **Recommendation:** (a) now. Promote to core only when a second module needs codes. This keeps core unchanged, in line with the "no unrelated refactors" rule.
- **Affects:** spec §6.6, FR-TST-06, AC-TST-06.*.

**Q6: default timeout for MCP calls**
- **Background:** Settings already has a request timeout for HTTP requests (`core/network/network_settings.dart`). MCP calls can be long, and progress notifications reset the timeout (FR-CON-08, which is in S3).
- **Options:**
  - (a) Use the Settings timeout as the default, overridable per server.
  - (b) A separate MCP default, for example 60 s.
- **Recommendation:** (a). It is one knob for the user, and per-server settings cover long tools.
- **Affects:** NFR-PRF-01, FR-CON-08, the "Open points" table in the S1 criteria.

**Q5: sign-off on the release slices**
- **Background:** spec §4.1 proposes S1–S4 plus Later. "Must" in §7 means Must for the slice that owns the requirement.
- **Recommendation:** approve as written, with one note: S1 also delivers the core of FR-CFG-01/03/04 (the Supabase catalog), which is already noted under the §4.1 table.
- **Affects:** spec §4.1, the implementation plan's Phase 8.

### 4.2 Needed before S1 is finished

**Q1: credential headers as secrets by default?**
- **Background:** headers like `Authorization` hold credentials. Right now headers are not secret by default (NFR-SEC-10), and FR-SEC-03 only warns about them.
- **Recommendation:** yes. Header names matching `Authorization`, `Proxy-Authorization`, `Cookie`, `X-Api-Key`, or ending in `-Token` / `-Key` / `-Secret` (case-insensitive), are marked secret automatically, and the user can unmark one.
- **Affects:** NFR-SEC-10, FR-SEC-03, R-3.

**Q2: what to do when the OS keychain is unavailable**
- **Background:** examples are Linux without a keyring or a locked keychain. NFR-SEC-05 says to warn loudly and to prefer failing closed over silent plain text. The environments module already fails closed with `StorageFailure('Secure storage is unavailable on this device…')`.
- **Options:**
  - (a) Fail closed: secrets can't be saved, a clear warning is shown, and non-secret fields still save.
  - (b) An encrypted file whose key is derived from a user passphrase.
  - (c) Plain text with a warning.
- **Recommendation:** (a), which matches the existing behaviour. (b) can come later if users ask for it.
- **Affects:** NFR-SEC-05, NFR-CMP-04, NFR-USE-05, NFR-OBS-02.

**Q12: proxy precedence**
- **Background:** Settings has proxy off/custom. Dio does not read `HTTPS_PROXY` / `HTTP_PROXY` / `NO_PROXY` on its own.
- **Recommendation:** when the Settings proxy is on, it wins and `NO_PROXY` is still honoured. When it is off, use the environment variables. `127.0.0.1` / `localhost` always bypass the proxy (needed for local servers and the OAuth callback).
- **Affects:** FR-CON-09, NFR-PRF-05.

**Q3: performance targets**
- **Recommendation:**
  - MCP Lab interactive in ≤ 2 s from a warm app;
  - the Protocol and Network buffers keep 10,000 entries and drop the oldest, with a counter;
  - bodies over 256 KB are truncated, with *Load full*;
  - JSON is parsed off the UI isolate (the PRD's 5 MB rule).
- **Affects:** NFR-PRF-02, NFR-PRF-03, AC-MON-01.4.

### 4.3 Needed before S2

**Q13: hosting the CIMD client metadata document [OWNER INPUT]**
- **Background:** with OAuth Client ID Metadata Documents, the client ID *is* an https URL that serves a JSON document (client name, redirect URIs, `token_endpoint_auth_method: none`, and so on). API Caffeine needs one public, stable URL. The redirect is loopback: `http://127.0.0.1:<port>/oauth/callback` (FR-AUT-02).
- **Recommendation:** host a static JSON file on the project website or GitHub Pages, for example `https://<domain>/oauth/client.json`. Draft the JSON in the spec as an appendix.
- **Needed from the owner:** a domain or GitHub Pages site they control.
- **Affects:** FR-AUT-01, S2.

### 4.4 Later (don't block anything)

| # | Question | Recommendation | Affects |
|---|---|---|---|
| Q7 | Support horizon for the legacy era | Support it until the MCP spec removes it (at least 12 months after 2026-07-28); review in 2027 | NFR-CMP-03 |
| Q8 | Is MCP Apps preview part of MCP Lab GA? | No: it comes after S4 (it stays at Could priority) | FR-APP-* |
| Q9 | Elicitation and sampling: dedicated tabs, or pending-request dialogs only? | Dialogs only, as designed in Stitch #18 | FR-INT-* |
| Q10 | Nav rail: is MCP Lab top-level, or nested under a future "Protocols" section? | Top-level, as designed in Stitch #14–#22 | Shell |
| PRD Q2 | Offline mode (catalog and collections without network) | Out of scope for the MVP; revisit after M6 | PRD §10 |

## 5. Assumptions in the S1 acceptance criteria to confirm

| # | Assumption | Where |
|---|---|---|
| A1 | The tool form falls back to the raw JSON editor when the schema nests more than **32 levels** or takes over **100 ms** to build | AC-TOL-02.6 |
| A2 | stdio shutdown: close stdin, wait **2 s**, send SIGTERM, wait **2 s**, send SIGKILL; the whole sequence is done within **5 s** | AC-NFR-REL-06.1/2 |
| A3 | A new user makes a first tool call in **under 3 minutes** (NFR-USE-01 walkthrough) | S1 exit check |
| A4 | **Revised 2026-11-16:** any effective env key/value, resolved executable, command, args or cwd change requires renewed approval | AC-SEC-04.2/3 |
| A5 | Server secrets are stored under the secure-storage key `mcp-server-secrets:<user id>:<server id>` | AC-CFG-01.3 |

## 6. Deliverables

1. **`docs/features/mcp-lab/feature-specification.md` §12:** for each decided question, strike through the question and add **Resolved:** with the decision and its reason. This is the same format as Q4 and Q11 there, e.g. `| Q6 | ~~Which default timeout…?~~ **Resolved:** … |`. Update any requirement text the decision changes (e.g. NFR-SEC-10 for Q1, FR-CON-09 for Q12).
2. **`docs/features/mcp-lab/s1-acceptance-criteria.md`:** update the "Open points this document depends on" table and any criterion a decision changes. Mark A1–A5 confirmed or changed.
3. **`docs/IMPLEMENTATION_PLAN.md` Phase 8 "Before S1":** strike through the decided items.
4. **`docs/PRD.md` §10:** only if PRD Q2 is resolved.
5. **A short summary** back to the owner: one line per question with the decision, plus every **[OWNER INPUT]** item still waiting.

Don't commit unless the owner asks you to. If you do, end the commit message with the project's attribution line.

## 7. Done when

- Q16, Q14, Q15, Q6 and Q5 are resolved in the spec, so the S1 transport spike can start; implementation follows only after the spike gate passes.
- Q1, Q2, Q12 and Q3 are resolved or explicitly deferred with a reason.
- Q13 has a recommendation and states exactly what the owner must provide.
- A1–A5 are confirmed or changed in the S1 criteria.
- No Dart code has changed. Links in the edited docs still resolve.
