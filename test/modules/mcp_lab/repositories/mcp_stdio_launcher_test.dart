import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_stdio_launcher.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_stdio_connection_repository.dart';

class _Process extends Mock implements Process {}

void main() {
  for (final entry in {
    577: 'executable signature',
    1260: 'application policy',
    225: 'blocked or removed',
    226: 'blocked or removed',
    5: 'Could not start the MCP server process.',
  }.entries) {
    test(
      'Windows launch error ${entry.key} is actionable without exposing launch secrets',
      () async {
        var attempts = 0;
        const secret = 'private-launch-canary';
        final launcher = McpStdioLauncher(
          start:
              (
                executable,
                args, {
                workingDirectory,
                environment,
                required includeParentEnvironment,
              }) async {
                attempts++;
                throw ProcessException(
                  executable,
                  args,
                  'raw exception $secret',
                  entry.key,
                );
              },
        );
        final result = await launcher.start(
          McpLaunchSnapshot(
            command: 'dart',
            executable: Platform.resolvedExecutable,
            cwd: Directory.current.path,
            args: [secret],
            environment: {'TOKEN': secret},
          ),
        );
        final failure = result.failureOrNull!;
        expect(failure, isA<McpNetworkFailure>());
        expect((failure as McpNetworkFailure).code, McpErrorCode.unreachable);
        expect(failure.message, contains(entry.value));
        expect(failure.message, isNot(contains(secret)));
        expect(failure.message, isNot(contains(Platform.resolvedExecutable)));
        expect(attempts, 1);
      },
      skip: !Platform.isWindows,
    );
  }

  test('missing or placeholder-only secrets cannot start a process', () async {
    var started = false;
    final launcher = McpStdioLauncher(
      start:
          (
            executable,
            args, {
            workingDirectory,
            environment,
            required includeParentEnvironment,
          }) async {
            started = true;
            return _Process();
          },
    );
    final repository = McpStdioConnectionRepository(
      launcher,
      isAuthorized: (_, _) => true,
      clientVersion: '1',
    );
    const context = McpAccessContext(
      userId: 'user',
      workspaceId: 'workspace',
      generation: 1,
    );
    const server = McpServer(
      id: 'server',
      workspaceId: 'workspace',
      draft: McpServerDraft(
        name: 'Fixture',
        transport: McpTransport.stdio,
        command: 'dart',
        env: {'TOKEN': ''},
        secretKeys: ['env.TOKEN'],
      ),
      secretStates: {'env.TOKEN': SecretValueState.present},
    );
    final target = McpConnectTarget(
      context: context,
      server: server,
      timeout: const Duration(seconds: 5),
      launch: McpLaunchSnapshot(
        command: 'dart',
        executable: Platform.resolvedExecutable,
        cwd: Directory.current.path,
        args: [],
        environment: {'TOKEN': ''},
      ),
    );
    expect(
      (await repository.connect(target)).failureOrNull,
      isA<McpValidationFailure>(),
    );
    expect(started, isFalse);
  });
  test(
    'resolution filters inherited credentials and freezes effective launch',
    () async {
      final launcher = McpStdioLauncher();
      final result = await launcher.resolve(
        command: Platform.resolvedExecutable,
        args: ['with spaces', '&'],
        environment: {
          'FOO': 'configured',
          'PATH': File(Platform.resolvedExecutable).parent.path,
        },
        inheritedEnvironment: {
          ...Platform.environment,
          'INHERITED_CREDENTIAL': 'canary',
        },
      );
      final snapshot = result.valueOrNull!;
      expect(File(snapshot.executable).isAbsolute, isTrue);
      expect(Directory(snapshot.cwd).isAbsolute, isTrue);
      expect(snapshot.environment['FOO'], 'configured');
      expect(snapshot.environment.containsKey('INHERITED_CREDENTIAL'), isFalse);
      expect(snapshot.args, ['with spaces', '&']);
      expect(() => snapshot.args.add('changed'), throwsUnsupportedError);
    },
  );
  test('missing cwd or executable fails before any process can start', () async {
    var started = false;
    final launcher = McpStdioLauncher(
      start:
          (
            executable,
            arguments, {
            workingDirectory,
            environment,
            required includeParentEnvironment,
          }) async {
            started = true;
            return _Process();
          },
    );
    final result = await launcher.resolve(
      command: Platform.resolvedExecutable,
      args: [],
      cwd:
          '${Directory.systemTemp.path}/missing-mcp-${DateTime.now().microsecondsSinceEpoch}',
    );
    expect(result.failureOrNull!.message, 'Working directory not found.');
    final missingExecutable = await launcher.start(
      McpLaunchSnapshot(
        command: 'missing',
        executable:
            '${Directory.systemTemp.path}${Platform.pathSeparator}missing-mcp-${DateTime.now().microsecondsSinceEpoch}.exe',
        cwd: Directory.current.path,
        args: [],
        environment: {},
      ),
    );
    expect(missingExecutable.failureOrNull!.message, 'Executable not found.');
    expect(started, isFalse);
  });
  test(
    'native process receives exactly the resolved snapshot without ambient env',
    () async {
      final process = _Process();
      final arguments = <String>[];
      Map<String, String>? capturedEnvironment;
      String? directory;
      bool? inherited;
      final launcher = McpStdioLauncher(
        start:
            (
              executable,
              args, {
              workingDirectory,
              environment,
              required includeParentEnvironment,
            }) async {
              arguments.addAll(args);
              capturedEnvironment = environment;
              directory = workingDirectory;
              inherited = includeParentEnvironment;
              return process;
            },
      );
      final snapshot = McpLaunchSnapshot(
        command: 'native',
        executable: Platform.resolvedExecutable,
        cwd: Directory.current.path,
        args: ['with spaces', '&', '^', 'quote"value'],
        environment: {'FOO': 'bar'},
      );
      final result = await launcher.start(snapshot);
      expect(result.valueOrNull!.process, same(process));
      expect(
        arguments,
        Platform.isWindows
            ? snapshot.args
            : ['--', snapshot.executable, ...snapshot.args],
      );
      expect(capturedEnvironment, snapshot.environment);
      expect(directory, snapshot.cwd);
      expect(inherited, isFalse);
    },
    skip: !Platform.isWindows && !File('/usr/bin/setsid').existsSync()
        ? 'Requires process-group launcher.'
        : null,
  );
  test(
    'Windows batch shims fail closed before spawning until quoting is verified',
    () async {
      var started = false;
      final launcher = McpStdioLauncher(
        start:
            (
              executable,
              args, {
              workingDirectory,
              environment,
              required includeParentEnvironment,
            }) async {
              started = true;
              return _Process();
            },
      );
      final result = await launcher.start(
        McpLaunchSnapshot(
          command: 'npx',
          executable: '${Directory.current.path}\\npx.cmd',
          cwd: Directory.current.path,
          args: ['&'],
          environment: {},
        ),
      );
      expect(result.failureOrNull!.message, contains('batch-shim'));
      expect(started, isFalse);
    },
    skip: !Platform.isWindows,
  );
}
