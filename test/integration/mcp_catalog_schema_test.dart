@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_point/modules/workspaces/repositories/workspace_repository_impl.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() {
  test(
    'MCP catalog constraints, round trip and workspace isolation',
    () async {
      final owner = SupabaseClient(_url, _key);
      final outsider = SupabaseClient(_url, _key);
      addTearDown(owner.dispose);
      addTearDown(outsider.dispose);
      await owner.auth.signInAnonymously();
      await outsider.auth.signInAnonymously();
      final workspace = (await WorkspaceRepositoryImpl(
        owner,
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
      final row = await owner
          .from('mcp_servers')
          .insert(draft)
          .select()
          .single();
      addTearDown(() => owner.from('mcp_servers').delete().eq('id', row['id']));
      expect(row['env'], {'TOKEN': ''});
      expect(row['secret_keys'], ['env.TOKEN']);
      expect(row['url'], isNull);
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
        await outsider
            .from('mcp_servers')
            .delete()
            .eq('id', row['id'])
            .select(),
        isEmpty,
      );

      for (final invalid in <Map<String, dynamic>>[
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
              '23514',
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
    },
    skip: _url.isEmpty || _key.isEmpty
        ? 'Requires local Supabase URL and anon key.'
        : null,
  );
}
