import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';

class _Session implements McpSession {
  final calls = <(String, Map<String, dynamic>)>[];
  late Future<Result<Map<String, dynamic>>> Function(
    String,
    Map<String, dynamic>,
  )
  respond;
  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) {
    calls.add((method, params));
    return respond(method, params);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Session session;
  late McpPrimitiveServices services;
  late ProviderContainer container;
  var listening = false;
  final provider = mcpResourcesProvider(('s', false));
  final source = Provider<McpPrimitiveServices>((ref) => services);
  McpPrimitiveServices create(_Session value) => McpPrimitiveServices(
    value,
    McpNegotiation(
      era: NegotiatedEra.legacy,
      version: '2025-11-25',
      discovery: {
        'capabilities': {'resources': {}},
      },
    ),
    isAuthorized: () => true,
  );
  setUp(() {
    session = _Session();
    services = create(session);
    container = ProviderContainer.test(
      overrides: [
        mcpPrimitiveServicesProvider('s')
            .overrideWith((ref) => ref.watch(source)),
      ],
    );
    listening = false;
  });
  Future<void> settle() {
    if (!listening) {
      listening = true;
      container.listen(provider, (_, _) {});
    }
    return Future<void>.delayed(Duration.zero);
  }

  test(
    'next page is explicit and resource/template cursors are independent',
    () async {
      session.respond = (method, params) async => Result.success(
        method == 'resources/list'
            ? {
                'resources': [
                  {
                    'name': 'Item',
                    'uri': params['cursor'] == null
                        ? 'data://one'
                        : 'data://two',
                  },
                ],
                if (params['cursor'] == null) 'nextCursor': 'page2',
              }
            : {
                'resourceTemplates': [
                  {'name': 'Template', 'uriTemplate': 'data://{id}'},
                ],
              },
      );
      await settle();
      expect(session.calls.length, 1);
      expect(container.read(provider).nextCursor, 'page2');
      final templates = mcpResourcesProvider(('s', true));
      container.listen(templates, (_, _) {});
      await settle();
      expect(container.read(templates).items.single.uri, 'data://{id}');
      await container.read(provider.notifier).loadNext();
      expect(session.calls.last.$1, 'resources/list');
      expect(session.calls.last.$2, {'cursor': 'page2'});
      expect(container.read(provider).items.map((item) => item.uri), [
        'data://one',
        'data://two',
      ]);
      expect(container.read(provider).nextCursor, isNull);
      await container.read(provider.notifier).loadNext();
      expect(session.calls.length, 3);
    },
  );
  test('page failure retains rows and retries the same cursor', () async {
    var fail = true;
    session.respond = (_, params) async {
      if (params['cursor'] != null && fail) {
        return const Result.failure(NetworkFailure('Try again.'));
      }
      return Result.success({
        'resources': [
          {'name': 'Item', 'uri': 'data://one'},
        ],
        if (params['cursor'] == null) 'nextCursor': 'next',
      });
    };
    await settle();
    await container.read(provider.notifier).loadNext();
    expect(container.read(provider).items.length, 1);
    expect(container.read(provider).failure?.message, 'Try again.');
    fail = false;
    await container.read(provider.notifier).loadNext();
    expect(session.calls.last.$2, {'cursor': 'next'});
    expect(container.read(provider).items.length, 2);
    expect(container.read(provider).failure, isNull);
  });
  test('repeated cursor stops paging and concurrent loads send once', () async {
    final pending = Completer<Result<Map<String, dynamic>>>();
    session.respond = (_, params) async {
      if (params['cursor'] != null) return pending.future;
      return const Result.success({'resources': [], 'nextCursor': 'same'});
    };
    await settle();
    final load = container.read(provider.notifier).loadNext();
    await container.read(provider.notifier).loadNext();
    expect(session.calls.length, 2);
    pending.complete(
      const Result.success({'resources': [], 'nextCursor': 'same'}),
    );
    await load;
    expect(
      container.read(provider).failure?.message,
      contains('repeated a cursor'),
    );
    expect(container.read(provider).nextCursor, isNull);
  });
  test('late page cannot replace a refreshed session list', () async {
    final pending = Completer<Result<Map<String, dynamic>>>();
    session.respond = (_, _) => pending.future;
    await settle();
    final replacement = _Session()
      ..respond = (_, _) async => const Result.success({
        'resources': [
          {'name': 'New', 'uri': 'data://new'},
        ],
      });
    services = create(replacement);
    container.invalidate(source);
    container.read(provider);
    await settle();
    pending.complete(
      const Result.success({
        'resources': [
          {'name': 'Old', 'uri': 'data://old'},
        ],
      }),
    );
    await settle();
    expect(container.read(provider).items.single.uri, 'data://new');
  });
}
