import 'dart:convert';
import 'dart:io';

import 'package:test_point/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_trust_digest.dart';

void main() {
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  const context = McpAccessContext(
    userId: 'user-a',
    workspaceId: 'ws-a',
    generation: 1,
  );
  final args = ['--token=argument-canary'];
  final env = {'TOKEN': 'environment-canary', 'PATH': '/approved/bin'};
  final snapshot = McpLaunchSnapshot(
    command: 'node',
    executable: '/approved/bin/node',
    cwd: '/workspace',
    args: args,
    environment: env,
  );
  args.clear();
  env.clear();
  check(
    snapshot.args.isNotEmpty && snapshot.environment.length == 2,
    'Snapshot retained mutable inputs',
  );
  var immutable = false;
  try {
    snapshot.environment['TOKEN'] = 'changed';
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Snapshot environment must be immutable');
  final key = List<int>.generate(32, (i) => i);
  McpTrustRecord digest(
    McpLaunchSnapshot target, {
    McpAccessContext scope = context,
    String serverId = 'server-a',
    List<int>? deviceKey,
  }) => digestMcpLaunch(
    deviceKey: deviceKey ?? key,
    context: scope,
    serverId: serverId,
    snapshot: target,
  );
  final approved = digest(snapshot);
  final stored = McpTrustRecord.fromJson(
    jsonDecode(jsonEncode(approved.toJson())) as Map<String, dynamic>,
  );
  check(
    compareMcpTrust(stored, approved).approved,
    'Unchanged launch lost approval',
  );
  check(
    !compareMcpTrust(null, approved).approved,
    'Missing record must require approval',
  );
  final reordered = McpLaunchSnapshot(
    command: snapshot.command,
    executable: snapshot.executable,
    cwd: snapshot.cwd,
    args: snapshot.args,
    environment: {'PATH': '/approved/bin', 'TOKEN': 'environment-canary'},
  );
  check(
    compareMcpTrust(approved, digest(reordered)).approved,
    'Map order changed trust',
  );
  final changes = <String, McpLaunchSnapshot>{
    'command': McpLaunchSnapshot(
      command: 'other',
      executable: snapshot.executable,
      cwd: snapshot.cwd,
      args: snapshot.args,
      environment: snapshot.environment,
    ),
    'executable': McpLaunchSnapshot(
      command: snapshot.command,
      executable: '/other/node',
      cwd: snapshot.cwd,
      args: snapshot.args,
      environment: snapshot.environment,
    ),
    'cwd': McpLaunchSnapshot(
      command: snapshot.command,
      executable: snapshot.executable,
      cwd: '/other',
      args: snapshot.args,
      environment: snapshot.environment,
    ),
    'args': McpLaunchSnapshot(
      command: snapshot.command,
      executable: snapshot.executable,
      cwd: snapshot.cwd,
      args: ['different'],
      environment: snapshot.environment,
    ),
    'env.TOKEN': McpLaunchSnapshot(
      command: snapshot.command,
      executable: snapshot.executable,
      cwd: snapshot.cwd,
      args: snapshot.args,
      environment: {...snapshot.environment, 'TOKEN': 'changed-secret'},
    ),
    'env.PATH': McpLaunchSnapshot(
      command: snapshot.command,
      executable: snapshot.executable,
      cwd: snapshot.cwd,
      args: snapshot.args,
      environment: {'TOKEN': 'environment-canary'},
    ),
  };
  for (final entry in changes.entries) {
    final result = compareMcpTrust(approved, digest(entry.value));
    check(
      !result.approved &&
          result.changedFields.length == 1 &&
          result.changedFields.single == entry.key,
      'Changed field not detected: ${entry.key}',
    );
  }
  for (final changedScope in [
    const McpAccessContext(
      userId: 'user-b',
      workspaceId: 'ws-a',
      generation: 1,
    ),
    const McpAccessContext(
      userId: 'user-a',
      workspaceId: 'ws-b',
      generation: 1,
    ),
  ]) {
    check(
      !compareMcpTrust(
        approved,
        digest(snapshot, scope: changedScope),
      ).approved,
      'Cross-account/workspace approval reused',
    );
  }
  check(
    !compareMcpTrust(approved, digest(snapshot, serverId: 'server-b')).approved,
    'Approval reused for another server',
  );
  check(
    !compareMcpTrust(
      approved,
      digest(snapshot, deviceKey: List.filled(32, 99)),
    ).approved,
    'Approval reused on another device',
  );
  check(
    compareMcpTrust(
      approved,
      digest(
        snapshot,
        scope: const McpAccessContext(
          userId: 'user-a',
          workspaceId: 'ws-a',
          generation: 2,
        ),
      ),
    ).approved,
    'Same account returning to authorized workspace must retain local approval',
  );
  final preferences = jsonEncode(stored.toJson());
  for (final forbidden in [
    'argument-canary',
    'environment-canary',
    '/approved/bin',
    '/workspace',
    '--token',
  ]) {
    check(
      !preferences.contains(forbidden),
      'Raw launch value entered preferences',
    );
  }
  var rejected = false;
  try {
    McpTrustRecord.fromJson({
      'version': 1,
      'fields': {'args': 'plaintext'},
    });
  } on FormatException {
    rejected = true;
  }
  check(rejected, 'Malformed trust record accepted');
  stdout.writeln(
    'PASS: immutable launch snapshots, per-field HMACs, scope isolation and digest-only records',
  );
}

