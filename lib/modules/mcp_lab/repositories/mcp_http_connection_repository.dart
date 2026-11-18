import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:mcp_dart/mcp_dart.dart'
    show McpMetaKey, legacyProtocolVersions, stableProtocolVersion;
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_diagnostics.dart';
import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';
import 'mcp_connection_repository.dart';
import 'mcp_diagnostic_sanitizer.dart';
import 'mcp_diagnostic_stream.dart';
import 'mcp_http_diagnostic_body.dart';
import 'mcp_error_mapper.dart';
import 'mcp_frame_limits.dart';
import 'mcp_proxy.dart';
import 'mcp_rpc_diagnostics.dart';
import 'mcp_sse_parser.dart';

typedef McpHttpClientFactory = Dio Function(
  McpConnectTarget target,
  Uri? proxy,
);

class McpHttpConnectionRepository implements McpConnectionRepository {
  McpHttpConnectionRepository({
    required this.isAuthorized,
    required this.clientVersion,
    this.listenForLegacyNotifications = true,
    McpHttpClientFactory? createClient,
  }) : _createClient = createClient ?? _client;
  final bool Function(McpAccessContext, String serverId) isAuthorized;
  final String clientVersion;
  final bool listenForLegacyNotifications;
  final McpHttpClientFactory _createClient;

