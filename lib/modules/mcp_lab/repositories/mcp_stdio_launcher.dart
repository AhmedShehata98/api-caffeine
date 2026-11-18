import 'dart:async';
import 'dart:io';

import 'package:test_point/core/error/result.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';

typedef McpProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  required bool includeParentEnvironment,
});

class McpStdioLauncher {
  McpStdioLauncher({McpProcessStarter? start})
    : _start = start ?? Process.start;
  final McpProcessStarter _start;
  Future<String?>? _loginPath;
  static const _allowed = {
    'PATH',
    'PATHEXT',
    'HOME',
    'USERPROFILE',
    'SYSTEMROOT',
    'WINDIR',
    'TEMP',
    'TMP',
    'TMPDIR',
    'LANG',
    'LC_ALL',
    'LC_CTYPE',
    'SHELL',
    'USER',
    'LOGNAME',
    'APPDATA',
    'LOCALAPPDATA',
    'HOMEDRIVE',
    'HOMEPATH',
    'COMSPEC',
    'TZ',
  };

  Future<Result<McpLaunchSnapshot>> resolve({
    required String command,
    required List<String> args,
    String? cwd,
    Map<String, String> environment = const {},
    Map<String, String>? inheritedEnvironment,
  }) async {
    try {
      final directory = Directory(cwd ?? Directory.current.path).absolute;
      if (!await directory.exists()) {
        return Result.failure(_failure('Working directory not found.'));
      }
      final inherited = inheritedEnvironment ?? Platform.environment;
      final effective = {
        for (final entry in inherited.entries)
          if (_allowed.contains(entry.key.toUpperCase()))
            entry.key: entry.value,
      };
      if (!Platform.isWindows && !environment.containsKey('PATH')) {
        final path = await (_loginPath ??= _readLoginPath(effective));
        if (path == null) {
          return Result.failure(_failure('Could not load login-shell PATH.'));
        }
        effective['PATH'] = path;
      }
      for (final entry in environment.entries) {
        if (Platform.isWindows) {
          effective.removeWhere(
            (key, _) => key.toLowerCase() == entry.key.toLowerCase(),
          );
        }
        effective[entry.key] = entry.value;
      }
      String? value(String name) {
        for (final entry in effective.entries) {
          if (Platform.isWindows
              ? entry.key.toUpperCase() == name
              : entry.key == name) {
            return entry.value;
          }
        }
        return null;
      }

      final extensions =
          Platform.isWindows && !RegExp(r'\.[^\\/]+$').hasMatch(command)
          ? ['', ...(value('PATHEXT') ?? '.COM;.EXE;.BAT;.CMD').split(';')]
          : [''];
      final paths =
          File(command).isAbsolute ||
              command.contains('/') ||
              command.contains('\\')
          ? [
              File(command).isAbsolute
                  ? command
                  : '${directory.path}${Platform.pathSeparator}$command',
            ]
          : (value('PATH') ?? '')
                .split(Platform.isWindows ? ';' : ':')
                .where((path) => path.isNotEmpty)
                .map(
                  (path) =>
                      '${path.replaceAll('"', '')}${Platform.pathSeparator}$command',
                )
                .toList();
      for (final path in paths) {
        for (final extension in extensions) {
          final file = File('$path$extension');
          if (!await file.exists()) continue;
          final stat = await file.stat();
          if (!Platform.isWindows && stat.mode & 0x49 == 0) continue;
          return Result.success(
            McpLaunchSnapshot(
              command: command,
              executable: await file.resolveSymbolicLinks(),
              cwd: await directory.resolveSymbolicLinks(),
              args: args,
              environment: effective,
            ),
          );
        }
      }
      return Result.failure(_failure('Executable not found.'));
    } on Object {
      return Result.failure(
        _failure('Could not resolve the server launch configuration.'),
      );
    }
  }

  Future<String?> _readLoginPath(Map<String, String> environment) async {
    final result = await Process.run(
      environment['SHELL'] ?? '/bin/sh',
      ['-lc', r'''printf '\n__TEST_POINT_PATH__%s' "$PATH"'''],
      environment: environment,
      includeParentEnvironment: false,
    ).timeout(const Duration(seconds: 3));
    final output = result.stdout as String;
    const marker = '__TEST_POINT_PATH__';
    final index = output.lastIndexOf(marker);
    return result.exitCode == 0 && index >= 0
        ? output.substring(index + marker.length).trim()
        : null;
  }

