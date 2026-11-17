# MCP Lab implementation progress

This tracks the complete feature, not just the latest change. Implementation follows
[the plan](implementation-plan.md); the specification and acceptance criteria remain authoritative.

## Phase status

| Phase | Status | Remaining work |
|---|---|---|
| Step 0 — transport feasibility | Complete | Production transports still belong to S1 |
| S1 database (§3.1) | Written; database validation blocked | Apply locally, run constraints/RLS checks |
| S1 models (§3.2) | Implemented; unit-tested | Extend as connection implementation requires |
| S1 repositories (§3.3) | Catalog/trust, native stdio and base Streamable HTTP implemented; modern HTTP parameter mirroring implemented | Stdio platform gaps, HTTP legacy resumption/optional GET and deprecated HTTP+SSE, remaining lifecycle guarantees |
| S1 services (§3.4) | Catalog, connect/negotiation, primitives, schema plans and diagnostic buffers implemented | Rich result rendering, output-schema diagnostics, remaining protocol gates |
| S1 providers (§3.5) | Session ownership, DI/settings, lifecycle, catalog/selection, draft/result state and monitor actions implemented | Preferences, native window-close validation, automatic access-revocation discovery |
| S1 UI (§3.6) | Server management, Tools/schema forms, initial Prompts/messages, Resources reads/Save/raster previews, scalar templates and initial Protocol/Network/Console monitors implemented | Composite template inputs/completion, other rich content, monitor pin/export/body distinctions, native save-dialog/full desktop review |
| S1 integration and exit (§3.7) | Seven stdio + six HTTP scenario groups pass on Windows; partial fixture matrix | Remaining protocol/fixture matrix, descendant cleanup, macOS/Linux/manual checks, S1 acceptance exit |
| S2 — remote auth | Blocked on Q13 | CIMD hosting URL, acceptance criteria, OAuth, callback, tokens, UI |
| S3 — interactions | Not started | Acceptance criteria, subscriptions, progress, pending requests, MRTR, tasks, logs |
| S4 — Test Point integration | Not started | Acceptance criteria, variables, tabs/status, saved calls, import/export |

Server management, Tools, Prompts, Resources and diagnostic monitors are accessible through the MCP Lab navigation item. No completion percentage is assigned:
the remaining live-session and UI work is substantially larger than the completed scaffolding.

## Implemented

- Dependencies: `mcp_dart 2.4.4`, direct `crypto 3.0.8`.
- Four standalone transport probes: SDK stdio and HTTP, raw stdio, Dio raw HTTP/SSE. Local transport boundaries selected for faithful diagnostics and manual control.
- `mcp_servers` migration, workspace RLS policy, constraints/index/trigger, data-model documentation and opt-in schema tests. No local or remote migration applied.
- Immutable catalog/settings, protocol/content/result, resource/prompt, diagnostic and connection-state models; MCP camelCase codecs; coded failures retaining core kinds.
- Catalog repository CRUD, workspace filters, stable ordering, explicit row mapping and secret placeholders.
- Launch trust: immutable resolved snapshots, per-field HMACs, per-user secure keys, digest-only preferences, authorization rechecks and changed-field reporting.
- Live-session contracts: resolved connection target, explicit protocol configuration after negotiation, caller-controlled requests, notifications, sanitized diagnostic streams and awaitable close. Native stdio and base Streamable HTTP implement the contract; connect-service/app/provider wiring is still pending.
- Production transport helpers: session-owned diagnostic sanitizer, safe JSON-RPC/HTTP/process error mapping, and proxy selection with Settings/environment precedence, loopback bypass and domain/port/CIDR NO_PROXY handling. Shared frame/startup diagnostics now serve both transports. HTTP consumes an explicitly resolved proxy and still enforces loopback bypass; app settings/environment wiring awaits the connect service/providers.
- Native stdio: PATH/PATHEXT resolution, inherited-environment allow-list, immutable launch snapshots, raw newline frame parsing, bounded line sizes, correlated IDs, timeout/close cancellation, no automatic retry/MRTR, unsupported client-method errors, modern metadata and explicit legacy initialized gating. Sanitized startup diagnostics wait in bounded buffers for the first listener, with overflow notices. Native Windows argv/env and SDK interoperability are verified.
- Base Streamable HTTP: JSON and bounded streaming SSE parsing (UTF-8 fragmentation, BOM, multiline data and CR/LF/CRLF), session/version headers, initialized notification, modern method/name routing and metadata, per-request cancellation/deadlines, auth/rate-limit mapping, unsupported server-request replies, 404 invalidation without replay, and bounded DELETE cleanup (405 accepted, failures visible). Dedicated Dio clients remove raw interceptors; protocol/network diagnostic copies are sanitized before buffering/truncation, including known credentials in encoded header sentinels.
- Modern SEP-2243 parameter mirroring: cache the latest modern `tools/list` input schemas, mirror `x-mcp-header` parameters at arbitrary nested object depth, and base64-sentinel encode unsafe values. Invalid or duplicate annotations exclude only that tool from the returned listing; unsupported values are never mirrored. Legacy and stdio requests do not use these headers.
- Catalog service and validator: target inference, names/URLs/timeouts, canonical headers, duplicate rejection, credential-header defaults and explicit plaintext overrides, qualified secret keys, device storage/hydration, missing-device states, account checks and failure handling. Unit verification passes. A failed new-server secret write rolls back the catalog row; failed remote deletion restores existing local values. Partial persistence failures are surfaced explicitly.