  @override
  Future<Result<McpSession>> connect(McpConnectTarget target) async {
    if (!isAuthorized(target.context, target.server.id)) {
      return const Result.failure(_accessFailure);
    }
    if (target.server.draft.transport != McpTransport.http) {
      return const Result.failure(
        McpValidationFailure(
          'Use Streamable HTTP for this target. Deprecated HTTP+SSE transport is not implemented yet.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final draft = target.server.draft;
    final uri = Uri.tryParse(draft.url ?? '');
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        RegExp(
          r'^https?://[^/?#]*@',
          caseSensitive: false,
        ).hasMatch(draft.url!)) {
      return const Result.failure(
        McpValidationFailure(
          'Use an HTTP(S) URL without user-info.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final headers = {
      for (final entry in draft.headers.entries)
        entry.key.toLowerCase(): entry.value,
    };
    final secrets = <String>[];
    for (final key in draft.secretKeys) {
      final value = key.startsWith('header.')
          ? headers[key.substring(7).toLowerCase()]
          : key.startsWith('env.')
          ? draft.env[key.substring(4)]
          : null;
      if (target.server.secretStates[key] != SecretValueState.present ||
          value == null ||
          value.isEmpty) {
        return const Result.failure(
          McpValidationFailure(
            'Set missing device secrets before connecting.',
            code: McpErrorCode.invalidParams,
          ),
        );
      }
      secrets.add(value);
    }
    final proxy = resolveMcpProxy(uri, target.proxy?.toString(), const {});
    if (proxy case Err(:final failure)) return Result.failure(failure);
    if (proxy.valueOrNull?.scheme == 'https') {
      return const Result.failure(
        McpValidationFailure(
          'TLS proxy endpoints are not supported yet. Configure an HTTP proxy endpoint.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    try {
      final client = _createClient(target, proxy.valueOrNull);
      // Dedicated client: credential-bearing exchanges must not hit debug interceptors.
      client.interceptors.clear();
      return Result.success(
        _HttpSession(
          client,
          uri,
          headers,
          McpDiagnosticSanitizer(
            secretValues: secrets,
            headers: {
              for (final entry in headers.entries) entry.key: [entry.value],
            },
          ),
          context: target.context,
          serverId: target.server.id,
          timeout: target.timeout,
          clientVersion: clientVersion,
          isAuthorized: isAuthorized,
          listenForLegacyNotifications: listenForLegacyNotifications,
        ),
      );
    } on Object {
      return Result.failure(
        McpNetworkFailure(
          'Could not configure the MCP HTTP client.',
          code: McpErrorCode.unreachable,
        ),
      );
    }
  }

  static Dio _client(McpConnectTarget target, Uri? proxy) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: target.timeout,
        receiveTimeout: target.timeout,
        sendTimeout: target.timeout,
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (_) => proxy == null
            ? 'DIRECT'
            : 'PROXY ${proxy.host.contains(':') ? '[${proxy.host}]' : proxy.host}:${proxy.port}';
        if (proxy != null && proxy.userInfo.isNotEmpty) {
          client.authenticateProxy = (host, port, scheme, realm) async {
            if (host != proxy.host || port != proxy.port) return false;
            final separator = proxy.userInfo.indexOf(':');
            final user = separator < 0
                ? proxy.userInfo
                : proxy.userInfo.substring(0, separator);
            final password = separator < 0
                ? ''
                : proxy.userInfo.substring(separator + 1);
            client.addProxyCredentials(
              host,
              port,
              realm ?? '',
              HttpClientBasicCredentials(
                Uri.decodeComponent(user),
                Uri.decodeComponent(password),
              ),
            );
            return true;
          };
        }
        return client;
      },
    );
    return dio;
  }
}

const _accessFailure = McpAuthFailure(
  'The account or workspace changed. Reconnect from the current workspace.',
);
final _cancelled = McpNetworkFailure(
  'Request cancelled because the MCP session closed.',
  code: McpErrorCode.unreachable,
);

class _HttpOperation {
  _HttpOperation(this.id, this.method, {this.listContinuation = false});
  final bool listContinuation;
  final Object? id;
  final String method;
  final completion = Completer<Result<Map<String, dynamic>>>();
  final finished = Completer<void>();
  final token = CancelToken();
  Timer? timer;
  String? lastEventId;
  int retryMilliseconds = 0;
  bool get done => completion.isCompleted;
}

class _ToolHeaderParameter {
  const _ToolHeaderParameter({
    required this.path,
    required this.headerName,
    required this.type,
  });

  final List<String> path;
  final String headerName;
  final String type;
}

class _HttpSession implements McpSession {
  _HttpSession(
    Dio client,
    this._url,
    this._headers,
    this._sanitizer, {
    required this.context,
    required this.serverId,
    required this.timeout,
    required this.clientVersion,
    required this.isAuthorized,
    required this.listenForLegacyNotifications,
  }) : _client = client,
       _mapper = McpErrorMapper(_sanitizer),
       _frames = McpRpcDiagnostics(_sanitizer);
  Dio? _client;
  final Uri _url;
  final Map<String, String> _headers;
  final McpDiagnosticSanitizer _sanitizer;
  final McpErrorMapper _mapper;
  final McpRpcDiagnostics _frames;
  final McpAccessContext context;
  final String serverId;
  final Duration timeout;
  final String clientVersion;
  final bool Function(McpAccessContext, String) isAuthorized;
  final bool listenForLegacyNotifications;
  _HttpOperation? _notificationOperation;
  bool _notificationsAttempted = false;
  final _operations = <_HttpOperation>{};
  final _tasks = <Future<void>>{};
  final _issued = <Object>{};
  final _network = McpDiagnosticStream<NetworkEntry>(
    (count) => NetworkEntry(
      method: 'WARNING',
      url: '',
      body: '$count startup network entries dropped (buffer limit).',
      duration: Duration.zero,
    ),
  );
  final _console = StreamController<ConsoleLine>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _current = const ConnectionStatus.connecting();
  Map<String, dynamic> _serverInfo = {};
  NegotiatedEra? _era;
  String? _version;
  String? _sessionId;
  final Map<String, List<_ToolHeaderParameter>> _toolHeaderParameters = {};
  McpCoded? _terminalFailure;
  var _nextId = 1;
  var _initialized = false;
  var _closing = false;
  var _disposed = false;
  Future<Result<void>>? _closeFuture;
  @override
  Stream<RpcFrame> get frames => _frames.stream;
  @override
  Stream<NetworkEntry> get network => _network.stream;
  @override
  Stream<ConsoleLine> get console => _console.stream;
  @override
  Stream<ConnectionStatus> get status => Stream.multi((sink) {
    final subscription = _status.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.add(_current);
    sink.onCancel = subscription.cancel;
  }, isBroadcast: true);
  bool _active() {
    if (_closing || _terminalFailure != null) return false;
    if (!isAuthorized(context, serverId)) {
      _disconnect(_accessFailure);
      return false;
    }
    return true;
  }

  Failure get _inactive => !isAuthorized(context, serverId)
      ? _accessFailure
      : _terminalFailure is Failure
      ? _terminalFailure as Failure
      : _cancelled;
  bool _allowed(String method) => _era == null
      ? method == 'initialize' || method == 'server/discover'
      : method != 'initialize' &&
            method != 'server/discover' &&
            (_era == NegotiatedEra.modern || _initialized);

  @override
  Result<void> configureProtocol({
    required NegotiatedEra era,
    required String version,
  }) {
    if (!_active()) return Result.failure(_inactive);
    if (era == NegotiatedEra.modern
        ? version != stableProtocolVersion
        : !legacyProtocolVersions.contains(version)) {
      return Result.failure(
        McpNetworkFailure(
          'Unsupported MCP protocol version.',
          code: McpErrorCode.protocolVersionUnsupported,
        ),
      );
    }
    _era = era;
    _version = version;
    if (era == NegotiatedEra.modern) {
      _sessionId = null;
      final listener = _notificationOperation;
      if (listener != null) _finish(listener, Result.failure(_cancelled));
    }
    _current = ConnectionStatus.connected(era: era, serverInfo: _serverInfo);
    _status.add(_current);
    return const Result.success(null);
  }

  Map<String, dynamic> _params(String method, Map<String, dynamic> params) =>
      _era != NegotiatedEra.modern && method != 'server/discover'
      ? params
      : {
          ...params,
          '_meta': {
            if (params['_meta'] is Map)
              ...Map<String, dynamic>.from(params['_meta'] as Map),
            McpMetaKey.protocolVersion: _version ?? stableProtocolVersion,
            McpMetaKey.clientCapabilities: <String, dynamic>{},
            McpMetaKey.clientInfo: {
              'name': 'API Caffeine',
              'version': clientVersion,
            },
          },
        };

  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) {
    if (!_active()) return Future.value(Result.failure(_inactive));
    if (id != null && (id is! String && id is! int || _issued.contains(id))) {
      return Future.value(
        const Result.failure(
          McpValidationFailure(
            'Use a fresh string or integer request ID.',
            code: McpErrorCode.invalidParams,
          ),
        ),
      );
    }
    while (_issued.contains(_nextId)) {
      _nextId++;
    }
    final requestId = id ?? _nextId++;
    _issued.add(requestId);
    return _run(
      method,
      params,
      id: requestId,
      duration: timeout ?? this.timeout,
    );
  }

  @override
  Future<Result<void>> notify(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (method == 'notifications/initialized' && _era != NegotiatedEra.legacy) {
      return const Result.failure(
        McpValidationFailure(
          'Initialize a legacy session before sending initialized.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final result = await _run(method, params, duration: timeout);
    if (result.isSuccess && method == 'notifications/initialized') {
      if (!_active()) return Result.failure(_inactive);
      _initialized = true;
      if (listenForLegacyNotifications && !_notificationsAttempted) {
        return _openNotificationStream();
      }
    }
    return result.when(
      success: (_) => const Result.success(null),
      failure: Result.failure,
    );
  }

  Future<Result<void>> _openNotificationStream() {
    _notificationsAttempted = true;
    final operation = _HttpOperation(null, 'notifications/listen');
    _notificationOperation = operation;
    final ready = Completer<Result<void>>();
    final task = _listenForNotifications(operation, ready);
    _tasks.add(task);
    unawaited(task.whenComplete(() => _tasks.remove(task)));
    return ready.future;
  }

  void _notificationWarning(String message) {
    if (_closing || _disposed || !isAuthorized(context, serverId)) return;
    _console.add(ConsoleLine(timestamp: DateTime.now().toUtc(), text: message));
  }

  Future<void> _listenForNotifications(
    _HttpOperation operation,
    Completer<Result<void>> ready,
  ) async {
    final headers = _requestHeaders('GET', {})
      ..remove('content-type')
      ..['accept'] = 'text/event-stream';
    final watch = Stopwatch()..start();
    final body = McpHttpDiagnosticBody();
    int? status;
    Map<String, List<String>> responseHeaders = {};
    McpCoded? terminal;
    Result<void> outcome = const Result.success(null);
    // Only header establishment has a request deadline. An established stream
    // may idle until the session closes; request calls keep their own deadlines.
    final openingTimer = Timer(timeout, () {
      if (ready.isCompleted) return;
      if (!_active()) {
        ready.complete(Result.failure(_inactive));
        _finish(operation, Result.failure(_inactive));
        return;
      }
      _notificationWarning(
        'Optional notification stream opening timed out. Request calls remain available.',
      );
      ready.complete(const Result.success(null));
      _finish(operation, Result.failure(_cancelled));
    });
    try {
      final response = await _client!.get<ResponseBody>(
        _url.toString(),
        cancelToken: operation.token,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: headers,
        ),
      );
      openingTimer.cancel();
      if (!_live(operation)) {
        await response.data!.stream.listen((_) {}).cancel();
        return;
      }
      status = response.statusCode;
      responseHeaders = response.headers.map;
      _sanitizer.headers(responseHeaders);
      if (status == 401 || status == 403 || status == 404) {
        final failure = _mapper.http(status!);
        terminal = failure as McpCoded;
        outcome = Result.failure(failure);
        if (status == 404) _sessionId = null;
        await response.data!.stream.listen((_) {}).cancel();
      } else if (status == 405) {
        await response.data!.stream.listen((_) {}).cancel();
      } else if (status != 200 ||
          response.headers
                  .value('content-type')
                  ?.split(';')
                  .first
                  .trim()
                  .toLowerCase() !=
              'text/event-stream') {
        body.truncated = true;
        _notificationWarning(
          'Optional notification stream is unavailable. Request calls remain available.',
        );
        await response.data!.stream.listen((_) {}).cancel();
      } else {
        if (!ready.isCompleted) ready.complete(const Result.success(null));
        await for (final event in mcpSseEvents(
          _body(response.data!, operation),
        )) {
          if (!_live(operation)) break;
          final data = event.data;
          if (data == null || data.isEmpty) continue;
          final result = await _acceptFrame(
            data,
            operation,
            body,
            allowResponse: false,
          );
          if (result != null && !result.isSuccess) {
            _notificationWarning(
              'Could not answer a server request on the optional notification stream.',
            );
          }
        }
        if (_live(operation)) {
          _notificationWarning(
            'Optional notification stream ended. Request calls remain available.',
          );
        }
      }
    } on Object {
      body.truncated = true;
      if (_live(operation)) {
        _notificationWarning(
          'Optional notification stream failed. Request calls remain available.',
        );
      }
    } finally {
      openingTimer.cancel();
      _captureNetwork(
        method: 'GET',
        requestHeaders: headers,
        responseHeaders: responseHeaders,
        status: status,
        body: body,
        duration: watch.elapsed,
      );
      body.clear();
      _finish(operation, Result.failure(_cancelled));
      if (identical(_notificationOperation, operation)) {
        _notificationOperation = null;
      }
      if (terminal != null) _disconnect(terminal);
      if (!ready.isCompleted) {
        ready.complete(!_active() ? Result.failure(_inactive) : outcome);
      }
    }
  }

  Future<Result<Map<String, dynamic>>> _run(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    required Duration duration,
  }) {
    if (!_active()) return Future.value(Result.failure(_inactive));
    final initializedNotice =
        method == 'notifications/initialized' && _era == NegotiatedEra.legacy;
    if (duration <= Duration.zero ||
        method.trim().isEmpty ||
        (!initializedNotice && !_allowed(method))) {
      return Future.value(
        const Result.failure(
          McpValidationFailure(
            'Use a positive timeout and negotiated session.',
            code: McpErrorCode.invalidParams,
          ),
        ),
      );
    }
    String wire;
    try {
      wire = jsonEncode({
        'jsonrpc': '2.0',
        'id': ?id,
        'method': method,
        'params': _params(method, params),
      });
    } on Object {
      return Future.value(
        const Result.failure(
          McpValidationFailure(
            'Request parameters must be JSON-compatible.',
            code: McpErrorCode.invalidParams,
          ),
        ),
      );
    }
    final operation = _HttpOperation(
      id,
      method,
      listContinuation: method == 'tools/list' && params['cursor'] != null,
    );
    _operations.add(operation);
    operation.timer = Timer(
      duration,
      () => _finish(
        operation,
        Result.failure(
          McpNetworkFailure(
            'MCP request timed out.',
            code: McpErrorCode.unreachable,
          ),
        ),
      ),
    );
    final task = _perform(operation, wire, params);
    _tasks.add(task);
    unawaited(task.whenComplete(() => _tasks.remove(task)));
    return operation.completion.future;
  }

  bool _live(_HttpOperation operation) => !operation.done && _active();
  void _finish(_HttpOperation operation, Result<Map<String, dynamic>> result) {
    if (operation.done) return;
    operation.timer?.cancel();
    operation.lastEventId = null;
    _operations.remove(operation);
    operation.completion.complete(result);
    operation.finished.complete();
    operation.token.cancel('MCP operation finished.');
  }

  void _disconnect(McpCoded failure) {
    _terminalFailure = failure;
    _current = ConnectionStatus.disconnected(failure: failure);
    _status.add(_current);
    for (final operation in _operations.toList()) {
      _finish(operation, Result.failure(failure as Failure));
    }
    unawaited(close());
  }

  Map<String, String> _requestHeaders(
    String method,
    Map<String, dynamic> params,
  ) {
    final headers = {..._headers}
      ..removeWhere(
        (key, _) =>
            key == 'mcp-session-id' ||
            key == 'mcp-protocol-version' ||
            key == 'last-event-id' ||
            key == 'mcp-method' ||
            key == 'mcp-name' ||
            key.startsWith('mcp-param-') ||
            key == 'content-type' ||
            key == 'accept',
      );
    headers['content-type'] = 'application/json';
    headers['accept'] = 'application/json, text/event-stream';
    final modern = _era == NegotiatedEra.modern || method == 'server/discover';
    if (_version != null || modern) {
      headers['mcp-protocol-version'] = modern
          ? stableProtocolVersion
          : _version!;
    }
    if (!modern && _sessionId != null) headers['mcp-session-id'] = _sessionId!;
    if (modern) {
      headers['mcp-method'] = _encodeHeader(method);
      final value = switch (method) {
        'tools/call' || 'prompts/get' => params['name'],
        'resources/read' => params['uri'],
        'tasks/get' || 'tasks/update' || 'tasks/cancel' => params['taskId'],
        _ => null,
      };
      if (value is String) headers['mcp-name'] = _encodeHeader(value);
      if (method == 'tools/call' && params['name'] is String) {
        final input = params['arguments'];
        final mappings = _toolHeaderParameters[params['name']];
        if (input is Map && mappings != null) {
          for (final mapping in mappings) {
            final value = _nestedValue(input, mapping.path);
            final encoded = _headerParameterValue(value, mapping.type);
            if (encoded != null) {
              headers['mcp-param-${mapping.headerName.toLowerCase()}'] =
                  encoded;
            }
          }
        }
      }
    }
    // Learn mirrored credential values before recording outgoing JSON.
    _sanitizer.headers({
      for (final entry in headers.entries) entry.key: [entry.value],
    });
    return headers;
  }

  String _encodeHeader(String value) =>
      value.isNotEmpty &&
          value.trim() == value &&
          !value.startsWith('=?base64?') &&
          value.codeUnits.every(
            (unit) => unit == 9 || unit >= 32 && unit <= 126,
          )
      ? value
      : '=?base64?${base64Encode(utf8.encode(value))}?=';

  Object? _nestedValue(Object root, List<String> path) {
    Object? value = root;
    for (final part in path) {
      if (value is! Map || !value.containsKey(part)) return null;
      value = value[part];
    }
    return value;
  }

  String? _headerParameterValue(Object? value, String type) {
    final rendered = switch ((type, value)) {
      ('string', final String text) => text,
      ('boolean', final bool boolean) => boolean.toString(),
      ('integer', final int integer)
          when integer >= -9007199254740991 && integer <= 9007199254740991 =>
        integer.toString(),
      _ => null,
    };
    if (rendered == null) return null;
    final trimmedAtEdge =
        rendered.startsWith(' ') ||
        rendered.startsWith('\t') ||
        rendered.endsWith(' ') ||
        rendered.endsWith('\t');
    final ascii = rendered.codeUnits.every((unit) => unit >= 32 && unit <= 126);
    final sentinel =
        rendered.startsWith('=?base64?') && rendered.endsWith('?=');
    return !trimmedAtEdge && ascii && !sentinel
        ? rendered
        : '=?base64?${base64Encode(utf8.encode(rendered))}?=';
  }

  List<dynamic> _rememberToolHeaders(
    Map<String, dynamic> result, {
    required bool continuation,
  }) {
    final tools = result['tools'];
    if (tools is! List) return const [];
    if (!continuation) _toolHeaderParameters.clear();
    final visibleTools = <dynamic>[];
    for (final tool in tools) {
      if (tool is! Map || tool['name'] is! String) {
        visibleTools.add(tool);
        continue;
      }
      _toolHeaderParameters.remove(tool['name']);
      final schema = tool['inputSchema'];
      if (schema is! Map) {
        visibleTools.add(tool);
        continue;
      }
      final mappings = <_ToolHeaderParameter>[];
      final headerNames = <String>{};
      if (!_collectToolHeaderParameters(
        schema,
        const [],
        mappings,
        headerNames,
      )) {
        _console.add(
          ConsoleLine(
            timestamp: DateTime.now(),
            text: 'Tool excluded because its x-mcp-header annotations are invalid.',
          ),
        );
        continue;
      }
      visibleTools.add(tool);
      _toolHeaderParameters[tool['name'] as String] = mappings;
    }
    return visibleTools;
  }

  bool _collectToolHeaderParameters(
    Map schema,
    List<String> path,
    List<_ToolHeaderParameter> output,
    Set<String> headerNames,
  ) {
    final properties = schema['properties'];
    if (properties is! Map) return true;
    for (final entry in properties.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final property = entry.value as Map;
      final propertyPath = [...path, entry.key as String];
      if (property.containsKey('x-mcp-header')) {
        final headerName = property['x-mcp-header'];
        final type = property['type'];
        if (headerName is! String ||
            headerName.isEmpty ||
            !RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(headerName) ||
            !const {'string', 'integer', 'boolean'}.contains(type) ||
            !headerNames.add(headerName.toLowerCase())) {
          return false;
        }
        output.add(
          _ToolHeaderParameter(
            path: List.unmodifiable(propertyPath),
            headerName: headerName,
            type: type as String,
          ),
        );
      }
      if (!_collectToolHeaderParameters(
        property,
        propertyPath,
        output,
        headerNames,
      )) {
        return false;
      }
    }
    return true;
  }

  Stream<List<int>> _body(ResponseBody body, _HttpOperation operation) =>
      Stream.multi((sink) {
        final subscription = body.stream.listen(
          sink.add,
          onError: sink.addError,
          onDone: sink.close,
        );
        unawaited(
          operation.finished.future.then((_) {
            unawaited(subscription.cancel());
            sink.close();
          }),
        );
        sink.onCancel = subscription.cancel;
      });

  Future<void> _perform(
    _HttpOperation operation,
    String wire,
    Map<String, dynamic> params,
  ) async {
    final watch = Stopwatch()..start();
    final body = McpHttpDiagnosticBody();
    final requestHeaders = _requestHeaders(operation.method, params);
    Map<String, List<String>> responseHeaders = {};
    int? status;
    Result<Map<String, dynamic>> result;
    McpCoded? terminal;
    var postCaptured = false;
    void capturePost() {
      if (postCaptured) return;
      postCaptured = true;
      _captureNetwork(
        method: 'POST',
        requestHeaders: requestHeaders,
        responseHeaders: responseHeaders,
        status: status,
        body: body,
        duration: watch.elapsed,
        wire: wire,
      );
      body.clear();
    }

    try {
      if (!_live(operation)) return;
      _frames.record(wire, RpcDirection.outgoing);
      final response = await _client!.post<ResponseBody>(
        _url.toString(),
        data: wire,
        cancelToken: operation.token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: requestHeaders,
        ),
      );
      if (!_live(operation)) {
        await response.data!.stream.listen((_) {}).cancel();
        return;
      }
      status = response.statusCode;
      responseHeaders = response.headers.map;
      // Learn response credentials before retaining frames that may echo them.
      _sanitizer.headers(responseHeaders);
      if (status == 404) {
        _sessionId = null;
        final failure = _mapper.http(404);
        terminal = failure as McpCoded;
        result = Result.failure(failure);
        await response.data!.stream.listen((_) {}).cancel();
      } else if (status == 401 || status == 403) {
        final failure = _mapper.http(status!);
        terminal = failure as McpCoded;
        result = Result.failure(failure);
        await response.data!.stream.listen((_) {}).cancel();
      } else if (status == null || status < 200 || status >= 300) {
        result = Result.failure(
          _mapper.http(
            status ?? 0,
            retryAfter: response.headers.value('retry-after'),
          ),
        );
        await response.data!.stream.listen((_) {}).cancel();
      } else {
        if (operation.method == 'initialize') {
          _sessionId = response.headers.value('mcp-session-id');
          if (_sessionId != null) _sanitizer.addSecrets([_sessionId!]);
        }
        if (operation.id == null) {
          await for (final chunk in _body(response.data!, operation)) {
            // Notification responses are not RPC results. Do not claim an
            // omitted nonempty body is a complete, empty diagnostic capture.
            if (chunk.isNotEmpty) body.truncated = true;
          }
          result = const Result.success({});
        } else {
          final contentType = response.headers
              .value('content-type')
              ?.split(';')
              .first
              .trim()
              .toLowerCase();
          final bytes = _body(response.data!, operation);
          Result<Map<String, dynamic>>? matched;
          if (contentType == 'text/event-stream') {
            matched = await _readSse(bytes, operation, body);
            if (matched == null) body.truncated = true;
            if (matched == null && _canResume(operation)) {
              capturePost();
              matched = await _resumeSse(operation, params);
            }
          } else if (contentType == 'application/json') {
            final collected = BytesBuilder(copy: false);
            await for (final chunk in bytes) {
              if (collected.length + chunk.length > mcpMaxFrameBytes) {
                throw const FormatException('HTTP frame limit exceeded.');
              }
              collected.add(chunk);
            }
            if (_live(operation)) {
              matched = await _acceptFrame(
                utf8.decode(collected.takeBytes()),
                operation,
                body,
              );
            }
          } else {
            throw const FormatException(
              'Unsupported MCP response content type.',
            );
          }
          result =
              matched ??
              Result.failure(
                McpNetworkFailure(
                  'Stream lost. Retry with a new request ID.',
                  code: McpErrorCode.unreachable,
                ),
              );
        }
      }
    } on Object catch (error) {
      if (!_live(operation)) return;
      if (error is FormatException) {
        body.truncated = true;
        _frames.record(
          'Malformed or incomplete MCP HTTP response.',
          RpcDirection.incoming,
          warning: true,
        );
        result = Result.failure(
          McpNetworkFailure(
            'Stream lost. Retry with a new request ID.',
            code: McpErrorCode.unreachable,
          ),
        );
      } else {
        result = Result.failure(
          _mapper.exception(error) ??
              const UnexpectedFailure('MCP HTTP stream failed.'),
        );
      }
    } finally {
      capturePost();
    }
    if (terminal != null) {
      _disconnect(terminal);
    } else {
      _finish(operation, result);
    }
  }

  void _captureNetwork({
    required String method,
    required Map<String, String> requestHeaders,
    required Map<String, List<String>> responseHeaders,
    required int? status,
    required McpHttpDiagnosticBody body,
    required Duration duration,
    String? wire,
  }) {
    if (_disposed || _closing || !isAuthorized(context, serverId)) return;
    final request = McpHttpDiagnosticBody();
    if (wire != null) request.add(_sanitizer.frame(wire).text);
    final entry = NetworkEntry(
      method: method,
      url: _sanitizer.text(_url.toString()),
      status: status,
      requestHeaders: _sanitizer.headers({
        for (final entry in requestHeaders.entries) entry.key: [entry.value],
      }),
      responseHeaders: _sanitizer.headers(responseHeaders),
      requestBody: wire == null ? null : request.text,
      requestTruncated: request.truncated,
      body: body.text,
      truncated: body.truncated,
      duration: duration,
    );
    _network.add(
      entry,
      utf8.encode(entry.body ?? '').length +
          utf8.encode(entry.requestBody ?? '').length +
          1024,
    );
    request.clear();
  }

  bool _canResume(_HttpOperation operation) =>
      _live(operation) &&
      _era == NegotiatedEra.legacy &&
      operation.lastEventId != null &&
      operation.lastEventId!.isNotEmpty;

  Future<Result<Map<String, dynamic>>?> _readSse(
    Stream<List<int>> bytes,
    _HttpOperation operation,
    McpHttpDiagnosticBody body,
  ) async {
    try {
      await for (final event in mcpSseEvents(bytes)) {
        if (!_live(operation)) break;
        if (_era == NegotiatedEra.legacy) {
          if (event.id case final id?) {
            // SSE IDs cannot be re-encoded without changing the server cursor.
            // Reject values that cannot safely be sent as an HTTP header.
            operation.lastEventId =
                id.length <= 8192 &&
                    id.codeUnits.every((unit) => unit >= 32 && unit <= 126)
                ? id
                : null;
          }
          if (event.retryMilliseconds case final retry?) {
            operation.retryMilliseconds = retry;
          }
        }
        final data = event.data;
        if (data == null || data.isEmpty) continue; // Includes priming events.
        final matched = await _acceptFrame(data, operation, body);
        if (matched != null) return matched;
      }
    } on Object catch (error) {
      body.truncated = true;
      if (error is! McpSseIncompleteEvent &&
          error is! DioException &&
          error is! SocketException &&
          error is! HttpException) {
        rethrow;
      }
    }
    return null;
  }

  Future<bool> _waitToResume(_HttpOperation operation) {
    final ready = Completer<bool>();
    final timer = Timer(
      Duration(milliseconds: operation.retryMilliseconds),
      () {
        if (!ready.isCompleted) ready.complete(_canResume(operation));
      },
    );
    unawaited(
      operation.finished.future.then((_) {
        timer.cancel();
        if (!ready.isCompleted) ready.complete(false);
      }),
    );
    return ready.future;
  }

  // One GET attempt, under the original request's cancellation/deadline. This
  // resumes its response stream; it never replays the original POST operation.
  Future<Result<Map<String, dynamic>>?> _resumeSse(
    _HttpOperation operation,
    Map<String, dynamic> params,
  ) async {
    if (!await _waitToResume(operation) || !_canResume(operation)) return null;
    final cursor = operation.lastEventId!;
    _sanitizer.addSecrets([cursor]);
    final headers = _requestHeaders(operation.method, params)
      ..remove('content-type')
      ..['accept'] = 'text/event-stream'
      ..['last-event-id'] = cursor;
    final watch = Stopwatch()..start();
    final body = McpHttpDiagnosticBody();
    int? status;
    Map<String, List<String>> responseHeaders = {};
    McpCoded? terminal;
    Result<Map<String, dynamic>>? result;
    try {
      final response = await _client!.get<ResponseBody>(
        _url.toString(),
        cancelToken: operation.token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: headers,
        ),
      );
      if (!_live(operation)) {
        await response.data!.stream.listen((_) {}).cancel();
        return null;
      }
      status = response.statusCode;
      responseHeaders = response.headers.map;
      _sanitizer.headers(responseHeaders);
      if (status != 200) {
        final failure = _mapper.http(
          status ?? 0,
          retryAfter: response.headers.value('retry-after'),
        );
        result = Result.failure(failure);
        if (status == 401 || status == 403 || status == 404) {
          terminal = failure as McpCoded;
          if (status == 404) _sessionId = null;
        }
        await response.data!.stream.listen((_) {}).cancel();
      } else if (response.headers
              .value('content-type')
              ?.split(';')
              .first
              .trim()
              .toLowerCase() !=
          'text/event-stream') {
        body.truncated = true;
        await response.data!.stream.listen((_) {}).cancel();
      } else {
        result = await _readSse(
          _body(response.data!, operation),
          operation,
          body,
        );
        if (result == null) body.truncated = true;
      }
    } on Object catch (error) {
      body.truncated = true;
      result = Result.failure(
        _mapper.exception(error) ??
            McpNetworkFailure(
              'Stream lost. Retry with a new request ID.',
              code: McpErrorCode.unreachable,
            ),
      );
    } finally {
      _captureNetwork(
        method: 'GET',
        requestHeaders: headers,
        responseHeaders: responseHeaders,
        status: status,
        body: body,
        duration: watch.elapsed,
      );
      body.clear();
    }
    if (terminal != null) _disconnect(terminal);
    return result;
  }

  Future<Result<Map<String, dynamic>>?> _acceptFrame(
    String wire,
    _HttpOperation operation,
    McpHttpDiagnosticBody body, {
    bool allowResponse = true,
  }) async {
    try {
      final value = jsonDecode(wire);
      if (value is! Map<String, dynamic> || value['jsonrpc'] != '2.0') {
        throw const FormatException();
      }
      final method = value['method'];
      if (value.containsKey('method')) {
        if (method is! String ||
            value.containsKey('result') ||
            value.containsKey('error')) {
          throw const FormatException();
        }
        if (value.containsKey('id')) {
          final id = value['id'];
          if (id is! String && id is! int) throw const FormatException();
          body.add(_frames.record(wire, RpcDirection.incoming));
          final response = await _rejectServerRequest(id as Object, operation);
          return switch (response) {
            Success() => null,
            Err(:final failure) => Result.failure(failure),
          };
        }
        body.add(_frames.record(wire, RpcDirection.incoming));
        return null;
      }
      if (!allowResponse) {
        body.add(
          _frames.record(
            'Ignored a response on the optional notification stream.',
            RpcDirection.incoming,
            warning: true,
          ),
        );
        return null;
      }
      if (value['id'] is! String && value['id'] is! int) {
        throw const FormatException();
      }
      final result = value['result'];
      final error = value['error'];
      if (value.containsKey('result') == value.containsKey('error') ||
          value.containsKey('result') && result is! Map<String, dynamic> ||
          value.containsKey('error') &&
              (error is! Map ||
                  error['code'] is! int ||
                  error['message'] is! String)) {
        throw const FormatException();
      }
      body.add(_frames.record(wire, RpcDirection.incoming));
      if (value['id'] != operation.id) return null;
      if (error is Map) {
        return Result.failure(
          _mapper.rpc(
            error['code'] as int,
            error['message'] as String,
            data: error['data'] is Map
                ? Map<String, dynamic>.from(error['data'] as Map)
                : null,
            method: operation.method,
          ),
        );
      }
      final payload = result as Map<String, dynamic>;
      if (operation.method == 'tools/list' && _era == NegotiatedEra.modern) {
        payload['tools'] = _rememberToolHeaders(
          payload,
          continuation: operation.listContinuation,
        );
      }
      if (operation.method == 'initialize' ||
          operation.method == 'server/discover') {
        final info =
            payload['serverInfo'] ??
            (payload['_meta'] is Map ? payload['_meta']['serverInfo'] : null);
        if (info is Map) {
          _serverInfo = Map<String, dynamic>.from(_sanitizer.json(info) as Map);
        }
      }
      return Result.success(payload);
    } on FormatException {
      body.add(_frames.record(wire, RpcDirection.incoming, warning: true));
      return null;
    }
  }

  Future<Result<void>> _rejectServerRequest(
    Object id,
    _HttpOperation operation,
  ) async {
    final wire = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': -32601, 'message': 'Client method not supported.'},
    });
    final headers = _requestHeaders('client-response', {})
      ..remove('mcp-method');
    final watch = Stopwatch()..start();
    int? status;
    Map<String, List<String>> responseHeaders = {};
    var responseBodyOmitted = false;
    final replyTimer = identical(_notificationOperation, operation)
        ? Timer(
            timeout,
            () => _finish(
              operation,
              Result.failure(
                McpNetworkFailure(
                  'The server-request reply timed out.',
                  code: McpErrorCode.unreachable,
                ),
              ),
            ),
          )
        : null;
    Result<void> result;
    try {
      if (!_live(operation)) return Result.failure(_inactive);
      _frames.record(wire, RpcDirection.outgoing);
      final response = await _client!.post<ResponseBody>(
        _url.toString(),
        data: wire,
        cancelToken: operation.token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: headers,
        ),
      );
      status = response.statusCode;
      responseHeaders = response.headers.map;
      await for (final chunk in _body(response.data!, operation)) {
        if (chunk.isNotEmpty) responseBodyOmitted = true;
      }
      result = status != null && status >= 200 && status < 300
          ? const Result.success(null)
          : Result.failure(_mapper.http(status ?? 0));
    } on Object catch (error) {
      result = Result.failure(
        _mapper.exception(error) ??
            const UnexpectedFailure('MCP client response failed.'),
      );
    } finally {
      replyTimer?.cancel();
      if (!_disposed && !_closing && isAuthorized(context, serverId)) {
        _sanitizer.headers(responseHeaders);
        final requestBody = McpHttpDiagnosticBody()
          ..add(_sanitizer.frame(wire).text);
        _network.add(
          NetworkEntry(
            method: 'POST',
            url: _sanitizer.text(_url.toString()),
            status: status,
            requestHeaders: _sanitizer.headers({
              for (final entry in headers.entries) entry.key: [entry.value],
            }),
            responseHeaders: _sanitizer.headers(responseHeaders),
            requestBody: requestBody.text,
            requestTruncated: requestBody.truncated,
            truncated: responseBodyOmitted,
            duration: watch.elapsed,
          ),
          utf8.encode(requestBody.text).length + 1024,
        );
        requestBody.clear();
      }
    }
    if (status == 404) {
      _sessionId = null;
      _disconnect(_mapper.http(404) as McpCoded);
    }
    return result;
  }

  @override
  Future<Result<void>> close() => _closeFuture ??= _close();
  Future<Result<void>> _close() async {
    _closing = true;
    final listener = _notificationOperation;
    if (listener != null) _finish(listener, Result.failure(_inactive));
    for (final operation in _operations.toList()) {
      _finish(operation, Result.failure(_inactive));
    }
    Result<void> result = const Result.success(null);
    final sessionId = _sessionId;
    _sessionId = null;
    if (sessionId != null) result = await _delete(sessionId);
    _client?.close(force: true);
    _client = null;
    try {
      await Future.wait(_tasks.toList()).timeout(const Duration(seconds: 2));
    } on Object {
      result = const Result.failure(
        UnexpectedFailure('MCP HTTP operations did not finish cleanup.'),
      );
    }
    _tasks.clear();
    _headers.clear();
    _toolHeaderParameters.clear();
    _issued.clear();
    _serverInfo = {};
    if (_current is! ConnectionDisconnected) {
      _current = const ConnectionStatus.disconnected();
    }
    _status.add(_current);
    _disposed = true;
    _sanitizer.dispose();
    unawaited(_frames.close());
    unawaited(_network.close());
    unawaited(_console.close());
    unawaited(_status.close());
    return result;
  }

  Future<Result<void>> _delete(String sessionId) async {
    final token = CancelToken();
    final timer = Timer(
      const Duration(seconds: 2),
      () => token.cancel('Cleanup deadline.'),
    );
    final watch = Stopwatch()..start();
    final headers = {
      ..._requestHeaders('DELETE', {}),
      'mcp-session-id': sessionId,
    };
    int? status;
    Map<String, List<String>> responseHeaders = {};
    try {
      final response = await _client!.delete<ResponseBody>(
        _url.toString(),
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: headers,
        ),
      );
      status = response.statusCode;
      responseHeaders = response.headers.map;
      await response.data!.stream.listen((_) {}).cancel();
      return status != null && (status == 405 || status >= 200 && status < 300)
          ? const Result.success(null)
          : Result.failure(_mapper.http(status ?? 0));
    } on Object catch (error) {
      return Result.failure(
        _mapper.exception(error) ??
            const UnexpectedFailure('MCP session cleanup failed.'),
      );
    } finally {
      timer.cancel();
      token.cancel('Cleanup finished.');
      final entry = NetworkEntry(
        method: 'DELETE',
        url: _sanitizer.text(_url.toString()),
        status: status,
        requestHeaders: _sanitizer.headers({
          for (final entry in headers.entries) entry.key: [entry.value],
        }),
        responseHeaders: _sanitizer.headers(responseHeaders),
        duration: watch.elapsed,
      );
      _network.add(entry, 1024);
    }
  }
}
