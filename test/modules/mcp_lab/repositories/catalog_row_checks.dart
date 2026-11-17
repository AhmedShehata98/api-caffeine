import 'dart:convert';
import 'dart:io';

import 'package:test_point/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_server_row.dart';

void main() {
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  for (final transport in McpTransport.values) {
    final draft = McpServerDraft(
      name: 'Fixture',
      transport: transport,
      command: transport == McpTransport.stdio ? 'dart' : null,
      url: transport == McpTransport.stdio ? null : 'https://example.test/mcp',
      args: ['server.dart', '--help'],
      cwd: '/fixture',
      env: {'TOKEN': 'env-canary', 'PUBLIC': 'visible'},
      headers: {'authorization': 'header-canary', 'x-public': 'visible'},
      secretKeys: ['env.TOKEN', 'header.authorization'],
      settings: const McpServerSettings(
        protocolEra: McpProtocolEra.auto,
        timeoutSeconds: 12,
      ),
    );
    final values = mcpServerValues(draft);
    final wire = jsonEncode(values);
    check(
      !wire.contains('env-canary') && !wire.contains('header-canary'),
      'Secret leaked into row',
    );
    check(
      values['secret_keys'] is List && !values.containsKey('secretKeys'),
      'Wrong row shape',
    );
    check(
      values['settings']['protocolEra'] == 'auto',
      'Wrong settings wire shape',
    );
    final decoded = mcpServerFromRow({
      ...jsonDecode(wire) as Map<String, dynamic>,
      'id': 'server',
      'workspace_id': 'workspace',
      'position': 2,
    });
    check(
      decoded.id == 'server' &&
          decoded.workspaceId == 'workspace' &&
          decoded.position == 2,
      'Catalog identity lost',
    );
    check(
      decoded.draft.transport == transport &&
          decoded.draft.args.last == '--help',
      'Target lost',
    );
    check(
      decoded.draft.env['TOKEN'] == '' &&
          decoded.draft.env['PUBLIC'] == 'visible',
      'Environment mapping failed',
    );
    check(
      decoded.draft.headers['authorization'] == '',
      'Header placeholder lost',
    );
    check(
      decoded.secretStates.values.every(
        (state) => state == SecretValueState.missingOnDevice,
      ),
      'Synced placeholders must never be treated as device credentials',
    );
    check(
      jsonEncode(mcpServerValues(decoded.draft)) == wire,
      'Database row round trip changed',
    );
    check(
      draft.env['TOKEN'] == 'env-canary',
      'Encoding mutated the hydrated draft',
    );
  }
  stdout.writeln(
    'PASS: catalog row mapping, transport targets, secret placeholders and settings',
  );
}

