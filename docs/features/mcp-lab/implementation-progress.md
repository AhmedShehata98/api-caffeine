# MCP Lab implementation progress

This tracks the complete feature, not just the latest change. Implementation follows
[the plan](implementation-plan.md); the specification and acceptance criteria remain authoritative.

## Phase status

| Phase | Status | Remaining work |
|---|---|---|
| Step 0 — transport feasibility | Complete | Production transports still belong to S1 |
| S1 database (§3.1) | Fresh isolated migrations/seed replay, 33 organization/RLS assertions and three REST/repository checks pass | Remote deployment not performed; wider account/security acceptance remains |
| S1 models (§3.2) | Implemented; unit-tested | Extend as connection implementation requires |
| S1 repositories (§3.3) | Catalog/trust, native stdio, Streamable HTTP, bounded legacy resumption, optional notification GET, deprecated HTTP+SSE and modern HTTP parameter mirroring implemented | Stdio platform gaps and remaining lifecycle guarantees |
| S1 services (§3.4) | Catalog, connect/negotiation, primitives, schema plans, output diagnostics and diagnostic buffers implemented | Remaining protocol gates and broader schema support |
| S1 providers (§3.5) | Session ownership, DI/settings, lifecycle, catalog/selection, draft/result state and monitor actions implemented | Preferences, native window-close validation, automatic access-revocation discovery |
| S1 UI (§3.6) | Server management, rich Tools/Prompts results, Resources reads/Save/raster previews, text/list/object templates, explicit resource/prompt argument completion and Protocol/Network/Console monitors with separate HTTP bodies implemented | Monitor pin/export, preferences, native save-dialog/full desktop review |
| S1 integration and exit (§3.7) | Seven stdio + twenty HTTP groups and three 20 MiB binary transport/export checks pass on Windows; partial fixture matrix | Native large-result responsiveness, remaining protocol/fixture matrix, descendant cleanup, macOS/Linux/manual checks, S1 acceptance exit |
| S2 — remote auth | Blocked on Q13 | CIMD hosting URL, acceptance criteria, OAuth, callback, tokens, UI |
| S3 — interactions | Not started | Acceptance criteria, subscriptions, progress, pending requests, MRTR, tasks, logs |
| S4 — Test Point integration | Not started | Acceptance criteria, variables, tabs/status, saved calls, import/export |

Server management, Tools, Prompts, Resources and diagnostic monitors are accessible through the MCP Lab navigation item. No completion percentage is assigned:
the remaining live-session and UI work is substantially larger than the completed scaffolding.

## Implemented

