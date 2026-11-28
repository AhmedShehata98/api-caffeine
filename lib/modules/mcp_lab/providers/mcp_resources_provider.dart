import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/error/failure.dart';

import '../models/mcp_protocol_models.dart';
import '../services/mcp_primitive_services.dart';
import 'mcp_primitive_providers.dart';

/// Common display fields; a template URI is shown verbatim, never read as-is.
class McpResourceListEntry {
  const McpResourceListEntry(
    this.name,
    this.uri,
    this.mimeType,
    this.description,
  );
  factory McpResourceListEntry.resource(McpResource value) =>
      McpResourceListEntry(
        value.title ?? value.name,
        value.uri,
        value.mimeType,
        value.description,
      );
  factory McpResourceListEntry.template(McpResourceTemplate value) =>
      McpResourceListEntry(
        value.title ?? value.name,
        value.uriTemplate,
        value.mimeType,
        value.description,
      );
  final String name;
  final String uri;
  final String? mimeType;
  final String? description;
}

class McpResourceListState {
  const McpResourceListState({
    this.items = const [],
    this.available = false,
    this.loading = false,
    this.nextCursor,
    this.failure,
  });
  final List<McpResourceListEntry> items;
  final bool available;
  final bool loading;
  final String? nextCursor;
  final Failure? failure;
}

/// Resources and templates have independent explicit pagination and retry state.
final mcpResourcesProvider = NotifierProvider.autoDispose
    .family<McpResourcesNotifier, McpResourceListState, (String, bool)>(
      McpResourcesNotifier.new,
    );

class McpResourcesNotifier extends Notifier<McpResourceListState> {
  McpResourcesNotifier(this.target);
  final (String, bool) target;
  int _revision = 0;
  int _pages = 0;
  final _cursors = <String>{};
  @override
  McpResourceListState build() {
    final services = ref.watch(mcpPrimitiveServicesProvider(target.$1));
    final revision = ++_revision;
    _pages = 0;
    _cursors.clear();
    if (services == null || !services.supports('resources')) {
      return const McpResourceListState();
    }
    Future.microtask(() {
      if (ref.mounted && revision == _revision) loadNext();
    });
    return const McpResourceListState(available: true);
  }

  Future<void> loadNext() async {
    if (!state.available ||
        state.loading ||
        (_pages > 0 && state.nextCursor == null)) {
      return;
    }
    final services = ref.read(mcpPrimitiveServicesProvider(target.$1));
    if (services == null) return;
    final revision = _revision;
    final previous = state;
    state = McpResourceListState(
      items: previous.items,
      available: true,
      loading: true,
      nextCursor: previous.nextCursor,
    );
    try {
      final page = target.$2
          ? (await services.resources.templates(cursor: previous.nextCursor))
                .when(
                  success: (page) => McpPage(
                    page.items.map(McpResourceListEntry.template).toList(),
                    page.nextCursor,
                  ),
                  failure: (failure) => throw failure,
                )
          : (await services.resources.list(cursor: previous.nextCursor)).when(
              success: (page) => McpPage(
                page.items.map(McpResourceListEntry.resource).toList(),
                page.nextCursor,
              ),
              failure: (failure) => throw failure,
            );
      if (!_current(revision, services)) return;
      final cursor = page.nextCursor;
      if (_pages >= 1000 ||
          previous.items.length + page.items.length > 10000 ||
          (cursor != null && !_cursors.add(cursor))) {
        state = McpResourceListState(
          items: previous.items,
          available: true,
          failure: const ValidationFailure(
            'The resource list exceeded its pagination limit or repeated a cursor. Refresh to start again.',
          ),
        );
        return;
      }
      _pages++;
      state = McpResourceListState(
        items: List.unmodifiable([...previous.items, ...page.items]),
        available: true,
        nextCursor: cursor,
      );
    } on Object catch (error) {
      if (!_current(revision, services)) return;
      state = McpResourceListState(
        items: previous.items,
        available: true,
        nextCursor: previous.nextCursor,
        failure: error is Failure
            ? error
            : const UnexpectedFailure('Could not load resources.'),
      );
    }
  }

  bool _current(int revision, McpPrimitiveServices services) =>
      ref.mounted &&
      revision == _revision &&
      identical(ref.read(mcpPrimitiveServicesProvider(target.$1)), services);
}
