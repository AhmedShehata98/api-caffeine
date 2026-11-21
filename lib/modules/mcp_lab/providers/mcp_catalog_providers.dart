import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';
import 'mcp_session_providers.dart';

final mcpAccessContextProvider = Provider<McpAccessContext?>(
  (ref) => ref.watch(mcpSessionsProvider).value?.context,
);

final mcpCatalogProvider =
    NotifierProvider<McpCatalogNotifier, AsyncValue<List<McpServer>>>(
      McpCatalogNotifier.new,
      retry: (_, _) => null,
    );

class McpCatalogNotifier extends Notifier<AsyncValue<List<McpServer>>> {
  var _revision = 0;
  static const _stale = McpAuthFailure(
    'The account or workspace changed. Reload the server catalog.',
  );

  @override
  AsyncValue<List<McpServer>> build() {
    final context = ref.watch(mcpAccessContextProvider);
    ref.watch(mcpCatalogServiceProvider);
    final revision = ++_revision;
    if (context == null) return const AsyncData([]);
    // Schedule after build so loading/error states never retain hydrated rows
    // from an earlier scope, as AsyncNotifier's previous-value merging would.
    Future.microtask(() async {
      if (!ref.mounted || revision != _revision) return;
      final loaded = await AsyncValue.guard(() => _load(context, revision));
      if (ref.mounted &&
          revision == _revision &&
          ref.read(mcpSessionOwnerProvider).isAuthorized(context, '')) {
        state = loaded;
      }
    });
    return const AsyncLoading();
  }

  Future<List<McpServer>> _load(McpAccessContext context, int revision) async {
    final owner = ref.read(mcpSessionOwnerProvider);
    final result = await ref.read(mcpCatalogServiceProvider).list(context);
    if (!ref.mounted || !owner.isAuthorized(context, '')) throw _stale;
    if (result case Err(:final failure)) throw failure;
    final rows = result.valueOrNull!;
    if (revision != _revision) return const [];
    final reconciled = await owner.reconcileCatalog(
      context,
      rows.map((row) => row.id).toSet(),
    );
    if (reconciled case Err(:final failure)) throw failure;
    return List.unmodifiable(rows);
  }

  Future<void> reload() async {
    final owner = ref.read(mcpSessionOwnerProvider);
    final context = owner.context;
    final revision = ++_revision;
    state =
        const AsyncLoading(); // Drop previous hydrated secrets while reloading.
    if (context == null) {
      state = const AsyncData([]);
      return;
    }
    final loaded = await AsyncValue.guard(() => _load(context, revision));
    if (ref.mounted &&
        revision == _revision &&
        owner.isAuthorized(context, '')) {
      state = loaded;
    }
  }

  Future<Result<T>> _mutate<T>(
    Future<Result<T>> Function(McpAccessContext) operation,
  ) async {
    final owner = ref.read(mcpSessionOwnerProvider);
    final context = owner.context;
    if (context == null) return const Result.failure(_stale);
    _revision++;
    state = const AsyncLoading();
    final result = await operation(context);
    if (!ref.mounted || !owner.isAuthorized(context, '')) {
      return const Result.failure(_stale);
    }
    // Reload after errors too: persistence can fail after a remote write.
    await reload();
    return result;
  }

  Future<Result<McpServer>> create(
    McpServerDraft draft, {
    Set<String> confirmedPlaintextHeaders = const {},
  }) => _mutate(
    (context) => ref
        .read(mcpCatalogServiceProvider)
        .create(
          context,
          draft,
          confirmedPlaintextHeaders: confirmedPlaintextHeaders,
        ),
  );

  Future<Result<McpServer>> save(
    McpServer server, {
    Set<String> confirmedPlaintextHeaders = const {},
  }) {
    final owner = ref.read(mcpSessionOwnerProvider);
    final service = ref.read(mcpCatalogServiceProvider);
    return _mutate((context) async {
      final stopped = await owner.disconnect(server.id);
      if (stopped case Err(:final failure)) return Result.failure(failure);
      return service.update(
        context,
        server,
        confirmedPlaintextHeaders: confirmedPlaintextHeaders,
      );
    });
  }

  Future<Result<void>> delete(String id) {
    final owner = ref.read(mcpSessionOwnerProvider);
    final service = ref.read(mcpCatalogServiceProvider);
    return _mutate((context) async {
      final stopped = await owner.disconnect(id);
      if (stopped case Err(:final failure)) return Result.failure(failure);
      return service.delete(context, id);
    });
  }
}

final mcpSelectedServerProvider = NotifierProvider<McpSelectedServer, String?>(
  McpSelectedServer.new,
);

class McpSelectedServer extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(mcpAccessContextProvider);
    ref.listen(mcpCatalogProvider, (_, next) {
      if (next case AsyncData(:final value)) {
        if (!value.any((server) => server.id == state)) state = null;
      }
    });
    return null;
  }

  void select(String? id) {
    final context = ref.read(mcpSessionOwnerProvider).context;
    final rows = ref.read(mcpCatalogProvider).value ?? const [];
    if (id == null ||
        (context != null &&
            rows.any(
              (row) => row.id == id && row.workspaceId == context.workspaceId,
            ))) {
      state = id;
    }
  }
}