- Dependencies: `mcp_dart 2.4.4`, direct `crypto 3.0.8`.
- Four standalone transport probes: SDK stdio and HTTP, raw stdio, Dio raw HTTP/SSE. Local transport boundaries selected for faithful diagnostics and manual control.
- `mcp_servers` migration, workspace RLS policy, constraints/index/trigger, data-model documentation and opt-in schema tests. The local migration is now applied and three real catalog/RLS checks pass; remote deployment has not been performed.
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
- The latest selected app regression run passes **412** tests (406 MCP and six desktop shutdown cases). Four real HTTP completion groups now cover both resource and prompt references in both eras over JSON and SSE. The existing HTTP session/notification groups passed in the preceding resource-completion slice; their fixture and production transport code are unchanged here. The preceding database slice passed 33 transactional pgTAP assertions and three real REST/repository tests against a fresh isolated stack. This completion slice does not change database code. Rich result and output-schema details are recorded in [the rich-content note](rich-content-progress.md).
- `dart test/integration/mcp_lab/stdio_session_checks.dart` passes **seven real-process scenario groups** on Windows: legacy/native argv/env/diagnostics/timeouts, modern intermediate results, crashes, bounded stubborn-process shutdown, late diagnostic listeners, SDK interoperability/status replay, and stale-account checks. This is separate from mocked unit verification.
- `dart test/integration/mcp_lab/http_session_checks.dart` passes **seven loopback scenario groups**: legacy JSON/SSE and diagnostics/DELETE, modern routing and explicit retry without replay, 404 cancellation of concurrent calls, bounded hanging DELETE, stale-account rejection, large sanitized request/response captures over JSON/SSE, and legacy response resumption with concurrent cursor isolation/refusal recovery. The stdio scenarios were rerun after sharing diagnostic code and still pass.
- `dart test/integration/mcp_lab/large_payload_checks.dart` passes three real stdio/HTTP JSON/SSE checks: a 20 MiB embedded binary result, bounded diagnostics, off-isolate preview metadata and decode, and byte-exact file export. Stdio framing overflow is also rejected. The exporter uses a test file destination, not a native dialog; native UI responsiveness remains unverified.
- `dart test/integration/mcp_lab/http_notification_checks.dart` passes **five additional real HTTP groups**: GET 405 with DELETE cleanup outcomes, sanitized live notifications/server-request rejection, bounded idle close, terminal auth/session rejection and modern non-listening behavior.
- `dart test/integration/mcp_lab/deprecated_sse_checks.dart` passes **four real HTTP+SSE groups**: old-protocol negotiation/routing/correlation/lifecycle, rejected unsafe endpoints, endpoint-announcement deadline and a 20 MiB binary result with metadata-only preview.
- Static analysis of the MCP module and tests is clean. The empty URL user-info marker case (`https://@host`) is rejected against the original URL before URI normalization can hide it.
- Redaction tests cover nested values, credential headers, bearer/cookie echoes, query names/values, mixed-case percent encoding, malformed JSON/stderr, wire-format preservation and disposal. This does not certify unwritten transport/cache/UI paths.
- Unit tests use a temporary `.dart_tool/mcp_unit_runner.dart` invoking Flutter's test command without native-plugin builds or asset bundling. This validates model/REST/mocked-storage behavior, not native plugins.
- The normal Flutter test command stalls in the existing `cnativeapi` hook.
- Docker Desktop's Linux engine and the existing local Supabase stack have been restarted. All three migrations and the seed replay cleanly in separate fresh projects, and broader catalog organization/RLS checks pass. Temporary stacks are removed; checked auth/catalog/organization data in the original stack is unchanged. Remote deployment and wider account/security acceptance are not certified.
- Stdio remains partial: Windows `.cmd`/`.bat` launch is explicitly rejected until quoting is implemented/tested; macOS process-group launch is not implemented (POSIX currently requires `/usr/bin/setsid`); Windows descendant cleanup after an early parent exit still needs work. Linux group/GUI-PATH behavior and platform shutdown guarantees remain unverified. No shell fallback weakens these gates.
- A Windows Job Object helper prototype compiled, but local Application Control blocked its unsigned executable (Code Integrity event 3077). The owner confirmed no signing setup is available. The prototype is not part of the app build or default launcher; the existing direct launch path remains in use. This approach needs an approved execution/signing route or a different supported native integration before its cleanup guarantee can be validated.
- HTTP remains partial: legacy Streamable HTTP supports one bounded response resume and an optional notification GET. Explicit deprecated HTTP+SSE targets now support fixed same-origin endpoint routing in legacy mode. Cross-origin announced endpoints, automatic transport fallback, continuous polling/reconnection and notification-stream UI controls are not implemented. Redirects are not followed; TLS proxy endpoints are explicitly rejected (an HTTP proxy can still tunnel an HTTPS MCP target). OAuth remains S2. No automatic POST replay or modern Last-Event-ID resumption is introduced.
- Q13's CIMD hosting URL is needed for S2, not for continuing S1.

## Design reference