## Validation and blockers

- Four transport feasibility probes passed.
- All **176** model, repository, trust, validator, catalog-service, transport-foundation, launcher and HTTP/parser unit tests pass.
- `dart test/integration/mcp_lab/stdio_session_checks.dart` passes **seven real-process scenario groups** on Windows: legacy/native argv/env/diagnostics/timeouts, modern intermediate results, crashes, bounded stubborn-process shutdown, late diagnostic listeners, SDK interoperability/status replay, and stale-account checks. This is separate from mocked unit verification.
- `dart test/integration/mcp_lab/http_session_checks.dart` passes **five loopback scenario groups**: legacy JSON/SSE and diagnostics/DELETE, modern routing and explicit retry without replay, 404 cancellation of concurrent calls, bounded hanging DELETE, and stale-account rejection. The stdio scenarios were rerun after sharing diagnostic code and still pass.
- Static analysis of the MCP module and tests is clean. The empty URL user-info marker case (`https://@host`) is rejected against the original URL before URI normalization can hide it.
- Redaction tests cover nested values, credential headers, bearer/cookie echoes, query names/values, mixed-case percent encoding, malformed JSON/stderr, wire-format preservation and disposal. This does not certify unwritten transport/cache/UI paths.
- Unit tests use a temporary `.dart_tool/mcp_unit_runner.dart` invoking Flutter's test command without native-plugin builds or asset bundling. This validates model/REST/mocked-storage behavior, not native plugins.
- The normal Flutter test command stalls in the existing `cnativeapi` hook.
- Docker Desktop Linux daemon is unavailable, so real Supabase migration/RLS verification remains pending.
- Stdio remains partial: Windows `.cmd`/`.bat` launch is explicitly rejected until quoting is implemented/tested; macOS process-group launch is not implemented (POSIX currently requires `/usr/bin/setsid`); Windows descendant cleanup after an early parent exit still needs work. Linux group/GUI-PATH behavior and platform shutdown guarantees remain unverified. No shell fallback weakens these gates.
- HTTP remains partial: legacy stream resumption/optional GET and deprecated HTTP+SSE transport remain pending. Redirects are not followed; TLS proxy endpoints are explicitly rejected (an HTTP proxy can still tunnel an HTTPS MCP target). OAuth remains S2. No automatic call replay or modern Last-Event-ID resumption is introduced.
- Q13's CIMD hosting URL is needed for S2, not for continuing S1.

## Design reference

Use Stitch project **3561297165959721299**, screens **#14–#22** and light variant **15L**.
Follow [the design handoff](../../design/stitch-mvp-progress.md): retain existing teal themes and bundled fonts, fix documented clipping/double-plus nits, keep labels on one line and keyboard hints as `Ctrl`. The initial server-management screen is implemented; primitive and monitor views are pending.

## Next implementation order

1. Close stdio platform/lifecycle and HTTP legacy resumption/deprecated-SSE gaps, then add transport dispatch for the connect service.
2. Add connect/negotiation and primitive services, schema forms and transcript buffering.
3. Wire Riverpod state and awaited account/workspace/app-exit shutdown.
4. Build and review Stitch-based UI, then complete integration/platform checks and the S1 exit criteria.
5. Proceed through S2–S4 prerequisites and acceptance criteria; S4 remains independently possible after S1.

## Protocol negotiation follow-up

Added a transport-independent `McpNegotiationService` for an already authorized
session. Legacy remains the default and sends initialize, validates the selected
version and handshake shape, configures the session, then awaits initialized.
Modern discovery validates the supported version before configuring the session;
explicit auto mode falls back to legacy when discovery fails or has no compatible
version. No unimplemented client interaction capabilities are advertised.
Handshake failures await close; cleanup failures remain visible. Discovery data
is an operation result for connection info, not a diagnostic cache.

Nine unit tests cover lifecycle ordering, modern discovery, auto fallback,
unsupported versions, malformed responses, configuration/notification failures,
authentication and failed cleanup. All 72 MCP unit tests pass through the existing
unit-only harness (native-plugin limitations above still apply). The five real
HTTP scenario groups now negotiate through this service and pass. Static analysis
of `lib` and `test` is clean. Launch approval/target orchestration, transport gaps,
providers and UI remain pending; this does not complete S1.

## Resolved-target connect and transport dispatch follow-up

Added `McpConnectService`, composing connection/trust contracts and negotiation.
It accepts a hydrated, fully resolved target; executable, proxy and timeout
resolution are still caller responsibilities. Untrusted stdio returns a memory-only
approval ticket bound to this service and the exact immutable launch snapshot.
Approval tickets are single-use; remembered exact trust can connect directly.
Missing device secrets fail before trust/transport access. Storage failure still
requires explicit approval, permits a one-time launch and remains visible; failed
remember persistence is carried by the connected outcome. Non-storage trust
failures do not authorize launch.

Account/workspace/server-generation checks run before and after asynchronous
trust, storage, transport and negotiation steps. Stale sessions are closed before
returning failure; cleanup errors remain visible. HTTP does not use process trust.
`McpTransportRepository` dispatches only to the selected stdio or Streamable HTTP
implementation; deprecated SSE fails explicitly without fallback.

