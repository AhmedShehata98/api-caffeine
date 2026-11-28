# MCP Lab — Gap Review of the Feature Specification

| | |
|---|---|
| **Reviewed document** | [feature-specification.md](feature-specification.md) Draft v1.1 → updated to v1.2 |
| **Date** | 2026-11-15 |
| **Method** | The spec compared with the final MCP **2026-07-28** specification, the official MCP Inspector docs and roadmap, the Dart MCP packages, and the current API Caffeine codebase |
| **Severity** | **High**: wrong behaviour, a security risk, or blocks implementation · **Med**: a missing requirement that users will hit · **Low**: polish, clarity or doc hygiene |

## Summary

The v1.1 spec copies the MCP Inspector faithfully. Most of its gaps are in five areas:

- **A:** statements that the final 2026-07-28 spec made wrong or out of date (deprecations, tasks, subscriptions, OAuth registration);
- **B:** protocol features that are missing entirely;
- **C:** Flutter desktop and platform problems that the Inspector (Node/browser) never had to solve;
- **D:** gaps in how MCP Lab fits API Caffeine's own product, data, auth and failure models;
- **E:** problems in the document itself.

Spec v1.2 resolves every item marked **→ v1.2**. Items marked **→ follow-up** need a decision or work outside the spec.

---

## A. Statements that are wrong or out of date