  Future<Result<McpStdioProcess>> start(McpLaunchSnapshot snapshot) async {
    try {
      if (!File(snapshot.executable).isAbsolute ||
          !Directory(snapshot.cwd).isAbsolute) {
        return Result.failure(
          _failure('Resolve absolute launch paths before approval.'),
        );
      }
      if (!await Directory(snapshot.cwd).exists()) {
        return Result.failure(_failure('Working directory not found.'));
      }
      if (Platform.isWindows &&
          RegExp(
            r'\.(cmd|bat)$',
            caseSensitive: false,
          ).hasMatch(snapshot.executable)) {
        // Fail closed until batch quoting has dedicated argv/injection tests.
        return Result.failure(
          _failure(
            'Windows batch-shim launch is not implemented yet. Use the native executable.',
          ),
        );
      }
      if (!await File(snapshot.executable).exists()) {
        return Result.failure(_failure('Executable not found.'));
      }
      final group = !Platform.isWindows;
      if (group && !await File('/usr/bin/setsid').exists()) {
        return Result.failure(
          _failure(
            'Safe process-group launch is not available on this platform yet.',
          ),
        );
      }
      final process = await _start(
        group ? '/usr/bin/setsid' : snapshot.executable,
        group ? ['--', snapshot.executable, ...snapshot.args] : snapshot.args,
        workingDirectory: snapshot.cwd,
        environment: snapshot.environment,
        includeParentEnvironment: false,
      );
      return Result.success(McpStdioProcess(process, processGroup: group));
    } on ProcessException catch (error) {
      // Match Windows error codes, never localized exception text or argv.
      final message = Platform.isWindows
          ? switch (error.errorCode) {
              577 => 'Windows could not verify the MCP executable signature. Use a trusted signed build or contact your administrator.',
              1260 => 'Windows application policy blocked the MCP executable. Use an approved build or contact your administrator.',
              225 || 226 => 'Windows security blocked or removed the MCP executable. Review Protection history and use a trusted build.',
              _ => 'Could not start the MCP server process.',
            }
          : 'Could not start the MCP server process.';
      return Result.failure(_failure(message));
    } on Object {
      return Result.failure(
        _failure('Could not start the MCP server process.'),
      );
    }
  }

  McpNetworkFailure _failure(String message) =>
      McpNetworkFailure(message, code: McpErrorCode.unreachable);
}

class McpStdioProcess {
  McpStdioProcess(this.process, {required this.processGroup});
  final Process process;
  final bool processGroup;
  Future<Result<void>>? _closing;
  Future<Result<void>> close() => _closing ??= _stop();

  Future<Result<void>> _stop() async {
    final clock = Stopwatch()..start();
    Duration remaining() => Duration(
      milliseconds: (4900 - clock.elapsedMilliseconds).clamp(1, 4900),
    );
    Future<bool> exited(Duration wait) async {
      try {
        await process.exitCode.timeout(wait);
        return true;
      } on TimeoutException {
        return false;
      }
    }

    try {
      try {
        await process.stdin.close().timeout(const Duration(milliseconds: 100));
      } on Object {
        /* An already closed/full pipe still requires process cleanup. */
      }
      if (await exited(const Duration(seconds: 2)) && !processGroup) {
        return const Result.success(null);
      }
      for (final force in [false, true]) {
        if (Platform.isWindows || processGroup) {
          final executable = Platform.isWindows
              ? '${Platform.environment['SYSTEMROOT'] ?? Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\taskkill.exe'
              : '/bin/kill';
          final arguments = Platform.isWindows
              ? ['/PID', '${process.pid}', '/T', if (force) '/F']
              : [force ? '-KILL' : '-TERM', '--', '-${process.pid}'];
          final killer = await Process.start(executable, arguments);
          final output = killer.stdout.drain<void>();
          final errors = killer.stderr.drain<void>();
          try {
            await killer.exitCode.timeout(remaining());
          } on TimeoutException {
            killer.kill();
          }
          await Future.wait([output, errors]).timeout(remaining());
        } else {
          process.kill(force ? ProcessSignal.sigkill : ProcessSignal.sigterm);
        }
        if (await exited(
              force ? remaining() : const Duration(milliseconds: 500),
            ) &&
            (!processGroup || force)) {
          return const Result.success(null);
        }
      }
    } on Object {
      process.kill();
    }
    return const Result.failure(
      McpUnexpectedFailure(
        'MCP process shutdown did not complete within five seconds.',
      ),
    );
  }
}