Twelve new tests cover these boundaries. The full 82-test MCP suite passed before
the final two lifecycle cases were added; all 12 connect/dispatch tests then passed.
There are now 84 verified MCP unit cases across those runs, using the existing
unit-only harness. Analysis of `lib` and `test` reports no issues. No new package,
database, provider or UI change was made. App-level cleanup, target resolution,
transport/platform gaps and the remaining S1 services/UI still need implementation.

## Saved-target resolution follow-up

Added single-server catalog get with workspace ownership checks before local
secret hydration, plus `McpTargetService` and the `McpTargetRepository` contract
and native implementation. Resolution reloads the saved server, preserves already
confirmed plaintext header overrides, validates target consistency, rejects missing
device secrets, applies server timeout overrides over captured app settings, and
resolves either an immutable executable/cwd/argv/environment snapshot or the
HTTP proxy with Settings/environment precedence and NO_PROXY/loopback bypass.
Resolution never launches a process or opens a network connection. Account changes
after catalog reads or filesystem awaits discard the resolved result.

`McpTargetSettings` is a Flutter-independent captured settings value; future
providers must map `networkSettingsProvider` into it. The catalog-dependent target
service stays internal; the public transport contracts and models remain usable
by standalone Dart transport checks. No provider or app wiring is complete yet.

Nine new cases cover catalog ownership/hydration, resolution settings, proxy
precedence/bypass, invalid settings/URLs, frozen native launch data, secret
preflight and stale accounts. All 93 MCP unit tests pass through the existing
unit-only harness. All five standalone HTTP scenario groups now resolve targets
through the native target repository and pass. Analysis of `lib` and `test` is
clean. Native-plugin and platform limitations documented above still apply.

Next: Riverpod session ownership and awaited account/workspace/app shutdown,
then remaining primitive services, monitors and UI. Existing transport gaps and
Supabase validation remain open; S1 is not complete.

## Session ownership and Riverpod lifecycle follow-up

Added `McpSessionOwner` and Riverpod service wiring, session snapshots and UI action
entry points for resolve/connect/approve. The owner holds live sessions and pending
approval tickets, prevents duplicate connects, enforces a default limit of eight
and exposes awaitable disconnect/shutdown. Account/workspace changes invalidate
the captured generation synchronously, clear owned tickets/results and wait for
existing sessions and in-flight connects to finish before enabling the new scope.
Late connected results are closed rather than published; bounded cleanup failure
history remains observable. This owns connection outcomes only; future drafts,
monitor buffers and primitive results still need lifecycle integration.

App eagerly observes `mcpLifecycleProvider`, which reacts to auth/workspace IDs,
loading and errors. DI composes catalog/target/trust/transports/negotiation and maps
current app network settings into captured target settings. The client version is
injectable with a current default of 1.0.0. Server deletion/membership revocation
without a provider refresh is not yet observed. Desktop window-close interception
is still pending; asynchronous provider disposal is only a fallback and does not
satisfy the app-exit acceptance criterion.

Standalone fixture checks now import the Flutter-independent protocol exports;
application modules continue importing only `mcp_lab.dart`. Seven new ownership/
provider cases pass; all 100 MCP unit tests passed using the existing unit-only
harness, and the ownership cases passed again after the final session-limit fix.
Analysis of `lib` and `test` is clean. All five HTTP scenario groups pass. Stdio
shutdown failed under sandbox process restrictions; all seven real-process groups
passed when rerun with permission for Windows process-tree termination.

Next: desktop window-close shutdown, catalog/selection and diagnostic provider
state, remaining primitive services and UI. Supabase validation and transport/
platform gates remain open; this is not S1 completion.

## Desktop exit follow-up

Added a desktop close coordinator and native close-request handler installed by
main before the app opens sessions. The handler uses the installed window_manager
0.6 native API rather than the older WindowListener API in the original plan.
It cancels the initial native request, shares repeated close requests, awaits MCP
cleanup with a five-second overall deadline, reports sanitized failures through
Flutter error reporting, removes the interceptor and requests the final native
close. A rejected native close restores the handler and permits another attempt.
Main now owns the root ProviderContainer so the native handler and app share the
same session owner.

`shutdownForExit` is a terminal, idempotent boundary: subsequent auth/workspace
updates cannot re-enable MCP access. The connect service reports opened sessions
to the owner before negotiation, so shutdown can close a transport with a pending
handshake rather than waiting for its normal request timeout. Cleanup failure
counting remains correct when the bounded failure history is full.

All 109 selected unit tests pass (103 MCP and six desktop coordinator cases).
The nine new cases cover exit permanence/idempotence, cleanup failures, pending
negotiation cancellation, duplicate requests, ordering, the deadline, late
completion, rejected native close/retry and sanitized exceptions. Analysis of lib
and test is clean. Tests use the existing unit-only harness and do not load window
FFI or validate native title-bar events. Native Windows/macOS/Linux close checks,
process-tree/platform guarantees and the existing native-hook blocker remain open;
do not treat the desktop acceptance criteria as fully validated yet. The deadline
is a bounded best-effort cleanup wait, not proof every descendant process exits.

Next: catalog/selection state, primitive services and diagnostic buffers/providers,
then the MCP Lab UI. Database and transport gaps remain documented above.

## Catalog and selection provider follow-up

Added Riverpod catalog loading, explicit refresh, create/save/delete actions and
workspace-scoped selection. Updates and deletion await session/approval cleanup
before changing the catalog; cleanup failure prevents the write. Mutations reload
after errors as well as successes because a device-secret failure may follow a
successful remote write. Selection rejects unknown IDs, survives loading and
clears when the selected server disappears or the scope changes.

