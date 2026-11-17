# Rich tool/prompt content and output-schema diagnostics

This completes the rich-result presentation slice following the initial monitor
UI. It follows the current orange themes in `lib/core/ui/theme/`; historical Stitch
colour choices do not override project tokens. No dependency was added.

## Result content

Tools and ordered prompt messages now share a content-block presenter:

- Text keeps a Unicode-safe 4,096-code-unit preview and offers an explicit full
  inspector. The full inspector uses the existing bounded read-only code viewer.
- Image blocks reuse the resource image preview, MIME/decoded-size display and
  explicit Save action. Existing 8 MiB encoded-image and 1024-by-1024 decode bounds,
  loading/error states and image-cache eviction continue to apply.
- Audio exposes MIME, decoded byte size and Save without autoplay or a new player
  dependency. Suggested filenames recognize WAV, MP3, Ogg and FLAC MIME types.
- Embedded text/JSON and binary resources reuse the resource content viewer.
  Text copy preserves the original source even when the preview is formatted.
- Resource links show their name, URI and metadata. Open in Resources validates
  current-result ownership and server capability, clears any old template draft,
  and seeds the URI before navigation. It never invokes resources/read or opens a
  browser automatically, and does not assume the link appears in resources/list.
- Tool structuredContent has its own JSON viewer and copy action, alongside the
  existing complete parsed-result JSON viewer.

Explicit binary saves now accept tool/prompt origins only when the supplied block
belongs by identity to that exact current result and its mapped resource data
matches. Replacing/clearing a result or changing scope revokes old exports. The
existing export service rechecks ownership after off-isolate decoding. Once the
native save dialog owns an explicit export, its combined choose-and-write API can
still finish after a scope change; stale completion UI is suppressed as before.
No operation payload is automatically persisted or routed into diagnostic buffers.

## Output-schema diagnostics

Output-schema checking runs off the UI isolate against the submitted tool
definition, using the existing bounded schema subset without coercion or external
reference fetching. The UI distinguishes a supported valid result, missing
structuredContent, invalid structuredContent and an unchecked unsupported schema.
Structured content must be a JSON object; a string containing JSON is not coerced
into one. Intermediate results are explicitly not checked. At most 20 field
findings are rendered, with single-line status/path text and ellipsis.

Findings leave the call outcome, tool-error status, returned values and complete
result JSON unchanged. The validation approach follows the structured-output and
output-schema sections of the [MCP tools specification](https://modelcontextprotocol.io/specification/2025-11-25/server/tools).
This is not a claim of complete JSON Schema validation: unsupported keywords,
dialects or reference patterns remain explicitly unchecked.

## Validation and remaining work

All 291 selected unit/widget tests pass (285 MCP plus six desktop shutdown cases),
followed by the 30 affected UI tests after a final single-line label adjustment.
Static analysis is clean. Twenty-three added cases cover schema validation and
non-coercion, missing/null/unsupported schemas, local references, content mapping,
exact export ownership, cleared/scope-revoked exports, links/manual-read semantics,
audio/image/binary saves, embedded JSON copy, Unicode previews, structured viewers,
non-failing diagnostics and current-theme renders. Reviewed artifacts are
`.dart_tool/mcp_rich_dark.png` and `.dart_tool/mcp_rich_light.png`.

Tests use the existing native-hook-bypass harness and mocked export repositories.
Native file dialogs, full multi-content desktop visual acceptance, playback,
20 MiB end-to-end transport acceptance and native responsiveness remain separate
gates. Existing database/RLS, transport/platform, monitor body/export/pinning and
other S1 acceptance gaps remain open. Next work should audit the remaining S1
acceptance criteria rather than treating these UI slices as full S1 completion.
