import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mcp_dart/mcp_dart.dart'
    show McpMetaKey, legacyProtocolVersions, stableProtocolVersion;
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_diagnostics.dart';
import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';
import 'mcp_connection_repository.dart';
import 'mcp_diagnostic_sanitizer.dart';
import 'mcp_error_mapper.dart';
import 'mcp_frame_limits.dart';
import 'mcp_diagnostic_stream.dart';
import 'mcp_rpc_diagnostics.dart';
import 'mcp_stdio_launcher.dart';

class McpStdioConnectionRepository implements McpConnectionRepository {
  McpStdioConnectionRepository(
    this._launcher, {
    required this.isAuthorized,
    required this.clientVersion,
  });
  final McpStdioLauncher _launcher;
  final bool Function(McpAccessContext, String serverId) isAuthorized;
  final String clientVersion;

  @override
  Future<Result<McpSession>> connect(McpConnectTarget target) async {
    if (!isAuthorized(target.context, target.server.id)) {
      return const Result.failure(_accessFailure);
    }
    if (target.server.draft.transport != McpTransport.stdio) {
      return const Result.failure(
        McpValidationFailure(
          'Use the HTTP transport for this target.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    if (target.server.draft.secretKeys.any((key) {
      final value = key.startsWith('env.')
          ? target.launch!.environment[key.substring(4)]
          : key.startsWith('header.')
          ? target.server.draft.headers[key.substring(7)]
          : null;
      return target.server.secretStates[key] != SecretValueState.present ||
          value == null ||
          value.isEmpty;
    })) {
      return const Result.failure(
        McpValidationFailure(
          'Set missing device secrets before connecting.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final launched = await _launcher.start(target.launch!);
    if (launched case Err(:final failure)) return Result.failure(failure);
    final child = launched.valueOrNull!;
    if (!isAuthorized(target.context, target.server.id)) {
      final stopped = await child.close();
      if (stopped case Err()) {
        return const Result.failure(
          McpUnexpectedFailure(
            'The account changed and the MCP process could not be stopped.',
          ),
        );
      }
      return const Result.failure(_accessFailure);
    }
    final draft = target.server.draft;
    final sanitizer = McpDiagnosticSanitizer(
      secretValues: [
        for (final key in draft.secretKeys)
          if (key.startsWith('env.'))
            target.launch!.environment[key.substring(4)] ?? ''
          else if (key.startsWith('header.'))
            draft.headers[key.substring(7)] ?? '',
      ],
    );
    return Result.success(
      _StdioSession(
        child,
        sanitizer,
        context: target.context,
        serverId: target.server.id,
        timeout: target.timeout,
        isAuthorized: isAuthorized,
        clientVersion: clientVersion,
      ),
    );
  }
}

const _accessFailure = McpAuthFailure(
  'The account or workspace changed. Reconnect from the current workspace.',
);
final _cancelled = McpNetworkFailure(
  'Request cancelled because the MCP session closed.',
  code: McpErrorCode.unreachable,
);

class _PendingRequest {
  _PendingRequest(this.method, this.completion, this.timer);
  final String method;
  final Completer<Result<Map<String, dynamic>>> completion;
  final Timer timer;
}

class _StdioSession implements McpSession {
  _StdioSession(
    McpStdioProcess child,
    this._sanitizer, {
    required this.context,
    required this.serverId,
    required this.timeout,
    required this.isAuthorized,
    required this.clientVersion,
  }) : _child = child,
       _mapper = McpErrorMapper(_sanitizer) {
    final process = child.process;
    _stdout = process.stdout.listen(
      (bytes) => _readBytes(bytes, stderr: false),
      onError: (Object error) => _transportError(error),
      onDone: () {
        if (_stdoutBytes.isNotEmpty && !_closing) {
          _warning(utf8.decode(_stdoutBytes.takeBytes(), allowMalformed: true));
        }
        _stdoutBytes.clear();
        _stdoutDone.complete();
      },
    );
    _stderr = process.stderr.listen(
      (bytes) => _readBytes(bytes, stderr: true),
      onError: (Object error) => _transportError(error),
      onDone: () {
        if (_stderrBytes.isNotEmpty && !_closing) {
          _consoleLine(
            utf8.decode(_stderrBytes.takeBytes(), allowMalformed: true),
          );
        }
        _stderrBytes.clear();
        _stderrDone.complete();
      },
    );
    unawaited(process.exitCode.then(_onExit));
  }
  McpStdioProcess? _child;
  final McpDiagnosticSanitizer _sanitizer;
  final McpErrorMapper _mapper;
  final McpAccessContext context;
  final String serverId;
  final Duration timeout;
  final bool Function(McpAccessContext, String) isAuthorized;
  final String clientVersion;
  late final _frames = McpRpcDiagnostics(_sanitizer);
  final _network = StreamController<NetworkEntry>.broadcast();
  final _console = McpDiagnosticStream<ConsoleLine>(
    (count) => ConsoleLine(
      timestamp: DateTime.now().toUtc(),
      text: '$count startup console entries dropped (buffer limit).',
    ),
  );
  final _status = StreamController<ConnectionStatus>.broadcast();
  final _stdoutBytes = BytesBuilder(copy: false);
  final _stderrBytes = BytesBuilder(copy: false);
  final _pending = <Object, _PendingRequest>{};
  final _issued = <Object>{};
  final _stdoutDone = Completer<void>();
  final _stderrDone = Completer<void>();
  final _closeSignal = Completer<void>();
  late final StreamSubscription<List<int>> _stdout;
  late final StreamSubscription<List<int>> _stderr;
  Future<void> _writes = Future.value();
  Future<Result<void>>? _closeFuture;
  ConnectionStatus _current = const ConnectionStatus.connecting();
  Map<String, dynamic> _serverInfo = {};
  String _stderrTail = '';
  String? _version;
  NegotiatedEra? _era;
  int _nextId = 1;
  bool _closing = false;
  bool _legacyInitialized = false;
  bool _dropStderrLine = false;
  static const _maxStderrLineBytes = 10 * 1024 * 1024;

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
    if (_closing) return false;
    if (!isAuthorized(context, serverId)) {
      _current = const ConnectionStatus.disconnected(failure: _accessFailure);
      _status.add(_current);
      _failAll(_accessFailure);
      unawaited(close());
      return false;
    }
    return true;
  }

  Failure get _inactiveFailure =>
      isAuthorized(context, serverId) ? _cancelled : _accessFailure;

  @override
  Result<void> configureProtocol({
    required NegotiatedEra era,
    required String version,
  }) {
    if (!_active()) return Result.failure(_inactiveFailure);
    final valid = era == NegotiatedEra.modern
        ? version == stableProtocolVersion
        : legacyProtocolVersions.contains(version);
    if (!valid) {
      return Result.failure(
        McpNetworkFailure(
          'Unsupported MCP protocol version.',
          code: McpErrorCode.protocolVersionUnsupported,
        ),
      );
    }
    _era = era;
    _version = version;
    _current = ConnectionStatus.connected(era: era, serverInfo: _serverInfo);
    _status.add(_current);
    return const Result.success(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) {
    if (!_active()) return Future.value(Result.failure(_inactiveFailure));
    final duration = timeout ?? this.timeout;
    if (method.trim().isEmpty ||
        duration <= Duration.zero ||
        (id != null && id is! String && id is! int) ||
        _issued.contains(id) ||
        !_allowed(method)) {
      return Future.value(
        const Result.failure(
          McpValidationFailure(
            'Use a fresh request ID, positive timeout and negotiated session.',
            code: McpErrorCode.invalidParams,
          ),
        ),
      );
    }
    while (_issued.contains(_nextId)) {
      _nextId++;
    }
    final requestId = id ?? _nextId++;
    String wire;
    try {
      wire = jsonEncode({
        'jsonrpc': '2.0',
        'id': requestId,
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
    final completion = Completer<Result<Map<String, dynamic>>>();
    final timer = Timer(
      duration,
      () => _complete(
        requestId,
        Result.failure(
          McpNetworkFailure(
            'MCP request timed out.',
            code: McpErrorCode.unreachable,
          ),
        ),
      ),
    );
    _issued.add(requestId);
    _pending[requestId] = _PendingRequest(method, completion, timer);
    unawaited(
      _write(wire, requestId: requestId).then((result) {
        if (result case Err(:final failure)) {
          _complete(requestId, Result.failure(failure));
        }
      }),
    );
    return completion.future;
  }

  bool _allowed(String method) => _era == null
      ? method == 'initialize' || method == 'server/discover'
      : method != 'initialize' &&
            method != 'server/discover' &&
            (_era == NegotiatedEra.modern || _legacyInitialized);

  Map<String, dynamic> _params(String method, Map<String, dynamic> params) {
    if (_era != NegotiatedEra.modern && method != 'server/discover') {
      return params;
    }
    return {
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
  }

  @override
  Future<Result<void>> notify(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (!_active()) return Result.failure(_inactiveFailure);
    if (method == 'notifications/initialized'
        ? _era != NegotiatedEra.legacy
        : !_allowed(method)) {
      return const Result.failure(
        McpValidationFailure(
          'Negotiate the session before sending notifications.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    try {
      final result = await _write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': method,
          'params': _params(method, params),
        }),
      );
      if (result.isSuccess && method == 'notifications/initialized') {
        _legacyInitialized = true;
      }
      return result;
    } on Object {
      return const Result.failure(
        McpValidationFailure(
          'Notification parameters must be JSON-compatible.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
  }

  Future<Result<void>> _write(String wire, {Object? requestId}) {
    final operation = _writes.then((_) async {
      if (!_active()) return Result<void>.failure(_inactiveFailure);
      if (requestId != null && !_pending.containsKey(requestId)) {
        return Result<void>.failure(_cancelled);
      }
      try {
        _record(wire, RpcDirection.outgoing);
        _child!.process.stdin.add(utf8.encode('$wire\n'));
        await Future.any<void>([
          _child!.process.stdin.flush().timeout(timeout),
          _closeSignal.future,
        ]);
        return _closing
            ? Result<void>.failure(_inactiveFailure)
            : const Result<void>.success(null);
      } on Object catch (error) {
        final failure =
            _mapper.exception(error) ??
            const UnexpectedFailure('Could not write an MCP frame.');
        _failAll(failure);
        unawaited(close());
        return Result<void>.failure(failure);
      }
    });
    _writes = operation.then<void>((_) {});
    return operation;
  }

  void _readBytes(List<int> bytes, {required bool stderr}) {
    if (!_active()) return;
    final buffer = stderr ? _stderrBytes : _stdoutBytes;
    final chunk = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    var start = 0;
    while (start < chunk.length) {
      if (_closing) return;
      final newline = chunk.indexOf(10, start);
      final end = newline < 0 ? chunk.length : newline;
      if (!stderr || !_dropStderrLine) {
        final limit = stderr ? _maxStderrLineBytes : mcpMaxFrameBytes;
        if (buffer.length + end - start > limit) {
          buffer.clear();
          if (stderr) {
            _dropStderrLine = true;
            _consoleLine('Oversized stderr line omitted.');
          } else {
            _transportError(const HttpException('Maximum frame size exceeded'));
            return;
          }
        } else if (end > start) {
          buffer.add(Uint8List.sublistView(chunk, start, end));
        }
      }
      if (newline < 0) break;
      start = newline + 1;
      if (stderr && _dropStderrLine) {
        _dropStderrLine = false;
        continue;
      }
      var line = buffer.takeBytes();
      if (line.isNotEmpty && line.last == 13) {
        line = Uint8List.sublistView(line, 0, line.length - 1);
      }
      try {
        final text = utf8.decode(line);
        if (stderr) {
          _consoleLine(text);
        } else {
          _line(text);
        }
      } on FormatException {
        _warning('Invalid UTF-8 in server output.');
      }
    }
  }

  void _line(String wire) {
    try {
      final message = jsonDecode(wire);
      if (message is! Map<String, dynamic> || message['jsonrpc'] != '2.0') {
        throw const FormatException();
      }
      final id = message['id'];
      final method = message['method'];
      if (message.containsKey('method') && method is! String) {
        throw const FormatException();
      }
      if (method is String) {
        if (message.containsKey('result') ||
            message.containsKey('error') ||
            (message.containsKey('id') && id == null)) {
          throw const FormatException();
        }
        if (id != null && id is! String && id is! int) {
          throw const FormatException();
        }
        _record(wire, RpcDirection.incoming);
        if (id != null) {
          unawaited(
            _write(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': id,
                'error': {
                  'code': -32601,
                  'message': 'Client method not supported.',
                },
              }),
            ),
          );
        }
        return;
      }
      if (id is! String && id is! int) throw const FormatException();
      final result = message['result'];
      final error = message['error'];
      if ((message.containsKey('result') == message.containsKey('error')) ||
          (message.containsKey('result') && result is! Map<String, dynamic>) ||
          (message.containsKey('error') &&
              (error is! Map ||
                  error['code'] is! int ||
                  error['message'] is! String))) {
        throw const FormatException();
      }
      _record(wire, RpcDirection.incoming);
      final request = _pending[id];
      if (request == null) return;
      if (error is Map) {
        _complete(
          id,
          Result.failure(
            _mapper.rpc(
              error['code'] as int,
              error['message'] as String,
              data: error['data'] is Map
                  ? Map<String, dynamic>.from(error['data'] as Map)
                  : null,
              method: request.method,
            ),
          ),
        );
      } else {
        final value = result as Map<String, dynamic>;
        if (request.method == 'initialize' ||
            request.method == 'server/discover') {
          final info =
              value['serverInfo'] ??
              (value['_meta'] is Map ? value['_meta']['serverInfo'] : null);
          if (info is Map) {
            _serverInfo = Map<String, dynamic>.from(
              _sanitizer.json(info) as Map,
            );
          }
        }
        _complete(id, Result.success(value));
      }
    } on FormatException {
      _warning(wire);
    }
  }

  void _record(String wire, RpcDirection direction, {bool warning = false}) {
    if (!_closing) _frames.record(wire, direction, warning: warning);
  }

  void _warning(String wire) =>
      _record(wire, RpcDirection.incoming, warning: true);
  void _consoleLine(String text) {
    if (_closing) return;
    final clean = _sanitizer.text(text);
    _stderrTail = '$_stderrTail$clean\n';
    if (_stderrTail.length > 8192) {
      _stderrTail = _stderrTail.substring(_stderrTail.length - 8192);
    }
    _console.add(
      ConsoleLine(timestamp: DateTime.now().toUtc(), text: clean),
      utf8.encode(clean).length,
    );
  }

  void _complete(Object id, Result<Map<String, dynamic>> result) {
    final pending = _pending.remove(id);
    if (pending == null) return;
    pending.timer.cancel();
    pending.completion.complete(result);
  }

  void _failAll(Failure failure) {
    for (final id in _pending.keys.toList()) {
      _complete(id, Result.failure(failure));
    }
  }

  void _transportError(Object error) {
    if (_closing) return;
    final failure =
        _mapper.exception(error) ??
        const UnexpectedFailure('MCP stream failed.');
    _current = ConnectionStatus.disconnected(
      failure: failure is McpCoded ? failure as McpCoded : null,
    );
    _status.add(_current);
    _failAll(failure);
    unawaited(close());
  }

  Future<void> _onExit(int code) async {
    try {
      await Future.wait([_stdoutDone.future, _stderrDone.future])
          .timeout(const Duration(milliseconds: 500));
    } on TimeoutException {
      /* Remaining partial output is discarded during close. */
    }
    if (_closing) return;
    final failure = _mapper.processExited(code, _stderrTail);
    _current = ConnectionStatus.disconnected(failure: failure);
    _status.add(_current);
    _failAll(failure);
    unawaited(close());
  }

  @override
  Future<Result<void>> close() => _closeFuture ??= _close();
  Future<Result<void>> _close() async {
    _closing = true;
    _closeSignal.complete();
    _failAll(_cancelled);
    final child = _child;
    var result = child == null
        ? const Result<void>.success(null)
        : await child.close();
    try {
      await Future.wait([_stdout.cancel(), _stderr.cancel()])
          .timeout(const Duration(milliseconds: 100));
    } on Object {
      result = const Result.failure(
        McpUnexpectedFailure('MCP diagnostic stream cleanup did not complete.'),
      );
    }
    _child = null;
    _stdoutBytes.clear();
    _stderrBytes.clear();
    _stderrTail = '';
    _issued.clear();
    _serverInfo = {};
    if (_current is! ConnectionDisconnected) {
      _current = const ConnectionStatus.disconnected();
    }
    _status.add(_current);
    unawaited(_frames.close());
    unawaited(_network.close());
    unawaited(_console.close());
    unawaited(_status.close());
    _sanitizer.dispose();
    return result;
  }
}
