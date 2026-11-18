import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'binary_payload.dart';

class DeprecatedSsePeer {
  DeprecatedSsePeer._(this._server) {
    _subscription = _server.listen(_handle);
  }
  final HttpServer _server;
  late final StreamSubscription<HttpRequest> _subscription;
  HttpResponse? _stream;
  Future<void> _writes = Future.value();
  final messages = <Map<String, dynamic>>[];
  final urls = <Uri>[];
  final headers = <Map<String, String>>[];
  final posted = StreamController<Map<String, dynamic>>.broadcast();
  final reply = Completer<int>();
  String? endpointOverride;
  bool announce = true;
  bool answerCalls = true;
  int postStatus = 202;
  int gets = 0;
  int deletes = 0;
  static const token = 'old-endpoint-private';
  static const secret = 'old-header-private';
  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/sse');
  static Future<DeprecatedSsePeer> start() async => DeprecatedSsePeer._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
  );

  Future<void> _handle(HttpRequest request) async {
    try {
      final response = request.response;
      if (request.method == 'GET') {
        gets++;
        response.bufferOutput = false;
        response.headers.contentType = ContentType('text', 'event-stream');
        _stream = response;
        _writes = _writes.then((_) async {
          response.add(
            utf8.encode(
              announce
                  ? 'event: endpoint\ndata: ${endpointOverride ?? '/messages?sessionId=$token'}\n\n'
                  : ': waiting\n\n',
            ),
          );
          await response.flush();
        });
        await _writes;
        return;
      }
      if (request.method == 'DELETE') {
        deletes++;
        response.statusCode = 405;
        await response.close();
        return;
      }
      urls.add(request.uri);
      final observed = <String, String>{};
      request.headers.forEach(
        (key, values) => observed[key] = values.join(','),
      );
      headers.add(observed);
      final message = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      messages.add(message);
      posted.add(message);
      if (message['error'] is Map) {
        if (!reply.isCompleted) reply.complete(message['error']['code'] as int);
      } else if (message['id'] != null &&
          (message['method'] == 'initialize' || answerCalls)) {
        await send({
          'jsonrpc': '2.0',
          'id': message['id'],
          'result': message['method'] == 'initialize'
              ? {
                  'protocolVersion': '2024-11-05',
                  'capabilities': {},
                  'serverInfo': {'name': 'old-http-sse', 'version': '1'},
                }
              : message['params']?['name'] == 'binary-20-mib'
              ? binaryToolResult()
              : {'id': message['id'], 'text': secret, 'endpointEcho': token},
        });
      }
      response.statusCode = postStatus;
      await response.close();
    } on HttpException {
      // Clients deliberately cancel streams and pending requests in these checks.
    }
  }

  Future<void> send(Map<String, dynamic> message) =>
      _writes = _writes.then((_) async {
        _stream!.add(
          utf8.encode('event: message\ndata: ${jsonEncode(message)}\n\n'),
        );
        await _stream!.flush();
      });

  Future<void> endStream() async {
    await _writes;
    await _stream?.close();
    _stream = null;
  }

  Future<void> close() async {
    await _server.close(force: true);
    await _subscription.cancel();
    await posted.close();
    _stream = null;
  }
}
