# MCP Lab — Implementation Plan

| | |
|---|---|
| **Status** | Draft v1.0 · 2026-11-16 |
| **Milestone** | M7 (app plan Phase 8) |
| **Detail level** | S1 in detail, by layer; S2–S4 as an outline |
| **Related** | [feature-specification.md](feature-specification.md) · [s1-acceptance-criteria.md](s1-acceptance-criteria.md) · [gap-review.md](gap-review.md) · [Stitch screens](../../design/stitch-mvp-progress.md#mcp-lab-screens-phase-8-started-2026-11-15) · [IMPLEMENTATION_PLAN.md](../../IMPLEMENTATION_PLAN.md) · [ARCHITECTURE.md](../../ARCHITECTURE.md) · [agents.md](../../../agents.md) · [DATA_MODEL.md](../../DATA_MODEL.md) |

This plan explains **how** to build MCP Lab. **What** to build is defined in the spec, and **when it is done** is defined in the acceptance criteria. If this plan disagrees with them, they win.

Current implementation status: [full phase progress](implementation-progress.md).

---

## 1. Scope and starting point

### 1.1 Slices

| Slice | Contents (spec §4.1) | Status |
|---|---|---|
| **S1: Core lab** | stdio + Streamable HTTP, protocol eras (`legacy` default, `auto`, `modern`), tools / resources / prompts, raw-JSON args fallback, Protocol / Network / Console monitors, Supabase catalog (migration + RLS), failure model | **In progress.** Step 0 complete; models, catalog/trust repositories and catalog service unit-tested. Database validation and live-session/UI work remain pending; apply spec §6.7 throughout S1. |
| S2: Remote auth | OAuth (CIMD → pre-registered → DCR), secret store, stored-auth-only harness | **Blocked on Q13** (CIMD hosting domain) |
| S3: Interactions | Subscriptions, listChanged, progress, elicitation, sampling, roots, MRTR, tasks, logs | After S1 |
| S4: Test Point integration | `{{variables}}`, tabs / status bar, saved calls, import / export | After S1 (independent of S2/S3) |

### 1.2 What already exists and must be reused

| Need | Existing code |
|---|---|
| Result / failure types | `lib/core/error/result.dart` (`Result`, `Success`, `Err`), `lib/core/error/failure.dart` (sealed `Failure` + `NetworkFailure`, `StorageFailure`, `ValidationFailure`, `AuthFailure`, `UnexpectedFailure`) |
| Device-only secrets | `lib/core/secrets/secret_store.dart` (`SecretStore`, `secretStoreProvider`). Fails closed with `StorageFailure`. |
| HTTP client + settings | `lib/core/network/dio_provider.dart` (`dioProvider`), `network_settings.dart` (`networkSettingsProvider`: timeout, proxy), `dio_failure_mapper.dart` (`mapDioError`) |
| Supabase | `lib/core/database/supabase_client_provider.dart`, `supabase_failure_mapper.dart` (`mapSupabaseError`) |
| Shared widgets | `lib/core/ui/widgets/`: `CodeView` (re_editor + find bar), `ResizableSplitPane`, `MethodPill`, `StatusChip`, `VariableChip`, `showConfirmDialog`, `showFailureSnackBar`, `ContextMenu`, `showNameDialog` |
| Theme | `lib/core/ui/theme/`: `AppSpacing`, `AppRadius`, `HttpColors` (`context.httpColors`) |
| Workspace / user | `currentWorkspaceProvider` (`modules/workspaces/workspaces.dart`), `sessionProvider` → `AuthUser.id` (`modules/auth/auth.dart`) |
| Reference module | `lib/modules/environments/`, especially `EnvironmentService`, which implements the secret placeholder merge (synced `''`, real value on the device, `missingOnDevice`) |
| Shell | `lib/app/router/app_router.dart` (`ShellRoute`), `lib/app/shell/nav_rail.dart` (`navDestinations`), `lib/app/shell/status_bar.dart`, `lib/app/di/app_overrides.dart` (`moduleWiring()`) |
| Test support | `test/support/fake_backend.dart` (`fakeBackend`, `FakeStore`, `FakeSecretStore`), `test/support/pump_app.dart` (`pumpApp`), `test/integration/supabase_repositories_test.dart` (skipped-by-default pattern), `dart_test.yaml` tags |

---

## 2. Decisions made by this plan

| # | Decision | Why |
|---|---|---|
| P1 | **Step 0 is a spike.** Before any layer work, add `mcp_dart` and prove that its transport can be wrapped so that (a) every raw JSON-RPC frame is recorded in both directions, and (b) the app sends requests itself, with no automatic MRTR or retries. Also prove legacy initialized notification, session/version headers, 404 invalidation and bounded DELETE cleanup (spec §6.7). If either fails for a transport, write a thin in-repo transport for that transport only and keep `mcp_dart` for the types and the server side. | Risk R-14. The transcript (FR-MON-01) and S3 MRTR depend on it, and the repository contract in §3.3 is designed from what the spike finds. |
| P2 | **`McpFailure` = subclasses of the core failure kinds.** `Failure` is sealed, but `NetworkFailure`, `ValidationFailure`, etc. are plain classes and can be extended. Define `McpNetworkFailure extends NetworkFailure implements McpCoded`, and likewise `McpValidationFailure`, `McpAuthFailure`, `McpStorageFailure` and `McpUnexpectedFailure`. `McpCoded` exposes `McpErrorCode code` plus the optional `retryAfter`, `supportedVersions`, `exitCode` and `stderrTail`. | Gives each failure both the stable code and the core kind that AC-TST-06.1 requires, without changing `core` (Q15). |
| P3 | **Route `/mcp-lab`.** Add a nav-rail entry `NavDestination('MCP Lab', Icons.hub_outlined, '/mcp-lab')` before Settings. The MCP servers sidebar is part of the module's screen, not `ShellSidebar`. | The path is not a prefix of another route. Keeping the sidebar in the module means no shell coupling. |
| P4 | **Proxy precedence (FR-CON-09) is a pure module-local helper** `resolveMcpProxy(uri, settingsProxyUrl, env)`. It returns a direct connection or a proxy and is used to configure the Dio adapter for MCP HTTP transports. | Only MCP needs env-var proxies today. Promote it to `core/network` when the requests module needs them. |
| P5 | **Trust records (FR-SEC-04)** are stored in `shared_preferences` under `mcp-trust:<user id>:<server id>`. The value is a keyed digest of a canonical resolved launch snapshot using HMAC-SHA-256 and a per-user device key in secure storage (spec §6.7); preferences store per-field digests and labels only, never raw env values or args, so the dialog can name the fields that changed. | They are not secrets and stay local (AC-SEC-04.4/5). Comparing per-field digests lets the dialog say "Changed since last approval: args" (AC-SEC-04.2). |
| P6 | **Secrets** are stored under `mcp-server-secrets:<user id>:<server id>` as a JSON map `{"env.KEY": value, "header.authorization": value}`, with the same merge rules as `EnvironmentService`. | Confirmed assumption A5; one secrets rule app-wide (Q11). |
| P7 | **Fixtures** are Dart servers on `mcp_dart` in `test/fixtures/mcp/`, with one entry point and a `--fixture=<name> --transport=stdio\|http --era=legacy\|modern\|both` CLI. Integration tests live in `test/integration/mcp_lab/`, tagged `integration`, and are skipped unless `--dart-define=MCP_INTEGRATION=true`. | Q14: no Node in CI. Matches the existing integration test pattern. |
| P8 | **App exit kills stdio sessions.** The app has no close handling today. Add a `WindowListener` (`window_manager`: `setPreventClose(true)` + `onWindowClose`) in the shell that runs the stdio stop sequence for all sessions (≤ 5 s) and then closes the window. | AC-NFR-REL-06.2 ("or closes the app"). |
| P9 | **`crypto` becomes a direct dependency.** It is already transitive in `pubspec.lock`; P5 needs HMAC-SHA-256. Add a row to the Core Stack table. | `depend_on_referenced_packages` lint; no new code in the tree. |

---

## 3. S1 by layer

Build bottom-up. Each layer ends with its tests green and `flutter analyze` clean. Folder layout follows [spec §6.1](feature-specification.md#61-module-placement). Create only the folders that are used.

### 3.0 Step 0: dependencies and spike

| Task | Files | Done when |
|---|---|---|
| Add `mcp_dart` (latest stable) and `crypto` | `pubspec.yaml`, `agents.md` Core Stack table (row + reason) | `flutter pub get` passes; exit check 5 is half done |
| Spike: recording transport wrapper | throw-away branch, `test/spike/` | A Dart test connects to an `mcp_dart` example server over stdio and over HTTP, captures every in/out frame, and issues `tools/call` with a hand-built id. Record the result (keep `mcp_dart` transport / in-repo transport) in §7 of this doc. |
| Fixture skeleton + `fx-basic` | `test/fixtures/mcp/fixture_server.dart`, `fx_basic.dart` | `dart run test/fixtures/mcp/fixture_server.dart --fixture=basic --transport=stdio` answers `initialize` and `server/discover` |

### 3.1 Database

| Task | Files | ACs |
|---|---|---|
| `mcp_servers` table: `id uuid pk default gen_random_uuid()`, `workspace_id uuid not null references workspaces on delete cascade`, `name text not null`, `transport text not null check (transport in ('stdio','http','sse'))`, `command text`, `url text`, `args jsonb not null default '[]'`, `cwd text`, `env jsonb not null default '{}'` (string map; secret values `''`), `headers jsonb not null default '{}'` (same), `secret_keys jsonb not null default '[]'` (qualified names as in spec §6.7), `settings jsonb not null default '{}'` (`protocolEra`, `timeoutSeconds`), `position int`, `created_at`, `updated_at` + `set_updated_at` trigger, index on `workspace_id`; CHECK JSON container types and transport/target consistency as specified in spec §6.7 | `supabase/migrations/<YYYYMMDDHHMMSS>_mcp_servers.sql` | AC-CFG-01.*, AC-CFG-03.* |
| RLS: `enable row level security`; policy `mcp_servers_all_member` for all to authenticated using / with check `public.is_workspace_member(workspace_id)` (same as `environments`) | same migration | AC-CFG-01.* |
| Document the table, columns, the placeholder rule and RLS | `docs/DATA_MODEL.md` | Exit check 4 |

Verify: `supabase db reset` applies cleanly; extend `test/integration/supabase_repositories_test.dart` with a cross-workspace RLS denial for `mcp_servers`.

### 3.2 Models (`models/`, freezed + json_serializable)

| Model | Notes |
|---|---|
| `McpServer`, `McpServerDraft` | `transport` enum (`stdio`, `http`, `sse`), `command`, `args`, `cwd`, `env`, `url`, `headers`, `secretKeys`, `settings` (`McpServerSettings`: `protocolEra` = `legacy` default, `timeoutSeconds?`). `args` is kept apart from Lab settings (FR-CON-06). |
| `SecretValueState` | `present` / `missingOnDevice`, mirroring environments |
| `McpTool`, `ToolAnnotations` | name, title, description, `inputSchema` (raw map), `outputSchema?`, annotations |
| `McpResource`, `McpResourceTemplate`, `ResourceContents` | text or blob (base64; size only for large blobs) |
| `McpPrompt`, `PromptArgument`, `PromptMessage` | role + content block |
| `ContentBlock` (union) | text, image, audio, embeddedResource, resourceLink |
| `ToolCallResult` | `resultType` (`complete` / `inputRequired` / `task`; missing → `complete`), `content`, `structuredContent` (any JSON), `isError` |
| `RpcFrame` | direction, timestamp, kind (request / response / notification / warning), id, method, raw JSON string, size, paired id, `_meta` |
| `NetworkEntry` | method, url, status, request/response headers, body (truncated), duration |
| `ConsoleLine` | timestamp, text |
| `ConnectionStatus` | idle / connecting / connected(`NegotiatedEra`, serverInfo) / disconnected(`McpFailure?`) |
| `McpErrorCode` + `McpFailure` types | P2; codes from spec §6.6 |

Tests: AC-TST-05.1 `toJson`/`fromJson` round-trip for every result model; `resultType` default.

### 3.3 Repositories (`repositories/`, contract + impl)

| Contract → impl | Responsibilities | ACs |
|---|---|---|
| `McpServerRepository` → `McpServerRepositoryImpl(SupabaseClient)` | `list(workspaceId)`, `create`, `update`, `delete`. Same shape as `EnvironmentRepositoryImpl`: `on Object catch` → `mapSupabaseError`. | AC-CFG-01.*, AC-TST-06.2 |
| `McpTrustRepository` → `McpTrustRepositoryImpl(SharedPreferences)` | `read(userId, serverId)` → `TrustRecord?`, `approve(...)`, `clear(...)` (P5) | AC-SEC-04.* |
| `McpConnectionRepository` → `McpConnectionRepositoryImpl` | `connect(McpConnectTarget)` → `Result<McpSession>`. `McpSession` exposes `request(method, params, {timeout})` → `Result<Map>`, `notify`, `Stream<RpcFrame> frames`, `Stream<NetworkEntry> network`, `Stream<ConsoleLine> console`, `Stream<ConnectionStatus> status`, `close()`. Uses the recording wrapper from Step 0. | CON, PRO-02/03/06, MON-01…03/10 |
| *(inside the impl)* `StdioLauncher` | Resolve the executable: login-shell `PATH` on macOS/Linux (`$SHELL -lc 'echo $PATH'`, cached); `PATH` + `PATHEXT` on Windows (`npx` → `npx.cmd`; `.cmd`/`.bat` started through `cmd /c` with correct quoting). Child env = OS allow-list (`PATH`, `HOME`/`USERPROFILE`, `SYSTEMROOT`, `TEMP`, `LANG`, …) + configured `env`. Check that `cwd` exists before spawning. Stop sequence: close stdin → 2 s → SIGTERM (Windows: `taskkill /T`) → 2 s → SIGKILL (`taskkill /T /F`), within 5 s. On POSIX, start in its own process group and signal the group. Non-JSON stdout lines → `warning` frame. stderr → console. | AC-CON-02/04/06, AC-NFR-SEC-07/13, AC-NFR-CMP-07, AC-NFR-REL-06, AC-MON-03/10 |
| *(inside the impl)* HTTP transport | Dio instance built from `networkSettingsProvider` + `resolveMcpProxy` (P4). Custom headers; `Mcp-Method` / `Mcp-Name` / `Mcp-Param-*` on modern POSTs; records a `NetworkEntry` per exchange. A modern stream loss fails the request with `unreachable` "Stream lost" (no `Last-Event-ID`); legacy SSE resumes with `Last-Event-ID`. SSE is labelled deprecated. | AC-CON-03/05, AC-PRO-03/06, AC-MON-02 |
| *(inside the impl)* `McpErrorMapper` | JSON-RPC `-32602` (unknown tool vs invalid params by message), `-32002`, `-32020/21/22` (+ `data.supported`); HTTP 401/403 → `auth_required`, 429 → `rate_limited` + `Retry-After`; `ProcessException` / missing executable / missing cwd → `unreachable`; process exit → `process_exited` + exit code + stderr tail; `SocketException` / `DioException` → `unreachable`; `FormatException` → warning frame, not a failure | AC-TST-06.*, AC-PRO-05 |

Tests: unit tests with a fake process (`StdioLauncher` takes a `ProcessStarter` function) and a mocked Dio adapter; integration tests against fixtures (§3.7).

### 3.4 Services (`services/`)

| Service | Responsibilities | ACs |
|---|---|---|
| `McpCatalogService(McpServerRepository, SecretStore)` | Validate the draft: name, URL scheme `http`/`https` only, and transport inference (url only → http, command only → stdio, both / neither → `ValidationFailure`). Auto-mark credential headers as secret (Q1 rule). Split secret values out (placeholder `''` synced, real values in `SecretStore`) and merge them back on load with `missingOnDevice`. Remove deletes the secrets key. | AC-CON-03.3, AC-CFG-01/03/04 |
| `McpConnectService(McpConnectionRepository, McpTrustRepository, SecretStore)` | Before connecting: if any secret is missing → `ValidationFailure` naming the key (the placeholder is never sent). For stdio, compare the trust hash → return `NeedsApproval(resolvedCommand, changedFields)`. Era negotiation: `legacy` → `initialize` then `notifications/initialized`; `auto` → `server/discover`, on failure `initialize` (both in the transcript); `modern` → `server/discover` only, failing with `protocol_version_unsupported`. Modern requests carry `_meta` protocolVersion / clientCapabilities / clientInfo (`Test Point` + app version). Default timeout = `networkSettingsProvider.timeout`, unless the server overrides it (Q6). | AC-CON-01/02/07, AC-SEC-01/04, AC-ERA-01…05, AC-PRO-02, AC-CFG-01.4 |
| `McpToolService` | `list` (paging aggregated in S1), `call(name, args)` → `ToolCallResult`; `isError` is a **successful** result with outcome code `tool_error`, identical in UI and harness, flagged as a tool error, distinct from `Err` (FR-TOL-04); `input_required` / `task` → notice only (S3) | AC-TOL-01/03/04, AC-PRO-01 |
| `McpResourceService`, `McpPromptService` | List resources + templates, read; list prompts, get with arguments; `-32602`/`-32002` → "Resource not found" | AC-RES-01/02, AC-PRM-01/02, AC-PRO-05 |
| `SchemaFormBuilder` (pure) | JSON Schema → `FormSpec` tree: `type`, `properties`, `required`, `enum`, `default`, arrays, nested objects, local `$ref`/`$defs`, `oneOf`/`anyOf` as a variant picker. Returns `RawJsonOnly(reason)` for an external `$ref` (never fetched), depth > 32, a build over 100 ms (`Stopwatch`), or unsupported keywords. Also coerces form values to arguments (JSON-then-schema, FR-TST-04). | AC-TOL-02, AC-TOL-08 (A1) |
| `TranscriptBuffer` | Ring buffer of 10,000 entries with a `dropped` counter; pairs requests with responses by id; bodies over 256 KB are stored truncated with sanitized full text kept lazily (never raw wire data; apply spec §6.7 before retention); *Load full* parses with `compute` (off the UI isolate) | AC-MON-01 (Q3) |

The services above **are** the headless harness (FR-TST-01/02). A Dart test builds them with real repositories and no widgets.

Tests: unit tests with mocktail mocks of the three repository contracts. `SchemaFormBuilder` uses table-driven tests over `fx-schema`'s schemas.

### 3.5 Providers (`providers/`)

| Provider | Kind | Notes |
|---|---|---|
| `mcpServerRepositoryProvider`, `mcpTrustRepositoryProvider`, `mcpConnectionRepositoryProvider` | `Provider` | DI chain, overridable in tests |
| `mcpCatalogServiceProvider`, `mcpConnectServiceProvider`, `mcpToolServiceProvider`, … | `Provider` | |
| `mcpServersProvider` | `AsyncNotifierProvider<…, List<McpServer>>` | `build()` awaits `currentWorkspaceProvider.future`, like `environmentsProvider`; mutators return `Result` |
| `selectedMcpServerIdProvider` | `NotifierProvider<…, String?>` | |
| `mcpSessionsProvider` | `NotifierProvider<…, Map<String, McpSessionState>>` | Owns live sessions (status, era, server info); `connect` / `approveAndConnect` / `disconnect` / `remove`; runs awaited shutdown on auth/workspace transitions, membership loss and app exit; invalidates generation before cleanup and drops late completions (spec §6.7); provider disposal alone is not an awaited shutdown mechanism |
| `mcpToolsProvider(serverId)`, `mcpResourcesProvider(serverId)`, `mcpPromptsProvider(serverId)` | `FutureProvider.family` | Re-run on reconnect |
| `mcpToolCallProvider(serverId)` | `NotifierProvider.family` | Last call: args, running, result / failure, duration |
| `mcpTranscriptProvider(serverId)`, `mcpNetworkProvider(serverId)`, `mcpConsoleProvider(serverId)` | `NotifierProvider.family` | Fed by session streams; clear |
| `mcpLabPrefsProvider` | `NotifierProvider` on `shared_preferences` | Sidebar width, pinned monitor, form / JSON mode |

Add `FakeMcpServerRepository` and `FakeMcpConnectionRepository` (scripted sessions) to `test/support/fake_backend.dart` so `pumpApp` can render MCP Lab.

### 3.6 UI (`screens/`, `widgets/`, shell)

| Item | Files | Design | ACs |
|---|---|---|---|
| Public API + routes | `mcp_lab.dart`, `mcp_lab_routes.dart` (`mcpLabPath = '/mcp-lab'`) | — | AC-CON-01.1 |
| Shell wiring | `lib/app/router/app_router.dart` (`...mcpLabRoutes`), `lib/app/shell/nav_rail.dart` (4th item), `lib/app/shell/status_bar.dart` ("… · modern era" for the selected server) | #14 | AC-CON-01.1, AC-ERA-05.1 |
| `McpLabScreen` | three panes with `ResizableSplitPane`: servers sidebar · main view · pinned monitor | #14, #15 | — |
| `McpServersSidebar` | header "MCP SERVERS" + count, filter (`Ctrl+K`), "+ Add server", rows with status dot / name / fixed 52 px transport tag, empty state | #14 | AC-CON-01.2, AC-CON-07.1 |
| `McpServerDialog` (add / edit) | transport segmented control (SSE marked Deprecated), command / args chips / cwd / env table with secret toggle, url / headers, era dropdown (Legacy / Auto / Modern), timeout override; Import is **not** in S1 | #21 | AC-CON-02…06, AC-CFG-*, AC-ERA-01.1 |
| Server header + settings | connect / disconnect / remove (confirm), era badge, "Not set on this device" fields | #14 | AC-CON-07, AC-CFG-01.4 |
| `StdioApprovalDialog` | resolved executable path, every arg, cwd, env **keys**, amber "Changed since last approval: …", Cancel / Run | #18 | AC-SEC-01, AC-SEC-04.2, AC-NFR-SEC-13 |
| Tools view | list with annotation chips; `SchemaForm` widget ⇄ raw JSON (`CodeView`), "Call tool" + `Ctrl+Enter`; result renderer for each content block, `structuredContent`, distinct `isError` panel; large blobs as size + Save | #15 | AC-TOL-01…04/08 |
| Resources view, Prompts view | resources / templates toggle, viewer; prompt list, argument form, rendered messages | #17, #19 | AC-RES-01/02, AC-PRM-01/02 |
| Monitors | Protocol (paired frames, era badge, filter, `Ctrl+F`, detail with `CodeView` + Copy, truncation + *Load full*, warnings), Network (headers pane highlighting `Mcp-*`, sentinel decode), Console (stderr, live) | #16 | AC-MON-01…03/10, AC-PRO-02.2/03.2 |

Known Stitch nits to fix in Flutter rather than copy: "Auth needed" badge wording, no double "+ +", the sidebar footer icon, one-line labels (ellipsis) everywhere. All hints say `Ctrl`.

Widget tests: each row of the table marked W in the ACs, using `pumpApp` with the fakes; dark and light theme for the screen-level test.

### 3.7 Fixtures, integration tests and exit

| Task | Files |
|---|---|
| Fixtures `fx-basic`, `fx-schema`, `fx-content`, `fx-errors`, `fx-noisy`, `fx-crash`, `fx-hang` (behaviour table in the ACs) | `test/fixtures/mcp/` |
| Integration tests (level I), one file per AC area: `connection_test.dart`, `eras_test.dart`, `primitives_test.dart`, `stdio_lifecycle_test.dart`, `harness_test.dart` | `test/integration/mcp_lab/` |
| Manual (M) checks on Windows, macOS, Linux + NFR-USE-01 walkthrough (< 3 min) | recorded in the S1 PR |

Run: `flutter test` (unit + widget), then `flutter test test/integration/mcp_lab --dart-define=MCP_INTEGRATION=true`, then the Supabase integration suite after `supabase db reset`.

**S1 is done** when the [S1 exit check](s1-acceptance-criteria.md#s1-exit-check) passes.

---

## 4. AC traceability (S1)

| AC area | Implemented in | Test levels |
|---|---|---|
| AC-CON-01…07 | §3.3 launcher + HTTP transport, §3.4 `McpConnectService` / `McpCatalogService`, §3.5 `mcpSessionsProvider`, §3.6 sidebar + server dialog | U, W, I |
| AC-CFG-01, 03, 04 | §3.1 migration, §3.3 `McpServerRepository`, §3.4 `McpCatalogService` | U, W, I |
| AC-TOL-01…04, 08 | §3.4 `McpToolService`, `SchemaFormBuilder`; §3.6 tools view | U, W, I |
| AC-RES-01/02, AC-PRM-01/02 | §3.4 resource / prompt services; §3.6 views | I, W |
| AC-PRO-01/02/03/05/06 | §3.2 `ToolCallResult`, §3.3 HTTP transport + error mapper, §3.4 connect service | U, W, I |
| AC-MON-01/02/03/10 | §3.3 frame recording, §3.4 `TranscriptBuffer`, §3.6 monitors | U, W, I |
| AC-ERA-01…05 | §3.4 era negotiation, §3.6 era dropdown / badge / status bar | U, W, I |
| AC-SEC-01, 04 | §3.3 `McpTrustRepository`, §3.4 trust check, §3.6 approval dialog | U, W |
| AC-NFR-SEC-07/13, AC-NFR-CMP-07, AC-NFR-REL-06 | §3.3 `StdioLauncher`, P8 | U, I, M |
| AC-NFR-CMP-06 | N/A in v1 (Q16) | — |
| AC-TST-01/02/05/06 | §3.2 models, §3.3 error mapper, §3.4 services as the harness, §3.7 `harness_test.dart` | U, I |

---

## 5. S2–S4 outline

Each later slice gets its own acceptance criteria document before it starts, in the same format as S1.

### S2: Remote auth (blocked on Q13)
- **Unblock:** the owner provides a domain or GitHub Pages URL; publish the CIMD JSON from [spec Appendix D](feature-specification.md#appendix-d--draft-cimd-client-metadata-q13).
- **Services:** OAuth flow: 401 + `WWW-Authenticate` → protected-resource metadata → issuer → registration in order CIMD → pre-registered → DCR; PKCE S256 + `resource`; check `iss` before redeeming the code; refresh.
- **Repositories:** a loopback callback server on `127.0.0.1` (bypasses the proxy, P4); tokens in `SecretStore` keyed by issuer, using the existing platform secure-storage implementation without truncation (NFR-SEC-12).
- **Harness:** stored-auth-only mode that fails fast with `auth_required` (FR-TST-08).
- **UI:** OAuth panel and browser-wait card (#22); the "Auth needed" amber dot. Possibly adds `url_launcher` (not a dependency yet), with a justification.

### S3: Interactions
- Subscriptions: legacy `resources/subscribe` / unsubscribe; modern `subscriptions/listen` with stream status (FR-RES-03/05). `listChanged` marks lists stale.
- Progress tokens + progress bar; progress resets the timeout (FR-PRO-09, FR-CON-08).
- Server-initiated requests as pending-request dialogs only (Q9): elicitation (form and URL mode, "Open in browser?"), sampling, roots (#18). MRTR rounds driven by the Step 0 wrapper.
- Tasks tab and detail drawer (#20); Logs panel (deprecated, both eras' level control).

### S4: Test Point integration
- `{{variables}}` in URL, headers, args, env and arguments via `variableResolverProvider` from `modules/environments/environments.dart`; amber chips for unresolved ones; masked secrets in the transcript.
- Top-bar tabs and status bar for MCP sessions and saved calls (`TOOL` / `RES` / `PROMPT` pills).
- Saved MCP calls in collections. Decide between a `mcp_saved_calls` table and a `kind` column on `requests` at the start of S4.
- Import (Claude Desktop / Cursor / Cline / VS Code / registry `server.json`, never auto-connect, summary first) and export (#21 Import).

---

## 6. Risks for the build

| Risk | Mitigation |
|---|---|
| R-14: `mcp_dart` hides raw frames or auto-handles MRTR | Step 0 spike decides before any layer work (P1) |
| R-9 / R-12: Windows quoting, `.cmd` shims, orphaned process trees | `StdioLauncher` unit tests with a fake `ProcessStarter`; `fx-hang` integration test; manual Windows check |
| R-11: no shell `PATH` on macOS/Linux GUI launch | Login-shell `PATH` lookup; resolved path shown in the approval dialog |
| R-2: no keyring on Linux | `SecretStore` already fails closed; the server dialog shows the warning and still saves non-secret fields |
| Schema-form scope creep | Hard limit to the FR-TOL-02 subset; everything else falls back to raw JSON (FR-TOL-08) |
| Flaky integration tests (ports, timing) | Fixtures bind port 0 and report it; no fixed sleeps, wait on frames; skipped by default |

---

## 7. Spike results

Step 0 feasibility probes are complete with `mcp_dart` **2.4.4** and `crypto` **3.0.8**. Production implementation still requires the S1 tests and security gates below.

- **Verified:** `dart test/spike/stdio_probe.dart` connects to the SDK echo fixture, sends legacy `initialize` and `notifications/initialized`, calls `tools/call` with caller-supplied ID `777`, checks the echo result, and closes within a five-second bound. The observed child exit code was zero.
- **Test-runner blocker:** Flutter test execution stalls before reaching the test in the existing `cnativeapi` native build hook. The standalone Dart probe bypasses Flutter hooks; it is not evidence that the Flutter test suite passes.
- **Capture limitation:** the SDK `Transport.onmessage` callback exposes parsed `JsonRpcMessage`, not original wire bytes. The initial stdio test captures reconstructed messages only; exact frame fidelity, unknown fields, malformed stdout and pre-retention sanitization remain unproven.
- **HTTP verified:** `dart test/spike/http_probe.dart` uses a scripted loopback peer on port 0. It verifies caller-supplied request IDs, session/version headers, bounded DELETE cleanup accepting 405, and session HTTP 404 invalidation without replay. The raw transport caller must validate the initialization result and explicitly set `transport.protocolVersion` before ordinary requests.
- **Modern verified:** the HTTP probe also creates a fresh modern transport, performs `server/discover`, and confirms an `input_required` result reaches the caller without an unsolicited next round. A transport invalidated by legacy HTTP 404 cannot be reused: explicit reconnect must create a fresh instance. This is not a full multi-round interaction test.
- **Raw stdio feasibility:** `dart test/spike/wire_probe.dart` launches the SDK fixture through `Process`, captures newline frames before SDK parsing, performs modern discovery and a manual tool call, and redacts a configured canary before retention while preserving the operation result. It also proves SDK reconstruction drops top-level extensions and formatting. The probe's sanitizer handles only its canary and URL-encoded form, not the complete §6.7 policy.
- **Transport direction:** use thin in-repo transport boundaries for stdio and HTTP so diagnostics can intercept wire frames before parsing. Keep `mcp_dart` for protocol types and SDK fixture peers. HTTP additionally needs the existing Dio settings/proxy path; the SDK HTTP transport constructs its own private HTTP client. Production boundaries and full sanitizer are not implemented by these probes.
- **Dio boundary verified:** `dart test/spike/raw_http_probe.dart` captures SSE JSON frames before SDK reconstruction, preserves extension fields and unmodified JSON formatting, explicitly sends a second round only after receiving `input_required`, surfaces malformed JSON and unsupported-version data, and accepts DELETE 405. Its bounded fixture parser is not a production streaming SSE parser.
- **Redaction feasibility verified:** the spike sanitizer covers configured values, nested JSON, credential headers including Set-Cookie, credential query parameters, URL-encoded values and stderr text. Diagnostic copies are sanitized before retention; operation results retain their content. Production must consolidate this policy before every diagnostic stream and test truncation, caching, Copy/Load full and lifecycle disposal. These probes do not certify production security.
- **Decision:** proceed to S1 layers with local stdio and Dio HTTP boundaries, retaining SDK types and fixture peers. The HTTP peer is intentionally scripted to control failures. Full streaming, process-tree cleanup, account generation gates and interaction semantics remain S1/S3 implementation work.

### Database phase progress

Added `20261116000000_mcp_servers.sql`, data-model documentation and an opt-in integration test covering catalog round trips, constraints and cross-workspace read/write denial. Local execution is blocked because the Docker Desktop Linux daemon is unavailable; the migration has not been applied locally or remotely. Do not consider the database phase validated until it applies and the integration test passes against local Supabase.

### Models phase progress

Added module-local immutable catalog/settings, tools/content/results, resources/templates, prompts, diagnostic and connection-state models, plus coded failures that retain core failure kinds. Exports are through `mcp_lab.dart`. Protocol JSON and server settings explicitly preserve MCP camelCase despite the app's global snake_case generator option. Runtime connection failures are not persisted.

`dart test/modules/mcp_lab/models/model_checks.dart` passes round-trip, hand-written wire payload, default, immutability and failure metadata checks. The same checks are exposed through a Flutter test entrypoint; Flutter execution remains subject to the native-hook blocker. Serializer generation completed through an in-process build_runner invocation because standard bootstrap compilation invoked the stalled native hooks. Database validation remains pending and is independent of these model checks.

### Catalog repository progress

Added `McpServerRepository` and its Supabase implementation. Create, list, update and delete capture an explicit workspace ID; update/delete filter by both workspace and server ID. List order is position (null last), creation time, then ID. Updates preserve position unless a replacement is provided. Infrastructure exceptions use the existing Supabase failure mapper.

Explicit row mapping separates the flat database shape from nested domain drafts. Writes replace qualified secret values with empty placeholders even when given a hydrated draft; reads mark synced secret keys as missing on this device until the catalog service attaches local values. `mcp_lab.dart` exports only the contract, not its implementation or row helpers.

`dart test/modules/mcp_lab/repositories/catalog_row_checks.dart` passes all transport and secret-placeholder round trips. The local REST-peer Flutter test for CRUD payloads, workspace filters and failure conversion also passes through the unit-only harness described below. Real database integration remains pending; these checks do not validate RLS. Session repositories are still outstanding.

### Launch-trust repository progress

Added immutable resolved launch snapshots and captured user/workspace/generation context, a trust contract and device-local implementation. A 32-byte random per-user key stays in `SecretStore`; preferences hold only versioned per-field HMAC-SHA-256 digests and field labels. Digests bind user, workspace, server and launch values, including the inherited environment. Map ordering is stable; argument ordering remains meaningful.

The repository requires an authorization callback and checks it before and after asynchronous storage operations. Missing device keys are unapproved; storage failures never enable remembered approval. Key creation/writes are serialized in the repository. Late preference writes are removed, and failed persistence clears the in-memory preference record. The future connect service must still gate explicit approval, permit a one-time approved launch when secure storage is unavailable, and launch the exact approved snapshot; no process launcher or UI is wired yet.

`dart test/modules/mcp_lab/repositories/trust_digest_checks.dart` passes snapshot immutability, changed-field detection, account/workspace/server/device isolation, returning-account trust and digest-only persistence checks. Added mocked-storage Flutter tests for approval/check/clear, missing keys, unavailable storage and account changes during reads. Live session repositories remain outstanding.

### Catalog service progress

Added draft validation/normalization and device-only secret persistence. Headers are canonicalized, duplicate names rejected, credential names default to secret and plaintext overrides require an explicit confirmation argument. URL validation rejects user-info, including an empty `@` marker hidden by URI normalization. The service proves server/workspace ownership before existing-secret reads, scopes keys to the captured user/server, rejects stale account generations and hydrates missing-device states without sending placeholders. Non-secret create/delete operations work without secure storage. Storage/remote failures are visible, including partial persistence; failed secret creation rolls back the catalog row and failed remote deletion restores local values when possible.

### Transport foundations progress

Added `McpConnectionRepository`, `McpSession` and a memory-only resolved target. The connect service will drive negotiation and explicitly configure the validated era/version before ordinary operations. Session requests return the JSON-RPC result object (protocol errors become `Err`), support caller-supplied IDs, and close through an awaited `Result<void>` so cleanup failures remain visible.

Added a session-owned diagnostic sanitizer, error mapper and pure proxy resolver. The sanitizer preserves unchanged wire formatting, redacts configured/learned credentials and credential query/header text, handles mixed-case percent escapes, keeps operation results separate, and rejects use after disposal. The mapper preserves stable error codes, sanitizes version/stderr metadata, parses optional Retry-After values and leaves malformed JSON as a warning rather than a disconnect. Proxy selection honors Settings precedence, HTTP(S) environment variables, NO_PROXY domain/port/IP/CIDR entries and mandatory loopback bypass. Header-name classification is shared at the model layer to preserve dependency direction.

These helpers are unit-tested and shared between native stdio and base Streamable HTTP. Full cross-platform process-tree shutdown, HTTP parameter mirroring/legacy resumption and awaited app-level account cleanup remain pending.

### Native stdio progress

Added executable/cwd/environment resolution and a native stdio session implementation. It uses explicit inherited-environment filtering, frozen launch data, serialized writes, caller-controlled IDs, timeout/close cancellation, raw newline capture, sanitized diagnostics, unsupported server-request responses and negotiated lifecycle gates. Startup protocol/console entries are held in bounded sanitized buffers until the first listener; overflow is visible. No raw operation result is stored in diagnostic buffers. Process exit fails pending requests with sanitized exit metadata; close is idempotent and bounded in the verified fixture scenarios.

`dart test/integration/mcp_lab/stdio_session_checks.dart` passes seven real-process scenario groups on Windows, including SDK interoperability, modern/legacy calls, native argv/env fidelity, noisy and fragmented stderr, server requests, timeout/crash/close behavior, late listeners and stale-account rejection. The opt-in Flutter entrypoint uses `MCP_INTEGRATION=true`.

**Open platform gates:** `.cmd`/`.bat` launching is explicitly unavailable until safe quoting is implemented and tested; macOS process-group launch is not implemented. POSIX currently requires `/usr/bin/setsid`; Linux group/GUI PATH behavior remains unverified. Windows live-parent shutdown uses taskkill tree termination, but descendant cleanup after an early parent exit still needs work. These limitations keep S1 process lifecycle acceptance incomplete. No connect-service approval flow, app exit coordinator, provider or UI is wired yet.

### Streamable HTTP progress

Added a dedicated Dio session with JSON/SSE response handling, legacy initialize/version/session lifecycle, modern metadata and method/name headers, cancellation/deadlines and shared sanitized diagnostics. SSE framing handles fragmented UTF-8, BOM and legal line endings; malformed/incomplete data becomes a warning and explicit stream-loss failure. Request results stay separate from diagnostic copies. Response credentials are learned before echoed values enter diagnostic buffers, and raw debug interceptors are removed.

HTTP 404 discards the session and cancels concurrent calls without replay; only an explicitly created session can reconnect. Unsupported server requests receive method-not-found responses. DELETE cleanup is bounded, accepts 405 and preserves other failures while completing local close. Modern streams never resume with Last-Event-ID or automatically repeat calls. The client consumes the connect target's resolved proxy with mandatory loopback bypass.

`dart test/integration/mcp_lab/http_session_checks.dart` passes five loopback scenario groups covering JSON/SSE, credentials/custom headers, modern routing and input_required, stream loss/explicit retry, rate limits, concurrent expiry, failed/hanging cleanup and stale accounts. The seven stdio scenario groups also pass after extracting shared diagnostics. HTTP fixtures explicitly disable response buffering for server-initiated open SSE streams.

**2026-11-16 SEP-2243 follow-up:** modern Streamable HTTP now remembers the latest `tools/list` input schemas and mirrors annotated parameters into `Mcp-Param-*` headers, including nested object properties. It excludes tools with invalid or duplicate annotation names and non-primitive annotation types, enforces safe JavaScript integer bounds at emission, omits missing/null/type-mismatched values, and applies the SEP base64 sentinel encoding for non-ASCII/control bytes, leading/trailing space or tab, and sentinel-shaped values. The operation result omits invalidly annotated tools from its modern `tools/list` response while the raw sanitized frame remains available in diagnostics. Legacy and stdio transports are unchanged.

**Open HTTP gates:** legacy stream resumption/optional GET and deprecated HTTP+SSE remain pending. Redirects are disabled and TLS proxy endpoints explicitly rejected. App settings/environment resolution, connect-service negotiation/approval orchestration, provider lifecycle and UI are not wired yet.

**Unit verification:** all **63** tests under `test/modules/mcp_lab` pass using a temporary runner in `.dart_tool/mcp_unit_runner.dart`. The suite includes modern nested parameter mirroring, invalid tool filtering, and sentinel encoding. It invokes Flutter's `TestCommand` with no native-assets builder and the normal template renderer, and disables asset bundling for these model/REST/mocked-storage tests. This bypasses the unrelated cnativeapi hook without changing the SDK or app configuration. It does not validate native plugins or replace normal Flutter/integration validation. Static analysis of the module, tests and current fixtures/integration checks is clean. The ordinary Flutter test command still encounters the native-hook blocker.

## 8. S1 high-priority review implementation gates

- Catalog: implement the exact `url`/transport and qualified secret-key wire shape in spec §6.7, with round-trip tests and database constraint rejection tests in addition to RLS tests.
- Account lifecycle: an app-level coordinator observes auth/workspace/access changes and awaits module shutdown through its public API. Session operations capture user/workspace/generation. Secret/trust repositories enforce that context; no unscoped lookup fallback. Cleanup clears drafts, results, buffers and temporary bodies, not only the connection map.
- Diagnostics: add one sanitizer before repository diagnostic streams and before truncation or caching; apply it to protocol, network, stderr, exceptions and Copy/Load full. Test canary secrets and prevent debug interceptors from observing raw credentials. Keep operation results separate from sanitized diagnostic copies.
- Trust: replace env-key-only approval with the immutable resolved snapshot and per-field HMACs in spec §6.7. Never put raw arguments or environment values in preferences. A device key failure disables remembered approval, not the explicit approval gate.
- Legacy transport: include mandatory lifecycle in Step 0 and S1 repository integration tests. Optional GET stream controls remain S3. Test 404, DELETE 405, unsupported versions and no replay after expiry.

### Protocol negotiation progress

`McpNegotiationService` now handles the protocol handshake on an already authorized
session: legacy initialize/initialized, modern discovery, explicit auto fallback,
version and response validation, and awaited cleanup on failure. Nine unit tests
and the five HTTP integration scenario groups verify this slice. Connect target
resolution, launch approval and transport dispatch remain separate pending work;
the full connect service in section 3.4 is not complete. See the progress tracker.

### Resolved-target connect progress

Added transport dispatch and `McpConnectService` for hydrated/resolved targets,
composing the trust and connection contracts with negotiation. Explicit approval
uses a single-use, service-bound ticket for the displayed immutable snapshot;
remembered trust, storage-unavailable one-time launch, secret preflight and stale
account cleanup are covered by twelve tests. Executable/proxy/settings resolution,
provider lifecycle and approval UI remain pending. Deprecated SSE still fails
explicitly. See the progress tracker for current validation and remaining gates.

### Saved-target resolution progress

Added ownership-checked single-server hydration and target resolution through a
repository contract. Resolution reuses native executable/PATH/environment and
proxy helpers, captures settings in a Flutter-independent value, applies timeout
overrides and rejects stale contexts/missing secrets. Nine new unit cases pass;
all 93 MCP unit cases and five HTTP scenario groups pass. Provider mapping from
app settings, session ownership and lifecycle shutdown remain pending. See the
progress tracker for detailed validation and outstanding S1 gates.

### Session ownership and provider progress

Added session ownership with generation invalidation, duplicate/limit protection,
awaited boundary drain, late-result cleanup and pending approval ownership. Riverpod
now wires catalog/targets/trust/transports/negotiation, settings capture and session
actions/state. App eagerly observes account/workspace loading/errors/ID changes
through the lifecycle provider. Seven new tests cover owner and provider behavior;
all 100 unit cases, five HTTP groups and seven stdio groups pass (stdio needs
Windows process-tree permissions). Desktop window-close interception, explicit
server-access refresh, catalog/selection and monitor/result lifecycle remain open.

### Desktop close shutdown progress

Implemented native close interception using window_manager 0.6 close-request
events, plus a tested coordinator with an overall five-second cleanup deadline,
duplicate-request sharing, sanitized failure reporting and native-close retry.
Terminal session-owner shutdown prevents scope updates from reopening access;
opened sessions are tracked before negotiation so cleanup cancels pending
handshakes. All 109 selected unit cases (103 MCP plus six coordinator cases) and
static analysis pass. Native window events and cross-platform descendant cleanup
still require desktop/manual validation; see the progress tracker.

### Catalog and selection state progress

Added catalog loading/refresh and create/save/delete provider actions, with
workspace-scoped server selection and awaited session cleanup before save/delete.
Explicit catalog state drops previous hydrated rows during loading/errors;
generation/revision checks reject obsolete results. Successful refresh reconciles
missing servers through session-owner revocation, including pending negotiation.
All 118 selected cases (112 MCP and six desktop shutdown tests) and static analysis
pass. Automatic access-revocation discovery, preferences, diagnostic state and UI
remain pending; see the progress tracker for current S1 gates.

### Diagnostic buffers and providers progress

Added per-session protocol/network/console retention, typed/directional request
pairing and duration, entry/body limits, UTF-8 previews, sanitized Copy and
isolate-based Load full JSON. Capture attaches before negotiation; provider updates
are coalesced and lifecycle cleanup clears bodies and cancels subscriptions.
All 126 selected cases (120 MCP and six desktop shutdown tests) and analysis pass.
The HTTP transport still supplies only a 256 KiB Network prefix; such bodies are
explicitly partial and cannot Load full yet. Complete HTTP body capture and monitor
UI/performance validation remain pending. See the progress tracker for details.

### Primitive services progress

Added session-bound tool/resource/prompt services and provider wiring. Tool/prompt
lists aggregate bounded cursor pages; resources/templates expose explicit pages.
Calls preserve tool-error success and stop at intermediate results; prompt get
checks required arguments. Capability/access guards, JSON argument snapshots and
safe malformed-result conversion are covered by fourteen new unit cases. Modern
HTTP tool header mappings now survive continuation pages and reset on a first page.
All 140 selected unit cases and analysis pass; the final 28 affected cases were
rerun after decoding/cache changes. Both legacy/modern real HTTP primitive groups
and the five existing HTTP transport groups pass. Schema forms, result state and
UI remain pending. See the progress tracker for remaining S1 gates.

### Schema form planning and validation progress

Added pure bounded schema form plans, local reference resolution, variant choices,
JSON-then-type coercion and field-level validation, wired through schema-aware tool
calls. Unsupported schemas explicitly require raw mode; defaults are metadata for
future form prefilling and do not mutate explicit arguments. The full 155 selected
unit cases passed, followed by all 29 affected schema/primitive cases after variant
handling changes. Static analysis is clean. Flutter form widgets, Form/JSON editing
round trips, default prefilling and UI/performance acceptance remain pending; see
the progress tracker for details and processing limits.

### Draft and result state progress

Added session-owned tool/resource/prompt work controllers, stream providers and
explicit actions with current/submitted drafts, running/result/failure state and
duration. Old completions cannot overwrite newer work or escape a revoked scope.
Boundary disposal publishes empty snapshots and releases owned state without
waiting on paused UI listeners; reconnect starts fresh. All 165 selected unit
cases (159 MCP and six desktop shutdown tests) and static analysis pass. Large
HTTP body capture, Flutter form/default/round-trip UI and remaining exit gates
remain pending; see the progress tracker.

### Large HTTP diagnostic capture progress

HTTP diagnostic capture now retains up to 16 MiB of sanitized data frames, leaving
256 KiB preview truncation to the monitor. Capture overflow is explicit and UTF-8
safe, request-local bytes are released after emission, and Load full parses JSON
or SSE captured frame lists off-isolate. All 173 selected tests, six real HTTP
scenario groups and static analysis pass. Existing per-frame/binary-size limits,
UI responsiveness and other S1 exit gates remain open. See the progress tracker
for full capture semantics and current limits.

### Initial server-management UI progress

MCP Lab is now reachable through /mcp-lab and the navigation rail. Added the
resizable server sidebar/filter, masked settings, add/edit/delete, connection
controls and explicit stdio approval using existing providers/services. Dialogs
close on scope changes; saving never launches/connects. Applied frontend-design
and ui-ux-pro-max and inspected Stitch screen 14. Nine widget cases and dark/light
test renders validate this first UI slice; all 182 selected tests and analysis pass.
Primitive/form/result and monitor UI, full native desktop review and remaining S1
exit gates are still pending. See the progress tracker for validation limits.

### Tools and Prompts UI progress

Added capability-gated Tools and Prompts views, including prompt-only navigation.
Tools now have default-prefilled schema controls, Form/JSON editing, explicit
validated invocation/Ctrl+Enter, destructive confirmation and results. Prompts
have required/optional arguments, explicit Get prompt/Ctrl+Enter and ordered
messages. Both use session-owned drafts/results and an off-isolate JSON viewer
with bounded preview, explicit Load full, copy and clear. Restoring views preserves
drafts; scope cleanup clears them. Duplicate server definitions fail explicitly.

Applied frontend-design and ui-ux-pro-max, inspected Stitch screens 15/19 and
reviewed dark/light renders. All 203 selected tests (197 MCP plus six desktop
shutdown cases) and static analysis pass through the existing unit-only harness.
Resources/templates and monitor UI are next. Rich media/binary save, prompt
completion, output-schema diagnostics, destructive-confirmation preferences and
native/database/protocol S1 exit gates remain pending. See the progress tracker
for exact behavior and validation limits.

### Initial Resources UI progress

Added capability-gated resource-only navigation and independent Resources/Templates
lists with explicit next-page loading, refresh/retry, retained rows on failure,
pagination bounds and stale-response rejection. Selection fills a session-owned
URI draft; Read/Ctrl+Enter explicitly requests content. Text/JSON previews are
read-only, prepared off-isolate and bounded with Load full; raw text copy, result
JSON, duration, failure and clear controls are available. Binary metadata reports
decoded size and malformed base64. Template expressions require manual resolution
and are blocked from reads until replaced.

All 220 selected regression tests and analysis pass, with nine resource widget
checks rerun after final spacing adjustment. Reviewed Stitch screen 17 and both
theme renders using frontend-design and ui-ux-pro-max. Binary Save/inline images,
automatic URI-template expansion/completion and monitor UI remain next. This is
the initial Resources browsing/text-read slice; full S1 acceptance remains open.

### Binary resource Save and image preview progress

Added explicit native Save through a repository/service/provider boundary using
the existing file_picker package. Original bytes decode off-isolate; cancellation,
safe suggested names, failure/retry and current-result ownership guards are handled.
The native API owns the write once its dialog opens and cannot revoke that explicit
export on a later scope change; stale UI completion is suppressed.

Supported raster image previews are capped at 8 MiB encoded and fit within 1024 by
1024 decoded dimensions. Loading/error fallbacks, unsupported-type notices and
cache eviction accompany the Save control. All 235 selected regression tests and
analysis pass, with native exports mocked; actual desktop save dialogs, platform
image support and the existing transport-size/S1 exit gates remain unvalidated.
Automatic URI-template expansion and monitor UI remain next. See the progress
tracker for precise lifecycle semantics and validation limits.

### Scalar URI-template expansion progress

Added session-owned template selection/string arguments, Include controls,
automatic resolved-URI preview, explicit reads and manual-URI fallback. The bounded
pure expander covers scalar RFC 6570 operators and modifiers with Unicode-safe
encoding, valid percent-triplet preservation for reserved expansion, and explicit
undefined/empty semantics. Malformed/over-budget input returns application failures;
no new dependency or automatic request is added.

All 248 selected regression tests and analysis pass; the 29 affected cases were
rerun after final UTF-8 budget refinements. Both theme renders were reviewed using
frontend-design and ui-ux-pro-max. Composite list/map editors, completion and active
environment integration remain follow-ups. Protocol/network/console monitor UI is
next, with the existing native/database/protocol S1 exit gates still open.
