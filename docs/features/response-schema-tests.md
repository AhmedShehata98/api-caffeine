# Response schema tests

## User flow

Open **Test → Test schema** on a request, enter an explicit JSON Schema, enable the test, then send. Capture the current draft at send time. Evaluate the complete response locally after receipt, including responses with 4xx and 5xx statuses. Keep HTTP status, timing, and body available independently of validation.

## Functional acceptance cases

| Given | Expected outcome |
| --- | --- |
| A new or legacy request | Testing defaults to off. Sending does no schema work. |
| A saved request is reopened | Restore the schema source and enabled flag. Start without a previous result. Disabling retains the source. |
| Required integer id and string name both match | Schema passed. |
| HTTP 200 with string id and missing name | Schema failed. Show both paths and expected conditions. Attach a missing property to its existing parent in the body view. |
| Completed 4xx or 5xx with a matching error payload | Schema passed alongside the original HTTP status. |
| Current schema is invalid | Send proceeds. Show Test couldn’t run · Invalid schema and Edit schema. Preserve the draft. |
| Malformed JSON or invalid UTF-8 in the payload | Show a response diagnostic and retain access to the body. |
| JSON with an unexpected content type | Validate the body when enabled. Accept any JSON root permitted by the schema, including null. |
| Empty HEAD, 204 or 304 | Skipped · No body expected. Empty 205 remains a proposed extension pending confirmation. |
| Empty 200 | Failed · Expected JSON body. |
| Cancelled request or transport failure before completion | No schema verdict for that run. |
| Schema edited after sending | Bind the result to its captured revision. Indicate when the editor now shows a different schema. |

## Non-functional acceptance criteria

- Publish the HTTP result independently of schema processing. Keep validation time outside HTTP duration. Validate the full body even when the preview is truncated.
- Scope results to the tab and send operation. Exercise rapid resend, concurrent tabs and closing a tab during validation.
- Keep validation local. Exclude schema settings from outgoing requests and avoid logging response values. Persist configuration through the existing request repository and workspace access rules.
- Bound work and diagnostic output. Distinguish an incomplete check from a known mismatch. Label capped issue lists accurately.
- Verify keyboard access, visible focus, screen-reader status announcements and measured text contrast in both themes. Preserve the selected body view when the result arrives.

## Design references

