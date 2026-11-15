# MCP Lab — S1 (Core lab) Acceptance Criteria

| | |
|---|---|
| **Slice** | S1: Core lab ([spec §4.1](feature-specification.md#41-proposed-release-slices)) |
| **Date** | 2026-11-15 |
| **Status** | Draft v1.1: open points resolved; S1 assumptions A1–A5 confirmed |
| **Designs** | Stitch #14–#18, #19 (Prompts), #21 (Add server) in [stitch-mvp-progress.md](../../design/stitch-mvp-progress.md#mcp-lab-screens-phase-8-started-2026-11-15) |

Each S1 requirement has one or more Given/When/Then criteria. S1 is done when every
criterion passes at its verification level and the [S1 exit check](#s1-exit-check) passes.

**Verification levels**
- **U**: unit test (`flutter test`, `mocktail` at repository boundaries).
- **W**: widget test.
- **I**: integration test against a fixture MCP server over a real transport (`test/integration/mcp_lab/`, skipped by default like the Supabase tests).
- **M**: manual check on each desktop OS (Windows, macOS, Linux), recorded in the PR.

**Fixture servers (confirmed Q14).** Dart fixtures built on the `mcp_dart` server side,
one per behaviour, so CI does not need Node. They run in two modes: a stdio executable
and a Streamable HTTP server on `127.0.0.1`. Each fixture can answer as `legacy`
(`initialize`) or `modern` (`server/discover`). The criteria name them as:

| Fixture | Behaviour |
|---|---|
| `fx-basic` | 2 tools (`echo`, `add`), 2 resources + 1 template, 2 prompts; valid results |
| `fx-schema` | Tools with nested objects, arrays, `enum`, `default`, local `$ref`/`$defs`, `oneOf`, an external `$ref`, and a 200-level deep schema |
| `fx-content` | A tool returning text, image, audio, embedded resource (text and `blob`), `resource_link`, `structuredContent`, and a 20 MB blob |
| `fx-errors` | `isError: true` result, `-32602` unknown tool, `-32602`/`-32002` resource not found, `-32022` with `data.supported`, HTTP 429 |
| `fx-noisy` | Writes a non-JSON line to stdout and lines to stderr, then keeps working |
| `fx-crash` | Exits with code 3 after the first request |
| `fx-hang` | Ignores stdin close and SIGTERM; spawns a child process |

Criterion IDs are `AC-<requirement>.<n>`, so `AC-CON-02.1` belongs to FR-CON-02.

---

## 1. Launch and connection (FR-CON-01…07)

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-CON-01.1 | The app is open on any route | The user clicks **MCP Lab** in the nav rail | The MCP Lab route opens with the servers sidebar, without any install step or external process | W |
| AC-CON-01.2 | MCP Lab is open and the catalog is empty | The screen renders | An empty state shows **+ Add server** and **Import**, no error | W |
| AC-CON-02.1 | A stdio server `dart run fx-basic` is saved and approved | The user clicks **Connect** | A child process starts with exactly that command and args, the handshake completes, and the server shows **Connected** | I |
| AC-CON-02.2 | The command does not exist (`nonexistent-bin`) | The user connects | No process is left running; the UI shows `unreachable` "Command not found: nonexistent-bin" with the resolved `PATH` | U, I |
| AC-CON-03.1 | An HTTP server URL for `fx-basic` with transport `Streamable HTTP` | The user connects | The handshake is sent as HTTP POST to that URL and the server shows **Connected** | I |
| AC-CON-03.2 | The Add server dialog is open | The user looks at the transport control | Streamable HTTP is the default; SSE is selectable and labelled **Deprecated** | W |
| AC-CON-03.3 | A URL with a scheme other than `http`/`https` (`file:///x`, `ftp://x`) | The user saves | Save is blocked with a validation message | U |
| AC-CON-04.1 | A stdio server with `env {FOO: bar}` and working directory `<tmp>/work` | It connects | The fixture's `env` tool reports `FOO=bar` and `cwd` = `<tmp>/work` | I |
| AC-CON-04.2 | The working directory does not exist | The user connects | The connect fails with `unreachable` "Working directory not found", no process starts | U |
| AC-CON-05.1 | An HTTP server with header `X-Team: qa` | Any request is sent | The request carries `X-Team: qa` (checked by the fixture and in the Network view) | I |
| AC-CON-06.1 | A stdio server with args `["--port", "--help", "--era=modern"]` | It connects | The process receives exactly those three args, and the server's `protocolEra` setting is not changed by `--era=modern` | U |
| AC-CON-07.1 | Two servers in the catalog, one connected | The sidebar renders | Each row shows a status dot (connected green / idle gray), the name and a fixed-width transport tag | W |
| AC-CON-07.2 | A connected server | The user clicks **Disconnect** | The session closes (stdio: shutdown sequence of AC-REL-06.1), the dot turns gray, and in-flight calls end as cancelled | I |
| AC-CON-07.3 | A connected server | The user removes it from the catalog | The user confirms first; the session closes, then the catalog row is deleted | W, U |

## 2. Catalog in Supabase (FR-CFG-01, 03, 04)

These requirements are listed under S2/S4 in §4.1, but S1 ships the catalog with migrations and RLS, so their core belongs here.

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-CFG-01.1 | A signed-in user (guest or GitHub) in workspace W | The user saves a server | A `mcp_servers` row is created with `workspace_id = W`, and it appears after an app restart | I (Supabase) |
| AC-CFG-01.2 | User B in another organization | User B queries `mcp_servers` | User A's rows are not returned (RLS), and inserting into A's workspace is rejected | I (Supabase) |
| AC-CFG-01.3 | A stdio env value or header marked **secret** | The server is saved | The Supabase row stores the key with `secret: true` and the placeholder `""`; the real value is in `SecretStore` under `mcp-server-secrets:<server id>` | U, I |
| AC-CFG-01.4 | The same server opened on a device without the local secret | The server settings render | The field shows **Not set on this device**, and Connect is blocked with a message naming the missing key; the placeholder is never sent | U, W |
| AC-CFG-01.5 | A server with a secret is deleted | Delete completes | The Supabase row and the local `mcp-server-secrets:<id>` entry are both removed | U |
| AC-CFG-01.6 | The user adds headers `Authorization`, `x-api-key`, `X-Github-Token` and `X-Team` (Q1, NFR-SEC-10) | The headers table renders | The first three are marked secret automatically (case-insensitive match) and `X-Team` is not | U, W |
| AC-CFG-01.7 | An auto-marked header | The user unmarks it | The same confirmation as environments ("Stop keeping this value secret?") is shown; after confirming, the value syncs as plain text and the row keeps a warning icon (FR-SEC-03) | W |
| AC-CFG-01.8 | The secure store is unavailable (`SecretStore` returns a failure) (Q2, NFR-SEC-05) | The user saves a server that has a secret value | The secret is not written anywhere; a warning "Secure storage is unavailable…" is shown; non-secret fields save normally. A server without secrets saves with no warning | U, W |
| AC-CFG-03.1 | A server saved with era, timeout and headers | Its row is read back | `command`/`args`/`env`/`url`/`headers` map to the `mcpServers` entry shape, and Lab-only settings sit in `settings` (never mixed into `args`) | U |
| AC-CFG-04.1 | A server with `url` and no `command` | It is saved without a transport | The transport is inferred as Streamable HTTP; with `command` and no `url` it is stdio; with both or neither, save is blocked | U |
| AC-CFG-04.2 | Saving fails (network down, RLS error) | The user saves | A `StorageFailure` message is shown and the dialog keeps the entered values | U, W |

## 3. Tools (FR-TOL-01…04, 08)

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-TOL-01.1 | Connected to `fx-basic` | The Tools tab opens | Both tools are listed with name, description and annotation chips (e.g. `read-only`), in server order | I, W |
| AC-TOL-01.2 | A server that does not advertise `tools` | The server opens | The Tools tab is hidden (NFR-USE-02) | W |
| AC-TOL-02.1 | `fx-schema` tool with nested object, array, `enum`, `default`, `required` | The tool is selected | The form shows one field per property with the right control (text, number, switch, dropdown, list, nested group), defaults pre-filled, required fields marked `*` | W |
| AC-TOL-02.2 | A required field is empty | The user calls the tool | The call is not sent; the field shows "Required" | W, U |
| AC-TOL-02.3 | A schema with local `$ref` to `$defs` | The form renders | The referenced definition is rendered inline | U |
| AC-TOL-02.4 | A schema with `oneOf` of two object shapes | The form renders | A variant picker selects the shape, and only that shape's fields are sent | W |
| AC-TOL-02.5 | A schema with an external `$ref` (`https://…`) | The form renders | No network request is made (checked with a mock HTTP client); the tool opens in raw JSON mode with "External $ref not supported" | U |
| AC-TOL-02.6 | A 200-level deep schema | The form builds | Building stops at the depth limit (32) within 100 ms and falls back to raw JSON with a note; the UI does not freeze | U |
| AC-TOL-03.1 | `add` with `{a: 2, b: 3}` | The user clicks **Call tool** (or `Ctrl+Enter`) | The result shows `5` as text, plus status **Success** and the duration in ms | I, W |
| AC-TOL-03.2 | `fx-content` multi-content tool | The result renders | Text, image (rendered), audio (player or save), embedded text resource, base64 `blob` (decoded size + mime), `resource_link` (uri, clickable to Resources) and `structuredContent` (JSON viewer) all appear | W |
| AC-TOL-03.3 | A 20 MB blob in the result | The result renders | It shows mime + size and a **Save** action, not decoded inline; the UI stays responsive (decoding off the UI isolate) | W, M |
| AC-TOL-04.1 | `fx-errors` tool returns `isError: true` | The call completes | The result panel shows a red **Tool error** with the server's text; it is not shown as a connection failure and the session stays connected | I, W |
| AC-TOL-04.2 | The transport fails during a call (server killed) | The call is in flight | The panel shows the `Failure` message (`process_exited` / `unreachable`), distinct from **Tool error** | I |
| AC-TOL-08.1 | Any tool | The user switches **Form → JSON** | The JSON editor holds the current form values; switching back keeps edits that fit the schema | W |
| AC-TOL-08.2 | Invalid JSON in the raw editor | The user calls the tool | The call is not sent; the editor marks the parse error position | W |
| AC-TOL-08.3 | A schema feature the form does not support | The tool is selected | Raw JSON opens automatically with a note naming the feature | W |

## 4. Resources and prompts (FR-RES-01/02, FR-PRM-01/02)

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-RES-01.1 | Connected to `fx-basic` | The Resources tab opens | Resources and templates are listed (toggle *Resources (2) / Templates (1)*) with name, uri, mime type and description | I, W |
| AC-RES-01.2 | The server returns a `nextCursor` | The list renders | **Load next page** fetches the next page and appends it; it is hidden when there is no cursor | I, W |
| AC-RES-02.1 | A text resource is selected | It loads | `resources/read` is sent and the content shows in the viewer (JSON pretty-printed when the mime type is JSON) | I, W |
| AC-RES-02.2 | A binary resource (`blob`) | It loads | Mime + size and a **Save** action are shown; images render inline | W |
| AC-RES-02.3 | The resource no longer exists | It is read | The viewer shows "Resource not found" (see AC-PRO-05.1), not a generic error | I |
| AC-PRM-01.1 | Connected to `fx-basic` | The Prompts tab opens | Prompts are listed with name, description and an argument count tag | I, W |
| AC-PRM-02.1 | A prompt with a required `city` argument | The user fills it and clicks **Get prompt** | `prompts/get` is sent with the arguments, and the messages render in order with role badges (`user` / `assistant`) and their content types | I, W |
| AC-PRM-02.2 | A required argument is empty | The user clicks **Get prompt** | Nothing is sent; the field shows "Required" | W |

## 5. Protocol fundamentals (FR-PRO-01…03, 05, 06)

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-PRO-01.1 | A legacy result without `resultType` | It is parsed | It is handled as `complete` | U |
| AC-PRO-01.2 | A result with `resultType: "input_required"` or `"task"` in S1 | It arrives | The call ends with the notice "This server needs interaction support (coming in a later version)" and the raw result stays in the transcript; it does not crash | U |
| AC-PRO-02.1 | A modern-era connection | Any request is sent | Its `_meta` carries `io.modelcontextprotocol/protocolVersion = 2026-07-28`, `clientCapabilities` and `clientInfo` (name `Test Point`, app version) | U, I |
| AC-PRO-02.2 | A modern result with `_meta.serverInfo` | It is shown in the Protocol view | The request `_meta` and the result `serverInfo` are visible in the frame detail | W |
| AC-PRO-03.1 | Modern era over Streamable HTTP, `tools/call` for `add` | The POST is sent | It carries `Mcp-Method: tools/call` and `Mcp-Name: add`; `x-mcp-header` arguments are mirrored as `Mcp-Param-*` | U, I |
| AC-PRO-03.2 | Such a request in the Network view | The headers pane renders | `Mcp-*` headers are highlighted and sentinel values are decoded | W |
| AC-PRO-05.1 | `fx-errors` returns `-32602` (modern) or `-32002` (legacy) for `resources/read` | The read fails | Both map to "Resource not found" with the uri | U |
| AC-PRO-06.1 | A modern Streamable HTTP call whose response stream is cut | The stream drops | The call fails with `unreachable` "Stream lost"; **Retry** re-sends it with a new request id; no `Last-Event-ID` is sent | U, I |
| AC-PRO-06.2 | A legacy connection whose SSE stream drops with an event id | The client reconnects | It sends `Last-Event-ID` with the last id seen | U |

## 6. Monitors (FR-MON-01…03, 10)

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-MON-01.1 | Connected to any server | The handshake and a tool call happen | The Protocol view lists every frame in order with direction (→ / ←), method, id and time; each response is paired with its request and shows the duration | U, W |
| AC-MON-01.2 | Notifications arrive | They are recorded | They appear as unpaired frames with their method | U |
| AC-MON-01.3 | A frame is selected | Detail opens | The full JSON is shown (code viewer) with **Copy** | W |
| AC-MON-01.4 | 10,000 frames recorded | The user scrolls and filters | Scrolling stays smooth (lazy list); the oldest frames over the 10,000 limit are dropped with a "N older frames dropped" counter (Q3, NFR-PRF-03) | U, M |
| AC-MON-01.5 | A frame or HTTP body larger than 256 KB (Q3, NFR-PRF-03) | Its detail opens | It shows the first 256 KB with a "Truncated · <size>" note and **Load full**; loading the full body parses JSON off the UI isolate, and the UI stays responsive | U, W |
| AC-MON-02.1 | An HTTP server | A request is sent | The Network view shows method, URL, status, duration, request/response headers and bodies | I, W |
| AC-MON-02.2 | A request with `Authorization: Bearer x` | The Network view renders | The value is masked by default | W |
| AC-MON-02.3 | A stdio server | The tab strip renders | The tab is **Console**, not Network | W |
| AC-MON-03.1 | `fx-noisy` writes to stderr | The Console view is open | Each stderr line appears with a timestamp, live, in order | I, W |
| AC-MON-10.1 | `fx-noisy` writes `hello world` to stdout | The line is read | The Protocol view shows an amber **Protocol warning: non-JSON line on stdout** with the text, and the session stays connected | I |
| AC-MON-10.2 | A partial JSON line split across two reads | The second chunk arrives | It is joined and parsed as one frame (newline-delimited framing, NFR-INT-05) | U |

## 7. Protocol eras (FR-ERA-01…05)

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-ERA-01.1 | A new server | It is created | `protocolEra` is `legacy`; the dropdown offers Legacy, Auto (try modern, fall back to legacy), Modern | U, W |
| AC-ERA-02.1 | `protocolEra: legacy` | It connects | The first frame is `initialize`; no `server/discover` is ever sent | I |
| AC-ERA-03.1 | `protocolEra: auto` against a modern fixture | It connects | `server/discover` succeeds and the era is **modern** | I |
| AC-ERA-03.2 | `protocolEra: auto` against a legacy-only fixture | It connects | `server/discover` fails, `initialize` follows, the era is **legacy**; both attempts are in the transcript | I |
| AC-ERA-04.1 | `protocolEra: modern` against a legacy-only fixture | It connects | The connect fails with `protocol_version_unsupported` and the versions the server reported; no fallback to `initialize` | I |
| AC-ERA-05.1 | Any connected server | The UI renders | The negotiated era shows in the Protocol view badge, the server header and the status bar ("… · modern era") | W |

## 8. Security (FR-SEC-01, 04) and process handling

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-SEC-01.1 | A stdio server never approved on this device | The user clicks Connect | The approval dialog shows the resolved executable path, every arg, working directory and env **keys** (no secret values); nothing starts until **Run** | W, U |
| AC-SEC-01.2 | The user clicks **Cancel** in the approval dialog | — | No process starts and nothing is recorded as approved | U |
| AC-SEC-04.1 | A server approved on this device | It connects again unchanged | No dialog; it starts directly | U |
| AC-SEC-04.2 | The approved server's args, cwd, command or env keys change (locally or through the synced catalog) | It connects | The dialog appears again with an amber "Changed since last approval: <fields>" | U, W |
| AC-SEC-04.3 | An env **value** changes but the keys stay the same | It connects | No re-approval (the hash covers env keys only) | U |
| AC-SEC-04.4 | Approvals on device A | The same server opens on device B | Device B asks for approval; approvals are stored locally under the Supabase user id and never written to Supabase | U |
| AC-SEC-04.5 | Another user signs in on the same device | That user connects the server | Approval is asked again (records are per user id) | U |
| AC-NFR-SEC-07.1 | Parent process env contains `SECRET_TOKEN=abc` | A stdio server starts | The child env contains only the allow-listed variables for the OS plus the configured `env`; `SECRET_TOKEN` is absent | U, I |
| AC-NFR-SEC-13.1 | Windows, command `npx` | The command is resolved | `npx.cmd` is found through `PATH` + `PATHEXT`; arguments with spaces, `&`, `^` and `"` reach the server unchanged; the approval dialog shows the exact command line | U, M (Windows) |
| AC-NFR-CMP-07.1 | macOS/Linux app launched from the desktop (no shell `PATH`) | The user connects a `node`/`npx` server | `PATH` is taken from the login shell; the approval dialog shows the resolved absolute path | M (macOS, Linux) |
| AC-NFR-REL-06.1 | A connected stdio server | The user disconnects | stdin is closed; after the grace period (default 2 s) SIGTERM, then SIGKILL after another 2 s; the session ends within 5 s | U, I |
| AC-NFR-REL-06.2 | `fx-hang` that spawns a child and ignores signals | The user disconnects or closes the app | The process and its child are gone within 5 s (Windows: whole tree killed) | I, M (Windows) |
| AC-NFR-REL-06.3 | `fx-crash` exits with code 3 | The exit happens | The server shows **Disconnected** with `process_exited`, exit code 3 and the last stderr lines; pending calls fail with the same failure | I |
| AC-NFR-CMP-06.1 | ~~Sandboxed macOS build~~ **N/A (Q16):** macOS ships notarized without the App Sandbox, so stdio is available. Criterion retained only if a sandboxed App Store build is added later. | — | — | — |

## 9. Failure model and harness (FR-TST-01/02/05/06, §6.6)

| ID | Given | When | Then | Lvl |
|---|---|---|---|---|
| AC-TST-01.1 | A Dart test with no widgets | It calls the protocol service: connect → `tools/call add` → disconnect | It gets a typed result with `5` and no UI is needed | I |
| AC-TST-02.1 | Each method in FR-TST-02 that `fx-basic` supports (`initialize` / `server/discover`, `tools/list`, `tools/call`, `resources/list`, `resources/read`, `resources/templates/list`, `prompts/list`, `prompts/get`, `logging/setLevel` on legacy) | The harness runs it | It returns a `Result.success` with the parsed model | I |
| AC-TST-05.1 | Any harness result | It is serialized | `toJson()` round-trips to the same model (stable assertions) | U |
| AC-TST-06.1 | Each failure fixture: unreachable URL, missing command, `isError`, unknown tool, invalid params, `-32022`, HTTP 429, server crash | The harness runs it | It returns `Result.failure` with the `McpFailure.code` from spec §6.6 (`unreachable`, `unreachable`, `tool_error`, `tool_not_found`, `invalid_params`, `protocol_version_unsupported`, `rate_limited` with `retryAfter`, `process_exited`) and the matching core `Failure` kind | U, I |
| AC-TST-06.2 | Any infrastructure exception (`SocketException`, `ProcessException`, `FormatException`, `PostgrestException`) | It is thrown inside a repository | It is mapped to a `Failure`; no raw exception reaches a provider or the UI | U |

---

## S1 exit check

S1 is complete when all of the following are true:

1. Every criterion above passes at its level; **M** checks are recorded in the PR for Windows, macOS and Linux.
2. **NFR-USE-01 walkthrough** (manual, each OS): on a fresh guest account with an empty catalog, a user adds `fx-basic` as a stdio server, approves it, calls `add`, then adds the same fixture over HTTP and calls `add` again, in under 3 minutes without docs.
3. `flutter analyze` is clean and `flutter test` passes (integration tests run separately with the fixtures and local Supabase).
4. `docs/DATA_MODEL.md` documents `mcp_servers`, and the migration applies with `supabase db reset`.
5. `mcp_dart` is in the Core Stack table in `agents.md` with its reason, and the transport wrapper records every raw frame (R-14 closed or a fallback transport chosen).

## Out of S1 (checked in later slices)

OAuth and stored-auth-only mode (S2); subscriptions, `listChanged`, progress UI, elicitation,
sampling, roots, MRTR, tasks, logs (S3); `{{variables}}`, tabs/status-bar integration beyond
the era label, saved calls, history and config import/export (S4). S1 handles `input_required`
and `task` results only as the notice in AC-PRO-01.2.

## Open points this document depends on

| Point | Status |
|---|---|
| Q14 fixture runtime | **Resolved:** Dart fixtures on `mcp_dart` (fixture table stands). |
| Q16 macOS distribution | **Resolved:** notarized unsandboxed build; AC-NFR-CMP-06.1 is N/A for v1. |
| Q6 default timeout | **Resolved:** Settings request timeout is the per-call default (overridable per server). |
| Q15 failure codes | **Resolved:** module-local `McpFailure.code` (AC-TST-06.* stands). |

## Confirmed assumptions (A1–A5)

| # | Assumption | Status | Where |
|---|---|---|---|
| A1 | Tool form falls back to raw JSON when the schema nests more than **32** levels or takes over **100 ms** to build | **Confirmed** | AC-TOL-02.6 |
| A2 | stdio shutdown: close stdin → wait **2 s** → SIGTERM → wait **2 s** → SIGKILL; whole sequence within **5 s** | **Confirmed** | AC-NFR-REL-06.1/2 |
| A3 | A new user makes a first tool call in **under 3 minutes** (NFR-USE-01 walkthrough) | **Confirmed** | S1 exit check |
| A4 | Changing an env **value** does not require approval again; a change to command, args, cwd or env **keys** does | **Confirmed** | AC-SEC-04.2/3 |
| A5 | Server secrets are stored under the secure-storage key `mcp-server-secrets:<server id>` | **Confirmed** | AC-CFG-01.3 |
