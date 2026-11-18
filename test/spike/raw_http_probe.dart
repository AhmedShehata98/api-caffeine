import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'diagnostic_sanitizer.dart';

/// A controlled peer exercises the raw Dio boundary, not SDK reconstruction.
Future<void> main() async {
  const secret = 'canary+private/value';
  final sanitizer = DiagnosticSanitizer([secret, '']);
  final diagnostics = <String>[];
  final peer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var rounds = 0;
  var deleteCount = 0;
  final listener = peer.listen((request) async {
    if (request.method == 'DELETE') {
      deleteCount++;
      request.response.statusCode = 405;
    } else {
      final wire = await utf8.decoder.bind(request).join();
      final body = jsonDecode(wire) as Map<String, dynamic>;
      final method = body['method'];
      if (method == 'invalid-json') {
        request.response.headers.contentType = ContentType.json;
        request.response.write('not-json');
      } else if (method == 'unsupported-version') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': body['id'],
            'error': {
              'code': -32022,
              'message': 'Unsupported version',
              'data': {
                'supported': ['2026-07-28'],
              },
            },
          }),
        );
      } else {
        rounds++;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.headers.set('set-cookie', 'session=unknown-cookie');
        final result = rounds == 1
            ? {
                'resultType': 'input_required',
                'content': [],
                'continuation': 'round-two',
              }
            : {
                'resultType': 'complete',
                'content': [
                  {'type': 'text', 'text': secret},
                ],
              };
        request.response.write(
          'data: ${jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result, 'x-extra': true})}\n\n',
        );
      }
    }
    await request.response.close();
  });
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:${peer.port}',
      responseType: ResponseType.plain,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (_) => true,
    ),
  );
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  Future<Map<String, dynamic>> send(
    int id,
    String method, {
    Map<String, dynamic> params = const {},
  }) async {
    final wire = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });
    diagnostics.add(sanitizer.frame(wire));
    final response = await dio.post<String>(
      '/mcp',
      data: wire,
      options: Options(
        contentType: 'application/json',
        headers: {'Authorization': 'Bearer $secret'},
      ),
    );
    diagnostics.add(jsonEncode(sanitizer.json(response.headers.map)));
    final raw = response.data!;
    // Split complete SSE events for this bounded fixture; production must stream.
    final frames = raw.startsWith('data: ')
        ? raw
              .split('\n\n')
              .where((event) => event.isNotEmpty)
              .map((event) => event.substring(6))
        : [raw];
    Map<String, dynamic>? result;
    for (final frame in frames) {
      diagnostics.add(sanitizer.frame(frame));
      result = jsonDecode(frame) as Map<String, dynamic>;
    }
    return result!;
  }

  try {
    final first = await send(1, 'tools/call');
    check(
      first['result']['resultType'] == 'input_required' && rounds == 1,
      'Intermediate round must remain under caller control',
    );
    final second = await send(
      2,
      'tools/call',
      params: {'continuation': 'round-two'},
    );
    check(
      second['id'] == 2 &&
          rounds == 2 &&
          second['result']['content'][0]['text'] == secret,
      'Explicit second round failed or result mutated',
    );
    check(second['x-extra'] == true, 'Wire extension lost');
    final unsupported = await send(3, 'unsupported-version');
    check(
      unsupported['error']['code'] == -32022 &&
          unsupported['error']['data']['supported'][0] == '2026-07-28',
      'Supported versions lost',
    );
    var malformed = false;
    try {
      await send(4, 'invalid-json');
    } on FormatException {
      malformed = true;
    }
    check(malformed, 'Malformed response must be surfaced explicitly');
    final deleted = await dio.delete<String>('/mcp');
    check(deleted.statusCode == 405 && deleteCount == 1, 'DELETE 405 failed');
    const exact = ' { "jsonrpc":"2.0", "id":5, "result":{}, "x-extra":true } ';
    check(
      sanitizer.frame(exact) == exact,
      'Unredacted frame formatting changed',
    );
    final sanitized = sanitizer.json({
      'Authorization': 'unknown-bearer',
      'SET-COOKIE': 'unknown-cookie',
      'nested': [
        {'value': secret, 'encoded': Uri.encodeComponent(secret)},
      ],
      'url': 'https://example.test/?ACCESS_TOKEN=unknown-token&code=unknown-code&safe=ok',
    });
    final retained = jsonEncode(sanitized);
    check(
      !retained.contains(secret) &&
          !retained.contains('unknown-') &&
          retained.contains('safe=ok'),
      'Credential/header/query redaction failed',
    );
    diagnostics.add(
      sanitizer.text('stderr $secret ${Uri.encodeComponent(secret)}'),
    );
    check(
      !diagnostics.join().contains(secret) &&
          !diagnostics.join().contains('unknown-cookie'),
      'Raw credentials entered diagnostic retention',
    );
    stdout.writeln(
      'PASS: Dio raw SSE capture, explicit two-round control, preserved extensions',
    );
    stdout.writeln('PASS: unsupported version, malformed JSON, DELETE 405');
    stdout.writeln(
      'PASS: nested/header/query/encoded/stderr credential canaries',
    );
  } finally {
    dio.close(force: true);
    await peer.close(force: true);
    await listener.cancel();
  }
}
