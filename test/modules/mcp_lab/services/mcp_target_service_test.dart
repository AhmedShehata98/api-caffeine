import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_point/core/error/result.dart';

import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/services/mcp_target_service.dart';
import 'package:test_point/modules/mcp_lab/services/mcp_catalog_service.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_target_repository_impl.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_stdio_launcher.dart';

class _Catalog extends Mock implements McpCatalogService {}

class _Targets extends Mock implements McpTargetRepository {}

void main() {
  const context = McpAccessContext(
    userId: 'u',
    workspaceId: 'w',
    generation: 1,
  );
  const server = McpServer(
    id: 's',
    workspaceId: 'w',
    draft: McpServerDraft(
      name: 'Fixture',
      transport: McpTransport.http,
      url: 'https://example.test/mcp',
    ),
  );
  const settings = McpTargetSettings();
  final launcher = McpStdioLauncher(
    start: (
      executable,
      args, {
      workingDirectory,
      environment,
      required includeParentEnvironment,
    }) async => throw StateError('Resolution must never launch a process'),
  );
  setUpAll(() => registerFallbackValue(server));

  test(
    'HTTP timeout and proxy follow server, settings and environment precedence',
    () async {
      final repository = McpTargetRepositoryImpl(
        launcher,
        isAuthorized: (_, _) => true,
        environment: {'HTTPS_PROXY': 'http://env-proxy:8080'},
      );
      final fromEnvironment = (await repository.resolve(
        context,
        server,
        settings,
      )).valueOrNull!;
      expect(fromEnvironment.timeout, const Duration(seconds: 30));
      expect(fromEnvironment.proxy.toString(), 'http://env-proxy:8080');
      final override = server.copyWith(
        draft: server.draft.copyWith(
          settings: const McpServerSettings(timeoutSeconds: 7),
        ),
      );
      final resolved = (await repository.resolve(
        context,
        override,
        const McpTargetSettings(
          timeout: Duration(seconds: 99),
          proxyUrl: 'http://settings-proxy:9090',
        ),
      )).valueOrNull!;
      expect(resolved.timeout, const Duration(seconds: 7));
      expect(resolved.proxy.toString(), 'http://settings-proxy:9090');
    },
  );

  test('NO_PROXY and loopback bypass configured proxies', () async {
    final repository = McpTargetRepositoryImpl(
      launcher,
      isAuthorized: (_, _) => true,
      environment: {
        'NO_PROXY': 'example.test',
        'HTTPS_PROXY': 'http://env-proxy',
      },
    );
    for (final url in ['https://example.test/mcp', 'http://127.0.0.1/mcp']) {
      final resolved = await repository.resolve(
        context,
        server.copyWith(draft: server.draft.copyWith(url: url)),
        const McpTargetSettings(proxyUrl: 'http://settings-proxy'),
      );
      expect(resolved.valueOrNull!.proxy, isNull);
    }
  });

  test('invalid timeouts, URLs and proxies return failures', () async {
    final repository = McpTargetRepositoryImpl(
      launcher,
      isAuthorized: (_, _) => true,
      environment: {},
    );
    expect(
      (await repository.resolve(
        context,
        server,
        const McpTargetSettings(timeout: Duration.zero),
      )).isSuccess,
      isFalse,
    );
    expect(
      (await repository.resolve(
        context,
        server,
        const McpTargetSettings(proxyUrl: 'bad'),
      )).isSuccess,
      isFalse,
    );
    final invalid = server.copyWith(
      draft: server.draft.copyWith(url: 'https://@host/mcp'),
    );
    expect(
      (await repository.resolve(context, invalid, settings)).isSuccess,
      isFalse,
    );
  });

  test(
    'native executable resolves a frozen launch without starting a process',
    () async {
      final repository = McpTargetRepositoryImpl(
        launcher,
        isAuthorized: (_, _) => true,
        environment: {
          'PATH': '/inherited',
          'UNRELATED_SECRET': 'must-not-inherit',
        },
      );
      final native = server.copyWith(
        draft: McpServerDraft(
          name: 'Native',
          transport: McpTransport.stdio,
          command: Platform.resolvedExecutable,
          args: ['fixture.dart', 'a b'],
          cwd: Directory.current.path,
          env: {'PATH': '/explicit', 'TOKEN': 'device-value'},
        ),
      );
      final target = (await repository.resolve(
        context,
        native,
        settings,
      )).valueOrNull!;
      expect(File(target.launch!.executable).isAbsolute, isTrue);
      expect(target.launch!.args, ['fixture.dart', 'a b']);
      expect(target.launch!.environment['TOKEN'], 'device-value');
      expect(target.launch!.environment['UNRELATED_SECRET'], isNull);
      expect(
        () => target.launch!.environment['TOKEN'] = 'changed',
        throwsUnsupportedError,
      );
    },
  );

  test('account changes during path resolution discard the target', () async {
    var checks = 0;
    final repository = McpTargetRepositoryImpl(
      launcher,
      isAuthorized: (_, _) => ++checks == 1,
      environment: {},
    );
    final native = server.copyWith(
      draft: McpServerDraft(
        name: 'Native',
        transport: McpTransport.stdio,
        command: Platform.resolvedExecutable,
        env: {'PATH': '/explicit'},
      ),
    );
    expect(
      (await repository.resolve(context, native, settings)).failureOrNull,
      isA<McpAuthFailure>(),
    );
  });

  test(
    'service reloads the server and preserves saved plaintext overrides',
    () async {
      final catalog = _Catalog();
      final targets = _Targets();
      final saved = server.copyWith(
        draft: server.draft.copyWith(
          headers: {'authorization': 'explicit-plaintext'},
        ),
      );
      when(() => catalog.get(context, 's'))
          .thenAnswer((_) async => Result.success(saved));
      final target = McpConnectTarget(
        context: context,
        server: saved,
        timeout: settings.timeout,
      );
      when(() => targets.resolve(context, any(), settings))
          .thenAnswer((_) async => Result.success(target));
      final service = McpTargetService(
        catalog,
        targets,
        isAuthorized: (_, _) => true,
      );
      expect(
        (await service.resolve(context, 's', settings)).valueOrNull,
        same(target),
      );
      final passed =
          verify(() => targets.resolve(context, captureAny(), settings))
                  .captured
                  .single
              as McpServer;
      expect(passed.draft.secretKeys, isEmpty);
      expect(passed.draft.headers['authorization'], 'explicit-plaintext');
    },
  );

  test(
    'missing device secrets never reach executable or proxy resolution',
    () async {
      final catalog = _Catalog();
      final targets = _Targets();
      final missing = server.copyWith(
        draft: server.draft.copyWith(
          headers: {'authorization': ''},
          secretKeys: ['header.authorization'],
        ),
      );
      when(() => catalog.get(context, 's'))
          .thenAnswer((_) async => Result.success(missing));
      final service = McpTargetService(
        catalog,
        targets,
        isAuthorized: (_, _) => true,
      );
      expect(
        (await service.resolve(context, 's', settings)).failureOrNull,
        isA<McpValidationFailure>(),
      );
      verifyZeroInteractions(targets);
    },
  );

  test(
    'service discards resolution completed after an account change',
    () async {
      final catalog = _Catalog();
      final targets = _Targets();
      var current = true;
      when(() => catalog.get(context, 's'))
          .thenAnswer((_) async => const Result.success(server));
      when(() => targets.resolve(context, any(), settings))
          .thenAnswer((_) async {
            current = false;
            return Result.success(
              McpConnectTarget(
                context: context,
                server: server,
                timeout: settings.timeout,
              ),
            );
          });
      final service = McpTargetService(
        catalog,
        targets,
        isAuthorized: (_, _) => current,
      );
      expect(
        (await service.resolve(context, 's', settings)).failureOrNull,
        isA<McpAuthFailure>(),
      );
    },
  );
}