- [Stitch workspace](https://stitch.withgoogle.com/projects/3561297165959721299) contains configuration, failed response, recovery and a four-state reference for disabled, checking, passed and skipped.
- [Recovery](https://stitch.withgoogle.com/projects/3561297165959721299?node-id=d5109325437f4e4d96b11049022c436f) and [corrected light inspector](https://stitch.withgoogle.com/projects/3561297165959721299?node-id=d6cc66a6ddb148eabf939e955913a0f2). Use **Edit schema** for both. Preserve the existing Flutter shell and theme tokens.

## Implementation sequence

1. **Validator feasibility check.** Compare Dart validators against fixtures for nested objects, arrays, required fields, nullable values, extra properties and unsupported rules. Check dialect support, diagnostic paths, local references, disabling remote resolution, and behavior on large inputs. Record the supported keyword set and measured limits before selecting a dependency.
2. **Persist request configuration.** Extend the request draft and row mapper. Add a backwards-compatible Supabase migration. Verify legacy rows, save/reopen, disabled drafts and schema formatting round trips.
3. **Integrate post-response validation.** Reconcile with ongoing response-viewer work. Preserve decoding validity, publish the response first, then publish the run-scoped verdict. Cover the acceptance cases in service and provider tests.
4. **Connect the editor and inspector.** Reuse the request tab, editor and response components. Verify focus restoration, issue navigation, theme contrast and both pane layouts. Run relevant Flutter tests and static analysis.

## Validator feasibility findings

### Recommendation

Carry **json_schema_builder 0.1.7** into integration, conditional on a schema preflight and bounded execution. Its synchronous API and segment-based diagnostics met the inspector's navigation requirements in the fixtures. The comparison did not establish a safe production execution limit.

Use an explicit **Draft 2020-12 subset**. Start with boolean schemas, type (including nullable unions), properties, required, single-schema items, additionalProperties (boolean or schema), and acyclic document-local JSON Pointer references into schema nodes under $defs. Verify and consume the canonical root $schema declaration before calling validateSync, or supply a trusted in-memory metaschema. Native validateSync threw for the explicit declaration with an empty registry. The equivalent schema with the declaration omitted resolved the $defs pointer and reported the expected mismatch. [json_schema_builder 0.1.7](https://pub.dev/packages/json_schema_builder/versions/0.1.7).

### Stitch fixture and navigation

Both engines passed `{"user":{"id":42,"name":"Ada"}}`. Against the same schema, `{"user":{"id":"42"}}` produced these raw diagnostics.

**json_schema 5.2.2**

```json
[
  {"instancePath":"/user","schemaPath":"/properties/user/required","message":"required prop missing: name from {id: 42}"},
  {"instancePath":"/user/name","schemaPath":"/properties/user/required","message":"required prop missing: name from {id: 42}"},
  {"instancePath":"/user/id","schemaPath":"/properties/user/properties/id","message":"type: wanted [integer] got 42"}
]
```

The two required diagnostics represent one missing field. This fixture maps to `$.user.id` and `$.user.name`, with `$.user` as the missing field's anchor. General mapping from the raw result alone is ambiguous. The shared-reference fixture produced two identical diagnostics with instance `/a/b`, schema `/definitions/id` and the same message for `$["a/b"]` and `$.a.b`. The comparison uses the package's synchronous Draft 7 API. [json_schema 5.2.2](https://pub.dev/packages/json_schema/versions/5.2.2).

**json_schema_builder 0.1.7**

```json
[
  {"path":["user"],"error":"requiredPropertyMissing","details":"Required property \"name\" is missing"},
  {"path":["user","id"],"error":"typeMismatch","details":"Value `42` is not of type `integer`"}
]
```

The spike asserts the displayed paths `$.user.id` and `$.user.name` with anchors `$.user.id` and `$.user`, respectively. The alternative supplies the parent segments and a typed `requiredPropertyMissing` code. The child name comes from the pinned message's fixed prefix and suffix. The assertions cover several missing siblings and keys containing dots, slashes, tildes and quotes. Keep those assertions on upgrades. If the format changes, keep the parent link and use a generic required-property message until the child can be resolved. Render array indices according to the decoded parent type. With a numeric object key, the result is `$[0]["0"]`.

### Other fixture results

| Case | json_schema 5.2.2 | json_schema_builder 0.1.7 |
| --- | --- | --- |
| Nested arrays, multiple missing siblings, punctuation in keys | Two diagnostics per missing sibling and unescaped slash-delimited paths. | One diagnostic per missing sibling and intact segments, including slash paths and quoted keys. |
| `additionalProperties` as false or as a schema | Boolean form reported the parent with the extra key in the message. Schema form reported the child type mismatch. | Both forms gave the extra key's path. Boolean form also emitted `notConditionViolated`. Schema form emitted both `additionalPropertyNotAllowed` and the child mismatch. Collapse redundant diagnostics and preserve the applicable condition. |
| Nullable union, false, null, string, fractional number, 1.0 as integer, empty array and boolean schemas | Expected verdicts for all exercised cases. | Same. |
| Type-less required and items | Enforced against objects and arrays. The object rule allowed a boolean. | Same. |
| Invalid keyword values | Rejected invalid type, required and items values at construction. Duplicate union entries passed. | Invalid type, required and items values threw during validation. Duplicate union entries passed. |
| Unknown rule, known rule outside the subset, arbitrary property names | Ignored `minPropertiez`, enforced `minimum`, and accepted the property names case. | Same. |
| Document-local `$ref` | Plain Draft 7 definitions pointer passed and mismatched as expected. The escaped `$defs` fixture failed construction, including with the declaration omitted. Missing pointer rejected even with the property absent. | Plain pointer resolved. The implicit 2020-12 escaped pointer `#/$defs/a~1b~0c` resolved. An evaluated missing pointer produced `refResolutionError`. The same missing pointer in an absent property yielded no errors. |
| External HTTP, absolute file and relative file references | Synchronous construction without a `RefProvider` rejected the references. | `validateSync` threw `SchemaResolutionRequiredException` when evaluated. An HTTP ref in an absent property yielded no errors. |
| Same-instance `$ref` to `#` | Reported a cycle via `FormatException` during validation. | Threw `StackOverflowError`. |
| Malformed input | Dart JSON decoding reported the correct schema or response parse stage. Strict UTF-8 rejected an illegal byte inside a JSON string. Lossy decoding replaced it with U+FFFD and JSON parsing still succeeded. | Same decoding path. |

Both native synchronous paths recorded zero Dart file constructions and zero HTTP client creations across the guarded cases, including an unsupported external metaschema. The harness traps file and HTTP client creation during construction and validation. Source review confirmed that json_schema's synchronous path uses supplied providers for external resolution and json_schema_builder's `validateSync` resolves through the in-memory registry. The asynchronous APIs have external fetch paths. [json_schema reference API](https://pub.dev/packages/json_schema/versions/5.2.2) and [json_schema_builder reference API](https://pub.dev/packages/json_schema_builder/versions/0.1.7).

Run app preflight before instance validation. Validate keyword shapes, reject unknown and unsupported schema-position keywords, check the dialect, walk schema nodes including unused branches and `$defs`, resolve each permitted pointer to a schema node, and reject external references and cycles. Treat keys inside `properties` and `$defs` as names. Classify construction and resolution errors as invalid configuration. Both engines include response values in some raw details, including an entire parent object in json_schema's missing-property message. Build display text from the applicable rule and path and keep raw messages out of application logs.

### Benchmarks and limits

Windows x64, NT 10.0.26300, Intel Core i5-13450HX with 16 logical processors, Dart 3.13.7 stable. The isolated `pubspec.lock` records both resolved package versions and all transitive versions. A Dart AOT executable ran 63 fresh processes in sequence, with three samples per case and ten small warmups per process. Each synthetic row has an id and a 36-character label. Sparse fails every thousandth row and the final row. Dense fails every row. Equal-width row values and trailing JSON whitespace keep sizes exact. There were 69, 17,772 and 177,724 rows, respectively.

Times are medians in milliseconds. Peak RSS is the maximum of the three process high-water marks in MiB. It includes runtime, fixture construction, decode and diagnostics. Inputs were available as bytes before timing began. Timings exclude launcher, schema construction, Flutter, normalization, display and isolate handoff. The JSONL output also records RSS immediately after JSON parsing. A printed 0.000 ms is below the timer's microsecond resolution.

| Engine | Mode | Body | Case | Raw issues | UTF-8 ms | JSON ms | Validate ms | Peak RSS MiB |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| json_schema | All | 4 KiB | Pass | 0 | 0.000 | 0.026 | 0.049 | 16.3 |
| json_schema | All | 4 KiB | Sparse | 1 | 0.000 | 0.031 | 0.052 | 16.3 |
| json_schema | All | 4 KiB | Dense | 69 | 0.000 | 0.028 | 0.083 | 17.2 |
| json_schema | All | 1 MiB | Pass | 0 | 0.273 | 6.093 | 12.610 | 50.2 |
| json_schema | All | 1 MiB | Sparse | 18 | 0.305 | 6.637 | 13.806 | 50.2 |
| json_schema | All | 1 MiB | Dense | 17,772 | 0.288 | 6.443 | 27.350 | 60.4 |
| json_schema | All | 10 MiB | Pass | 0 | 3.672 | 77.906 | 102.904 | 131.6 |
| json_schema | All | 10 MiB | Sparse | 178 | 3.798 | 77.202 | 101.070 | 132.0 |
| json_schema | All | 10 MiB | Dense | 177,724 | 4.235 | 77.537 | 254.796 | 169.3 |
| json_schema_builder | All | 4 KiB | Pass | 0 | 0.000 | 0.017 | 0.228 | 17.2 |
| json_schema_builder | All | 4 KiB | Sparse | 1 | 0.000 | 0.016 | 0.240 | 17.2 |
| json_schema_builder | All | 4 KiB | Dense | 69 | 0.000 | 0.017 | 0.147 | 17.2 |
| json_schema_builder | All | 1 MiB | Pass | 0 | 0.266 | 5.948 | 40.133 | 59.8 |
| json_schema_builder | All | 1 MiB | Sparse | 18 | 0.253 | 6.235 | 39.378 | 59.8 |
| json_schema_builder | All | 1 MiB | Dense | 17,772 | 0.247 | 7.438 | 50.959 | 67.2 |
| json_schema_builder | All | 10 MiB | Pass | 0 | 3.492 | 73.775 | 365.174 | 142.8 |
| json_schema_builder | All | 10 MiB | Sparse | 178 | 3.523 | 74.452 | 370.489 | 142.9 |
| json_schema_builder | All | 10 MiB | Dense | 177,724 | 3.802 | 76.549 | 492.246 | 222.5 |
| json_schema | First | 10 MiB | Pass | 0 | 3.979 | 79.960 | 101.038 | 131.3 |
| json_schema | First | 10 MiB | Sparse | 1 | 3.472 | 80.518 | 0.664 | 121.9 |
| json_schema | First | 10 MiB | Dense | 1 | 3.423 | 75.862 | 0.052 | 119.0 |

The measured 1 MiB case is a starting point for testing a provisional byte admission limit. The 10 MiB dense builder case took about 492 ms in validation and peaked at 222.5 MiB process RSS. Compact arrays, many rules per node and concurrent runs change the work per byte. Neither benchmark size establishes a safe production threshold.

Keep a finite display cap and report that diagnostics were capped. Both full-validation APIs allocate the raw list before a caller can truncate it. The first-error mode in json_schema stops on the first mismatch and would return only one Stitch issue. It still scans matching data, as shown by the 10 MiB passing control. The builder path exposed no equivalent diagnostic-count limit.

Before enabling validation in production, prove enforceable limits for schema size, depth and reference expansion, and for response bytes, tree depth and work or issue allocations. Use a worker isolate with explicit cancellation and a deadline to protect responsiveness. Cancellation by the caller alone leaves synchronous validation running, and a deadline does not impose a heap bound. A bounded diagnostic collector or another verified bound on worst-case allocations is needed. Apply byte admission before decoding, and benchmark compact and deep payloads and concurrent runs before choosing thresholds. If processing stops before a mismatch is known, show **Test couldn’t complete**. Once a mismatch is known, show **Failed** and mark any incomplete diagnostic list.

### Reproduce on Windows

The source templates in `tool/response_schema_spike` materialize as Dart files in the temporary package. This keeps spike dependencies out of the Flutter app's analysis. The first sandboxed resolution reported “Got socket error trying to find package json_schema at https://pub.dev.” The approved retry resolved both packages. Run from the repository root with Dart on PATH.

```powershell
$source = Join-Path (Get-Location) 'tool/response_schema_spike'
$spike = Join-Path ([IO.Path]::GetTempPath()) ('response-schema-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $spike | Out-Null
foreach ($name in 'pubspec.yaml', 'pubspec.lock') {
    Copy-Item -LiteralPath (Join-Path $source $name) -Destination $spike
}
foreach ($name in 'spike.dart', 'fixtures.dart') {
    Copy-Item -LiteralPath (Join-Path $source "$name.in") -Destination (Join-Path $spike $name)
}
Push-Location -LiteralPath $spike
try {
    dart --version
    dart pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
    dart analyze
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed' }
    dart run spike.dart fixtures | Set-Content -Encoding UTF8 fixtures.jsonl
    if ($LASTEXITCODE -ne 0) { throw 'Fixture assertion failed' }
    dart compile exe spike.dart -o spike.exe
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    $results = foreach ($sample in 1..3) {
        foreach ($engine in 'workiva', 'builder') {
            foreach ($size in 4096, 1048576, 10485760) {
                foreach ($case in 'pass', 'sparse', 'dense') {
                    & .\spike.exe bench $engine $size $case
                    if ($LASTEXITCODE -ne 0) { throw "Unexpected issue count for $engine $size $case" }
                }
            }
        }
        foreach ($case in 'pass', 'sparse', 'dense') {
            & .\spike.exe bench workiva 10485760 $case first
            if ($LASTEXITCODE -ne 0) { throw "Unexpected first-error issue count for $case" }
        }
    }
    $results | Set-Content -Encoding UTF8 bench.jsonl
    Write-Output $spike
} finally {
    Pop-Location
}
```

Each fixture reports the expected product outcome alongside the native result. The harness asserts representative builder navigation paths, I/O counters and benchmark issue counts. The deliberately invalid and unsupported fixtures expose native behavior before app preflight.

## Request configuration persistence

`HttpRequestDraft` and `RequestRowMapper` now carry the enabled flag and the original schema source through the request save flow. The migration adds an off flag and empty source for existing and new rows. It also updates collection duplication to copy both fields under the existing workspace policies. Apply the migration before deploying a client that writes these columns.

The request, collections and import suites passed with 197 tests, and static analysis was clean. The Supabase repository integration test was skipped because the local stack was unavailable. An isolated PostgreSQL 17.5 check applied the migration over an existing request and verified defaults, verbatim text, collection copies, member access and the function's execute grants.

## Run-scoped validation progress

The request module records UTF-8 validity and stores a schema verdict against the captured send and tab. A bounded evaluator covers the subset above, with preflight, a cancellable worker, a bounded queue, and capped diagnostics. Empty 205 responses are skipped along with empty HEAD, 204, and 304 responses. The Test tab edits the schema and enabled flag. The response inspector shows the verdict and navigates issues to their body anchors. Its recovery action opens the editor, and a changed schema is identified against the captured source.

The implementation uses provisional limits of 64 KiB per schema, 1 MiB per response, 64 nesting levels, 100,000 traversal steps, 50 displayed issues, and a 500 ms worker deadline. In a single Windows Flutter test run, four jobs queued together completed in 28, 31, 45, and 47 ms from submission. The alternating fixtures were a 60,001-byte array of 30,000 integers checked against an item type and a 60-level nested array checked against `true`. All passed. These debug-mode measurements do not establish peak memory or production limits. The full requests test suite passed and Dart analysis reported no issues.
