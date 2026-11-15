# MCP Lab — Feature Specification (Flutter / Test Point)

| | |
|---|---|
| **Product** | Test Point — **MCP Lab** |
| **Document type** | Feature requirements adapted for Flutter desktop |
| **Source** | Product-owner analysis of MCP Inspector (`@modelcontextprotocol/inspector`), 2026-11-15 |
| **Adapted for** | Test Point stack: Flutter (desktop-first), Riverpod, go_router, Dio, Supabase, modular monolith |
| **Date** | 2026-11-15 |
| **Status** | Draft v1.2: aligned with the final MCP 2026-07-28 spec; gaps from the review closed |
| **Related** | [PRD.md](../../PRD.md) · [ARCHITECTURE.md](../../ARCHITECTURE.md) · [AGENTS.md](../../../AGENTS.md) · [gap-review.md](gap-review.md) |

> **v1.2 changes:** corrections for the deprecations, tasks, subscriptions and OAuth changes in 2026-07-28; new protocol fundamentals (§7.15 FR-PRO); Test Point integration (§6.5, §7.16 FR-TPI); failure model (§6.6); platform, process and secret-store NFRs; proposed release slices (§4.1). The reasoning for each change is in [gap-review.md](gap-review.md).

> **Decisions (2026-11-15):**
> 1. **Library:** use [`mcp_dart`](https://pub.dev/packages/mcp_dart) (resolves Q4).
> 2. **Catalog:** the MCP Lab server catalog is stored in **Supabase**, scoped to the workspace (resolves Q-DATA-1).
> 3. **Secrets:** secret values stay **on the device only** (OS secure storage). Rows synced to Supabase keep the key and the `secret` flag, but the value is replaced by a placeholder. This applies app-wide: MCP Lab and environment variables (resolves Q11 and PRD Q3). See §6.4.

> **How to read this document.** Capabilities are *derived* from the official MCP Inspector (Basis `Documented` / `Proposed` from the PO analysis), then **rewritten as requirements for building MCP Lab inside Test Point**. Technology that is Node/web/CLI-specific in the source is mapped to Flutter desktop equivalents. Priorities use **MoSCoW** (Must / Should / Could / Won't).

---

## Table of contents

1. [Product overview](#1-product-overview)
2. [Business context & goals](#2-business-context--goals)
3. [Stakeholders & personas](#3-stakeholders--personas)
4. [Scope](#4-scope)
5. [Requirements gathering](#5-requirements-gathering)
6. [Flutter architecture mapping](#6-flutter-architecture-mapping)
7. [Functional requirements](#7-functional-requirements)
8. [Non-functional requirements](#8-non-functional-requirements)
9. [Constraints, assumptions, dependencies](#9-constraints-assumptions-dependencies)
10. [Risks](#10-risks)
11. [Traceability matrix](#11-traceability-matrix)
12. [Open questions](#12-open-questions)
13. [Sources](#13-sources)
- [Appendix A — Example CI smoke test (Dart)](#appendix-a--example-ci-smoke-test-dart)
- [Appendix B — Settings, storage & platform notes](#appendix-b--settings-storage--platform-notes)
- [Appendix C — Source → Flutter adaptation map](#appendix-c--source--flutter-adaptation-map)

---

## 1. Product overview

**MCP Lab** is a Test Point workspace feature for testing and debugging **Model Context Protocol (MCP) servers**. It acts as an MCP *client* so a server author can exercise a server without wiring it into an LLM host (Claude Desktop, Cursor, etc.).

Unlike the reference Inspector (npm package with Web / CLI / TUI clients + Node backend), MCP Lab is a **native desktop UI** inside the Flutter app. The app process *is* the MCP client: no separate Node proxy, no browser UI, no `npx` launcher.

| Surface | Role in Test Point |
|---|---|
| **Desktop UI** (primary) | Full graphical lab in the app shell (nav rail section **MCP Lab**) |
| **Headless Dart harness** (secondary) | Integration / CI smoke tests against the same protocol services (not a user-facing CLI product) |
| **CLI / TUI / mcpdo** | Out of scope for MCP Lab v1 (see Won't-have) |

### Architecture at a glance

```
┌─────────────────────────────────────────────────────────────┐
│  Test Point (Flutter desktop)                               │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ App shell   │  │ MCP Lab UI   │  │ Other modules      │  │
│  │ nav · theme │──│ screens /    │  │ collections · HTTP │  │
│  └─────────────┘  │ widgets      │  └────────────────────┘  │
│                   └──────┬───────┘                          │
│  ┌───────────────────────▼────────────────────────────────┐ │
│  │ modules/mcp_lab                                        │ │
│  │ providers → services → repositories → models           │ │
│  │ · connection session · protocol transcript             │ │
│  │ · tools / resources / prompts / tasks                  │ │
│  │ · catalog · secrets · OAuth                            │ │
│  └───────────────────────┬────────────────────────────────┘ │
│                          │ stdio · SSE · Streamable HTTP      │
└──────────────────────────┼──────────────────────────────────┘
                           ▼
                    ┌──────────────┐
                    │  MCP server  │  ← system under test
                    └──────────────┘
```

> **Adaptation note.** The Inspector’s *client (6274) + proxy (6277)* and later *backend + API token* model do **not** apply. Test Point connects from the Dart isolate(s) directly. Security focus shifts from “unauthenticated web proxy RCE” to **local process spawn**, **secret storage**, and **OAuth loopback**.

---

## 2. Business context & goals

### Problem statement
Building an MCP server means implementing a JSON-RPC protocol with several primitives (tools, resources, prompts, tasks, logging, …), multiple transports, and an evolving spec. Without a purpose-built client, developers must wire the server into a full LLM host to test it — slow, non-deterministic, and opaque.

Test Point already shortens the HTTP *edit → run → observe* loop. **MCP Lab** extends that value to MCP servers in the same desktop product.

### Goals

| ID | Goal | Success indicator (proposed) |
|---|---|---|
| G-1 | Shorten the *edit → run → observe* loop for MCP server authors | First successful tool call within 5 minutes of opening MCP Lab for a new user |
| G-2 | Make protocol behaviour **observable** (not hidden behind an LLM) | Every request/response/notification visible in a transcript |
| G-3 | Support **automated verification** of servers in CI | Stable Dart test results / exit codes via a shared protocol service (not a separate npm CLI) |
| G-4 | Track the **MCP spec** across protocol revisions | New spec revision supported without breaking legacy debugging |
| G-5 | Be **safe by default** despite spawning processes and holding credentials | No silent credential leakage; clear warnings for process spawn and secret-store fallback |

### Out of scope as a business goal
MCP Lab is a *developer tool surface* inside Test Point — not a production gateway, load tester, LLM agent host, or standalone npm/Docker product.

---

## 3. Stakeholders & personas

| Stakeholder | Role | Primary interest |
|---|---|---|
| **MCP server developer** (primary) | Builds servers in TS/Python/other SDKs | Fast, visual testing and debugging in Test Point |
| **QA / test automation engineer** | Verifies servers in pipelines | Deterministic Dart/Flutter tests, stable failures |
| **AI-agent / coding-assistant user** | Agents verifying server changes | Machine-readable test output (headless harness) |
| **MCP Apps author** | Builds tools that ship UI | Sandboxed preview (post-MVP / Could) |
| **Security / platform engineer** | Approves tool use in the org | Threat model, secret handling, process spawn |
| **Server integrator / evaluator** | Assesses a third-party server before adoption | Quick capability survey, config import/export |
| **Test Point product / eng** | Ships MCP Lab as a module | Fits modular monolith, KISS, desktop UX |

### Personas (condensed)

| Persona | Needs | Pain today |
|---|---|---|
| **Dana — server dev** | Call a tool, see schema, see raw JSON-RPC | Testing through an LLM hides protocol errors |
| **Raj — QA** | Gate a build if `tools/list` changes or a tool errors | Scraping human-readable output is brittle |
| **Mei — security** | Know what the app can spawn and store | Process spawn + OAuth tokens on disk |

---

## 4. Scope

### In scope (MCP Lab v1 target)
- Connecting to MCP servers over **stdio, SSE, Streamable HTTP** from the Flutter desktop app.
- Exercising server primitives: tools, resources (+templates, subscriptions), prompts, tasks, logging.
- Handling server-initiated interactions (elicitation, sampling, roots) so servers that need them can be tested.
- Protocol observability (JSON-RPC transcript, HTTP network view, stdio stderr console).
- Multi-server catalog, import/export of `mcpServers` configs, OAuth for remote servers, secret storage.
- Desktop UI integrated with the Test Point shell (nav rail, theme, keyboard hints with `Ctrl`).
- Shared protocol services usable from unit/integration tests.

### Out of scope (v1)
- Hosting or deploying MCP servers.
- Load/performance testing of servers.
- Acting as an LLM host or running a model.
- Modifying the server under test.
- Shipping a separate Web UI, Node backend, npm CLI, TUI, or `mcpdo` daemon.
- Docker image for MCP Lab itself (Test Point remains a desktop app).
- MCP Apps sandboxed iframe/port model (Could / later — see FR-APP).

### 4.1 Proposed release slices

Answers Q5 for planning. "Must" in §7 means *Must for the slice that owns the requirement*, not for the first slice.

| Slice | Contents | Key requirements |
|---|---|---|
| **S1: Core lab** | stdio + Streamable HTTP, both eras (`legacy` default), tools / resources / prompts, raw-JSON args fallback, Protocol + Network + Console, catalog in Supabase (with migrations and RLS), failure model | FR-CON-01…07, FR-TOL-01…04/08, FR-RES-01/02, FR-PRM-01/02, FR-PRO-01…03/05/06, FR-MON-01…03/10, FR-ERA-01…05, FR-SEC-01/04, FR-TST-01/02/05/06 |
| **S2: Remote auth** | OAuth (CIMD / pre-registered / DCR fallback), secret store, stored-auth-only harness | FR-AUT-*, NFR-SEC-03…06/12, FR-TST-08 |
| **S3: Interactions** | Subscriptions, listChanged, progress, elicitation, sampling, roots, MRTR, tasks, logs | FR-RES-03/05, FR-PRO-07…09, FR-INT-*, FR-TSK-*, FR-MON-04 |
| **S4: Test Point integration** | Environment variables, saved MCP calls, history, import/export, synced catalog | FR-TPI-*, FR-CFG-05…10 |
| **Later** | MCP Apps, Skills, extension toggles, OpenTelemetry | FR-APP-*, FR-SKL-01, FR-ERA-06/07, FR-MON-09 |

---

## 5. Requirements gathering

### 5.1 Elicitation techniques used

| Technique | How applied here |
|---|---|
| **Document analysis** | PO spec reverse-engineered from MCP Inspector docs/repo |
| **Stack adaptation** | Mapped Node/web/CLI surfaces onto Test Point Flutter architecture |
| **Persona & scenario modelling** | Section 3 personas → user stories below |
| **Threat modelling** | Inspector security lessons (e.g. CVE-2025-49596 class) reinterpreted for desktop spawn + secrets |
| **Gap analysis** | Documented Inspector behaviour vs Flutter-feasible delivery (Section 12) |

### 5.2 User needs → requirement themes

| # | Need (user story) | Theme | Requirements |
|---|---|---|---|
| N1 | *As a server dev, I want to connect to my server from the app so I can start testing immediately.* | Connection | FR-CON-01…11, FR-PRO-01…12 |
| N2 | *…see a tool's input schema as a form and call it.* | Tools | FR-TOL-01…10 |
| N3 | *…read resources and subscribe to changes.* | Resources | FR-RES-01…06 |
| N4 | *…preview what a prompt renders to.* | Prompts | FR-PRM-01…03 |
| N5 | *…watch raw JSON-RPC and HTTP while I work.* | Observability | FR-MON-01…10 |
| N6 | *As QA, I want automated checks with stable outcomes.* | Test harness | FR-TST-01…08 |
| N7 | *…test servers that ask for LLM output or user input mid-call.* | Client-side primitives | FR-INT-01…07 |
| N8 | *…test long-running tool calls.* | Tasks | FR-TSK-01…04 |
| N9 | *…test against both legacy and the 2026-07-28 protocol.* | Protocol eras | FR-ERA-01…07 |
| N10 | *…authenticate to OAuth-protected remote servers.* | Auth | FR-AUT-01…11 |
| N11 | *…reuse my existing client configs and export mine.* | Configuration | FR-CFG-01…10 |
| N12 | *As an MCP App author, I want to render and review my tool's UI.* | MCP Apps | FR-APP-01…03 (Could / later) |
| N13 | *As security, I want safe defaults and clear secret handling.* | Security | FR-SEC-01…05 + NFR-SEC |
| N14 | *As a Test Point user, I want to reuse my environments, save calls and replay them like HTTP requests.* | Test Point integration | FR-TPI-01…06 |

### 5.3 Key insights from analysis
1. **MCP Lab is a protocol microscope, not an LLM client.** Requirements prioritise *fidelity and visibility* over convenience.
2. **Defaults are deliberate.** `legacy` remains the default protocol era (auto-probing can stall silent stdio servers and pollute the transcript).
3. **One client core, many UIs later.** Behaviour lives in Dart services/repositories so UI and tests cannot drift (replaces Inspector’s “three clients, one core”).
4. **Process spawn + secrets are the highest-risk areas** on desktop (not a public HTTP API token surface).
5. **Fit the existing product.** Catalog, theme, split panes, code editor, Failure mapping, and module boundaries follow Test Point conventions — do not invent a parallel app-inside-the-app.

---

## 6. Flutter architecture mapping

### 6.1 Module placement

MCP Lab is a **new module** under `lib/modules/mcp_lab/` (public API: `mcp_lab.dart`). Create only the folders the feature needs.

```
lib/modules/mcp_lab/
├── mcp_lab.dart                 # public API (only file others import)
├── mcp_lab_routes.dart          # go_router routes for the nav-rail section
├── models/                      # freezed: server config, tool, resource, prompt, rpc frames, …
├── repositories/                # transport + catalog + secrets contracts/impls
├── services/                    # connect, call tool, list/read, era negotiation, OAuth
├── providers/                   # Riverpod notifiers (session, catalog, transcript, UI state)
├── screens/                     # Lab shell, connection, tools, resources, prompts, monitor
└── widgets/                     # schema form, method pills, transcript list, …

test/modules/mcp_lab/            # mirrors lib/
```

**Dependency direction:** `screens/widgets → providers → services → repositories → models`

- UI never calls repositories directly.
- Services depend on repository **contracts**.
- Infrastructure errors (process, socket, OAuth, JSON-RPC) map to `core/error` `Failure` types — never leak raw exceptions to the UI.
- Cross-module use only via `modules/mcp_lab/mcp_lab.dart`.

### 6.2 Suggested internal seams (KISS — split only if the module grows)

| Seam | Responsibility |
|---|---|
| Catalog | Persist/import/export `mcpServers` entries (workspace-scoped in Supabase) |
| Session / transport | stdio process lifecycle, SSE / Streamable HTTP via Dio (or dedicated client), connect/disconnect |
| Protocol | JSON-RPC framing, initialize, eras, cancellation, progress |
| Primitives | Tools, resources, prompts, tasks, logging, roots, elicitation, sampling |
| Observability | Transcript buffer, network capture, stderr console, export |
| Secrets / OAuth | OS secure storage, loopback callback, token refresh |

Shared HTTP proxy settings from `modules/settings` should be reused for remote transports where applicable (honour app proxy + `HTTPS_PROXY` / `HTTP_PROXY` / `NO_PROXY`).

### 6.3 Shell integration

- Add **MCP Lab** to the nav rail (alongside Collections, Environments, Settings).
- Use existing theme (`ColorScheme` teal `#0F9D8A`), `multi_split_view` for resizable panes, `re_editor` / `re_highlight` for JSON bodies and transcripts.
- Keyboard hints always say `Ctrl` (never `⌘` / `^`).
- Labels/chips stay on one line with ellipsis.

### 6.4 Data persistence (proposed)

| Data | Proposed store | Notes |
|---|---|---|
| Server catalog | **Supabase**, workspace-scoped (new tables via `supabase/migrations/`, RLS scoped to the organization) | **Decided.** Secret fields are stored as placeholders (see below). Schema to be added to `docs/DATA_MODEL.md`. |
| Secrets (OAuth tokens, client secrets, stdio env values, secret headers, secret environment variables) | OS secure storage (`flutter_secure_storage` or equivalent), **on the device only** | **Decided.** Never synced and never in exported `mcp.json`. **New dependency: add it to the Core Stack table in `agents.md` with a reason.** Linux needs libsecret. Windows Credential Manager entries are capped at about 2.5 KB, so large tokens need chunking or an encrypted file whose key is in the OS store. Keys are namespaced by Supabase user ID (FR-TPI-06). |
| Per-device stdio trust records | Local only (secure storage or app data dir) | Never synced; see FR-SEC-04 |

**Secret placeholder rule (app-wide).** Applies to MCP Lab and to environment variables.
- A field marked secret is synced with its key and `secret: true`, but its `value` is replaced by a fixed placeholder. The exact placeholder is chosen in the data model, for example an empty value.
- The real value is saved in OS secure storage under a key built from the record's UUID, for example `environment-secrets:<environment id>`, which holds a JSON map `{key: value}`. Record UUIDs are unique across users and workspaces, so a different account never loads another account's values. Implemented for environments in `EnvironmentService` with the shared `lib/core/secrets/secret_store.dart`.
- On load, the app swaps the placeholder for the local value.
- On a device that has no local value, the field shows **"Not set on this device"**. A variable that uses it stays unresolved and shows as an amber chip. The placeholder is never sent to a server as if it were the real value.
- Clearing the `secret` flag syncs the value as plain text, so the user must confirm this first.
- Turning on the flag for a value that is already synced uploads the placeholder over it. The previous plaintext may still exist in Supabase backups, so the UI warns about it.
| UI prefs (sidebar width, pinned monitor) | `shared_preferences` | Same pattern as theme/layout |

### 6.5 Test Point integration

MCP Lab is part of Test Point, not a separate app inside it. It reuses the product's existing parts through their public API files only:

| Test Point concept | MCP Lab behaviour | Via |
|---|---|---|
| **Environments / `{{variables}}`** | Resolve in server URL, headers, stdio args, env values and tool / prompt arguments. Unresolved variables show as amber chips. Secret variables stay masked in the transcript. | `modules/environments/environments.dart` |
| **Request tabs** | Each open server, or each saved MCP call, is a top-bar tab with the unsaved dot. The method pill shows the MCP method family (`TOOL`, `RES`, `PROMPT`). | shell / `core/ui/widgets` |
| **Status bar** | Shows the active MCP connection: transport, negotiated era, connection state. | shell |
| **Collections** | An MCP call (server ref + method + params) can be saved to a collection and replayed (FR-TPI-02). | `modules/collections/collections.dart` |
| **Settings** | Default timeout and proxy come from Settings; per-server overrides win. | `core/network/network_settings.dart` |
| **Account** | Catalog and secrets follow the account rules in FR-TPI-06. | `modules/auth/auth.dart` |

### 6.6 Failure model

`Failure` in `lib/core/error/failure.dart` is sealed and has no machine-readable code. To keep `core` unchanged, MCP Lab defines **module-local** failure subtypes that carry a stable `code`, and maps them to the existing `Failure` kinds at the module boundary:

| `code` | Maps to | Meaning |
|---|---|---|
| `unreachable` | `NetworkFailure` | DNS, refused, timeout, process failed to start |
| `auth_required` | `AuthFailure` | 401/403, or no stored auth in non-interactive mode |
| `rate_limited` | `NetworkFailure` | HTTP 429; carries `retryAfter` when sent |
| `protocol_version_unsupported` | `NetworkFailure` | `-32022`; carries `data.supported` |
| `header_mismatch` / `missing_capability` | `NetworkFailure` | `-32020` / `-32021` |
| `tool_not_found` / `invalid_params` | `ValidationFailure` | `-32602` split by message (FR-TOL-05) |
| `tool_error` | `ValidationFailure` | `isError: true` result (not a transport failure) |
| `schema_unportable` | `ValidationFailure` | Strict schema check failed (FR-TST-07) |
| `store_unavailable` | `StorageFailure` | Secret store unreadable / refused (NFR-SEC-06) |
| `process_exited` | `UnexpectedFailure` | stdio server exited unexpectedly; carries exit code + stderr tail |

Whether `code` should move up into the core `Failure` for every module is open question Q15.

---

## 7. Functional requirements

**Priority:** M = Must · S = Should · C = Could · W = Won't (this release)
**Basis:** D = Documented in Inspector source · P = Proposed · **A** = Adapted for Flutter/Test Point

### 7.1 Launch & connection management (FR-CON)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-CON-01 | The user shall open MCP Lab from the Test Point nav rail with no separate installer or `npx` step. | M | A |
| FR-CON-02 | The system shall accept an ad-hoc **stdio** target as a command + arguments (e.g. `node build/index.js arg1`) spawned via Dart `Process`. | M | D/A |
| FR-CON-03 | The system shall accept an ad-hoc **remote** target via server URL with transport `http` (Streamable HTTP, default) \| `sse`. The legacy HTTP+SSE transport is **Deprecated** (SEP-2596) and shall be labelled as such in the UI. | M | D/A |
| FR-CON-04 | The system shall pass environment variables and a working directory to stdio servers. | M | D |
| FR-CON-05 | The system shall pass custom HTTP headers to HTTP/SSE servers. | M | D |
| FR-CON-06 | Server arguments shall be stored distinctly from Lab UI flags/settings so they are not mis-parsed. | M | D/A |
| FR-CON-07 | The system shall display connection state per server (transport, connected/disconnected) and allow connect / disconnect / inspect / remove. | M | D |
| FR-CON-08 | The system shall allow configurable per-request timeouts, including reset on progress notifications. | S | D |
| FR-CON-09 | The system shall honour app proxy settings and `HTTPS_PROXY` / `HTTP_PROXY` / `NO_PROXY` for outbound remote connections. Dio does not read these variables itself, so the system shall resolve them explicitly. The precedence between the Settings proxy and the environment variables is Q12. | S | D/A |
| FR-CON-10 | The system shall offer **Fetch Lists One Page at a Time** vs auto-aggregating paginated lists, with a *Load next page* control. | S | D |
| FR-CON-11 | Deep links into MCP Lab (`serverUrl`, `transport`, `autoConnect`) restricted to `http:`/`https:` and confirmed by the user before connect. | C | D/A |

### 7.2 Tools (FR-TOL)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-TOL-01 | The system shall list a server's tools with name, description, and annotations. | M | D |
| FR-TOL-02 | The system shall render a tool's **JSON Schema 2020-12 input** (SEP-2106) as a fillable Flutter form, supporting at least `type`/`properties`/`required`/`enum`/`default`, arrays, nested objects, local `$ref`/`$defs`, and `oneOf`/`anyOf` (as a variant picker). It shall **never dereference external `$ref` URIs** and shall bound schema depth and validation time. | M | D/A |
| FR-TOL-03 | The system shall invoke a tool and render the result, including `structuredContent` (any JSON value), text, images, audio, embedded resources (text and base64 `blob`) and `resource_link` items. Large binaries are shown as size + type with a save action rather than decoded inline. | M | D |
| FR-TOL-04 | The system shall surface tool-level errors (`isError`) distinctly from protocol / transport failures (`Failure` types). | M | D/A |
| FR-TOL-05 | The system shall render `-32602` rejections as distinct panels (**Unknown Tool** vs **Invalid Parameters**). | S | D |
| FR-TOL-06 | On modern-era servers, the system shall show mirrored `Mcp-Param-*` headers (SEP-2243) and list tools excluded for invalid annotations with the reason. | S | D |
| FR-TOL-07 | On **legacy-era** servers the system shall support "Run as task" for long-running calls. On modern servers the **server** decides when a call becomes a task (`resultType: "task"`), so the control is hidden (see FR-TSK). | S | D |
| FR-TOL-08 | The system shall always offer a **raw JSON arguments editor** as an alternative to the form, used automatically when the schema has features the form does not support. | M | P/A |
| FR-TOL-09 | When a tool declares `outputSchema`, the system shall flag a missing or schema-invalid `structuredContent` as a diagnostic, without failing the call. | S | D |
| FR-TOL-10 | The system shall ask for confirmation before calling a tool annotated `destructiveHint: true` (can be turned off per server). Annotations are shown as hints from the server, not as guarantees. | S | P |

### 7.3 Resources (FR-RES)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-RES-01 | The system shall list resources and resource templates with MIME type and description. | M | D |
| FR-RES-02 | The system shall read and display resource content on selection. | M | D |
| FR-RES-03 | The system shall support subscribing to resource changes and show update notifications. **Legacy:** `resources/subscribe` / `resources/unsubscribe` + `notifications/resources/updated`. **Modern:** a long-lived `subscriptions/listen` request with a `resourceSubscriptions` filter, confirmed by `notifications/subscriptions/acknowledged`. | M | D |
| FR-RES-04 | The system shall expand URI templates with user-supplied variables. | S | D |
| FR-RES-05 | In the modern era, the system shall show subscription stream status (`Connecting…`, `Listening`, `Reconnecting…`, `Stream ended`, `Not acknowledged`). | S | D |
| FR-RES-06 | The system shall offer argument completion (`completion/complete`) for resource-template variables where the server supports it. | C | P |

### 7.4 Prompts (FR-PRM)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-PRM-01 | The system shall list prompts with arguments and descriptions. | M | D |
| FR-PRM-02 | The system shall accept argument values and render the generated messages. | M | D |
| FR-PRM-03 | The system shall support argument completion where the server provides it. | C | P |

### 7.5 Server-initiated interactions (FR-INT)

> **Deprecation note.** Roots and Sampling are **Deprecated** in 2026-07-28 (SEP-2577) but stay functional for at least 12 months. MCP Lab supports them so existing servers can be tested, and labels them *Deprecated* in the UI.

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-INT-01 | The system shall surface server **elicitation** requests (legacy: `elicitation/create`; modern: embedded in an MRTR `input_required` result) in a pending-request dialog and return the user's answer with **accept / decline / cancel**. | M | D/A |
| FR-INT-02 | *(Deprecated feature)* The system shall surface server **sampling** requests so the user can write or inspect the response, showing `messages`, `systemPrompt`, `modelPreferences`, `maxTokens` and any tools offered. The `includeContext` values `thisServer`/`allServers` are deprecated and shall be flagged. | S | D/A |
| FR-INT-03 | *(Deprecated feature)* The system shall advertise and answer **roots** (`roots/list`) from per-server configured roots. | S | D |
| FR-INT-04 | In the modern era, the system shall drive **multi-round tool results (MRTR)** manually, pausing each `input_required` round for user input and grouping rounds as one conversation. | S | D |
| FR-INT-05 | The system shall cap MRTR retries to stop non-terminating calls. | S | D |
| FR-INT-06 | Elicitation shall support **form mode** (rendering the restricted flat `requestedSchema` subset) and **URL mode**. In URL mode the target domain is shown and the system browser opens only after the user confirms. It never opens automatically. | M | D/P |
| FR-INT-07 | When several server requests are waiting at once (elicitation, sampling, MRTR rounds, task input), they shall be queued in the pending-request dialog with their origin (server, method, request id) and stay answerable in any order. | S | P |

### 7.6 Tasks (FR-TSK)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-TSK-01 | The system shall show a Tasks view only when the server advertises task support (legacy: `capabilities.tasks`; modern: the `io.modelcontextprotocol/tasks` extension, SEP-2663). | S | D |
| FR-TSK-02 | The system shall track task status by polling `tasks/get`. Legacy also lists with `tasks/list`. Modern has no `tasks/list`, so *Refresh* re-polls the handles the client already holds, including unsolicited `CreateTaskResult`s. | S | D |
| FR-TSK-03 | The system shall retrieve results (legacy: blocking `tasks/result`; modern: inlined in the completed task) and support cancellation (`tasks/cancel`). On Streamable HTTP, `tasks/*` requests shall carry the required `Mcp-Name` header. | S | D |
| FR-TSK-04 | For modern tasks in `input_required`, the system shall surface the embedded elicitation and answer via `tasks/update`. | C | D |

### 7.7 Monitoring & observability (FR-MON)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-MON-01 | The system shall show a **Protocol** transcript of JSON-RPC requests, responses, and notifications, pairing requests with responses. | M | D |
| FR-MON-02 | For HTTP/SSE servers, the system shall show a **Network** view (status, headers, bodies). | M | D |
| FR-MON-03 | For stdio servers, the system shall show a **Console** view of the server's `stderr`. | M | D |
| FR-MON-04 | *(Deprecated feature, SEP-2577)* The system shall show a **Logs** view of `notifications/message` with era-appropriate level control (legacy: session `logging/setLevel`; modern: per-request `_meta["io.modelcontextprotocol/logLevel"]`, default `debug`, with *Off* omitting the key). | M | D |
| FR-MON-05 | The system shall allow pinning monitoring views into a resizable sidebar (≈320–720 px) that persists across sessions (`shared_preferences`). | S | D/A |
| FR-MON-06 | The system shall mask secrets in Network headers/bodies by default, with a reveal control. | S | D |
| FR-MON-07 | The system shall allow clearing and **exporting** captured entries. | S | D |
| FR-MON-08 | The system shall render spec errors by class (`-32020` HeaderMismatch, `-32021` MissingRequiredClientCapability, `-32022` UnsupportedProtocolVersion with `data.supported`, `-32601`, `-32602`) rather than as generic failures. | S | D |
| FR-MON-09 | The system may stamp W3C `traceparent` / `tracestate` in request `_meta` (SEP-414) and show it, so calls can be matched to server-side traces. | C | D |
| FR-MON-10 | For stdio servers, a non-JSON or malformed line on **stdout** shall appear as a protocol warning in the transcript. It shall not end the session. | M | P/A |

### 7.8 Automated test harness (FR-TST)

> Replaces Inspector **CLI** Musts for CI. User-facing CLI is Won't for v1; the **same protocol services** power headless tests.

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-TST-01 | Protocol services shall support connect → execute **one** method → return a structured result usable from `flutter test` / Dart tests without UI. | M | A |
| FR-TST-02 | The harness shall support methods: connect probe (legacy `initialize` / modern `server/discover`), `tools/list`, `tools/call`, `resources/list`, `resources/read`, `resources/templates/list`, `prompts/list`, `prompts/get`, and `logging/setLevel` (legacy only). It should also support `completion/complete`, `resources/directory/read`, and `skills/list` / `skills/get` where the server advertises them. | M | D/A |
| FR-TST-03 | Catalog CRUD methods (`servers/list|show|add|edit|remove`) shall be callable without an active MCP connection. | S | D/A |
| FR-TST-04 | Tool arguments shall accept map/JSON input with JSON-then-schema coercion. | M | D/A |
| FR-TST-05 | Results shall be available as typed Dart objects and as JSON suitable for assertions. | M | D/A |
| FR-TST-06 | Failures shall use stable `Failure` / error codes: usage, auth required, unreachable, tool error/not found, schema portability, etc. | M | D/A |
| FR-TST-07 | `tools/list` strict mode shall fail on error-severity schema portability findings. | S | D |
| FR-TST-08 | Non-interactive contexts shall never block on OAuth UI; they fail fast with `auth_required` when no stored auth exists. | M | D/A |

### 7.9 Protocol eras (FR-ERA)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-ERA-01 | Each server shall have a `protocolEra` of `legacy` (default), `auto`, or `modern`. | M | D |
| FR-ERA-02 | `legacy` shall use plain `initialize` with **no probing**. | M | D |
| FR-ERA-03 | `auto` shall probe `server/discover` and fall back to `initialize`. | S | D |
| FR-ERA-04 | `modern` shall pin `2026-07-28` and fail loudly against non-modern servers. | S | D |
| FR-ERA-05 | The negotiated era shall be shown in the Protocol tab and Connection Info. | S | D |
| FR-ERA-06 | The system shall allow choosing which **extensions** the client advertises, for debugging capability-dependent behaviour. | C | D |
| FR-ERA-07 | Connection Info shall show an **extension declaration view**: the server's `capabilities.extensions` next to what the client advertised, plus `supportedVersions`, `instructions` and `serverInfo`. | C | D |

### 7.10 Authentication (FR-AUT)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-AUT-01 | The system shall support OAuth for remote servers. Registration is tried in this order: **Client ID Metadata Document (CIMD)** → pre-registered (static) client → **Dynamic Client Registration** as a fallback. DCR is Deprecated (PR #2858) and kept only for authorization servers without CIMD. CIMD needs a hosted https metadata document (Q13). | M | D |
| FR-AUT-02 | The system shall use a **loopback-only** OAuth callback (default `http://127.0.0.1:<port>/oauth/callback`) and reject non-loopback hosts. This flow is separate from Test Point's Supabase GitHub sign-in deep link. | M | D/A |
| FR-AUT-03 | The system shall support scopes, refresh-token requests, token revocation on clear, and authorization/token URL overrides. | S | D |
| FR-AUT-04 | The system shall handle `403 insufficient_scope` by step-up re-authorization or surfacing the error (configurable). | S | D |
| FR-AUT-05 | Automated tests shall offer **stored-auth-only** (never interactive) reuse of tokens obtained in the UI. | M | D/A |
| FR-AUT-06 | Headless runs shall fail fast with `auth_required` rather than hang waiting for a browser. | M | D/A |
| FR-AUT-07 | Discovery shall follow RFC 9728 protected-resource metadata (from `WWW-Authenticate` or the `.well-known` path with the suffix rule, SEP-2351) and then authorization-server metadata. Requests shall use **PKCE S256** and the RFC 8707 `resource` parameter. | M | D |
| FR-AUT-08 | The client shall validate a present `iss` in the authorization response against the recorded issuer **before** redeeming the code (RFC 9207, SEP-2468) and reject a mismatch. | M | D |
| FR-AUT-09 | Persisted client credentials and tokens shall be **keyed by issuer**. They shall never be reused with another authorization server, and the client shall re-register when the issuer changes (SEP-2352). | M | D |
| FR-AUT-10 | DCR requests shall send `application_type: "native"` (SEP-837). Step-up shall request the accumulated scope set (SEP-2350). | S | D |
| FR-AUT-11 | OAuth **Client Credentials** (machine-to-machine) for headless runs. | C | P |

### 7.11 Configuration & catalog (FR-CFG)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-CFG-01 | The system shall maintain a writable **catalog** of MCP servers stored in **Supabase**, scoped to the current workspace. Secret fields are synced as placeholders, with values only on the device (§6.4). | M | D/A |
| FR-CFG-02 | The system shall accept a **read-only** import/config file that is never written back; writable catalog and read-only import are distinct flows. | M | D/A |
| FR-CFG-03 | The catalog shall use the standard `mcpServers` shape with per-server Lab settings (`protocolEra`, log level, headers, roots, timeouts, OAuth). | M | D |
| FR-CFG-04 | The system shall auto-detect or declare the transport type (`stdio`, `streamable-http`/`http`, and the deprecated `sse`). | M | D |
| FR-CFG-05 | The system shall **export** server config as *Server Entry* and *Servers File* for use in Cursor, Claude Code, or other clients. | S | D |
| FR-CFG-06 | The system shall **import** existing client configs (Claude Desktop, Cursor, Cline: `mcpServers`; VS Code `.vscode/mcp.json`: `servers` + `inputs`) and registry `server.json` via `file_picker`, using a per-source adapter. `${env:…}` / `${input:…}` placeholders shall become Test Point variables or prompts. They are never left as literal strings. | S | D/A |
| FR-CFG-07 | First-run Lab may seed sample servers that work on every OS (no `/tmp`-only paths). If the required runtime (`node`, `uvx`, …) is missing, the sample shows "runtime not found". An empty catalog is acceptable for guests with no imports. | C | D/A |
| FR-CFG-08 | Exports shall omit default-valued fields to keep diffs minimal. | C | D |
| FR-CFG-09 | Import shall **never connect automatically**. Before confirming, it shows a summary listing every stdio command + args that would be spawned and every remote URL, plus what was skipped (same pattern as Postman import). | M | P/A |
| FR-CFG-10 | Registry `server.json` import shall map `remotes` to HTTP entries and `packages` (`npm`, `pypi`, `oci`) to the matching stdio launcher (`npx`, `uvx`, `docker run -i`), with required env vars as prompts. | S | D/A |

### 7.12 MCP Apps & Skills (FR-APP / FR-SKL)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-APP-01 | Preview an MCP App tool UI in a **sandboxed WebView** (desktop) and exercise the `ui/*` bridge. | C | D/A |
| FR-APP-02 | Show the app's `ui/message` submissions and `notifications/message` logs beside the preview. | C | D |
| FR-APP-03 | Honour `_meta.ui.domain` with a dedicated app-origin serving strategy suitable for desktop WebView. | C | D/A |
| FR-SKL-01 | Browse and fetch skills when the server declares the Skills extension (SEP-2640). | C | D |

### 7.13 Distribution (FR-DST)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-DST-01 | MCP Lab ships as part of the Test Point desktop binaries (Windows, macOS, Linux) — not as an npm package. | M | A |
| FR-DST-02 | Development runs via `flutter run -d windows\|macos\|linux` with existing `--dart-define` for Supabase. | M | A |

### 7.14 Security-facing product behaviours (FR-SEC)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-SEC-01 | Connecting a **stdio** server shall require an explicit user action and show the command that will be spawned. | M | P/A |
| FR-SEC-02 | Secrets (OAuth tokens, client secrets, stdio `env` values) shall not appear in catalog exports or transcript defaults. | M | D/A |
| FR-SEC-03 | Credential-bearing custom headers shall be warn-flagged until moved into the secret store (see NFR-SEC-10). | S | P |
| FR-SEC-04 | **Per-device stdio trust:** before a stdio server first runs on a device, the user approves a hash of (command, args, cwd, env keys). Any change, including one that arrives through a synced or shared catalog, requires approval again. Trust records stay local and are never synced. | M | P |
| FR-SEC-05 | Server-supplied text (tool, prompt and resource descriptions, server `instructions`) shall be shown as plain text. Zero-width / bidi Unicode and ANSI escapes are made visible, and HTML or Markdown is never rendered as live content. | S | P |

### 7.15 Protocol fundamentals (FR-PRO)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-PRO-01 | Every result shall be read through `resultType` (`complete` \| `input_required` \| `task`, SEP-2322). A result from an earlier-protocol server that has no `resultType` is treated as `complete`. | M | D |
| FR-PRO-02 | On modern connections, every request shall carry `_meta` `io.modelcontextprotocol/protocolVersion`, `clientCapabilities` and `clientInfo` (SEP-2575). The transcript shows the request `_meta` and the result `_meta` `serverInfo`. | M | D |
| FR-PRO-03 | Streamable HTTP POSTs shall send the required `Mcp-Method` and `Mcp-Name` headers and mirror `x-mcp-header` arguments into `Mcp-Param-*` (SEP-2243). The Network view highlights `Mcp-*` headers and decodes sentinel values. | M | D |
| FR-PRO-04 | The system shall display the `ttlMs` / `cacheScope` cache hints on list and read results (SEP-2549). It does not cache by them in v1. | C | D |
| FR-PRO-05 | Resource-not-found shall be recognised as `-32602` (modern) and `-32002` (legacy servers). | S | D |
| FR-PRO-06 | **Stream loss:** on a modern connection, a broken response stream fails the in-flight request, which the user can re-issue under a new request ID (no `Last-Event-ID`). Legacy connections may resume with `Last-Event-ID`. | S | D |
| FR-PRO-07 | **Legacy sessions:** keep the server-assigned `Mcp-Session-Id`, send `DELETE` on disconnect, open the standalone GET notification stream, and offer a *Suppress Notification Stream* option per server. Modern connections are sessionless, so disconnect is purely local. | S | D |
| FR-PRO-08 | The system shall handle `notifications/{tools,prompts,resources}/list_changed` (legacy notifications; modern via the `subscriptions/listen` opt-ins) by marking the list stale and re-listing (automatically or on click, per a setting). | S | D |
| FR-PRO-09 | The system shall attach a progress token to long calls and show `notifications/progress` as a progress bar with message. Progress resets the request timeout (FR-CON-08). | S | D |
| FR-PRO-10 | On legacy connections the system shall offer `ping` as a manual health check and show the round-trip time. The control is hidden on modern connections, where `ping` was removed. | C | D |
| FR-PRO-11 | Lists and details shall show `title` (falling back to `name`) and icons. `data:` icons are rendered inline. Remote icon URLs are fetched only after the user allows it per server (privacy), with a size limit. | C | D/P |
| FR-PRO-12 | HTTP 429 shall map to `rate_limited`, showing `Retry-After` when present. The system does not retry automatically. | S | D |

### 7.16 Test Point integration (FR-TPI)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| FR-TPI-01 | `{{variables}}` from the active environment shall resolve in server URL, headers, stdio args, env values, and tool / prompt / resource-template arguments, with the same chips and autocomplete as the request builder. | S | P/A |
| FR-TPI-02 | A tool call, prompt get or resource read (server ref + method + params) can be **saved to a collection** and replayed. Saved items never hold resolved secrets. | S | P/A |
| FR-TPI-03 | The system shall keep a per-server **call history** for the current app session, with replay and copy-as-JSON. | C | P |
| FR-TPI-04 | Open servers and saved MCP calls shall use the top-bar **tabs** with the unsaved marker. The **status bar** shows the active MCP connection (transport, era, state). | S | P/A |
| FR-TPI-05 | Several servers may be connected at once (a default limit of 8, configurable). Each has its own transcript, and a slow call on one server never blocks another (NFR-PRF-04). | S | P |
| FR-TPI-06 | **Account rules:** the catalog follows the workspace (PRD §5.8). Local secrets and trust records are namespaced by Supabase user ID. When a guest links GitHub, they are kept. On sign-out or a switch to an existing account, the previous user's secrets are no longer readable, and the user can choose to clear them. | M | P/A |

### 7.17 Out-of-scope / Won't-have (this release)

| ID | Item | Rationale |
|---|---|---|
| FR-W-01 | User-facing CLI / TUI / `mcpdo` daemon | Desktop UI + Dart test harness cover the need; keep KISS |
| FR-W-02 | Node web backend, API bearer token, `/healthz`, Docker Inspector image | No browser/proxy architecture in Flutter desktop |
| FR-W-03 | CLI streaming methods (e.g. `logging/tail` as a one-shot process) | Use the live Monitor UI for streams |
| FR-W-04 | Load / stress testing of servers | Not an MCP Lab goal |
| FR-W-05 | Running an LLM or acting as a chat host | Not an MCP Lab goal |
| FR-W-06 | CLI `roots/set` | Roots configured via catalog/UI only |

---

## 8. Non-functional requirements

### 8.1 Security (NFR-SEC) — highest-risk area

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-SEC-01 | stdio servers run as **child processes of the Test Point app** (same user). Document that users must only launch trusted commands. | M | A |
| NFR-SEC-02 | There is **no** network-exposed process-spawning HTTP API in MCP Lab v1 (eliminates the Inspector web-proxy RCE class by architecture). | M | A |
| NFR-SEC-03 | OAuth callback listeners bind **loopback only**; non-loopback hosts are rejected with no override. | M | D/A |
| NFR-SEC-04 | Secrets shall be stored in the **OS secure store** on the device only. Supabase rows and catalog exports hold a placeholder in place of each secret value (§6.4). | M | D/A |
| NFR-SEC-05 | When secure storage is unavailable, the fallback shall warn loudly in the UI; prefer fail-closed or encrypted-at-rest over silent plaintext. | M | D/A |
| NFR-SEC-06 | The secret store shall not overwrite undecryptable data; misconfiguration fails visibly. | M | D |
| NFR-SEC-07 | stdio servers shall receive only an **allow-listed environment** plus their configured `env`. POSIX: `HOME`, `LOGNAME`, `PATH`, `SHELL`, `TERM`, `USER`. Windows: `PATH`, `PATHEXT`, `SystemRoot`, `SystemDrive`, `ComSpec`, `APPDATA`, `LOCALAPPDATA`, `USERPROFILE`, `TEMP`, `TMP`, `USERNAME`. Without these, `node`/`npx` fail on Windows. | M | D/A |
| NFR-SEC-08 | Deep-link auto-connect shall require explicit user confirmation (CSRF / drive-by gate). | S | D/A |
| NFR-SEC-09 | Redact query-string secrets in URLs shown in errors; mask secrets in the Network view. | S | D |
| NFR-SEC-10 | `headers` are **not** treated as secrets by default today; product should move credential-bearing headers to the secret store or clearly warn. | S | P |
| NFR-SEC-11 | A threat model for MCP Lab shall be documented: spawn, secrets, OAuth, import of untrusted config, synced catalogs (FR-SEC-04), malicious server text (FR-SEC-05), URL-mode elicitation and remote icons. | S | P/A |
| NFR-SEC-12 | Secrets shall never be truncated by a platform size limit. `flutter_secure_storage` 11.x on Windows already writes values to an AES-GCM encrypted file and keeps only the key in Credential Manager, so the about 2.5 KB entry limit does not apply. | M | A |
| NFR-SEC-13 | stdio commands shall be launched **without a shell** when possible. Where a shell is needed (Windows `.cmd` shims), arguments are quoted for that shell and the exact command line is shown before approval (FR-SEC-01/04). | M | A |

### 8.2 Performance & efficiency (NFR-PRF)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-PRF-01 | Default client-side request timeouts shall be configurable per server (align with Settings request timeout where sensible). | S | D/A |
| NFR-PRF-02 | Opening MCP Lab from a warm app session shall be interactive in **≤ 2 s** (feature surface, not full process cold start). | S | P/A |
| NFR-PRF-03 | Protocol and Network views shall stay responsive with **≥ 10,000** captured entries: lazy lists, a bounded ring buffer (oldest entries dropped, with a counter), bodies over a size limit (for example 256 KB) truncated with *Load full*, and JSON parsing off the UI isolate (in line with the PRD's 5 MB rule). | S | P/A |
| NFR-PRF-04 | Fast operations (list/read/get) shall not be blocked by a slow in-flight tool call. | S | P |
| NFR-PRF-05 | Proxy agent / HTTP client setup shall avoid cost when proxy is off (reuse Settings behaviour). | C | D/A |

### 8.3 Reliability & robustness (NFR-REL)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-REL-01 | Headless/auth flows shall **never hang** waiting for interactive OAuth; fail fast with `auth_required`. | M | D |
| NFR-REL-02 | A failed probe or malformed UI resource for one tool shall not abort a whole list/inspect run. | S | D |
| NFR-REL-03 | Concurrent secret writes shall be safe (no truncated/corrupt secure-storage entries). | S | D/A |
| NFR-REL-04 | Dropped modern subscription streams shall auto-reconnect and report status. | S | D |
| NFR-REL-05 | A non-terminating MRTR loop shall be bounded by a retry cap. | S | D |
| NFR-REL-06 | Disconnect and app close shall tear down child stdio processes and cancel in-flight remote requests. stdio shutdown follows the spec sequence: close stdin → wait (grace period) → SIGTERM → SIGKILL. On Windows the **whole process tree** is killed (for example a Job Object or `taskkill /T`), because `Process.kill` leaves `npx` children orphaned. | M | P/A |
| NFR-REL-07 | stdio children left running after an app crash shall be detected and offered for cleanup on next launch (for example from a recorded pid list). | S | P/A |

### 8.4 Usability (NFR-USE)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-USE-01 | A new user shall reach a first successful tool call with an ad-hoc stdio/URL connect and no prior catalog file. | M | D/A |
| NFR-USE-02 | UI tabs shall appear **only** when the server reports the corresponding capability. | S | D |
| NFR-USE-03 | Monitoring layout and sidebar width shall persist across sessions. | C | D/A |
| NFR-USE-04 | Error UI shall be actionable (stable error code, cause, status, URL) via `Failure` mapping. | M | D/A |
| NFR-USE-05 | Secret-store state shall be visible where secrets are entered (warning footer). | S | D |
| NFR-USE-06 | Meet **WCAG 2.2 AA** contrast and keyboard navigation within MCP Lab screens (aligned with Test Point NFR). | S | P |
| NFR-USE-07 | Keyboard shortcuts for connect, call tool, focus filter (`Ctrl+K`), search transcript (`Ctrl+F`), consistent with the rest of the app. | S | P/A |

### 8.5 Compatibility & portability (NFR-CMP)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-CMP-01 | MCP Lab shall run on **Flutter stable** desktop: Windows, macOS, Linux. | M | A |
| NFR-CMP-02 | The system shall support stdio, SSE, and Streamable HTTP transports through the same services used by UI and tests. | M | D/A |
| NFR-CMP-03 | The system shall support both **legacy** and **2026-07-28** protocol eras, selectable per server. | M | D |
| NFR-CMP-04 | The system shall run on hosts without a keychain with a defined, warned fallback. | M | D |
| NFR-CMP-05 | stdio launch shall work with each platform's path and quoting rules on Windows and POSIX, including resolving Windows `.cmd`/`.bat` shims (`npx`, `uvx`) through `PATHEXT` (see NFR-SEC-13). | M | A |
| NFR-CMP-06 | The **macOS** build shall define its sandbox and entitlements. The App Sandbox blocks spawning arbitrary binaries, and the OAuth loopback listener needs `com.apple.security.network.server`. If the sandboxed build cannot support stdio, it shall say so in the UI instead of failing silently. | M | A |
| NFR-CMP-07 | GUI-launched apps do not inherit the login-shell `PATH` (macOS, Linux desktop launchers). The system shall resolve `PATH` from the user's login shell, or accept absolute paths, and show the resolved binary path before launch. | M | A |

### 8.6 Interoperability & spec conformance (NFR-INT)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-INT-01 | MCP Lab shall behave as a **faithful MCP client** for the supported spec revisions. | M | D |
| NFR-INT-02 | Mirror SEP-2243 `x-mcp-header` arguments into `Mcp-Param-*` headers for remote transports. | S | D |
| NFR-INT-03 | Modern cancellation shall close the request's SSE stream; legacy and stdio shall send `notifications/cancelled`. | S | D |
| NFR-INT-04 | Config import shall accept the common client config shape (`mcpServers`) and the VS Code shape (`servers` + `inputs`). See FR-CFG-06. | S | D |
| NFR-INT-05 | stdio framing shall be newline-delimited UTF-8 JSON-RPC, with no embedded newlines in outgoing messages. | M | D |

### 8.7 Maintainability & testability (NFR-MNT)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-MNT-01 | UI and tests shall share one Dart protocol core so behaviour cannot drift. | M | D/A |
| NFR-MNT-02 | Ship **composable fixtures** / local test servers so protocol features are reproducible over real transports where practical; mock only at repository boundaries for unit tests (`mocktail`). | M | D/A |
| NFR-MNT-03 | Follow modular monolith rules: public API file only; no circular module deps. | M | A |
| NFR-MNT-04 | Prefer freezed models + `json_serializable`; no new packages without justification. | S | A |
| NFR-MNT-05 | Core services/repositories aim for strong automated coverage; widget tests for key Lab screens. | S | P/A |
| NFR-MNT-06 | License / product: part of Test Point (project license). | M | A |

### 8.8 Observability of the tool itself (NFR-OBS)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-OBS-01 | Opt-in debug logging for MCP Lab (structured, no secrets) for supportability. | S | D/A |
| NFR-OBS-02 | Active secret-store mode shall be visible in settings/Lab status. | S | D/A |

### 8.9 Documentation & supportability (NFR-DOC)

| ID | Requirement | Pri | Basis |
|---|---|---|---|
| NFR-DOC-01 | Feature docs cover connection, configuration, authorization, protocol eras, security, and recipes. | M | D/A |
| NFR-DOC-02 | Each protocol feature should have a "Reproduce with…" fixture reference under `test/` or `docs/features/mcp-lab/`. | S | D/A |
| NFR-DOC-03 | Security-relevant defaults and risks shall be documented in one place (threat model). | M | D/A |

---

## 9. Constraints, assumptions, dependencies

### Constraints
- **Runtime:** Flutter stable, desktop-first (Windows, macOS, Linux).
- **Process-spawning:** stdio transport launches local processes as the current user; inherent risk, mitigated by UX confirmation and docs.
- **No user-facing CLI in v1:** session-spanning flows (tasks, subscriptions, elicitation) are UI-first; tests use the shared services.
- **Roots** for automation are catalog/config driven.
- **Keychain availability** varies by host; fallback must be explicit.
- **Module boundaries** and Supabase rules from `AGENTS.md` / `ARCHITECTURE.md` apply.

### Assumptions
- Users trust the stdio servers they launch (they run as the user).
- Users run Test Point on a single-user, trusted machine.
- MCP spec revisions continue to land; Lab must carry two eras for some time.
- Existing Settings proxy / timeout preferences are the default knobs unless overridden per server.

### Dependencies
- **Dart MCP client: [`mcp_dart`](https://pub.dev/packages/mcp_dart) (decided).** Version 2.4.x supports 2026-07-28 and legacy, stdio, Streamable HTTP, opt-in SSE, OAuth hooks and Flutter desktop. It must be added to the Core Stack table in `agents.md`. The first implementation task is to wrap its transport behind a repository contract that records every raw frame (for the transcript) and drives MRTR manually (R-14).
- Dio (or equivalent) for HTTP/SSE/Streamable HTTP.
- OS secure storage plugin for secrets.
- `file_picker` for config import (already in Core Stack).
- Supabase for workspace-scoped catalog **if** cloud sync is chosen (migrations required).
- Optional desktop WebView for MCP Apps (Could).

---

## 10. Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-1 | User launches untrusted stdio command | Med | **Critical** | Explicit confirm + show full command (FR-SEC-01, NFR-SEC-01) |
| R-2 | Silent plaintext secret storage on keychain-less hosts | High | High | Loud warnings, fail-closed/encrypt options (NFR-SEC-04/05) |
| R-3 | Credentials in `headers` committed to VCS via export | Med | High | Warn or move to secret store (NFR-SEC-10) |
| R-4 | Behaviour drift between UI and tests | Low | Med | Shared Dart core (NFR-MNT-01) |
| R-5 | Spec churn breaks users mid-migration | Med | Med | Protocol eras; legacy default |
| R-6 | CI flakiness from interactive OAuth | Med | Med | Stored-auth-only; fail-fast headless (FR-AUT-05/06) |
| R-7 | MCP Apps WebView / CSP complexity on desktop | High | Med | Keep FR-APP as Could; ship primitives first |
| R-8 | Synced catalog leaks secrets or is missing them on a new device | Med | High | Placeholder rule (§6.4); "Not set on this device" state; never send a placeholder as a real value |
| R-9 | Windows process quoting / PATH differences for stdio | Med | Med | Platform-specific launch tests (NFR-CMP-05, NFR-SEC-13) |
| R-10 | A shared or synced catalog makes another member's device run a command | Med | **Critical** | Per-device trust on first use of the command hash; trust is never synced (FR-SEC-04) |
| R-11 | macOS sandbox or missing GUI `PATH` stops stdio servers from launching | High | High | NFR-CMP-06/07; clear "runtime not found" errors |
| R-12 | Orphaned stdio processes (Windows tree, app crash) | Med | Med | Tree kill + crash cleanup (NFR-REL-06/07) |
| R-13 | Malicious server text misleads the user (hidden Unicode, URL elicitation, remote icons) | Med | High | FR-SEC-05, FR-INT-06, FR-PRO-11 |
| R-14 | `mcp_dart` hides raw frames or handles MRTR automatically | Med | High | Wrap its transport behind a repository contract that records every frame; fall back to a thin in-repo transport for one transport if needed |

---

## 11. Traceability matrix

| Goal | Needs | Functional | Non-functional |
|---|---|---|---|
| **G-1** Fast feedback loop | N1–N4, N14 | FR-CON, FR-TOL, FR-RES, FR-PRM, FR-TPI, FR-DST | NFR-USE-01, NFR-PRF-02, NFR-CMP-05…07 |
| **G-2** Observability | N5, N7, N8 | FR-MON, FR-INT, FR-TSK, FR-PRO-02/03/09 | NFR-OBS, NFR-PRF-03 |
| **G-3** CI automation | N6, N10 | FR-TST, FR-AUT-05/06/11 | NFR-REL-01, NFR-USE-04, NFR-MNT-01/02 |
| **G-4** Spec tracking | N9, N12 | FR-ERA, FR-PRO, FR-TOL-05/06, FR-APP, FR-SKL | NFR-INT, NFR-CMP-03 |
| **G-5** Safe by default | N13 | FR-SEC, FR-AUT, FR-CFG-09/10, FR-INT-06 | NFR-SEC, NFR-REL-06/07, NFR-CMP-06 |

---

## 12. Open questions

| # | Question | Owner | Impact |
|---|---|---|---|
| Q-DATA-1 | ~~Where is the server catalog stored?~~ **Resolved:** Supabase, scoped to the workspace; secret values stay on the device. | Product / Eng | FR-CFG, migrations |
| Q1 | Should credential-bearing `headers` be stored as secrets by default? | Product / Security | NFR-SEC-10 |
| Q2 | Should secure-storage fallback require a key (fail closed) rather than plaintext? | Security | NFR-SEC-05 |
| Q3 | What are the target SLOs (Lab open time, transcript buffer size)? | Product | NFR-PRF-02/03 |
| Q4 | ~~Which Dart MCP library?~~ **Resolved:** `mcp_dart`. | Eng | Dependencies, R-14 |
| Q5 | ~~MVP slice?~~ *Proposed answer in §4.1 (release slices); needs product sign-off.* | Product | Prioritisation |
| Q6 | Which default timeout is authoritative for MCP calls vs HTTP Settings timeout? | Eng | NFR-PRF-01 |
| Q7 | Support horizon for the legacy era? | Product | NFR-CMP-03 |
| Q8 | Is MCP Apps preview planned for GA of MCP Lab? | Product | FR-APP |
| Q9 | Elicitation/Sampling: dedicated tabs vs pending-request dialogs only? | Design | FR-INT |
| Q10 | Nav rail IA: top-level **MCP Lab** vs nested under a future Protocols section? | Design | Shell |
| Q11 | ~~One secrets rule for the whole app?~~ **Resolved:** secret values stay on the device; Supabase stores a placeholder (§6.4). Implemented in the environments module. | Product / Security | NFR-SEC-04, environments |
| Q12 | Proxy precedence: does the Settings proxy override `HTTPS_PROXY`/`NO_PROXY`, or the other way round? | Eng | FR-CON-09 |
| Q13 | Who hosts Test Point's public **CIMD** client metadata document (https URL), and what redirect URIs does it list? | Eng / Ops | FR-AUT-01 |
| Q14 | CI fixture runtime: reuse the Inspector's Node composable test servers (MIT, needs Node in CI), or write Dart fixtures? | Eng | NFR-MNT-02, NFR-DOC-02 |
| Q15 | Should `code` move up into the core `Failure` for every module, or stay module-local in `McpFailure` (§6.6)? | Eng | Failure model |
| Q16 | macOS distribution: a sandboxed build (App Store) without stdio, or an unsandboxed notarized build? | Product / Eng | NFR-CMP-06 |

---

## 13. Sources

- PO analysis of MCP Inspector (this document’s v1.0 source content)
- MCP docs — [MCP Inspector overview](https://modelcontextprotocol.io/docs/tools/inspector.md)
- MCP docs — [Web client](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/web.md)
- MCP docs — [CLI client](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/cli.md)
- MCP docs — [Configuration and flags](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/configuration.md)
- MCP docs — [Security](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/security.md)
- MCP docs — [Protocol eras](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/protocol-eras.md)
- Repo — [modelcontextprotocol/inspector](https://github.com/modelcontextprotocol/inspector) · [Inspector roadmap 2026-H2](https://github.com/modelcontextprotocol/inspector/blob/HEAD/docs/inspector-roadmap-2026-h2.md)
- MCP spec — [2026-07-28 changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog) · [Release-candidate post](https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/)
- Dart — [`mcp_dart`](https://pub.dev/packages/mcp_dart) · [`dart_mcp`](https://pub.dev/documentation/dart_mcp/latest/)
- Review — [gap-review.md](gap-review.md)
- Test Point — [ARCHITECTURE.md](../../ARCHITECTURE.md), [PRD.md](../../PRD.md), [AGENTS.md](../../../AGENTS.md)

> Items marked **Proposed** / **Adapted** are recommendations for Test Point, not guarantees of the upstream Inspector. Section 12 lists decisions still needed before implementation.

---

## Appendix A — Example CI smoke test (Dart)

Demonstrates FR-TST-05/06/08 and NFR-REL-01 against the shared protocol service (no UI).

```dart
// test/modules/mcp_lab/mcp_lab_smoke_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';

void main() {
  late McpLabClient lab;

  setUp(() {
    lab = McpLabClient.stdio(
      command: 'node',
      args: const ['build/index.js'],
    );
  });

  tearDown(() async {
    await lab.disconnect();
  });

  test('exposes the expected tool', () async {
    final result = await lab.call(method: 'tools/list');
    expect(result.isSuccess, isTrue);
    final names = result.data!.tools.map((t) => t.name);
    expect(names, contains('get_weather'));
  });

  test('portable tool schemas', () async {
    final result = await lab.call(
      method: 'tools/list',
      strictSchemas: true,
    );
    expect(result.isSuccess, isTrue);
  });

  test('tool errors use a stable failure code', () async {
    final result = await lab.call(
      method: 'tools/call',
      toolName: 'get_weather',
      arguments: const {'city': ''},
    );
    // success or tool_error — never hang / unknown
    expect(
      result.isSuccess || result.failure?.code == 'tool_error',
      isTrue,
    );
  });

  test('unreachable remote fails fast', () async {
    final remote = McpLabClient.http(
      url: Uri.parse('http://127.0.0.1:1/mcp'),
      transport: McpTransport.http,
    );
    final result = await remote.call(method: 'tools/list');
    expect(result.failure?.code, 'unreachable');
  });
}
```

**Trade-offs:** spawning a real server per test is faithful but slower; prefer a shared `setUpAll` connection for suites. Remote OAuth servers must use stored-auth-only so CI never opens a browser.

> Type names (`McpLabClient`, `result.failure?.code`) are illustrative. The `code` comes from the module-local `McpFailure` (§6.6), not from the core `Failure`, which has no `code`. The final API lives behind `modules/mcp_lab/mcp_lab.dart`.

---

## Appendix B — Settings, storage & platform notes

| Item | Test Point approach | Notes |
|---|---|---|
| App entry | Flutter desktop binary | No `CLIENT_PORT` / Inspector backend |
| OAuth callback | Loopback HTTP and/or custom URL scheme | Reject non-loopback; align with existing auth patterns where possible |
| MCP Apps sandbox | Deferred (Could) | WebView-based if pursued; no separate sandbox ports by default |
| Catalog | Supabase, workspace-scoped | Secrets as placeholders (§6.4) |
| Secrets | OS secure storage | Not in exported `mcpServers` JSON |
| Proxy | Settings module + env proxy vars | Reuse existing proxy off/custom behaviour |
| Logging | Opt-in Lab debug flag | No secrets in logs |

| Variable / setting | Purpose |
|---|---|
| Settings → request timeout | Default MCP request timeout unless overridden per server |
| Settings → proxy | Outbound remote MCP transports |
| Secure store backend | Platform keychain / credential store |
| `HTTPS_PROXY` / `HTTP_PROXY` / `NO_PROXY` | Outbound proxy routing for remote servers |

Upstream Inspector ports (`6274`–`6278`) and `MCP_INSPECTOR_API_TOKEN` / `DANGEROUSLY_*` flags **do not apply** to MCP Lab.

---

## Appendix C — Source → Flutter adaptation map

| Inspector (source) | MCP Lab (Test Point / Flutter) |
|---|---|
| `npx` Web UI + Node backend | In-app desktop screens (`modules/mcp_lab`) |
| CLI client | Dart protocol services + `flutter test` harness (FR-TST) |
| TUI / `mcpdo` | Won't (v1) |
| `MCP_INSPECTOR_API_TOKEN`, loopback HTTP UI | Not applicable — no web API surface |
| `~/.mcp-inspector/mcp.json` catalog | Supabase workspace catalog |
| OS keychain / `secrets.json` | `flutter_secure_storage` (or equivalent) + UI warnings |
| Docker image / `/healthz` | Desktop app distribution only |
| Sandboxed iframe on extra ports | Optional desktop WebView (Could) |
| Storybook presentational components | Flutter widgets + widget tests |
| Node 22.19+ | Flutter stable desktop |
