param([switch]$KeepRunning)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$projectId = "api_caffeine_mcp_replay_$suffix"
$replayRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot ".dart_tool/mcp_db_replay_$suffix"))
$supabaseRoot = Join-Path $replayRoot 'supabase'
$cli = (Get-Command supabase -ErrorAction Stop).Source
$docker = (Get-Command docker -ErrorAction Stop).Source
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Invoke-CapturedNative([string]$Binary, [string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& $Binary @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    # Supabase output can contain privileged keys. Never emit the captured text.
    return [pscustomobject]@{ Code = $code; Lines = $lines }
}

function Assert-Success($Result, [string]$Step) {
    if ($Result.Code -ne 0) { throw "$Step failed (exit $($Result.Code)). No credential output was printed." }
}

function Assert-IsolatedProject {
    $expectedParent = [IO.Path]::GetFullPath((Join-Path $repoRoot '.dart_tool')) + [IO.Path]::DirectorySeparatorChar
    if (!$replayRoot.StartsWith($expectedParent, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Replay directory escaped the workspace scratch directory.'
    }
    $config = [IO.File]::ReadAllText((Join-Path $supabaseRoot 'config.toml')).Replace("`r`n", "`n")
    if ($config -notmatch ('(?m)^project_id = "' + [Regex]::Escape($projectId) + '"$') -or
        $config -notmatch '(?m)^\[db\]\nport = 55322$' -or
        $config -notmatch '(?m)^\[api\]\nport = 55321$' -or $projectId -eq 'api_caffeine') {
        throw 'Isolated project identity or database port changed; refusing reset/stop.'
    }
}

$probe = Invoke-CapturedNative $docker @('info', '--format', '{{.ServerVersion}}')
Assert-Success $probe 'Docker availability check'
foreach ($port in @(55320, 55321, 55322)) {
    if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
        throw "Replay port $port is already in use; no existing service was stopped."
    }
}

$baselineSql = "select md5(coalesce(string_agg(value, '|' order by value), '')) from (select 'auth:' || row_to_json(t)::text value from auth.users t union all select 'users:' || row_to_json(t)::text from public.users t union all select 'orgs:' || row_to_json(t)::text from public.organizations t union all select 'members:' || row_to_json(t)::text from public.organization_members t union all select 'ws:' || row_to_json(t)::text from public.workspaces t union all select 'mcp:' || row_to_json(t)::text from public.mcp_servers t) rows;"
$mainRunning = Invoke-CapturedNative $docker @('container', 'inspect', '--format', '{{.State.Running}}', 'supabase_db_api_caffeine')
$baseline = $null
if ($mainRunning.Code -eq 0 -and ($mainRunning.Lines -join '') -eq 'true') {
    $before = Invoke-CapturedNative $docker @('exec', 'supabase_db_api_caffeine', 'psql', '-U', 'postgres', '-d', 'postgres', '-At', '-c', $baselineSql)
    Assert-Success $before 'Existing database fingerprint'
    $baseline = ($before.Lines -join '').Trim()
}

New-Item -ItemType Directory -Path (Join-Path $supabaseRoot 'migrations') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $supabaseRoot 'tests') -Force | Out-Null
Copy-Item -Path (Join-Path $repoRoot 'supabase/migrations/*.sql') -Destination (Join-Path $supabaseRoot 'migrations')
Copy-Item -Path (Join-Path $repoRoot 'supabase/tests/*.sql') -Destination (Join-Path $supabaseRoot 'tests')
Copy-Item -LiteralPath (Join-Path $repoRoot 'supabase/seed.sql') -Destination (Join-Path $supabaseRoot 'seed.sql')
$config = @"
project_id = "$projectId"
[api]
port = 55321
schemas = ["public", "graphql_public"]
[db]
port = 55322
shadow_port = 55320
major_version = 17
[db.seed]
enabled = true
sql_paths = ["./seed.sql"]
[auth]
enabled = true
site_url = "http://127.0.0.1:3000"
enable_anonymous_sign_ins = true
[studio]
enabled = false
[local_smtp]
enabled = false
[storage]
enabled = false
[realtime]
enabled = false
[analytics]
enabled = false
[edge_runtime]
enabled = false
"@
[IO.File]::WriteAllText((Join-Path $supabaseRoot 'config.toml'), $config, $utf8)
$passed = $false
try {
    Assert-IsolatedProject
    $started = Invoke-CapturedNative $cli @('start', '--workdir', $replayRoot, '-o', 'json')
    Assert-Success $started 'Isolated Supabase startup'
    Assert-IsolatedProject
    $reset = Invoke-CapturedNative $cli @('db', 'reset', '--workdir', $replayRoot)
    Assert-Success $reset 'Fresh isolated migration/seed replay'
    $tests = Invoke-CapturedNative $cli @('test', 'db', '--workdir', $replayRoot)
    Assert-Success $tests 'Transactional MCP RLS tests'
    $testText = ($tests.Lines | ForEach-Object { $_.ToString() }) -join "`n"
    $testCounts = [Regex]::Match($testText, 'Files=(\d+), Tests=(\d+)')
    if (!$testCounts.Success -or [int]$testCounts.Groups[1].Value -lt 1 -or [int]$testCounts.Groups[2].Value -lt 1) {
        throw 'pgTAP did not report executed tests; refusing a false success.'
    }
    $assertions = [int]$testCounts.Groups[2].Value
    $status = Invoke-CapturedNative $cli @('status', '--workdir', $replayRoot, '-o', 'json')
    Assert-Success $status 'Isolated API configuration'
    $text = ($status.Lines | ForEach-Object { $_.ToString() }) -join "`n"
    $first = $text.IndexOf('{')
    $last = $text.LastIndexOf('}')
    $settings = $text.Substring($first, $last - $first + 1) | ConvertFrom-Json
    if ($settings.API_URL -ne 'http://127.0.0.1:55321') { throw 'Unexpected isolated API URL.' }
    $defines = @{ SUPABASE_URL = $settings.API_URL; SUPABASE_ANON_KEY = $settings.ANON_KEY } | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $replayRoot 'local_defines.json'), $defines, $utf8)
    $unchanged = $null
    if ($null -ne $baseline) {
        $after = Invoke-CapturedNative $docker @('exec', 'supabase_db_api_caffeine', 'psql', '-U', 'postgres', '-d', 'postgres', '-At', '-c', $baselineSql)
        Assert-Success $after 'Existing database recheck'
        $unchanged = ($after.Lines -join '').Trim() -eq $baseline
        if (!$unchanged) { throw 'Existing database fingerprint changed; investigate concurrent writes.' }
    }
    $summary = @{ project = $projectId; workdir = $replayRoot; migrationReplay = 'passed';
        rlsTests = 'passed'; assertions = $assertions; existingDatabaseUnchanged = $unchanged }
    [IO.File]::WriteAllText((Join-Path $replayRoot 'verification.json'), ($summary | ConvertTo-Json), $utf8)
    $passed = $true
    Write-Output "PASS: isolated migrations, seed and $assertions RLS assertions. Workdir: $replayRoot"
    if ($unchanged) { Write-Output 'PASS: existing auth/catalog/organization data fingerprint is unchanged.' }
} finally {
    if (!$KeepRunning -or !$passed) {
        Assert-IsolatedProject
        $stopped = Invoke-CapturedNative $cli @('stop', '--workdir', $replayRoot, '--no-backup')
        Assert-Success $stopped 'Isolated project cleanup'
    }
}