Catalog state explicitly replaces loading/error snapshots instead of preserving
previous hydrated rows. Generation and request revisions prevent late responses
from publishing old data or reconciling obsolete availability. Successful refresh
is authoritative for missing servers: the session owner revokes their access
synchronously, drops approval tickets, closes owned/opening sessions and awaits
pending connects. A later successful catalog result can restore availability.
Failed refresh exposes its failure without inferring revocation for every session.
This reconciliation occurs on catalog load/refresh; automatic polling/realtime
membership and server-access revocation discovery remains pending.

All 118 selected tests pass (112 MCP plus six desktop shutdown cases), including
eight new catalog/selection cases and one pending-negotiation revocation case.
Analysis of lib and test is clean. Tests cover selection, deletion ordering,
cleanup failure, partial writes, stale account responses, out-of-order refreshes,
error-state data removal and revocation/restoration during negotiation. No database,
UI, preferences or transport change was introduced in this follow-up.

Next: diagnostic buffers and providers, remaining tools/resources/prompts services
and schema forms, then UI. Native exit/platform and Supabase validation gates
remain open; S1 is not complete.

## Diagnostic retention and provider follow-up

Added protocol/network/console diagnostic buffers with a default 10,000-entry
limit per channel, a 64 MiB retained-body budget per channel, oldest-entry eviction
and drop counters. Preview text ends on a UTF-8 boundary at 256 KiB. Sanitized full
text stays in memory only and is removed with its entry; Copy uses that same
sanitized representation. Explicit Load full JSON parsing runs in a Dart isolate
and rejects results after clear, eviction or disposal. The body budget measures
retained body text, not all headers/metadata or VM allocation overhead.

Protocol pairing uses direction and typed JSON-RPC IDs, records elapsed duration,
leaves notifications unpaired, and releases pairing links when peers are evicted.
Per-session diagnostic subscriptions attach at transport opening, before the
handshake. Provider snapshots coalesce notifications to approximately one per
16 ms. Error events expose a count without retaining exception text. Clear and
session disposal release all channel bodies; scope changes, disconnect and
catalog revocation clear monitors and await subscription cancellation. Failed
handshake diagnostics remain available within the current scope for inspection.

All 126 selected tests pass (120 MCP plus six desktop shutdown tests). Eight new
cases cover pairing, the 10,000-entry ring, body budgets, eviction, UTF-8 previews,
canary redaction through Copy/Load full, off-isolate parsing, clear/dispose,
partial transport bodies and opening/provider/account cleanup. Analysis of lib
and test is clean. Existing unit-only harness/native-plugin limitations remain.

Large Network Load full is still incomplete: the existing HTTP transport retains
only a 256 KiB body prefix. The new buffer labels such input partial and explicitly
rejects full JSON loading, even if that prefix happens to be valid JSON. Protocol
frames retain full sanitized text within the new budget. Extending HTTP capture
and building/reviewing monitor UI remain required for AC-MON-01.5; no complete
monitor or performance acceptance claim is made. No diagnostic files are written.

Next: remaining tools/resources/prompts services, schema forms, complete large
HTTP diagnostic-body capture and UI. Existing database/platform/transport exit
gates remain open; S1 is not complete.

## Tools, resources and prompts follow-up

Added `McpPrimitiveServices` with tool/resource/prompt services and a session-bound
Riverpod provider. Each operation checks declared capabilities and current owner
access before sending and after awaiting the result. Retained provider handles
cannot act after disconnect, revocation or an account change. Services do not
cache results or trigger requests automatically.

Tools aggregate pages in server order, with repeated-cursor detection and limits
of 1,000 pages/10,000 items. Calls freeze JSON arguments before transport access;
raw JSON rejects malformed or non-object input before sending. `isError` stays a
successful tool result with `tool_error`. S1 intermediate `input_required`/`task`
results preserve the raw operation payload, return the specified notice and never
drive another round. Malformed/unknown content is converted to a generic failure
without echoing server data. Raw operation results remain separate from diagnostics.

Resources/templates expose explicit cursor pages and resource reads preserve text
and base64 blobs without automatic binary decoding. Prompt lists aggregate pages;
get validates required string arguments and preserves ordered messages/description.
Existing transport failures, including resource-not-found mapping, pass through.
Full schema validation/coercion and form construction remain the next step.

Modern HTTP parameter-header mappings now survive cursor continuation pages;
a new first page clears the previous mapping set. Existing HTTP tests verify both
continuation preservation and first-page reset, including invalid-tool filtering.

All 140 selected tests passed (134 MCP plus six desktop shutdown cases). Fourteen
new primitive/provider cases passed; after the final unknown-content decoding and
HTTP pagination assertions, all 28 affected service/HTTP unit cases passed again.
The five existing real HTTP transport scenario groups pass. A new standalone
`primitive_service_checks.dart` runs real HTTP negotiation and primitives in both
legacy and modern modes, checking paged tools, calls/tool errors, resources,
templates and prompts; both groups pass. Analysis of lib and test is clean.
The existing unit-only harness and native/platform limitations still apply.

Next: schema forms/argument validation, remaining large HTTP diagnostic capture,
result/draft providers and UI. Database, platform and transport exit gates remain
open; S1 is not complete.