| # | Spec ref | Finding | Sev | Resolution |
|---|---|---|---|---|
| A1 | FR-INT-02, FR-INT-03, FR-MON-04 | **Roots, Sampling and Logging are deprecated** (SEP-2577). They still work for at least 12 months under the lifecycle policy (SEP-2596). | Med | → v1.2: marked *Deprecated (legacy support)*; Roots and Sampling lowered to Should |
| A2 | FR-CON-03, FR-CFG-04, NFR-CMP-02 | The **HTTP+SSE transport is formally Deprecated** (SEP-2596). Streamable HTTP is the current transport. | Med | → v1.2: SSE kept as a legacy option and labelled deprecated in the UI |
| A3 | FR-AUT-01 | **Dynamic Client Registration is deprecated in favor of Client ID Metadata Documents (CIMD)** (PR #2858). | High | → v1.2: registration order is CIMD → pre-registered → DCR fallback |
| A4 | FR-RES-03 | Only describes `resources/subscribe`. In the modern era these calls are replaced by **`subscriptions/listen`** with opt-in filters and `notifications/subscriptions/acknowledged`. | High | → v1.2: split by era |
| A5 | FR-TST-02 | `initialize` does not exist in the modern era (SEP-2575), where the probe is **`server/discover`**. `logging/setLevel` is legacy-only. The list also leaves out `resources/directory/read`, `skills/*` and `completion/complete`. | High | → v1.2 |
| A6 | FR-TOL-07, FR-TSK-* | Tasks are now the `io.modelcontextprotocol/tasks` extension (SEP-2663). On modern servers **the server decides** when a call becomes a task, so "Run as task" is legacy-only. `tasks/list` and the blocking `tasks/result` are gone, and `tasks/update` is new. | Med | → v1.2 |
| A7 | FR-AUT-02 | The suggestion to align with "custom-scheme patterns" mixes MCP OAuth (loopback, native-app pattern) with API Caffeine's Supabase GitHub deep link, which is a separate flow. | Low | → v1.2: loopback only; custom scheme dropped |
| A8 | NFR-INT-04, FR-CFG-06 | Assumes every client config uses the `mcpServers` shape. **VS Code `.vscode/mcp.json` uses `servers` plus `inputs`** with `${input:…}` / `${env:…}` placeholders. | Med | → v1.2: per-client import adapters plus placeholder handling |
| A9 | Appendix A | Uses `failure?.code` and `result.data!`, but `Failure` (`lib/core/error/failure.dart`) has **no `code`** field. | Med | → v1.2: the example uses `McpFailure.code` (see D4) |

## B. Protocol features that are missing

| # | Finding | Source | Sev | Resolution |
|---|---|---|---|---|
| B1 | Every result carries **`resultType`** (`complete` / `input_required`). When a legacy server omits it, the client must treat the result as `complete`. | SEP-2322 | High | → v1.2 FR-PRO-01 |
| B2 | **Per-request `_meta`** (`protocolVersion`, `clientCapabilities`, `clientInfo`, `logLevel`) and `serverInfo` in each result's `_meta` should be visible in the transcript. | SEP-2575 | Med | → v1.2 FR-PRO-02 |
| B3 | **Required `Mcp-Method` / `Mcp-Name` headers** on Streamable HTTP. Only `Mcp-Param-*` was covered. | SEP-2243 | High | → v1.2 FR-PRO-03 |
| B4 | **Cache hints `ttlMs` / `cacheScope`** on list and read results. | SEP-2549 | Low | → v1.2 FR-PRO-04 |
| B5 | **Error-code changes:** resource-not-found is now `-32602` (was `-32002`). `-32020..-32099` is reserved for the spec. `UnsupportedProtocolVersion` carries `data.supported`. | 2026-07-28 changelog | Med | → v1.2 FR-PRO-05, FR-MON-08 |
| B6 | **Stream loss and sessions:** modern has no `Last-Event-ID`, so the client must re-issue the request under a new ID. Legacy has `Mcp-Session-Id`, `DELETE` on disconnect, a standalone GET stream and a *Suppress Notification Stream* option. | SEP-2575, Inspector *Protocol eras* | Med | → v1.2 FR-PRO-06/07 |
| B7 | **`listChanged` notifications** (tools, prompts, resources) with automatic re-list. | Core spec | Med | → v1.2 FR-PRO-08 |
| B8 | A **progress UI** for `notifications/progress`, beyond resetting the timeout. | Core spec | Med | → v1.2 FR-PRO-09 |
| B9 | **`ping`** as a connection health check (legacy only; removed in modern). | 2026-07-28 changelog | Low | → v1.2 FR-PRO-10 |
| B10 | **JSON Schema 2020-12 input forms:** `oneOf`/`anyOf`/`allOf`, conditionals, `$ref`/`$defs`. External `$ref` must **not** be dereferenced. Depth and validation time must be bounded. There is no raw-JSON fallback. | SEP-2106 | High | → v1.2 FR-TOL-02 updated, FR-TOL-08 |
| B11 | **`outputSchema` vs `structuredContent` validation** (the Inspector's `validateToolOutput`). | Inspector roadmap | Med | → v1.2 FR-TOL-09 |
| B12 | **Destructive-call confirmation** driven by `destructiveHint`. | Inspector roadmap Phase 2 | Med | → v1.2 FR-TOL-10 |
| B13 | **Elicitation details:** form vs **URL mode** (open the browser only after confirmation, showing the domain), accept / decline / cancel, the restricted `requestedSchema` subset, and a queue for several pending requests. `notifications/elicitation/complete` was removed. | 2025-11-25 / 2026-07-28 | High | → v1.2 FR-INT-06/07 |
| B14 | **Sampling editor:** `modelPreferences`, `systemPrompt`, `maxTokens`, tools in sampling. The `includeContext` values `thisServer`/`allServers` are deprecated. | SEP-2596 | Low | → v1.2 FR-INT-02 note |
| B15 | **Content types and metadata:** text vs base64 `blob`, audio, `resource_link`, large binaries; **icons** (`data:` vs remote URL, with privacy and fetch risks); `title` vs `name`; server `instructions` and `websiteUrl`. | 2025-06-18 / 2025-11-25 | Med | → v1.2 FR-TOL-03 updated, FR-PRO-11 |
| B16 | **Completions** for resource-template variables as well as prompts. | Core spec | Low | → v1.2 FR-RES-06 |
| B17 | Handling **HTTP 429 / `Retry-After`** (`rate_limited`). | Inspector CLI | Low | → v1.2 FR-PRO-12 |
| B18 | **OAuth details:** RFC 9728 protected-resource metadata and the `.well-known` suffix rule (SEP-2351); PKCE S256; RFC 8707 `resource`; **RFC 9207 `iss` validation** (SEP-2468, MUST); **credentials keyed by issuer** with re-registration when the issuer changes (SEP-2352, MUST); DCR `application_type` (SEP-837); scope accumulation during step-up (SEP-2350). | 2026-07-28 changelog | High | → v1.2 FR-AUT-07…10 |
| B19 | An **extension declaration view** (what the server advertises vs what the client advertises). `Mcp-Name` must also be sent on `tasks/*` calls (Inspector bug #1917, avoid repeating it). | SEP-2133 / SEP-2663 | Low | → v1.2 FR-ERA-07 |
| B20 | OpenTelemetry `traceparent` in `_meta`, so calls can be matched to server traces. | SEP-414 | Low | → v1.2 FR-MON-09 (Could) |
| B21 | OAuth **Client Credentials** (machine-to-machine). The Inspector does not support it yet either. | Inspector roadmap | Low | → v1.2 FR-AUT-11 (Could) |

## C. Flutter, desktop and platform gaps

| # | Finding | Sev | Resolution |
|---|---|---|---|
| C1 | The **macOS App Sandbox** blocks spawning arbitrary binaries. The OAuth loopback listener needs the `com.apple.security.network.server` entitlement. | High | → v1.2 NFR-CMP-06; entitlement decision → follow-up |
| C2 | **GUI apps don't inherit the shell `PATH`** (macOS, and Linux desktop launchers), so `node`, `npx` and `uvx` come back "not found". | High | → v1.2 NFR-CMP-07 |
| C3 | **Windows:** `npx`/`uvx` are `.cmd` shims, which need shell resolution and safe quoting (a command-injection risk). `Process.kill` does **not** kill the process tree, so the child `node` is orphaned. | High | → v1.2 NFR-CMP-05 expanded, NFR-REL-07 |
| C4 | The **env allow-list** lists only POSIX variables. On Windows it also needs `SystemRoot`, `PATHEXT`, `APPDATA`, `LOCALAPPDATA`, `USERPROFILE`, `TEMP`/`TMP` and `ComSpec`. | High | → v1.2 NFR-SEC-07 |
| C5 | The **stdio shutdown sequence** (close stdin → wait → SIGTERM → SIGKILL) and cleanup of children orphaned by an app crash are not defined. | Med | → v1.2 NFR-REL-06 expanded, NFR-REL-07 |
| C6 | **stdio framing:** newline-delimited UTF-8 JSON. Non-JSON lines on stdout (a common server bug) must show as warnings, not break the session. | Med | → v1.2 FR-MON-10 |
| C7 | **Secure storage:** `flutter_secure_storage` is not in the Core Stack. Linux needs libsecret. Windows Credential Manager entries are capped at about 2.5 KB, so large OAuth tokens need chunking or an encrypted file. | High | → v1.2 §6.4, NFR-SEC-12 |
| C8 | **SSE over Dio** needs `ResponseType.stream` and a line parser. Dio does not read `HTTPS_PROXY`/`NO_PROXY` itself. Whether the Settings proxy or the environment variables win is undefined. | Med | → v1.2 FR-CON-09 updated, Q12 |
| C9 | **Transcript memory:** needs a bounded ring buffer, large bodies truncated with "load full", and parsing off the UI isolate, in line with the PRD's 5 MB rule. | Med | → v1.2 NFR-PRF-03 expanded |

## D. Gaps in how MCP Lab fits API Caffeine

| # | Finding | Sev | Resolution |
|---|---|---|---|
| D1 | **Environments and `{{variables}}`:** nothing says whether variables resolve in server URLs, headers, args, env and tool arguments. This is API Caffeine's main advantage over the Inspector. | Med | → v1.2 §6.5, FR-TPI-01 |
| D2 | **Saved calls and history:** a tool call, prompt or resource read cannot be saved or replayed. This is the "organize" pillar from the PRD. | Med | → v1.2 FR-TPI-02/03 |
| D3 | **Shell integration:** tabs, unsaved marker, status bar, environment dropdown and the number of concurrent connections are not defined. | Med | → v1.2 §6.5, FR-TPI-04/05 |
| D4 | **Failure model:** `Failure` is sealed and has no `code`, but the spec needs stable codes. | High | → v1.2 §6.6 (module-local `McpFailure` carrying `code`) |
| D5 | **Supabase data model:** no tables, migrations or RLS policies, and no update to `docs/DATA_MODEL.md`. | High | **Decided:** the catalog lives in Supabase, scoped to the workspace. Schema and migrations → follow-up |
| D6 | **Remote-command risk in a synced stdio catalog:** anyone who can edit a shared catalog can make another member's machine run a command. | **High** | → v1.2 FR-SEC-04 (per-device trust on first use for each command hash), R-10 |
| D7 | **Inconsistent secret handling:** environment `variables` already keep secrets in Supabase JSONB (`DATA_MODEL.md`, PRD Q3), while MCP Lab says "never in Supabase". | Med | **Decided:** values stay on the device; Supabase stores a placeholder (spec §6.4, PRD Q3). **Done:** the environments module now follows this rule, and existing plaintext secrets move to the device when first loaded. |
| D8 | **Guest and account rules:** what happens to the catalog and local secrets when a guest links GitHub, signs out or switches account (PRD §5.8)? | Med | → v1.2 FR-TPI-06 |
| D9 | **Untrusted imports:** an import must never connect automatically. List every command it would spawn. Map `server.json` `packages` (npm, pypi, oci) and `remotes`. | High | → v1.2 FR-CFG-09/10 |
| D10 | **Hidden text in tool and prompt descriptions:** zero-width or bidi Unicode, ANSI sequences or HTML. Render as plain text and highlight hidden characters. | Med | → v1.2 FR-SEC-05 |
| D11 | **CIMD needs a public https client metadata document** that API Caffeine hosts. | Med | → v1.2 Q13 |
| D12 | **Sample servers on first run:** the Inspector's filesystem sample uses `/tmp`, which does not exist on Windows. Node or Python may not be installed. | Low | → v1.2 FR-CFG-07 updated |
| D13 | **Test fixture runtime** not chosen: the Inspector's Node composable servers vs Dart fixtures. | Med | → v1.2 Q14 |
| D14 | PRD §4/§5 and `IMPLEMENTATION_PLAN.md` don't mention MCP Lab. | Low | → follow-up |

## E. Problems in the document itself

| # | Finding | Sev | Resolution |
|---|---|---|---|
| E1 | No acceptance criteria for each requirement, so most FRs can't be tested as written. | Med | → follow-up: add Given/When/Then for the MVP slice first |
| E2 | No **MVP slice** (Q5 is open) while 40+ requirements are Must. | High | → v1.2 §4.1 proposed release slices |
| E3 | No UI spec, screen inventory or Stitch designs (Q9, Q10). | Med | → follow-up: Stitch screens for Lab shell, tool call, transcript, pending-request modal |
| E4 | The N1 count was wrong (FR-CON-01…10, but there are 11). The traceability matrix left out FR-DST, FR-SEC and FR-TOL-05/06. The risk register didn't cover synced catalogs, sandboxing or orphaned processes. | Low | → v1.2 |
| E5 | **Q4 (Dart MCP library)** can now be answered. `mcp_dart` 2.4.3 supports 2026-07-28 plus legacy, stdio, Streamable HTTP, opt-in SSE, OAuth hooks and Flutter desktop. The Dart team's `dart_mcp` is experimental, focused on stdio and has no auth. **Caveat:** MCP Lab needs raw frames and manual MRTR, so the SDK transport must allow interception. | Med | **Decided:** `mcp_dart`, wrapped behind a repository contract that records frames (R-14) |

---

## Follow-ups outside the spec

1. Design the **Supabase tables, migrations and RLS** for the MCP catalog and saved MCP calls, with secret fields as placeholders. Update `docs/DATA_MODEL.md`.
2. ~~**Change the environments module** to follow the placeholder rule.~~ **Done** (`EnvironmentService` + `lib/core/secrets/`).
3. Add **`mcp_dart`** to the Core Stack table in `agents.md`. Build the transport wrapper first: frame recording, manual MRTR, and Windows stdio (`.cmd` + tree kill).
4. Decide on **macOS sandboxing and entitlements**, and **hosting the CIMD metadata document**.
5. ~~Add MCP Lab to the **PRD** and **`IMPLEMENTATION_PLAN.md`**.~~ **Done** (PRD §5.9 / M7; plan Phase 8, D10–D11, `mcp_servers` table sketch).
6. Create **Stitch designs** for the MCP Lab screens.
7. Write **acceptance criteria** for the Slice 1 requirements.
8. ~~Justify `flutter_secure_storage` in the **Core Stack** table.~~ **Done** (`agents.md`).

## Sources

- MCP spec — [2026-07-28 changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog) · [Release-candidate post](https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/)
- MCP Inspector — [Web client](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/web) · [CLI client](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/cli) · [Protocol eras](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/protocol-eras) · [Security](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/security) · [Roadmap 2026-H2](https://github.com/modelcontextprotocol/inspector/blob/HEAD/docs/inspector-roadmap-2026-h2.md)
- Dart — [`mcp_dart`](https://pub.dev/packages/mcp_dart) · [`dart_mcp`](https://pub.dev/documentation/dart_mcp/latest/)
- API Caffeine — `lib/core/error/failure.dart`, `lib/core/network/network_settings.dart`, `docs/DATA_MODEL.md`, `docs/PRD.md`

## 2026-11-16 high-priority readiness follow-up

The original review above is historical. The six additional high-priority documentation findings are resolved in [spec §6.7](feature-specification.md#67-s1-review-decisions-2026-11-16), [S1 regression criteria](s1-acceptance-criteria.md#10-high-priority-review-regression-criteria-s1), and [implementation gates](implementation-plan.md#8-s1-high-priority-review-implementation-gates): catalog URL/wire shape; successful tool-error results; S1 account/workspace isolation; mandatory legacy lifecycle; diagnostic redaction; and approval of resolved launch targets including environment values. Original assumptions A4/A5 are superseded. This closes documentation findings, not implementation verification: the transport spike remains pending, Q13 remains open for S2, and medium-priority findings remain follow-up work.
