# MCP catalog database verification

Run from the repository root on Windows with Docker Desktop and Supabase CLI:

```powershell
powershell -NoProfile -File tool/verify_mcp_database.ps1
```

The verifier creates a unique project under `.dart_tool/mcp_db_replay_<suffix>`.
It copies the committed migrations, seed and SQL tests, uses API/database ports
55321/55322 (shadow 55320), starts that project, and resets **only that isolated
project**. It replays all migrations and the seed, then runs `supabase test db`.
An occupied port aborts before starting or stopping any project. Reset and cleanup
recheck the scratch path, unique project ID and exact API/database ports.

By default the verifier removes its temporary containers and database data in a
finally block. It leaves the ignored configuration and `verification.json` as
evidence. CLI output containing keys is captured without being printed or logged;
only the isolated API URL and public anon key are written to ignored
`local_defines.json` for optional REST checks. No service-role key is written.

If the existing `supabase_db_test_point` container is running, fingerprints of its
auth users, public users, organizations, memberships, workspaces and MCP catalog
must match before and after verification. The verifier never resets that project,
copies linked-project state, or invokes a remote database command.

For additional REST checks, pass `-KeepRunning`; the success output identifies the
workdir. Run `test/integration/mcp_catalog_schema_test.dart` with that workdir's
`local_defines.json`, then stop **that named workdir** with
`supabase stop --workdir <printed-workdir> --no-backup`. The normal Flutter test
command currently has the separate `cnativeapi` hook blocker; this session used
the existing unit-only harness for the three REST tests. Do not point a reset at
the main project to work around a test-runner issue.

The 33 transactional pgTAP assertions cover actual authenticated/anon database
roles, owner and shared-member CRUD, two workspaces in an organization, explicit
multi-organization membership, foreign reads/writes/transfers, self-grant denial,
membership revocation without changing the subject, and workspace cascades. SQL
fixtures roll back, including auth-trigger-created personal organizations. The
three REST cases separately cover constraints, real repository serialization,
marked-secret placeholders and anonymous/outsider denial through the API.

This verifies local migration replay and these database security cases. It does
not certify remote deployment, every application table/policy, OAuth/account-link
flows, automatic app-side access-revocation discovery, or native secure storage.