## Schema form plans and argument validation follow-up

Added the pure `SchemaFormBuilder`, immutable form plans and field-level argument
failures. Plans cover object properties/required fields, arrays, primitive types,
enums/default annotations, local $ref/$defs and escaped JSON pointer tokens,
oneOf/anyOf picker branches and boolean additionalProperties. External references
are never fetched. Unsupported assertion keywords/types, recursive or missing
references, nested schema identifiers and unsupported combinations explicitly
return RawJsonOnly with a reason instead of silently dropping constraints.

Build and validation traversal check depth 32, 10,000 processing steps and a 100 ms
Stopwatch budget. The synchronous schema-aware JSON argument parser refuses inputs
over 256 KiB and directs them to raw mode; this is separate from transport limits.
These are processing guards, not a desktop rendering/performance certification.
Default annotations are retained for future form prefilling; validation does not
silently insert defaults into explicit caller arguments.

Argument processing accepts JSON objects or JSON text, optionally coerces form
strings through JSON then the field type, validates nested arrays/objects/enums,
reports required/type/unknown-property errors by field path and strips explicit
variant-picker wrappers before sending. oneOf exclusivity remains enforced after
picker selection. Field errors do not include argument values. Form required blank
strings are rejected while strict JSON required uses property presence semantics.

`McpToolService.callWithSchema` validates/coerces before transport access. Unsupported
form schemas return schema_unportable and require explicit use of the existing raw
JSON call path; raw mode remains available. No general-purpose JSON Schema package
or network dependency was added, and no Flutter form widget has been implemented.

The full 155 selected cases passed (149 MCP plus six desktop shutdown cases).
Thirteen schema cases and two schema-aware tool-call cases were added. After final
variant/root handling changes, all 29 affected schema/primitive cases passed again.
Analysis of lib and test is clean. The cases cover local references, unsupported
fallbacks, 200-level/wide schemas, coercion, nested/enum errors, oneOf/anyOf,
immutability/default metadata and pre-send validation/raw fallback. Existing
unit-only harness/native and database limitations remain unchanged.

Next: result/draft state, complete large HTTP diagnostic capture, then the Flutter
form and remaining MCP Lab UI. Form default prefilling, Form/JSON round trips,
widget accessibility and desktop responsiveness still need UI implementation and
validation. S1 is not complete.

## Session-scoped drafts and results follow-up

Added separate tool-call, resource-read and prompt-get controllers/providers.
Each holds the current draft, immutable submitted-input snapshot, running state,
last Result and elapsed duration. Editing a draft during a call does not relabel
the submitted input. A newer explicit invocation or Clear result invalidates old
completions without replaying, retrying or claiming transport cancellation. Tool
errors remain successful protocol results, and unexpected callback exceptions
become generic application failures without exception text.

`McpSessionOwner` lazily owns this work state for each active connection, so it
survives provider/widget rebuilds within the same session. Disconnect, catalog
revocation, account/workspace change and app shutdown synchronously release owned
draft/result references. Reconnect creates fresh state. Retained handles reject
new operations and late completion payloads after revocation. Disposal publishes
an empty final snapshot before closing its stream, preventing Riverpod from
retaining a previous draft/result as the replacement stream loads. Paused UI
listeners do not block owner cleanup.

Work actions connect raw/schema-aware tool calls, resource reads and prompt gets
to the existing services. Prompt argument maps are copied into immutable drafts;
tool drafts currently hold the selected tool, JSON argument text and schema/raw
choice. No result, draft or payload file is automatically persisted. Flutter form
values/default prefilling and Form/JSON round-trip UI still require implementation.

All 165 selected tests pass (159 MCP plus six desktop shutdown cases), including
ten new controller/provider cases. Tests cover submitted/current input separation,
last-invocation wins, Clear result races, revoked access, sanitized exceptions,
paused listeners, immutable prompt arguments, all three primitive action types,
provider rebuilds, disconnect/reconnect and account-boundary snapshot cleanup.
Analysis of lib and test is clean. Existing unit-only/native-plugin limitations
remain; no new transport, database or UI changes were made in this follow-up.

Next: complete large HTTP diagnostic body capture, then MCP Lab UI/form widgets.
Database, native window/platform and remaining transport exit gates stay open;
S1 is not complete.

## Large HTTP diagnostic capture follow-up

Replaced the 256 KiB transport diagnostic prefix with a dedicated bounded
`McpHttpDiagnosticBody` retaining up to 16 MiB of sanitized response data frames.
The monitor still shows UTF-8-safe 256 KiB previews and retains full text within
its existing body budget. Capture uses byte chunks, stops at a valid UTF-8 prefix
when its budget is exceeded, marks that input partial and never appends later
frames after truncation. Request-local capture bytes are released after the
Network entry is emitted. The existing protocol frame/request limits are unchanged.

Sanitization still occurs at the shared frame boundary before body retention;
operation results remain separate and unchanged. Network Copy reads the sanitized
retained body. Load full JSON parses application/json responses off the UI isolate;
for text/event-stream it parses the captured JSON data frames into a list, handling
pretty-printed JSON and escaped strings. This is a diagnostic data-frame capture,
not preservation of original SSE comment/id/envelope bytes. Malformed/incomplete
captures fail explicitly; over-budget partial bodies cannot masquerade as full.
No diagnostic payload is written to disk.

