@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_server_repository_impl.dart';
import 'package:api_caffeine/modules/workspaces/repositories/workspace_repository_impl.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

String? get _skipReason {
  if (_url.isEmpty || _key.isEmpty) {
    return 'Requires local Supabase URL and anon key.';
  }
  final uri = Uri.tryParse(_url);
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      !const {'localhost', '127.0.0.1', '::1', '[::1]'}.contains(uri.host)) {
    return 'MCP database integration checks only run against a loopback Supabase URL.';
  }
  return null;
}

void main() {
  test('MCP catalog constraints, round trip and workspace isolation', () async {
    final owner = SupabaseClient(_url, _key);
    final outsider = SupabaseClient(_url, _key);
    addTearDown(owner.dispose);
    addTearDown(outsider.dispose);
    await owner.auth.signInAnonymously();
    await outsider.auth.signInAnonymously();
    final workspace = (await WorkspaceRepositoryImpl(
      owner,
    ).loadDefault()).valueOrNull!;
    final otherWorkspace = (await WorkspaceRepositoryImpl(
      outsider,
    ).loadDefault()).valueOrNull!;
    final draft = <String, dynamic>{
      'workspace_id': workspace.id,
      'name': 'MCP schema test',
      'transport': 'stdio',
      'command': 'dart',
      'args': ['server.dart'],
      'env': {'TOKEN': ''},
      'headers': <String, String>{},
      'secret_keys': ['env.TOKEN'],
      'settings': {'protocolEra': 'legacy'},
    };
    final row = await owner.from('mcp_servers').insert(draft).select().single();
    addTearDown(() => owner.from('mcp_servers').delete().eq('id', row['id']));
    addTearDown(
      () => outsider.from('mcp_servers').delete().eq('id', row['id']),
    );
    expect(row['env'], {'TOKEN': ''});
    expect(row['secret_keys'], ['env.TOKEN']);
    expect(row['url'], isNull);
    await expectLater(
      owner
          .from('mcp_servers')
          .update({'workspace_id': otherWorkspace.id})
          .eq('id', row['id']),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.code,
          'workspace transfer RLS',
          '42501',
        ),
      ),
    );
    expect(
      (await owner
          .from('mcp_servers')
          .select('workspace_id')
          .eq('id', row['id'])
          .single())['workspace_id'],
      workspace.id,
    );
    expect(
      await outsider.from('mcp_servers').select().eq('id', row['id']),
      isEmpty,
    );
    await expectLater(
      outsider.from('mcp_servers').insert(draft),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'RLS code', '42501'),
      ),
    );
    expect(
      await outsider
          .from('mcp_servers')
          .update({'name': 'stolen'})
          .eq('id', row['id'])
          .select(),
      isEmpty,
    );
    expect(
      await outsider.from('mcp_servers').delete().eq('id', row['id']).select(),
      isEmpty,
    );

    for (final invalid in <Map<String, dynamic>>[
      {'name': '   '},
      {'transport': 'invalid'},
      {'command': null},
      {'url': 'https://example.test'},
      {'transport': 'http'},
      {'transport': 'http', 'command': null, 'url': 'file:///tmp/server'},
      {
        'transport': 'http',
        'command': null,
        'url': 'https://user:pass@example.test',
      },
      {'args': <String, dynamic>{}},
      {'env': []},
      {'headers': []},
      {'secret_keys': <String, dynamic>{}},
      {'settings': []},
      {'args': null},
      {'env': null},
      {
        'args': [1],
      },
      {
        'env': {'TOKEN': 1},
      },
      {
        'headers': {'authorization': false},
      },
    ]) {
      await expectLater(
        owner.from('mcp_servers').insert({...draft, ...invalid}),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.code,
            'constraint code',
            invalid.values.contains(null) &&
                    (invalid.containsKey('args') || invalid.containsKey('env'))
                ? '23502'
                : '23514',
          ),
        ),
      );
    }
    final remote = await owner
        .from('mcp_servers')
        .insert({
          ...draft,
          'transport': 'http',
          'command': null,
          'url': 'https://example.test/mcp',
          'headers': {'authorization': ''},
          'secret_keys': ['header.authorization'],
        })
        .select()
        .single();
    addTearDown(
      () => owner.from('mcp_servers').delete().eq('id', remote['id']),
    );
    expect(remote['headers'], {'authorization': ''});
    expect(remote['secret_keys'], ['header.authorization']);
    expect(remote['url'], 'https://example.test/mcp');
    final updated = await owner
        .from('mcp_servers')
        .update({
          'name': 'Updated MCP schema test',
          'updated_at': '2000-01-01T00:00:00Z',
        })
        .eq('id', remote['id'])
        .select()
        .single();
    expect(updated['created_at'], remote['created_at']);
    expect(
      DateTime.parse(updated['updated_at'] as String)
          .isAfter(DateTime.utc(2000)),
      isTrue,
    );
  }, skip: _skipReason);

  test('real MCP repository CRUD preserves transport fields and strips marked secrets', () async {
    final client = SupabaseClient(_url, _key);
    addTearDown(client.dispose);
    await client.auth.signInAnonymously();
    final workspace = (await WorkspaceRepositoryImpl(
      client,
    ).loadDefault()).valueOrNull!;
    final repository = McpServerRepositoryImpl(client);
    const draft = McpServerDraft(
      name: 'Repository integration',
      transport: McpTransport.stdio,
      command: 'dart',
      args: ['server.dart', '--flag'],
      cwd: 'C:/mcp',
      env: {'TOKEN': 'device-only-canary', 'MODE': 'test'},
      secretKeys: ['env.TOKEN'],
      settings: McpServerSettings(
        protocolEra: McpProtocolEra.modern,
        timeoutSeconds: 45,
      ),
    );
    final created = await repository.create(
      workspaceId: workspace.id,
      draft: draft,
      position: 3,
    );
    expect(created.isSuccess, isTrue, reason: created.failureOrNull?.message);
    final server = created.valueOrNull!;
    addTearDown(() => client.from('mcp_servers').delete().eq('id', server.id));
    expect(server.draft.env, {'TOKEN': '', 'MODE': 'test'});
    expect(server.secretStates['env.TOKEN'], SecretValueState.missingOnDevice);
    expect(server.draft.args, draft.args);
    expect(server.draft.cwd, draft.cwd);
    expect(server.draft.settings, draft.settings);
    expect(server.position, 3);
    final listed = await repository.list(workspace.id);
    expect(listed.valueOrNull!.single.id, server.id);
    final remote = await repository.update(
      workspaceId: workspace.id,
      id: server.id,
      draft: const McpServerDraft(
        name: 'Remote integration',
        transport: McpTransport.http,
        url: 'https://example.test/mcp?team=qa',
        headers: {'authorization': 'device-only-canary'},
        secretKeys: ['header.authorization'],
      ),
      position: 7,
    );
    expect(remote.isSuccess, isTrue, reason: remote.failureOrNull?.message);
    expect(remote.valueOrNull!.draft.url, 'https://example.test/mcp?team=qa');
    expect(remote.valueOrNull!.draft.command, isNull);
    expect(remote.valueOrNull!.draft.headers['authorization'], '');
    expect(remote.valueOrNull!.position, 7);
    final deprecated = await repository.update(
      workspaceId: workspace.id,
      id: server.id,
      draft: remote.valueOrNull!.draft.copyWith(transport: McpTransport.sse),
    );
    expect(deprecated.valueOrNull!.draft.transport, McpTransport.sse);
    expect(
      (await repository.delete(
        workspaceId: workspace.id,
        id: server.id,
      )).isSuccess,
      isTrue,
    );
    expect((await repository.list(workspace.id)).valueOrNull, isEmpty);
  }, skip: _skipReason);

  test(
    'unauthenticated client cannot read or write another guest catalog',
    () async {
      final owner = SupabaseClient(_url, _key);
      final unauthenticated = SupabaseClient(_url, _key);
      addTearDown(owner.dispose);
      addTearDown(unauthenticated.dispose);
      await owner.auth.signInAnonymously();
      final workspace = (await WorkspaceRepositoryImpl(
        owner,
      ).loadDefault()).valueOrNull!;
      final values = {
        'workspace_id': workspace.id,
        'name': 'Anonymous denial',
        'transport': 'stdio',
        'command': 'dart',
      };
      final row = await owner
          .from('mcp_servers')
          .insert(values)
          .select()
          .single();
      addTearDown(() => owner.from('mcp_servers').delete().eq('id', row['id']));
      expect(
        await unauthenticated.from('mcp_servers').select().eq('id', row['id']),
        isEmpty,
      );
      await expectLater(
        unauthenticated.from('mcp_servers').insert(values),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.code,
            'anonymous write denial',
            '42501',
          ),
        ),
      );
    },
    skip: _skipReason,
  );
}
