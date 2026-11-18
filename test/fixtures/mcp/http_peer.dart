import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'binary_payload.dart';

/// Controlled loopback peer for real HTTP transport integration checks.
class McpHttpPeer {
  McpHttpPeer._(this._server) {
    _subscription = _server.listen(_handle);
  }
  final HttpServer _server;
  late final StreamSubscription<HttpRequest> _subscription;
  final bodies = <Map<String, dynamic>>[];
  final headers = <Map<String, String>>[];
  final heldArrived = Completer<void>();
  final _held = <HttpResponse>[];
  HttpResponse? _waitingStream;
  Object? _waitingId;
  bool expired = false;
  bool sse = false;
  bool cutStream = false;
  bool malformed = false;
  bool resumeStreams = false;
  int resumeStatus = 200;
  final resumeHeaders = <Map<String, String>>[];
  final _resumeMessages = <String, String>{};
  String? largeText;
  bool holdCalls = false;
  bool holdDelete = false;
  int? nextStatus;
  int deleteStatus = 405;
  int deletes = 0;
  int gets = 0;
  bool _disposed = false;
  static const secret = 'http-canary+private';
  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/mcp');
  static Future<McpHttpPeer> start() async =>
      McpHttpPeer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> _handle(HttpRequest request) async {
    try {
      final response = request.response;
      if (request.method == 'DELETE') {
        deletes++;
        if (holdDelete) {
          _held.add(response);
          return;
        }
        response.statusCode = deleteStatus;
        await response.close();
        return;
      }
      if (request.method == 'GET') {
        gets++;
        if (resumeStreams) {
          final observed = <String, String>{};
          request.headers.forEach(
            (key, values) => observed[key] = values.join(','),
          );
          resumeHeaders.add(observed);
          final message = _resumeMessages.remove(
            request.headers.value('last-event-id'),
          );
          response.statusCode = resumeStatus;
          if (resumeStatus == 200 && message != null) {
            response.headers.contentType = ContentType('text', 'event-stream');
            response.add(utf8.encode('data: $message\n\n'));
          } else if (resumeStatus == 200) {
            response.statusCode = 400;
          }
          await response.close();
          return;
        }
        response.statusCode = 405;
        await response.close();
        return;
      }
      final body = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      bodies.add(body);
      final observedHeaders = <String, String>{};
      request.headers.forEach(
        (name, values) => observedHeaders[name] = values.join(','),
      );
      headers.add(observedHeaders);
      if (body['id'] == 'server-request' && body['error'] is Map) {
        response.statusCode = 202;
        await response.close();
        final stream = _waitingStream!;
        stream.write(
          'data: ${jsonEncode({
            'jsonrpc': '2.0',
            'id': _waitingId,
            'result': {'clientErrorCode': body['error']['code']},
          })}\n\n',
        );
        await stream.close();
        _waitingStream = null;
        return;
      }
      if (expired || nextStatus != null) {
        response.statusCode = expired ? 404 : nextStatus!;
        response.headers.set('retry-after', '2');
        nextStatus = null;
        await response.close();
        return;
      }
      final method = body['method'];
      final id = body['id'];
      if (id == null) {
        response.statusCode = 202;
        await response.close();
        return;
      }
      Map<String, dynamic> result;
      if (method == 'initialize') {
        response.headers.set('mcp-session-id', 'fixture-session');
        result = {
          'protocolVersion': '2025-11-25',
          'capabilities': {},
          'serverInfo': {'name': 'http-peer', 'version': '1'},
        };
      } else if (method == 'server/discover') {
        result = {
          'supportedVersions': ['2026-07-28'],
          'capabilities': {},
          'serverInfo': {'name': 'http-peer', 'version': '1'},
        };
      } else {
        if (holdCalls) {
          _held.add(response);
          if (!heldArrived.isCompleted) heldArrived.complete();
          return;
        }
        if (body['params']['name'] == 'ask') {
          _waitingStream = response;
          _waitingId = id;
          response.bufferOutput = false;
          response.headers.contentType = ContentType('text', 'event-stream');
          response.write(
            'data: ${jsonEncode({'jsonrpc': '2.0', 'id': 'server-request', 'method': 'sampling/createMessage', 'params': {}})}\n\n',
          );
          await response.flush();
          return;
        }
        result = body['params']['name'] == 'binary-20-mib'
            ? binaryToolResult()
            : {
                'resultType': body['params']['name'] == 'needs-input'
                    ? 'input_required'
                    : 'complete',
                'content': [
                  {'type': 'text', 'text': secret},
                ],
                'cookieEcho': 'response-canary',
                if (largeText != null) 'largeText': largeText,
                'observedMeta': body['params']['_meta'],
                'label': '雪',
              };
      }
      response.headers.set('set-cookie', 'session=response-canary; Path=/');
      final message = jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
        'x-wire-extension': true,
      });
      if (resumeStreams && method == 'tools/call') {
        final cursor = 'resume-$id-$secret';
        _resumeMessages[cursor] = message;
        response.headers.contentType = ContentType('text', 'event-stream');
        response.write('id: $cursor\nretry: 1\ndata:\n\ndata: {"cut"');
        await response.close();
        return;
      }
      if (sse && method != 'initialize' && method != 'server/discover') {
        response.headers.contentType = ContentType('text', 'event-stream');
        if (cutStream) {
          response.write('id: ignored\ndata: {"jsonrpc":');
        } else {
          final split = message.indexOf(',');
          final event =
              ': heartbeat\r\nid: ignored\r\ndata: ${message.substring(0, split + 1)}\r\ndata: ${message.substring(split + 1)}\r\n\r\n';
          final bytes = utf8.encode(event);
          response.add(bytes.sublist(0, bytes.length ~/ 2));
          await response.flush();
          response.add(bytes.sublist(bytes.length ~/ 2));
        }
      } else {
        response.headers.contentType = ContentType.json;
        response.write(
          malformed ? '{"Authorization":"$secret",broken' : message,
        );
      }
      await response.close();
    } on HttpException {
      // Fixture clients deliberately cancel/expire streams in several checks.
    }
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    await _server.close(force: true);
    await _subscription.cancel();
    _held.clear();
    _waitingStream = null;
    _resumeMessages.clear();
  }
}