All 173 selected tests pass (167 MCP plus six desktop shutdown cases), including
six new body/capture-decoding cases and two large-response transport/monitor cases.
The real loopback HTTP harness now passes six scenario groups; the new group checks
large JSON and SSE responses, sanitized tails beyond the preview boundary,
unchanged raw operation results, full-body availability, off-isolate loading and
clear. Analysis of lib and test is clean. Existing unit-only/native limitations
still apply; these checks do not certify desktop rendering responsiveness.

The old 256 KiB Network limitation documented in earlier entries is superseded
for captures within the 16 MiB body budget. Larger data remains explicitly partial.
The existing 10 MiB individual protocol-frame limit, 20 MiB binary-result acceptance
and platform/transport gaps remain separate open gates; no S1 exit claim is made.

Next: MCP Lab UI, including routes/sidebar, server editing/approval, primitive
forms/results and monitors. Use the documented Stitch references and relevant UI
skills. Native/window/platform, Supabase and remaining protocol gates remain open.

## Initial MCP Lab UI follow-up

Added /mcp-lab and a hub entry between Environments and Settings. The module owns
its resizable sidebar, filter with Ctrl+K, server selection/count, refresh/retry and
add action. Selected servers show masked settings summaries, current connection
status/era, edit/delete and explicit connect/disconnect controls. Auth-required
status is labelled Auth needed; status colour also has a text/icon equivalent.
No fake primitive/monitor controls or automatic connection triggers were added.

The add/edit dialog supports stdio, HTTP and stored deprecated SSE configurations,
argv as a JSON string array, working directory, protocol era, timeout override,
key/value environment variables and headers. Secrets are obscured; new credentials
use device-only storage. Existing explicit plaintext header choices are preserved.
Saving does not connect. Unsupported SSE connection controls are disabled, with
availability explained in the editor. Expected failures remain application-level
messages. Editing/saving/deletion use the catalog provider rather than repositories.

Stdio approval displays the exact resolved executable/cwd/argv snapshot and only
environment key names, masking known secret values (including escaped arguments).
Approval defaults to once; remembered approval is optional and unavailable storage
still permits explicit one-time approval. Cancel discards the ticket. Account or
workspace changes close open edit/approval dialogs and prevent stale launches.
Summary views also mask credential URL query values. No secret reveal control or
raw diagnostic bypass was introduced.

Applied frontend-design and ui-ux-pro-max, inspected Stitch screen 14, and retained
the app's existing teal ColorScheme, bundled fonts, mono fields and spacing style.
Nine widget cases cover filtering/Ctrl+K, required-field/create behavior, masked
editor/account cleanup, explicit launch approval, deletion cancellation, app-rail
navigation, URL query masking and minimum-width dark/light layout. Both rendered
screenshots were reviewed with bundled fonts and Material icons; local artifacts
are .dart_tool/mcp_ui_dark.png and mcp_ui_light.png. These are test renders, not
native-window or complete screenshot acceptance.

All 182 selected tests pass (176 MCP and six desktop shutdown tests). Analysis of
lib and test is clean. The unit-only harness uses InkRipple for widget checks
because its disabled asset bundling cannot load InkSparkle shaders; the production
theme is unchanged. Native desktop/keychain execution and the regular Flutter
native-hook pipeline remain unvalidated here. Real Supabase schema/RLS validation
also remains pending, so catalog persistence still depends on applying the migration.

Next: tools/schema forms and results, resources/prompts, and monitor UI. Global
server tabs/status, import/export and later interactions/auth remain in their
planned slices. S1 is not complete.

## Tools and Prompts UI follow-up

Connected servers now expose capability-gated Settings, Tools and Prompts views.
Prompt-only servers work without a tools capability. Lists load when their view
opens; refreshing or selecting never invokes a tool or gets a prompt automatically.
Service list validation rejects duplicate tool names, prompt names and prompt
argument names as application failures before they can break the selectors.

Tools support default-prefilled schema forms with required/optional properties,
nested objects, arrays, enums, booleans and variant selection. Form/JSON round trips
use the existing bounded validation/coercion service. Unsupported schemas explain
why raw JSON is required; invalid raw drafts survive view changes. Explicit calls
and Ctrl+Enter validate before sending. Destructive hints require confirmation;
changed arguments invalidate an open confirmation. Read-only/idempotent hints,
duration, success/tool-error outcomes, clear and copy controls are visible.
Per-server destructive-confirmation preferences remain pending.

Prompts support required and optional string arguments, explicit Get prompt and
Ctrl+Enter, application failures, duration, clear and ordered role/content messages.
Empty optional arguments are omitted. Selecting another prompt starts a fresh
draft; refreshing its definition retains matching arguments. Removed definitions
clear the selection. Drafts/results remain session-owned across view changes and
clear at scope boundaries. Provider startup distinguishes unavailable services
from an actual empty server list, preserving drafts when views reopen.

Both views show complete operation-result JSON through a read-only code viewer.
Formatting runs off the UI isolate with a 256 KiB preview and explicit Load full;
Copy result JSON copies the full formatted result. Text message previews are
bounded. Non-text prompt content is identified and retained in JSON; media
playback/image previews, binary save and resource-link navigation remain pending.
No operation result is automatically persisted or added to diagnostic buffers.
Tool output-schema presentation/validation and prompt completion are still pending.

