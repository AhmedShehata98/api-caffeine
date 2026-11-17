import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final mode = args
      .firstWhere(
        (arg) => arg.startsWith('--fixture='),
        orElse: () => '--fixture=basic',
      )
      .substring(10);
  final secret = Platform.environment['MCP_TEST_SECRET'] ?? '';
  final methods = <String>[];
  Object? waitingCall;
  if (mode == 'startup') {
    stdout.writeln('startup $secret');
    stderr.writeln('startup $secret');
  }
  void reply(Object? id, Map<String, dynamic> result) => stdout.writeln(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
      'x-wire-extension': true,
    }),
  );
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final value = jsonDecode(line) as Map<String, dynamic>;
    final method = value['method'];
    if (method == null && value['id'] == 'server-request') {
      reply(waitingCall, {'clientErrorCode': (value['error'] as Map)['code']});
      continue;
    }
    methods.add(method as String);
    final id = value['id'];
    if (method == 'initialize') {
      reply(id, {
        'protocolVersion': '2025-11-25',
        'capabilities': {},
        'serverInfo': {'name': 'fixture', 'version': '1'},
      });
    } else if (method == 'server/discover') {
      reply(id, {
        'supportedVersions': ['2026-07-28'],
        'capabilities': {},
        'serverInfo': {'name': 'fixture', 'version': '1'},
      });
    } else if (method == 'tools/call') {
      final params = value['params'] as Map;
      if (mode == 'crash') {
        stderr.writeln('crash $secret');
        await stderr.flush();
        exit(7);
      }
      if (mode == 'hang' || params['name'] == 'never') continue;
      if (mode == 'noisy') {
        stdout.writeln('noise $secret');
        stdout.writeln('{"jsonrpc":"2.0","method":123,"id":999,"result":{}}');
        final split = secret.length ~/ 2;
        stderr.write(secret.substring(0, split));
        await stderr.flush();
        stderr.writeln(secret.substring(split));
        await stderr.flush();
      }
      if (params['name'] == 'ask') {
        waitingCall = id;
        stdout.writeln(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 'server-request',
            'method': 'sampling/createMessage',
            'params': {},
          }),
        );
      } else {
        reply(id, {
          'resultType': params['name'] == 'needs-input'
              ? 'input_required'
              : 'complete',
          'content': [
            {'type': 'text', 'text': secret},
          ],
          'args': args,
          'cwd': Directory.current.path,
          'foo': Platform.environment['FOO'],
          'parentLeaked': Platform.environment.containsKey(
            'UNRELATED_PRIVATE_KEY',
          ),
          'methods': methods,
          'observedMeta': params['_meta'],
        });
      }
    }
  }
  if (mode == 'hang') {
    Timer.periodic(const Duration(seconds: 1), (_) {});
    await Completer<void>().future;
  }
}
