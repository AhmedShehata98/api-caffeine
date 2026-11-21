import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_server_repository_impl.dart';

import 'catalog_row_checks.dart' as row_checks;

void main() {
  test(
    'catalog database row round trips and secret placeholders',
    row_checks.main,
  );

  test('CRUD scopes requests and maps database errors to Failure', () async {
    final peer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => peer.close(force: true));
    var fail = false;
    final requests = <({String method, Uri uri, Object? body})>[];
    final row = <String, dynamic>{
      'id': 'server',
      'workspace_id': 'workspace',
      'name': 'Fixture',
      'transport': 'stdio',
      'command': 'dart',
      'url': null,
      'cwd': null,
      'args': <String>[],
      'env': <String, String>{},
      'headers': <String, String>{},
      'secret_keys': <String>[],
      'settings': <String, dynamic>{},
      'position': 0,
    };
    final subscription = peer.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      final body = text.isEmpty ? null : jsonDecode(text);
      requests.add((method: request.method, uri: request.uri, body: body));
      request.response.headers.contentType = ContentType.json;
      if (fail) {
        request.response.statusCode = 403;
        request.response.write(
          jsonEncode({'code': '42501', 'message': 'Access denied'}),
        );
      } else if (request.method == 'DELETE') {
        request.response.statusCode = 204;
      } else if (request.method == 'GET') {
        request.response.write(jsonEncode([row]));
      } else {
        request.response.write(
          jsonEncode({...row, ...body as Map<String, dynamic>}),
        );
      }
      await request.response.close();
    });
    addTearDown(subscription.cancel);
    final client = SupabaseClient(
      'http://127.0.0.1:${peer.port}',
      'fixture-anon',
    );
    addTearDown(client.dispose);
    final repository = McpServerRepositoryImpl(client);
    expect(
      (await repository.list('workspace')).valueOrNull!.single.id,
      'server',
    );
    expect(requests.last.uri.queryParameters['workspace_id'], 'eq.workspace');
    expect(requests.last.uri.queryParameters['order'], contains('position'));
    const draft = McpServerDraft(
      name: 'Fixture',
      transport: McpTransport.stdio,
      command: 'dart',
      env: {'TOKEN': 'canary'},
      secretKeys: ['env.TOKEN'],
    );
    expect(
      (await repository.create(
        workspaceId: 'workspace',
        draft: draft,
      )).isSuccess,
      isTrue,
    );
    expect((requests.last.body as Map)['env'], {'TOKEN': ''});
    expect((requests.last.body as Map)['workspace_id'], 'workspace');
    expect(
      (await repository.update(
        workspaceId: 'workspace',
        id: 'server',
        draft: draft,
        position: 3,
      )).valueOrNull!.position,
      3,
    );
    expect(requests.last.uri.queryParameters['workspace_id'], 'eq.workspace');
    expect(requests.last.uri.queryParameters['id'], 'eq.server');
    expect(
      (await repository.delete(
        workspaceId: 'workspace',
        id: 'server',
      )).isSuccess,
      isTrue,
    );
    expect(requests.last.uri.queryParameters['workspace_id'], 'eq.workspace');
    expect(requests.last.uri.queryParameters['id'], 'eq.server');
    fail = true;
    expect(
      (await repository.list('workspace')).failureOrNull,
      isA<StorageFailure>(),
    );
    expect(
      (await repository.create(
        workspaceId: 'workspace',
        draft: draft,
      )).failureOrNull,
      isA<StorageFailure>(),
    );
    expect(
      (await repository.update(
        workspaceId: 'workspace',
        id: 'server',
        draft: draft,
      )).failureOrNull,
      isA<StorageFailure>(),
    );
    expect(
      (await repository.delete(
        workspaceId: 'workspace',
        id: 'server',
      )).failureOrNull,
      isA<StorageFailure>(),
    );
  });
}