Applied frontend-design and ui-ux-pro-max and reviewed Stitch screens 15 and 19.
Retained the existing teal themes, bundled fonts and developer-focused form/code
layout. Reviewed dark/light test renders at .dart_tool/mcp_tools_{dark,light}.png
and .dart_tool/mcp_prompts_{dark,light}.png. Visual checks caught and fixed an
isolate closure capturing editor state; form regression checks also fixed rapid
cross-field edits and controller updates during Form rebuilding.

All 203 selected tests pass (197 MCP and six desktop shutdown cases); analysis of
lib and test is clean. Added coverage includes required validation, typed tool
arguments, Ctrl+Enter, raw fallback, Form/JSON round trips, nested/array/variant
editing, destructive cancellation, tool errors, draft restoration, ordered prompt
messages, failures, refreshed selections, duplicate names, account cleanup and
capability-gated navigation. These remain unit/widget checks through the existing
native-hook bypass harness; native windows/keychains, regular Flutter test hooks,
real Supabase RLS and full S1 acceptance are not certified by this run.

Next: Resources/templates and read results, followed by protocol/network/console
monitor UI. Rich content, preferences and existing native/protocol/database exit
gates remain open. S1 is not complete.

## Initial Resources UI follow-up

Added a capability-gated Resources view, including resource-only servers. Opening
the view loads the first resources/templates pages independently. Their toggle
shows loaded counts, name/title, URI/template, description and MIME type. Lists
use bounded scroll areas and lazy rows. Load next page appends only on request
and disappears after the last page. Refresh starts the active list again. Page
failures retain existing rows and the cursor for explicit retry; repeated cursors,
1,000-page/10,000-item limits and stale session responses are guarded in providers.

Selecting a row fills the editable resource URI. Read resource and Ctrl+Enter
invoke the existing session-owned read action; selecting, typing and paging do
not read automatically. URI drafts survive reopening the view, clear alongside
results on account/workspace boundaries, and remain separate from submitted
URIs. A selected template is shown verbatim for manual replacement with a resolved
URI; unresolved braces and invalid absolute URIs fail validation without a request.
Automatic template expansion and completion remain pending.

Read results show submitted URI, duration, application failures and clear. Each
content part retains its own URI/MIME metadata. Text is shown read-only; JSON MIME
types (including +json) are pretty-printed off the UI isolate. Malformed JSON falls
back to the original text with a notice. Content previews stop at 256 KiB with an
explicit Load full content action; Copy resource text preserves the original
source. The existing full result JSON viewer retains the complete parsed response.
Binary base64 decoding runs off-isolate for decoded byte size; malformed data is
explicit. Binary Save and inline images remain pending, so AC-RES-02.2 is not met.
No data is automatically persisted and no new dependency was introduced.

Applied frontend-design and ui-ux-pro-max, inspected Stitch screen 17 and reviewed
dark/light renders (.dart_tool/mcp_resources_dark.png and mcp_resources_light.png).
All 220 selected tests pass (214 MCP and six desktop shutdown tests), followed by
the nine affected resource widget tests after a final list-spacing adjustment.
Static analysis is clean. Seventeen added cases cover pagination/retry/cursors,
stale responses, isolated previews, explicit invocation, template validation,
draft restoration, scope cleanup, failures, binary metadata, large text and
resource-only navigation. Existing native-hook harness, native desktop/keychain,
database/RLS and protocol-size/platform limitations remain unchanged.

Next: resource binary Save/inline images and template expansion, then monitor UI.
S1 remains incomplete; this completes the resource browsing/text-read slice only.

## Binary resource Save and image previews follow-up

Binary results now offer an explicit Save resource action using the existing
file_picker dependency. A repository owns native export and converts platform
exceptions into application failures; the service decodes the original bytes
off-isolate and chooses a safe MIME-based suggested filename independent of the
server URI. Native cancellation stays silent, failures permit retry, and saving
disables duplicate clicks. No automatic file write is added.

Export actions capture the owning session work/result and require the selected
content to belong to that exact result. Ownership is rechecked after decoding and
before opening the native dialog, and stale completions cannot produce a current
success. The file_picker 13 API combines destination selection and writing: once
an explicit export is handed to the native dialog it may finish after a view or
account change. This operation cannot be revoked through that API; it is distinct
from automatic persistence. Native-dialog behavior still requires desktop checks.

Supported binary raster MIME types (PNG, JPEG, GIF, WebP and BMP) have inline
previews. Preview bytes are retained only up to 8 MiB and decoded image dimensions
are bounded to fit 1024 by 1024, preserving aspect ratio. Larger or unsupported
image types explain that the original can be saved. Decode errors show a fallback
while preserving Save. Image loading has a visible state and a semantic label.
Disposing/replacing a preview evicts its image-cache entry; the session-owned
original remains separate from this widget-local preview.

Applied frontend-design and ui-ux-pro-max to the existing Resources layout. All
235 selected regression tests pass (229 MCP plus six desktop shutdown cases), and
static analysis is clean. Fifteen new cases cover export bytes/names, cancellation,
failures, ownership checks before/during decoding and after native handoff, image
size bounds, malformed binary/image data, UI exports, scope cleanup and cache
eviction. The image widget checks also run in both themes; screenshot artifacts
are .dart_tool/mcp_resource_image_dark.png and mcp_resource_image_light.png.
These use the existing unit-only hook-bypass harness and mocked native export.
They do not certify real file permissions, native save dialogs, cross-platform
image support or 20 MiB transport acceptance. Full AC-RES-02.2 platform acceptance
and the existing native/database/protocol gates remain open.

