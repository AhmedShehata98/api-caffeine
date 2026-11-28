import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/database/supabase_client_provider.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/core/network/network_settings.dart';
import 'package:api_caffeine/core/secrets/secret_store.dart';
import 'package:api_caffeine/modules/auth/auth.dart';
import 'package:api_caffeine/modules/settings/settings.dart';
import 'package:api_caffeine/modules/workspaces/workspaces.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_target_settings.dart';
import '../repositories/mcp_http_connection_repository.dart';
import '../repositories/mcp_server_repository_impl.dart';
import '../repositories/mcp_stdio_connection_repository.dart';
import '../repositories/mcp_stdio_launcher.dart';
import '../repositories/mcp_target_repository_impl.dart';
import '../repositories/mcp_transport_repository.dart';
import '../repositories/mcp_trust_repository_impl.dart';
import '../services/mcp_catalog_service.dart';
import '../services/mcp_connect_service.dart';
import '../services/mcp_negotiation_service.dart';
import '../services/mcp_session_owner.dart';
import '../services/mcp_session_diagnostics.dart';
import '../services/mcp_target_service.dart';
import 'mcp_catalog_providers.dart';

final mcpSessionOwnerProvider = Provider<McpSessionOwner>((ref) {
  final owner = McpSessionOwner(createDiagnostics: McpSessionDiagnostics.new);
  ref.onDispose(() => unawaited(owner.dispose()));
  return owner;
});

/// Eagerly observed by App. Scope loading/errors revoke access as well as ID changes.
final mcpLifecycleProvider = Provider<void>((ref) {
  final owner = ref.watch(mcpSessionOwnerProvider);
  Timer? accessRefresh;
  var refreshRunning = false;
  void refreshCatalog() {
    if (refreshRunning || owner.context == null || !ref.mounted) return;
    refreshRunning = true;
    unawaited(
      ref.read(mcpCatalogProvider.notifier).reload().whenComplete(() {
        refreshRunning = false;
      }),
    );
  }

  void scheduleRefresh() {
    accessRefresh?.cancel();
    if (owner.context != null) {
      accessRefresh = Timer.periodic(
        const Duration(seconds: 60),
        (_) => refreshCatalog(),
      );
    }
  }

  (String?, String?)? previous;
  void update() {
    final user = ref.read(sessionProvider);
    final workspace = ref.read(currentWorkspaceProvider);
    final scope =
        (!user.isLoading &&
            !user.hasError &&
            !workspace.isLoading &&
            !workspace.hasError)
        ? (user.value?.id, workspace.value?.id)
        : (null, null);
    if (scope == previous) return;
    previous = scope;
    unawaited(owner.switchScope(scope.$1, scope.$2));
    scheduleRefresh();
  }

  ref.listen(sessionProvider, (_, _) => update());
  ref.listen(currentWorkspaceProvider, (_, _) => update());
  update();
  ref.onDispose(() => accessRefresh?.cancel());
});

final mcpSessionsProvider = StreamProvider<McpOwnedSessions>((ref) {
  final owner = ref.watch(mcpSessionOwnerProvider);
  return Stream.multi((sink) {
    final subscription = owner.changes.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.add(owner.state);
    sink.onCancel = subscription.cancel;
  });
});

final mcpCatalogServiceProvider = Provider<McpCatalogService>((ref) {
  final owner = ref.watch(mcpSessionOwnerProvider);
  return McpCatalogService(
    McpServerRepositoryImpl(ref.watch(supabaseClientProvider)),
    ref.watch(secretStoreProvider),
    isAuthorized: (context) => owner.isAuthorized(context, ''),
  );
});

final _launcherProvider = Provider((ref) => McpStdioLauncher());

final mcpTargetServiceProvider = Provider<McpTargetService>((ref) {
  final owner = ref.watch(mcpSessionOwnerProvider);
  return McpTargetService(
    ref.watch(mcpCatalogServiceProvider),
    McpTargetRepositoryImpl(
      ref.watch(_launcherProvider),
      isAuthorized: owner.isAuthorized,
    ),
    isAuthorized: owner.isAuthorized,
  );
});

/// Inject the build version here when release metadata is wired.
final mcpClientVersionProvider = Provider<String>((ref) => '1.2.1');

final mcpConnectServiceProvider = Provider<McpConnectService>((ref) {
  final owner = ref.watch(mcpSessionOwnerProvider);
  final version = ref.watch(mcpClientVersionProvider);
  return McpConnectService(
    McpTransportRepository(
      stdio: McpStdioConnectionRepository(
        ref.watch(_launcherProvider),
        isAuthorized: owner.isAuthorized,
        clientVersion: version,
      ),
      http: McpHttpConnectionRepository(
        isAuthorized: owner.isAuthorized,
        clientVersion: version,
      ),
    ),
    McpTrustRepositoryImpl(
      ref.watch(sharedPreferencesProvider),
      ref.watch(secretStoreProvider),
      isAuthorized: owner.isAuthorized,
    ),
    McpNegotiationService(clientVersion: version),
    isAuthorized: owner.isAuthorized,
    onSessionOpened: owner.trackOpening,
  );
});

/// UI entry points keep pending tickets and successful sessions with their owner.
final mcpSessionActionsProvider = Provider<McpSessionActions>(
  (ref) => McpSessionActions(
    ref.watch(mcpSessionOwnerProvider),
    ref.watch(mcpTargetServiceProvider),
    ref.watch(mcpConnectServiceProvider),
    () {
      final settings = ref.read(networkSettingsProvider);
      return McpTargetSettings(
        timeout: settings.timeout,
        proxyUrl: settings.proxyUrl,
      );
    },
  ),
);

class McpSessionActions {
  McpSessionActions(this.owner, this.targets, this.connections, this.settings);
  final McpSessionOwner owner;
  final McpTargetService targets;
  final McpConnectService connections;
  final McpTargetSettings Function() settings;

  Future<Result<McpConnectOutcome>> connect(String id) =>
      owner.run(id, (context) async {
        final target = await targets.resolve(context, id, settings());
        if (target case Err(:final failure)) return Result.failure(failure);
        return connections.connect(target.valueOrNull!);
      });

  Future<Result<McpConnectOutcome>> approve(
    String id, {
    bool remember = false,
  }) {
    final ticket = owner.state.sessions[id];
    if (ticket is! McpNeedsApproval) {
      return Future.value(
        const Result.failure(
          McpValidationFailure(
            'Request a fresh launch approval.',
            code: McpErrorCode.invalidParams,
          ),
        ),
      );
    }
    return owner.run(
      id,
      (_) => connections.approve(ticket, remember: remember),
    );
  }
}
