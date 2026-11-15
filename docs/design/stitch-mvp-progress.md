# Test Point — Stitch MVP Design: Progress Notes

_Last updated: 2026-11-10. Resume from "Next steps"._

## Goal
MVP screens for Test Point, a lightweight Postman/Insomnia-style desktop API client built with Flutter.
Style: Material 3 Expressive, teal brand, dark theme first and light theme after. Only the core features are in scope.

**Decisions**
- Theme: Dark (primary) + Light variant
- Brand seed: Teal `#0F9D8A`
- MVP extras: Environments & variables, Import (cURL / Postman v2.1), Settings. History excluded.
- Out of scope (future iterations): history, pre-request/test scripts, runner, mock servers, monitors, GraphQL/gRPC/WebSocket, OAuth2, codegen, sync/teams/sharing, cookie editing, certificates, console, visualizer.

## Stitch references
- Project: **Test Point — MVP**, ID `3561297165959721299` (https://stitch.withgoogle.com)
- Design system Dark: `assets/1955584032106423519`
- Design system Light: `assets/11861585566286790069`
- Fonts: Google Sans Flex (headline), Inter (UI), JetBrains Mono (code/URLs). Roundness ROUND_TWELVE, colorVariant EXPRESSIVE.
  Note: the generated HTML uses Public Sans for headlines. Ignore this; Flutter will use the design-system fonts.

### Token notes (from designMd)
| Token | Dark | Light |
|---|---|---|
| Background | `#0E1513` | `#F5FBF8` |
| Surface container | `#161D1B` | `#EAF2EF` |
| Surface high | `#1E2624` | `#E0EAE6` |
| Outline | `#3F4946` | `#BFC9C5` |
| Primary | `#0F9D8A` | `#006B5E` |
| GET | `#34C759` | `#1E8E3E` |
| POST | `#F5A524` | `#B26A00` |
| PUT | `#4C9AFF` | `#1A66D2` |
| PATCH | `#A78BFA` | `#7C4DDB` |
| DELETE | `#F25F5C` | `#C62828` |
| HEAD/OPTIONS | `#9AA4A2` | `#5F6B68` |

Status chips: 2xx green, 3xx blue, 4xx amber, 5xx red. An unresolved `{{var}}` is shown as an amber chip with a dotted underline.
Shape: cards 12–16px, dialogs 28px, pill buttons, tags 6px, inputs 12px. Spacing: 4/8/12/16/24/32.

## Screen inventory (dark)
| # | Screen | Screen ID | Status |
|---|---|---|---|
| 1 | Request Builder — Params (base layout for the shell) | `ed998a08cff84f2bb84eedb841b0436d` | ✅ Shell standard verified in HTML (2026-11-10). Nits: `{baseUrl}` chip shows single braces; Send hint `Ctrl+↵` → `Ctrl+Enter` |
| 2 | Request — Body (JSON) | `4c01036bbdb74674888855b2cbe9f395` | ✅ Shell standard verified. The edit created this **new** screen; the old `d6e2924243da4523b6e7ee0a0ce72fa1` is stale, so delete it in the Stitch UI |
| 3 | Request — Headers & Auth | `48099dc4b4e04c1db230e0bc117c661c` | ✅ Shell standard verified in HTML (2026-11-10) |
| 4 | Response — Success | `e0408493e8294cf3ad161b043becaa96` | ✅ Shell mostly verified. The edit created this **new** screen; the old `1215c64090fe4c0d939084d99c3c95ec` is stale, so delete it in the Stitch UI. Nits: remove the "Tests" request tab; the search tooltip says `⌘F` (should be `Ctrl+F`); the 200 chip is teal (2xx should be green) |
| 5 | Response — Error & Loading | `a8e02c1a0f7746d7a824baac0d30960a` | ✅ Shell standard + guest avatar verified in HTML (2026-11-10, second pass; edit landed in place after ~8 min) |
| 6 | URL variable autocomplete & method menu | `22b2c180a74c48ac86eec96893438acf` | ❌ First edit was lost (HTML still old). Second shell + avatar edit sent 2026-11-10; **not landed after 13 min**: re-check |
| 7 | Collections — Context menu & Overview | `873ceb87a55f478c852c3de677bbfe5b` | ❌ First edit lost. Issues: "TESTPOINT" logo text, "+" and "JD" avatar in rail, `⌘K`, "Synced", cookie/gear top-bar icons, Share / Run collection / Pre-request Scripts, UTF-8 and Zoom in status bar. Needs shell + guest avatar edit (keep Export) |
| 8 | Welcome — Empty workspace | `1944f19e6dea46ed8e8e545fa2bed3ee` | ❌ First edit lost. Issues: no avatar, `⌘K`, code/eye top-bar icons, "v1.0.0" badge, text mentions GraphQL / OpenAPI / scripts / tests, `Ctrl+↵`, status bar has UTF-8 / Zoom / Console. Needs shell + avatar edit |
| 9 | Environments manager | `99e290784847420d8009bab4cc14a1f1` | ❌ First edit lost. Issues: gradient logo + "TP v1.0" + divider, no avatar, breadcrumb in top bar, code/eye/gear icons, "PINNED" Globals, status bar UTF-8 / Zoom / Console. Needs shell + avatar edit |
| 10 | Import dialog | `ced12a93fd1a4957a19067a618d7089e` | Good |
| 11 | Settings | `2deb00d7f4c84bef8b3570ebfc07b4ba` | ✅ Shell standard applied in place via DOM ops (2026-11-10). Nits: logo is a gradient tile with a divider below it, and the top bar has a "Test Point / Settings" breadcrumb plus a "Saved" chip |
| 12 | Dialogs & feedback components sheet | `db66394568e7446c898bc41af769ac4b` | Good |
| 13 | Account dialogs — GitHub OAuth & Waiting state | `d08e5905101f4d4e9e6e6d87fa3a7bea` | ✅ Dark: 440px 28px-radius dialogs over the dimmed shell: "Account" with a neutral "Continue with GitHub" button and "Signing in with GitHub keeps your guest workspace.", and "Waiting for GitHub" with spinner and Cancel. Built in Flutter. Still to design: signed-in dialog and guest-data warning (built from the doc spec), light variant |
| — | Stale duplicates `d6e29242…`, `1215c640…`, `89a58325…` | — | ✅ Gone from `list_screens` (2026-11-10) |
| — | Fallback generation of #5 (sent 2026-11-10) | — | Never appeared. If a second "Response — Error & Loading states" shows up later, delete it and keep `a8e02c1a…` |
| L1 | Response Success (Light), early variant | `19efbd895bee44e4bcc073fc8c6bd39b` | Made too early; regenerate after the dark screens are fixed |

## MCP Lab screens (Phase 8, started 2026-11-15)
Spec: [../features/mcp-lab/feature-specification.md](../features/mcp-lab/feature-specification.md). Dark design system `assets/1955584032106423519`.

**MCP Lab shell additions** (on top of the SHELL STANDARD below):
- Nav rail gets a 4th item **MCP Lab** (hub icon) between Environments and Settings.
- Sidebar is **"MCP SERVERS"** + count + Import; filter "Filter servers" (`Ctrl+K`); full-width "+ Add server"; rows = status dot (green connected / gray idle / amber auth needed) + name + fixed 52px transport tag (`STDIO` / `HTTP` / `SSE`); footer "N servers".
- Top-bar tabs are open servers (status dot + name); environment dropdown unchanged.
- Status bar left: "Connected · <server> · <transport> · <era> era".
- Server main area has a tab strip: Settings, Tools, Resources, Prompts, Protocol, Console (Network instead of Console for HTTP servers).

| # | Screen | Screen ID | Status |
|---|---|---|---|
| 14 | MCP Lab — Servers & Server settings | `84e7bc3a7ec34fa5b625994bf52ddbbb` | ✅ Landed in ~4 min (2026-11-15). Shell, MCP Lab rail item, transport tags, deprecated SSE/Roots labels, secret footer and status bar all correct. Nits: amber row badge says "Auth" (want "Auth needed"); sidebar footer has a stray layout icon |
| 15 | MCP Lab — Tool call + pinned Protocol monitor | `0fe876c6afa84874b5735c89cf4b43a4` | Landed 2026-11-15; structure correct (tools list, schema form, result + "Matches outputSchema", Protocol monitor with paired frames and `_meta.progressToken`). Wrapping/clipping in the center column ("Call tool", "Copy as JSON", "days (integer, 1–7)", "idempotent", result JSON) and "+ + Add server". Fix edit landed **in place** in ~5 min: single-column form, "Call tool" + `Ctrl+Enter` and "Copy as JSON" on one line, single "+". Accepted with nits (fix in Flutter, not Stitch): "Add server" now wraps; render is wider than the frame so the right edge (Development pill, Export, monitor edge) is cut; "idempotent" chip and "Structured" tab missing/clipped; result JSON lines clipped |
| 16 | MCP Lab — Monitors (Protocol / Network) | `0575a546cf6142569af193e77bfc7c4a` | ✅ Landed in ~4 min (2026-11-15). Content correct: negotiated-era badge, filter chips + `Ctrl+F`, `server/discover` 200, `tools/list` complete · ttl 60 s, MRTR conversation group (2 rounds), typed `-32602` / `-32022` (+ supported versions) error rows, headers pane with highlighted `Mcp-Method`/`Mcp-Name`, `Mcp-Param-Repo`, masked `Authorization`, `_meta` section. Nit: right edge cut off (Development pill, Disconnect, `_meta` values). Cause: prompts for #15/#16 said 1440px but project frames are 1280px; use 1280px from #17 |
| 17 | MCP Lab — Resources & Prompts | `7e50576a4835412e833885331c63edd5` | ✅ Landed in ~4 min (2026-11-15); 1280px prompt fixed the overflow. Resources (5) / Templates (2) toggle, mime tags, "Load next page · Page 1 of 2", Subscriptions with Unsubscribe, resource viewer with Subscribe / Copy, template field with `completion/complete` suggestions and Read. Nits: "1.2 KB" tag wraps; Environments rail icon is sliders (others use globe); template card title hidden by the dropdown. **Gap:** no Prompts view was drawn (title only); design it later or build from spec FR-PRM |
| 18 | MCP Lab — Dialogs (stdio approval, pending request, destructive confirm) | `b7b2dc79f685445ca617dbab0156f50a` | ✅ Returned directly (no timeout), 2026-11-15. stdio approval (resolved `npx.cmd`, args, directory, env keys, amber "Changed since last approval: args"), pending request (`input_required`, Round tag, schema form, "1 more pending · sampling" queue, Decline / Cancel / Accept), URL-mode "Open in browser?" with bold domain, destructive confirm (red, "hints, not guarantees", Don't ask again). Nits: "Round 1 of 2" tag clipped by dialog 3; sheet footer wraps |

| 19 | MCP Lab — Prompts | `78ad639e6ea349aca82e9694224aad3e` | ✅ Landed in ~4 min (2026-11-15). Closes the #17 gap: prompt list with arg-count tags, argument form with `completion/complete` dropdown (Lisbon / Lisburn / Lismore), `{{defaultTone}}` variable chip resolving to "friendly", rendered messages (user / assistant role badges, embedded resource `weather://lisbon/…` + mime, image block), `prompts/get · 84 ms`. Nit: a "Context ready for…" note in the messages footer wraps |
| 20 | MCP Lab — Tasks & Logs | `0038fb73c35b4c22a0f29b6c1dbd1ee3` | ✅ Landed in ~4 min (2026-11-15). Tasks tab with status filter chips, "re-polls held handles (no tasks/list in modern era)" + Refresh, rows Working (62% progress) / Input required (Respond) / Completed / Failed, detail drawer (pollInterval, ttl, statusMessage, Cancel task / Copy ID). Logs panel with "Deprecated · legacy support" tag, Level dropdown, "sent per request in _meta", level-colored rows, "142 messages · showing last 500". Nits: render shorter than 800px; stray layout icon in sidebar footer again |
| 21 | MCP Lab — Add server & Import | `684b6c75e37740ecb0f69e78e85f3b65` | ✅ Landed in ~4 min (2026-11-15). Add server: stdio / Streamable HTTP / SSE (Deprecated) segmented control, resolved `npx.cmd` hint, arg chips, working dir, env table with secret `{{weatherKey}}` "stored on this device", era dropdown "Auto (try modern, fall back to legacy)", per-device approval note, Cancel / Test connection / Save server. Import: source file + format auto-detect, "Will be added (3)" with transport tags and full commands, amber "nothing connects until you open a server", `${input:github_token}` → `{{githubToken}}`, Skipped (1), "Import 3 servers". Nits: dialogs fill the frame so the dimmed shell barely shows; large vertical gaps between sections |
| 22 | MCP Lab — OAuth sign-in (HTTP server) | `9b2dad36fab346e8b36db248acd80623` | ✅ Landed in ~4 min (2026-11-15). 401 + `WWW-Authenticate` banner, 5-step discovery stepper (protected-resource metadata → issuer → CIMD registration with "fallback: static → DCR" → waiting, PKCE S256 + `resource` → token exchange "verify iss before redeeming code"), scopes chips, loopback-only callback, browser-wait card (Copy sign-in link / Open browser again / Cancel), Saved credentials "keyed by issuer. Never synced" with Refresh now / Clear & revoke. Nits: "+ + Add server" double plus; weather-server tab dot green (should be gray); invented "OAuth 2.0 / MCP 2026" tag |
| 15L | MCP Lab — Tool call + Protocol monitor (Light) | `aee5a32df3b145308f104466072e6ab8` | ✅ `generate_variants` (REFINE, COLOR_SCHEME) from #15, 2026-11-15. Light tokens applied correctly (surfaces, dark-teal primary, green/amber/red). Inherits #15's right-edge cut; "read-only" tag now overlapped by the Form/JSON toggle |
| 14L | MCP Lab — Servers & Server settings (Light) | — | Not produced: the `generate_variants` call with both #14 and #15 selected returned only one variant (15L). Not needed; 15L is the light reference. To get one, call `generate_variants` with #14 alone |

**MCP Lab next steps**
1. ~~Prompts view~~ #19 · ~~Tasks / Logs~~ #20 · ~~Add-server + Import~~ #21 · ~~OAuth state~~ #22 · light variant 15L. All MCP Lab screens from the spec now have a design.
2. Optional polish pass (Flutter can fix instead): #15 overflow + "Add server" wrap, #16 right-edge cut, #17 "1.2 KB" wrap and rail icon, #14 "Auth needed" badge, #22 "+ +" and tab dot, #20/#14 sidebar footer icon.
3. Light variants for the rest are optional: the Flutter theme derives light from the same tokens, so 15L is enough as a reference.
5. Lesson: `generate_variants` with several selected screens may return only one variant in total; select one screen per call.
4. Lesson: ask for a **1280px-wide** frame (project frame width); 1440px prompts overflow.

## Known issues found in review
- **Text wrapping and clipping** in the Stitch renders, for example "Form-/data", "SECRE/T", "PINNE/D", "Active/Environment", a squashed filter field ("Fil"), names cut short ("List p…"), and status-bar text split over two lines.
- **Inconsistent shell across screens:** the logo (TP circle / bolt / "TEST POINT" / "TP v1.0"), the rail-bottom items (+, avatar, help), the top-bar icons (code, eye, gear, cookies), the sidebar title (EXPLORER vs COLLECTIONS), ⌘/^ vs Ctrl, DEL vs DELETE, pill vs plain method tags, and the status-bar contents (Console, Zoom, UTF-8).
- **Out-of-scope items Stitch keeps adding:** Tests/Scripts tabs, Visualizer, Sync/Synced, Share, Run collection, Audit log. (The user avatar is now in scope: see the shell standard.)

## Stitch MCP gotchas
- `generate_screen_from_text` and `edit_screens` usually return **"operation timed out"**. A generation still finishes server-side (2–6 min), so poll with `list_screens` and don't retry blindly. A **timed-out edit is sometimes lost** (this happened to Welcome and Error once), so check the HTML afterwards.
- In-place DOM edits **do not refresh the screenshot**: the file ID and size stay the same. To verify, download the HTML (`download_file` on `htmlCode.name`) or look in the Stitch UI.
- `download_file` screenshots are large base64 JSON. They are auto-saved to tool-results and can be decoded with PowerShell `[Convert]::FromBase64String`.
- `update_design_system` returned "invalid argument". It isn't needed, because the design systems exist and are passed via `designSystem` on generation.
- `GEMINI_3_5_FLASH_LITE` handled small text-only edits quickly without timing out.
- A timed-out edit can take **8+ minutes** to land (#5 on 2026-11-10). Wait at least 10 minutes before treating it as lost, and **do not send a fallback generation meanwhile**: jobs seem to queue per project, so an extra job delays the next edit (#6 had not landed after 13 min while a #5 generation was queued).
- A timed-out edit can land as a **new screen** with the same title instead of updating in place (this happened to Body and Response Success). After each edit, compare the `list_screens` output for new IDs as well as changed `htmlCode.name` values.

## SHELL STANDARD (apply to every workspace screen)
- **Nav rail 72px:** top is the teal rounded-square bolt logo only, with no text, version or dot. Items are icon above label, label 11px on one line: Collections, Environments, Settings. The active item gets a teal tonal pill and teal text. The bottom holds only the theme toggle (moon), help (?) and the user avatar (guest icon for anonymous users, the user's initial when signed in; click opens the Account dialog). No "+" button.
- **Top bar 44px:** request tabs show a method pill and the full name on one line (max 200px, then ellipsis), an amber unsaved dot and a close ×, followed by a "+" new-tab button. The right side holds only the environment dropdown pill (green dot + "Development" + chevron), a layout toggle and an overflow ⋮. No code, eye, gear or cookies icons.
- **Collections sidebar 280px:** a header row with "COLLECTIONS" and the count "8" on the left and "Import" on the right; a filter field ("Filter requests" with a "Ctrl+K" hint); a full-width teal "+ New" split button; the tree under "Petstore API" (GET List pets, POST Create pet, GET Get pet by ID, PUT Update pet, PATCH Update pet status, DEL Delete pet) plus a collapsed "Authentication" (2). Method pills are a fixed 52px wide. The footer shows only "8 requests".
- **Status bar 28px:** the left side shows "Ready" and "Development · http://localhost:8080"; the right side shows "Proxy: Off" and a layout icon. No Console, Zoom or UTF-8.
- **Keyboard hints:** always Ctrl, never ⌘ or ^.
- **No wrapping:** every label, chip, badge, tab, button and status text stays on one line with no clipping or overlap, and containers grow to fit.

## Next steps
1. ~~Verify #1–#4~~ Done 2026-11-10 (see the inventory). In the Stitch UI, delete the stale `d6e29242…` (old Body), `1215c640…` (old Response Success) and `89a58325…` (duplicate Params).
2. Shell + avatar pass, **one screen at a time, wait ≥10 min each**: #5 ✅ done; #6 edit pending (check `htmlCode.name` / new same-title screen); then #7, #8, #9 (issues listed in the inventory). The prompt is the SHELL STANDARD section below plus the screen-specific removals.
3. Avatar + nit pass on #1–#4 and #11 (avatar at rail bottom on all of them). Nits: #1 `{{baseUrl}}` double braces and `Ctrl+Enter`; #4 remove the Tests tab, `⌘F` → `Ctrl+F`, green 2xx chip; #11 a flat tonal bolt logo with no divider, and drop the breadcrumb and Saved chip from the top bar.
3b. Generate #13 Account dialogs with the Dark design system, each shown as a modal dialog (28px radius, scrim) over the dimmed workspace shell: **13a** guest dialog (one "Continue with GitHub" button, "Signing in with GitHub keeps your guest workspace", plus a "Waiting for GitHub" state with Cancel) and **13b** signed-in dialog (GitHub name or email + Sign out) plus the guest-data warning dialog ("Your guest workspace will not be carried over", Cancel / Sign in anyway). These could also be added to the #12 dialogs sheet.
4. ~~Fix #11 Settings~~ Done 2026-11-10.
5. Re-check every screen for wrapping, clipping and consistency.
6. Then generate the light variants (`generate_variants`, REFINE, COLOR_SCHEME, using the light tokens above) for Params, Response, Environments, Welcome and Account (13a), and delete the early L1 variant.
7. Write the design-to-Flutter handoff: map the tokens to `ColorScheme` plus a `ThemeExtension` (method/status colors) for `lib/core/ui/theme/`.