Next: automatic URI-template expansion, then monitor UI. S1 is not complete.

## Scalar URI-template expansion follow-up

Selecting a resource template now exposes string-variable controls and a resolved
URI preview. Include checkboxes distinguish undefined variables from explicitly
empty strings. Values update the URI locally without requesting content. Read and
Ctrl+Enter retain explicit invocation; editing the resolved URI switches to manual
input. Invalid/over-budget templates explain the manual fallback and cannot send
unresolved expressions. Template selection/values are session-owned, restore when
the view reopens and clear on scope boundaries alongside the read draft/results.

Added a bounded pure expander for scalar variables using the operators in
[RFC 6570](https://www.rfc-editor.org/rfc/rfc6570.html): simple, reserved, fragment,
label, path, matrix and query/continuation, plus scalar prefix/explode modifiers.
Unicode is UTF-8 encoded, prefixes count code points, and reserved expansions
preserve valid percent triplets. The existing SDK expander walks UTF-16 code units
in its encoder; this service avoids splitting supplementary Unicode characters.
No new dependency or external lookup is introduced. Composite list/map values,
completion requests and environment-variable integration remain pending.

Limits are 16 KiB UTF-8 templates, 128 expressions, 64 distinct variables, 4 KiB
UTF-8 per value and 64 KiB expanded URI. Expansion checks intermediate growth,
including repeated variable references. Invalid syntax and over-budget input
return application failures without partial expansion or network activity.

Applied frontend-design and ui-ux-pro-max and reviewed both theme renders at
.dart_tool/mcp_template_dark.png and mcp_template_light.png. All 248 selected
regression tests pass (242 MCP plus six desktop shutdown cases), followed by the
29 affected template/resource cases after tightening UTF-8 budgets. Analysis is
clean. Thirteen new cases cover scalar operator examples, encoding, Unicode,
omission/empty semantics, malformed/bounded inputs, explicit reads, manual fallback,
draft restoration, cleanup and both themes. Existing unit-only/native, database,
transport-size and platform validation limits still apply; S1 remains incomplete.

Next: protocol/network/console monitor UI. Composite template editors and completion
remain later follow-ups; the completed slice is automatic scalar expansion.

## Protocol, Network and Console monitor UI follow-up

Added Protocol plus the transport-specific Network (HTTP) or Console (stdio) tabs.
They require a retained diagnostic session rather than primitive capabilities, so
servers with no tools/resources/prompts can still be inspected. Capture starts at
transport opening through the existing session monitor, including handshake frames.
Both layouts retain the app themes and use the documented Stitch monitor reference.

Monitors show ordered entries, typed IDs, direction, timestamps where captured,
kind/status, pairing/duration, dropped-entry and stream-error counts. A lazy fixed-
extent list builds visible rows only. Ctrl+F focuses the metadata/console filter;
Protocol also filters direction and frame kind. Filtering searches a bounded title
prefix (1,024 characters), not every payload body. The code viewer's own find control
can inspect the selected preview or explicitly loaded body. Clear affects the
active buffer, and request/response pair controls open the partner frame.

Selected details show the sanitized retained payload read-only, metadata and Copy.
Truncated previews explain their retained size and offer explicit Load full; JSON
and captured SSE-frame lists parse/format off-isolate. Console/warning full loads
retain plain text. Partial transport bodies have a distinct notice, no Load full,
and Copy retained body wording. Copy always reads the retained sanitized body rather
than an operation result or raw transport source. Non-JSON stdout warnings remain
visible with an amber theme colour and do not disconnect the session.

Network details expose status/duration, the retained body and request/response
headers. Mcp-* header names use the theme accent. Sentinels are decoded for display
only after repository sanitization of their decoded representation. A pre-scan
learns credentials from every encoded header before cleaning any, including
earlier echoes of credentials declared by a later header. Values are bounded to
4,096 displayed characters per header. No reveal/raw-copy path is added. Separate
request/response body retention and header-copy/full-value controls remain pending;
outgoing protocol payloads are available in Protocol.

Monitor disposal now emits an empty snapshot before closing without awaiting
paused UI listeners. A current-session identity gate rejects StreamProvider's
previous-session values while streams reattach. Clear/eviction/scope changes reject
late full-body completions and remove selected detail controllers. No diagnostic
export or temporary payload file is introduced.

Applied frontend-design and ui-ux-pro-max; reviewed Stitch screen 16 and both theme
renders (.dart_tool/mcp_monitor_dark.png and mcp_monitor_light.png). All 268 selected
tests pass (262 MCP and six desktop shutdown cases), and analysis is clean. Twenty
new cases cover filters/typed IDs, safe sentinel decoding, full-copy/load behavior,
clear/paused-listener/scope cleanup, pairing, live console, warnings, partial bodies,
10,001-frame eviction/lazy rows, themes and transport-specific navigation. All six
real loopback HTTP scenario groups also pass after the redaction refinement.

This validates the initial monitor slice through the existing unit-only harness;
native scroll/render throughput, complete S1 screenshot acceptance, pinned layouts,
diagnostic export, richer protocol-error presentation and separate Network bodies
remain open. Existing database, native plugin/platform and transport-size gates
still apply. Next: rich tool/prompt content and output-schema diagnostics, followed
by remaining S1 acceptance gaps. S1 is not complete.
