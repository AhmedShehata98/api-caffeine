import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_catalog_service.dart';

class _Catalog extends Mock implements McpCatalogService {}

class _Session extends Mock implements McpSession {}

void main() {
  const server = McpServer(
    id: 's',
    workspaceId: 'w',
    draft: McpServerDraft(
      name: 'Fixture',
      transport: McpTransport.http,
      url: 'https://example.test/mcp',
    ),
  );
  late McpSessionOwner owner;
  late McpAccessContext context;
  late _Catalog catalog;
  late ProviderContainer container;
  late List<McpServer> rows;

  setUp(() async {
    owner = McpSessionOwner();
    await owner.switchScope('u', 'w');
    context = owner.context!;
    rows = [server];
    catalog = _Catalog();
    when(() => catalog.list(context))
        .thenAnswer((_) async => Result.success(List.of(rows)));
    container = ProviderContainer(
      overrides: [
        mcpSessionOwnerProvider.overrideWithValue(owner),
        mcpCatalogServiceProvider.overrideWithValue(catalog),
      ],
    );
    container.listen(mcpSelectedServerProvider, (_, _) {});
    await container.read(mcpSessionsProvider.future);
    await container.pump();
    final loaded = Completer<void>();
    final subscription = container.listen(mcpCatalogProvider, (_, value) {
      if (!value.isLoading && !loaded.isCompleted) loaded.complete();
    }, fireImmediately: true);
    await loaded.future;
    subscription.close();
  });
  tearDown(() async {
    container.dispose();
    await owner.dispose();
  });

  test('loads current catalog and rejects unknown selection', () {
    expect(container.read(mcpCatalogProvider).value, [server]);
    final selected = container.read(mcpSelectedServerProvider.notifier);
    selected.select('unknown');
    expect(container.read(mcpSelectedServerProvider), isNull);
    selected.select('s');
    expect(container.read(mcpSelectedServerProvider), 's');
  });

  test(
    'refresh removes missing selection and awaits live session cleanup',
    () async {
      container.read(mcpSelectedServerProvider.notifier).select('s');
      final session = _Session();
      when(() => session.close())
          .thenAnswer((_) async => const Result.success(null));
      await owner.run(
        's',
        (_) async => Result.success(
          McpConnected(
            session,
            McpNegotiation(
              era: NegotiatedEra.legacy,
              version: '2025-11-25',
              discovery: {},
            ),
          ),
        ),
      );
      rows = [];
      await container.read(mcpCatalogProvider.notifier).reload();
      expect(container.read(mcpCatalogProvider).value, isEmpty);
      expect(container.read(mcpSelectedServerProvider), isNull);
      expect(owner.isAuthorized(context, 's'), isFalse);
      verify(() => session.close()).called(1);
    },
  );

  test('delete stops live session before removing catalog row', () async {
    final events = <String>[];
    final session = _Session();
    when(() => session.close()).thenAnswer((_) async {
      events.add('close');
      return const Result.success(null);
    });
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          session,
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {},
          ),
        ),
      ),
    );
    when(() => catalog.delete(context, 's')).thenAnswer((_) async {
      events.add('delete');
      rows = [];
      return const Result.success(null);
    });
    expect(
      (await container.read(mcpCatalogProvider.notifier).delete('s')).isSuccess,
      isTrue,
    );
    expect(events, ['close', 'delete']);
    expect(container.read(mcpCatalogProvider).value, isEmpty);
  });

  test('failed refresh clears hydrated rows and exposes failure', () async {
    const failure = McpStorageFailure('Unavailable');
    when(() => catalog.list(context))
        .thenAnswer((_) async => const Result.failure(failure));
    await container.read(mcpCatalogProvider.notifier).reload();
    expect(container.read(mcpCatalogProvider).error, same(failure));
    expect(container.read(mcpCatalogProvider).value, isNull);
  });

  test(
    'partial save error returns original failure and reloads remote state',
    () async {
      const failure = McpStorageFailure('Device secret write failed');
      final changed = server.copyWith(
        draft: server.draft.copyWith(name: 'Changed'),
      );
      when(
        () => catalog.update(
          context,
          changed,
          confirmedPlaintextHeaders: const {},
        ),
      ).thenAnswer((_) async {
        rows = [changed];
        return const Result.failure(failure);
      });
      final result = await container
          .read(mcpCatalogProvider.notifier)
          .save(changed);
      expect(result.failureOrNull, same(failure));
      expect(
        container.read(mcpCatalogProvider).value!.single.draft.name,
        'Changed',
      );
    },
  );

  test('late catalog response cannot repopulate a revoked scope', () async {
    final response = Completer<Result<List<McpServer>>>();
    when(() => catalog.list(context)).thenAnswer((_) => response.future);
    final pending = container.read(mcpCatalogProvider.notifier).reload();
    await owner.switchScope(null, null);
    await container.pump();
    response.complete(const Result.success([server]));
    await pending;
    await container.pump();
    expect(container.read(mcpCatalogProvider).value ?? [], isEmpty);
    expect(container.read(mcpSelectedServerProvider), isNull);
  });

  test('older refresh never overwrites a newer response', () async {
    final session = _Session();
    when(() => session.close())
        .thenAnswer((_) async => const Result.success(null));
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          session,
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {},
          ),
        ),
      ),
    );
    final response = Completer<Result<List<McpServer>>>();
    when(() => catalog.list(context)).thenAnswer((_) => response.future);
    final first = container.read(mcpCatalogProvider.notifier).reload();
    when(() => catalog.list(context))
        .thenAnswer((_) async => const Result.success([]));
    await container.read(mcpCatalogProvider.notifier).reload();
    response.complete(const Result.success([server]));
    await first;
    expect(container.read(mcpCatalogProvider).value, isEmpty);
    expect(owner.isAuthorized(context, 's'), isFalse);
  });

  test('failed session cleanup prevents remote deletion', () async {
    final session = _Session();
    const failure = McpUnexpectedFailure('Process could not stop');
    when(() => session.close())
        .thenAnswer((_) async => const Result.failure(failure));
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          session,
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {},
          ),
        ),
      ),
    );
    expect(
      (await container.read(mcpCatalogProvider.notifier).delete('s'))
          .failureOrNull,
      same(failure),
    );
    verifyNever(() => catalog.delete(context, 's'));
    expect(container.read(mcpCatalogProvider).value, [server]);
  });
}