Use Stitch project **3561297165959721299**, screens **#14–#22** and light variant **15L**.
Follow [the design handoff](../../design/stitch-mvp-progress.md#current-color-tokens): use the current orange-seeded themes in `lib/core/ui/theme/` and bundled fonts, fix documented clipping/double-plus nits, keep labels on one line and keyboard hints as `Ctrl`. Historical implementation notes below describe the theme at the time; the current app theme takes precedence. Server management, primitive/rich result views and initial monitors are implemented; full native acceptance remains open.

## Next implementation order

1. Finish monitor pin/export and preferences while the Windows helper approach is blocked.
2. Revisit Windows descendant cleanup with an approved native execution route; close remaining stdio platform/lifecycle gaps.
3. Finish wider account/security and remaining S1 fixture-matrix acceptance; remote database deployment remains separate.
4. Complete normal Flutter/native-plugin, desktop/window/keychain and cross-platform/manual exit checks.
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

## Local catalog database acceptance follow-up

The local database gate is now exercised against real Supabase. Docker Desktop's
Linux engine had stopped; it and the existing project were restarted. Auth health
returned HTTP 200, but the first database run found public.mcp_servers missing.
Local migration history showed only 20261116000000 pending. Applied that reviewed
additive migration with supabase migration up --local, without a database reset or
remote deployment. All three local migration versions are now recorded as applied.

Expanded the opt-in catalog integration suite to three cases. It verifies direct
constraint failures (targets, credentials in URL user-info, JSON containers/value
types, empty names and required values), stdio/HTTP round trips, timestamp-trigger
behavior, cross-organization select/insert/update/delete denial and rejection of
workspace reassignment into an outsider's organization. Real repository CRUD also
checks stdio args/cwd/settings/ordering, HTTP/SSE target updates, marked-secret
placeholder stripping and missing-on-device state. An unauthenticated client cannot
read or insert another guest's catalog. Test clients use only the local anon key.

The suite refuses non-loopback URLs; a verification run with a non-local dummy URL
skipped all three cases before client creation. The local launch/test defines are
refreshed under ignored .dart_tool/local_supabase_defines.json; no key was added to
version control or printed. Test-owned MCP rows are removed. Guest auth/bootstrap
records created by signInAnonymously may remain, following the integration suite's
existing convention; no administrator account deletion or broad cleanup was added.

Results: all three real database cases pass, all 291 selected MCP/desktop regression
tests pass, and static analysis is clean. Read-only database metadata confirms RLS
enabled, the workspace index and timestamp trigger present, and zero retained
catalog rows after the checks. No migration SQL change was needed.

This closes the previously blocked local catalog/RLS verification slice, not every
database or S1 exit criterion. Fresh full migration replay on an isolated instance,
broader organization/security fixtures, remote deployment and native/platform/large-
payload acceptance remain open. Next: separate HTTP request/response body capture
and presentation in Network, then the remaining S1 transport and platform gates.

## Separate Network request and response bodies

Network captures now retain a sanitized request body alongside the existing
response body. The response keeps its existing `body`/`truncated` codec fields;
`requestBody`/`requestTruncated` are additive. Normal POSTs, initialized
notifications and unsupported client-method replies capture their outgoing JSON.
DELETE has no request body. Mirrored credential headers are learned before
outgoing diagnostics, and request capture is sanitized again after response
credentials have been learned. Operation payloads remain unchanged.

Each side has an independent UTF-8-safe 256 KiB preview, partial-transport flag,
off-isolate JSON Load full and sanitized Copy. Requests use JSON parsing even
when the response is SSE. Transport captures remain bounded at 16 MiB per body;
both bodies count toward the monitor's shared 64 MiB budget and startup stream
budget. Eviction, clear and scope disposal release both sides together. Nonempty
notification/client-reply responses deliberately discarded by the transport are
marked partial instead of appearing as complete empty bodies.

The detail view exposes Request body, Response body and both header tabs. Copy
names the active body; partial captures explicitly copy only retained text.
Loading/full/error state belongs to each side, so switching tabs during an isolate
load cannot overwrite the other body's editor. Empty captures are explicit.

All 299 selected tests pass, including body budget/eviction, independent partial
flags, request redaction, notification/DELETE, scope invalidation, tab-switch
loads and dark/light Network rendering. Six real loopback HTTP scenario groups
pass, now exercising large request and response bodies over both JSON and SSE;
`dart analyze lib test` is clean. Frontend-design and ui-ux-pro-max were applied,
and both theme renders were reviewed. The existing unit-only harness still omits
native plugins; this does not close normal Flutter/native or S1 exit acceptance.

Next: address the large-payload transport acceptance gap and Windows descendant
cleanup, followed by remaining legacy HTTP, database replay and platform gates.

## 20 MiB binary transport and export verification

The shared incoming frame budget is now 32 MiB for stdio JSON lines, HTTP JSON
and SSE events. A 20 MiB binary blob expands to about 26.7 MiB in base64, which
the previous 10 MiB limit rejected. This leaves envelope room while preserving
a hard bound. HTTP and stdio/SSE collectors use typed byte buffers instead of
growable integer lists; stderr keeps its independent 10 MiB line limit.

The live binary fixture exposed a sanitizer regular-expression stack overflow on
long base64 tokens. Credential header matching now uses fixed suffixes rather
than backtracking over arbitrary-length names, and quoted credential values are
scanned with escape handling. Regression cases preserve long values and redact
long custom header names, large quoted credentials and malformed strings.

Real Windows stdio, loopback HTTP JSON and loopback SSE now each receive a
20 MiB embedded binary tool result, map it through the content model, prepare
metadata without inline content, decode through the existing isolate-based Save
service, and export a byte-exact file. The test destination verifies every decoded
byte and the saved file's SHA-256 digest, then deletes the temporary file.
Protocol previews remain 256 KiB. Network response retention remains 16 MiB and
is explicitly partial; Load full is denied for that partial capture. Clear releases
both diagnostic buffers. No diagnostic cap was raised to match operation payloads.

Over-budget HTTP JSON fails only that request and permits an explicit new call;
oversized SSE events fail parsing, and oversized stdio lines disconnect rather
than trying to recover framing. Invalid/incomplete HTTP responses now also mark
the diagnostic body partial. Tests cover the production 32 MiB overflow bounds.

All 304 selected regression tests, seven existing real stdio groups, six existing
real HTTP groups and three new large-binary checks pass; static analysis is clean.
The navigation test now targets the rail specifically because the current welcome
screen also contains an MCP Lab label. Existing welcome/theme changes are outside
this commit. The unit harness still skips native-plugin hooks. This closes the
transport/export capacity slice, not full AC-TOL-03.3: native dialog behavior,
Flutter frame responsiveness during large-message parsing/sanitization, and
macOS/manual acceptance remain open. Next: Windows descendant cleanup.

## Windows application-policy launch diagnostics

The attempted Windows descendant-cleanup helper compiled with MSVC, but Windows
Application Control blocked execution before the server could start. Code Integrity
event 3077 reported signing-level/policy requirements. The owner confirmed no
signing setup is available. The helper integration was removed from production
and fixtures, restoring the existing direct executable path; it is not bundled
or retried. No security policy, Defender setting, exclusion or certificate trust
was changed. Reliable descendant cleanup after early parent exit remains open.

The completed change instead makes process-start failures actionable without
copying executable paths, arguments, environment values or raw OS exception text.
On Windows, error 577 reports signature verification failure, 1260 reports an
application-policy block, and 225/226 report a security block/removal with a
Protection history hint. Other launch errors retain the safe generic message.
These follow Microsoft's [signature-error](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--500-999-),
[policy-error](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--1000-1299-)
and [security-error](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-)
definitions. Existing coded `unreachable` failures remain compatible; no fallback
launch or automatic retry is introduced.

All 309 selected tests and seven real stdio scenario groups pass after restoring
direct launch; static analysis is clean. Five added cases verify Windows error
classification, generic fallback, secret-safe messages and exactly one launch
attempt. This completes the policy-diagnostics slice, not Windows process-tree
acceptance. Next unblocked work: legacy HTTP/SSE compatibility.

## Bounded legacy response-stream resumption

Negotiated legacy Streamable HTTP calls can now resume an interrupted SSE
response with one GET to the same MCP URL and its request-local Last-Event-ID.
The original POST is sent once. Concurrent calls keep separate cursors; no cursor
is carried into a new call. Modern sessions never resume or send Last-Event-ID.
Initialization before protocol configuration remains outside this resume path.

The parser exposes completed SSE block metadata separately from JSON data. Empty
priming data, explicit empty ID resets, NUL-ID rejection, retry metadata, fragmented
UTF-8/BOM and CR/LF/CRLF are handled. Partial blocks cannot advance the cursor.
Cursor headers are bounded to 8 KiB and visible ASCII; unsupported IDs prevent
resumption rather than being re-encoded. Input frame budgets remain 32 MiB.

Server retry delays are honored within the original request deadline. Closing or
revoking the session cancels pending resume work, and late payloads are rejected
before protocol retention. A second interruption fails explicitly; there is no
repeated polling, POST replay or new timeout window. GET 401/403/404 invalidates
the session, 429 preserves Retry-After, and other failures (including 405) fail
only that call. A refused resume does not prevent an explicit new call.

POST and GET captures retain separate timing, headers and bounded sanitized body
segments. The interrupted POST is marked partial; a resume cursor is masked in
the GET capture, and GET has no request body. Priming metadata is not recorded as
a malformed JSON frame. This follows the legacy specification's
[response resumption rules](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports#resumability-and-redelivery).

All 328 selected regression tests, seven real HTTP groups and three real 20 MiB
transport/export checks pass; static analysis is clean. Nineteen added cases cover
metadata, priming, safe/cleared cursors, retry/deadline/close behavior, revoked
access, status/type failures, diagnostics and modern non-resumption. The live
fixture verifies concurrent cursor isolation and unchanged operation results.
No new process helper or security-setting change is involved. Next: the optional
GET notification listener and its tolerated 405 response, then deprecated SSE.

## Optional legacy GET notification stream

The HTTP repository now opens one optional SSE GET after a successful legacy
initialized notification. It carries the negotiated session/version and configured
headers, requests text/event-stream, and never forwards a configured Last-Event-ID.
Modern negotiation does not open it. The default app path enables the listener;
the repository constructor can disable it for request-only clients and fixtures.
Repeated initialized notifications do not create duplicate listeners.

GET 405 is a normal unsupported outcome and leaves calls usable. GET 401/403/404
invalidates negotiation/session state. Other unsupported responses, stream errors
and EOF emit safe console diagnostics and leave ordinary calls available. Opening
headers have a bounded deadline; an accepted stream may idle independently of
request timeouts. The opening deadline rechecks authorization so revoked access
cannot become a successful negotiation. Listener EOF is not automatically retried.

Incoming notifications use the existing sanitized protocol pipeline. Unsupported
server requests receive method-not-found POST replies; those replies have a
deadline so a nonresponsive peer cannot hang the listener. Unsolicited JSON-RPC
responses on this independent stream are ignored with a protocol warning and
cannot complete concurrent POST calls. Subscriptions, list refresh, elicitation
and sampling capabilities remain unadvertised and unimplemented until S3.

Closing the session, switching to modern, or discovering revoked access cancels
the listener and rejects late frames. Finished live captures remain bounded and
sanitized; closing does not publish stale payloads into disposed diagnostics.
DELETE 405 is still accepted and other cleanup failures remain visible.

All 345 selected tests pass. Seventeen new cases cover 405/header behavior,
modern gating, sanitized live events, unsupported requests and reply timeouts,
response isolation, terminal/nonterminal responses, idle/header deadlines, EOF,
errors, protocol switching and access revocation. Five new real loopback groups,
seven existing HTTP groups, three 20 MiB transport/export checks and static
analysis pass. This closes the optional GET/405 slice, including AC-PRO-07.3's
GET/DELETE behavior. Normal native-plugin and full S1 acceptance remain open.
Next: deprecated HTTP+SSE transport compatibility.

## Deprecated HTTP+SSE transport compatibility

Explicit `sse` targets now dispatch through the shared HTTP repository. A persistent
GET must announce its POST endpoint before a finite connect deadline; subsequent
JSON-RPC messages are posted there, with responses correlated from SSE message
events. This implements the two-endpoint layout in the
[2024-11-05 transport specification](https://modelcontextprotocol.io/specification/2024-11-05/basic/transports#http-with-sse).
There is no automatic fallback from Streamable HTTP and no modern discovery sent
to this old transport. Auto negotiation can select legacy without sending the
unsupported modern probe; explicit Modern mode is refused.

The announced endpoint is accepted once, must resolve to the configured origin
(same scheme, host and port), and cannot contain user-info, a fragment, whitespace
or backslashes. It is bounded to 8192 characters. Cross-origin endpoints and live
endpoint replacement fail before posting to the new target. Query values on the
announced endpoint are learned as device-memory credentials and redacted from
Network URLs, headers, frames and echoed diagnostic values. Endpoint control
events are not misrepresented as JSON-RPC frames.

Concurrent integer/string IDs remain distinct. A response arriving before its
POST acknowledgement is retained until that POST succeeds; a rejected POST cannot
be hidden by an early SSE result. Per-call timeouts do not close the shared stream.
Stream loss fails remaining calls, disconnects and requires explicit reconnect,
without replay. Unsupported server requests receive bounded method-not-found
replies. Close cancels the GET and pending calls without Streamable HTTP DELETE.
Authorization gates reject late payloads after access changes.

The editor retains the Deprecated label, explains Legacy mode and enables the
existing Connect action. Applied ui-ux-pro-max interaction guidance and added a
widget regression for that availability; no theme or layout change was required.

All 367 selected tests pass. Twenty-two added cases cover endpoint trust/deadline,
event types, response/ack ordering, correlation, timeouts, stream loss, unsupported
requests, modern refusal, revocation and Connect availability. Four new real
HTTP+SSE groups, seven existing HTTP groups, five notification groups, three existing
20 MiB transfer/export checks and static analysis pass. The old transport also
receives a 20 MiB binary result and prepares metadata off-isolate. Native dialog,
large-result Flutter responsiveness and remaining full S1 gates remain open.
Next: isolated migration replay and broader database-security verification.

## Isolated migration replay and broader organization RLS verification

Added `tool/verify_mcp_database.ps1` and a 33-assertion transactional pgTAP suite.
The verifier creates a unique ignored Supabase project on separate ports, copies
only committed migrations/seed/tests, verifies the scratch path/project/ports
before reset or cleanup, and requires a nonzero executed-test count. It never
targets the original project or a remote database. Default cleanup removes only
its temporary containers/data; KeepRunning supports additional REST verification.
CLI key output is captured without logging it; only API/anon test defines are
written to the ignored workdir. See [database verification](database-verification.md).

All three migrations and the committed seed replayed successfully in two isolated
fresh projects. The SQL suite verifies owner/shared-member access across two
workspaces, foreign organization read/write/transfer denial, membership self-grant
denial, explicit multi-organization access, partial/full membership revocation
without changing the subject, anon-role restrictions and workspace cascades.
Assertions use actual authenticated/anon database roles, not superuser reads for
access checks. Fixtures and their auth-trigger-created profiles/organizations roll
back; post-test metadata confirms no SQL fixture users or MCP catalog rows remain.

The three existing REST/repository integration cases also pass against the first
fresh isolated API: constraints, real CRUD/serialization, marked-secret stripping
and outsider/anonymous denial. The second run verifies the final script's executed
test count and automatic cleanup. A deliberately occupied-port run refused before
starting or stopping anything. Original auth/user/organization/membership/workspace/
MCP row fingerprints match, and only the original local stack remains running.

Static analysis is clean. No Dart or migration SQL change was required, so the
preceding 367 app regression results remain the app baseline. Applied
supabase-postgres-best-practices and its RLS guidance. This closes local fresh-replay
and these broader catalog-RLS cases, not remote deployment, automatic app-side
revocation discovery, every table/account flow or full S1/native acceptance.
Next: resource-template composite inputs/completion and remaining S1 UI gaps.

## Composite resource-template inputs

Resource-template expansion now accepts text, lists of strings and string-key/value
objects. Explode modifiers are retained and expanded across all eight operators,
with deterministic object entry order, reserved/percent encoding and Unicode
handling. Empty collections are omitted; empty members remain defined. Nonempty
composite values reject prefix modifiers instead of truncating or stringifying
them. Expansion follows the supported shapes in
[RFC 6570 variable expansion](https://www.rfc-editor.org/rfc/rfc6570.html#section-3.2.1).

The form offers explicit Text, List and Object input kinds. List/object editors
accept JSON with strings only and use the bundled monospace font. Text that looks
like JSON remains text. Malformed JSON, wrong root types, nested/non-string values
and exceeded budgets show validation errors, clear the derived URI and block both
Read and Ctrl+Enter. Switching type starts an empty value of that type; nothing
reads automatically. Manual URI editing still explicitly replaces template mode.

Unsubmitted drafts retain input kind and raw editable text, including invalid
JSON, so switching tabs cannot restore an older valid value and silently enable
Read. Their maps are immutable and memory-only, and account/workspace disposal
clears them. The service permits at most 128 list items/object entries and 4 KiB
of combined decoded strings per argument; raw editor inputs are also limited to
4 KiB. Existing 16 KiB template, 128-expression, 64-variable and 64 KiB final URI
limits remain in place. No new dependency or database field was introduced.

All 380 selected tests pass, followed by all 25 Resources widget tests after a
font-family adjustment; static analysis is clean. Thirteen added cases cover RFC
operator examples, empty values, Unicode/percent encoding, prefix/type/size errors,
immutable typed parsing, explicit Read, object/list draft restoration, invalid
draft blocking, manual fallback and scope cleanup. Both final dark/light form
renders were reviewed using ui-ux-pro-max, with existing app colors and fonts.
This completes composite template editing/expansion, not server-provided argument
completion or full S1/native acceptance. Next: capability-gated template completion.

## Explicit resource-template completion

Included Text arguments now offer a Suggest action when the live server advertises
`completions`. It sends `completion/complete` with a `ref/resource` pointing to the
original template, the current argument text, and other included Text arguments
as `context.arguments`. List/object values are not coerced into string context;
invalid input shapes and exceeded input budgets fail locally. No completion RPC
runs merely from typing, selecting a template, remounting, or connecting.

Completion responses preserve server ordering, optional totals and `hasMore`, with
at most 100 strings, 4 KiB UTF-8 per value and 64 KiB total retained suggestion
text. Malformed results return a typed failure. A bounded, keyboard-accessible
list shows loading/error/empty states and supports explicit retry. Choosing a
suggestion updates the Text draft and URI preview; reading remains an explicit
Read/Ctrl+Enter action. `hasMore` asks the user to refine the text, not paginate.

Suggestions are field-local and memory-only. Any argument edit, type/include
change, template/manual-URI change, remount or session/scope replacement clears
them and invalidates pending responses. The service also checks authorization
before sending and after receiving; no result is cached or automatically saved.

Validation: all 396 selected app tests pass, including 16 new service/widget
cases for capability gating, context, bounded decoding, stale authorization and
edits, retry/empty states, keyboard selection, draft retention and disposal.
Four real loopback HTTP cases verify legacy/modern completion over JSON/SSE,
session/version or modern routing metadata, diagnostic redaction, rate limits and
no implicit read/retry. The existing seven HTTP session and five notification
groups still pass. Analysis is clean; dark/light screenshots were reviewed using
ui-ux-pro-max. Unit/widget checks still use the documented native-hook bypass.

Wire shapes follow the official [legacy completion specification](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/docs/specification/2025-11-25/server/utilities/completion.mdx)
and [modern completion specification](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/docs/specification/2026-07-28/server/utilities/completion.mdx).
Production transport code and database schema are unchanged. Prompt completion,
monitor pin/export, preferences and the existing platform/security/native S1 exit
gates remain open. Next: prompt-argument completion, then monitors/preferences.

## Explicit prompt-argument completion

Prompt fields now offer Suggest only when the connected server advertises
`completions`. Requests use `ref/prompt` with the protocol prompt name, current
argument text (empty when unset), and other supplied arguments as string context.
Required arguments can still be empty during completion; Get prompt retains its
required-field validation and remains an explicit action. Typing, changing the
selection, refresh and remount never initiate completion or Get automatically.

Prompt completion validates known argument names, unique prompt arguments and
input budgets before sending: at most 64 supplied arguments, 4 KiB UTF-8 per
name/value, and 64 KiB aggregate supplied key/value text. These completion limits
do not restrict manual prompt inputs or prompts/get. Response validation reuses
the bounded resource-completion decoder and preserves ordering, total and hasMore.

Both primitive forms now share the controller-backed suggestion field, loading/
error/empty feedback and keyboard selection. Choosing a suggestion updates the
draft before rebuilding the enclosing Form. Suggestions remain transient; any
argument edit, selected-prompt refresh/replacement, session/scope change or view
disposal invalidates pending results. Refreshed/unavailable prompts cannot send
requests through stale fields, and authorization is checked around the RPC.

Validation: all 412 selected app tests pass (406 MCP and six desktop shutdown),
including 16 new prompt service/widget cases. Coverage includes both protocol
eras, capability gating, empty required/optional fields, context snapshots,
input budgets, malformed/failure responses, stale authorization, keyboard and
pointer selection, retry, remount, prompt replacement, scope cleanup and large
manual values. Four real HTTP groups now exercise both resource and prompt
completion over legacy/modern JSON/SSE, checking wire references/context,
metadata, diagnostic redaction, rate limits and no automatic Get/retry. Analysis
is clean and both prompt-completion themes were reviewed using ui-ux-pro-max.

The specification references in the preceding completion note apply to both
reference types. No new dependency, production transport or database change is
introduced. Normal native-plugin testing still has the documented hook blocker;
Windows process cleanup and other platform/security/native S1 exit gates remain
open. Next: monitor pin/export and preferences.
