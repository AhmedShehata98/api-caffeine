import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';

const _handshake = <String, dynamic>{
  'protocolVersion': '2025-11-25',
  'supportedVersions': ['2026-07-28'],
  'serverInfo': {'name': 'fixture', 'version': '1'},
  'capabilities': <String, dynamic>{},
  'instructions': 'Use the tools',
};

class _Session implements McpSession {
  final calls = <String>[];
  final params = <Map<String, dynamic>>[];
  final replies = <Result<Map<String, dynamic>>>[];
  Result<void> ready = const Result.success(null);
  Result<void> configuration = const Result.success(null);
  Result<void> cleanup = const Result.success(null);
  NegotiatedEra? era;

  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> arguments, {
    Object? id,
    Duration? timeout,
  }) async {
    calls.add(method);
    params.add(arguments);
    return replies.removeAt(0);
  }

  @override
  Result<void> configureProtocol({
    required NegotiatedEra era,
    required String version,
  }) {
    calls.add('configure:$version');
    this.era = era;
    return configuration;
  }

  @override
  Future<Result<void>> notify(
    String method,
    Map<String, dynamic> params,
  ) async {
    calls.add(method);
    return ready;
  }

  @override
  Future<Result<void>> close() async {
    calls.add('close');
    return cleanup;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const service = McpNegotiationService(clientVersion: '1.2.3');
  test('default legacy validates version before initialized; advertises no interactions', () async {
    final session = _Session()..replies.add(const Result.success(_handshake));
    final result = await service.negotiate(session);
    expect(result.valueOrNull!.era, NegotiatedEra.legacy);
    expect(result.valueOrNull!.discovery['instructions'], 'Use the tools');
    expect(session.calls, [
      'initialize',
      'configure:2025-11-25',
      'notifications/initialized',
    ]);
    expect(session.params.single['capabilities'], isEmpty);
    expect(session.params.single['clientInfo'], {
      'name': 'Test Point',
      'version': '1.2.3',
    });
  });

  test(
    'modern discovery configures without legacy initialized notification',
    () async {
      final session = _Session()..replies.add(const Result.success(_handshake));
      final result = await service.negotiate(
        session,
        era: McpProtocolEra.modern,
      );
      expect(result.valueOrNull!.era, NegotiatedEra.modern);
      expect(session.calls, ['server/discover', 'configure:2026-07-28']);
    },
  );

  test(
    'auto falls back after rejected discovery, retaining both attempts',
    () async {
      final session = _Session()
        ..replies.addAll([
          const Result.failure(UnexpectedFailure('Method not found')),
          const Result.success(_handshake),
        ]);
      expect(
        (await service.negotiate(session, era: McpProtocolEra.auto)).isSuccess,
        isTrue,
      );
      expect(session.calls.take(2), ['server/discover', 'initialize']);
    },
  );

  test('auto falls back when no supported modern version overlaps', () async {
    final session = _Session()
      ..replies.addAll([
        Result.success(Map.of(_handshake)..['supportedVersions'] = ['future']),
        const Result.success(_handshake),
      ]);
    expect(
      (await service.negotiate(session, era: McpProtocolEra.auto)).isSuccess,
      isTrue,
    );
    expect(session.era, NegotiatedEra.legacy);
  });

  test(
    'unsupported legacy and modern versions close without configuring',
    () async {
      for (final era in [McpProtocolEra.legacy, McpProtocolEra.modern]) {
        final session = _Session()
          ..replies.add(
            Result.success(
              Map.of(_handshake)
                ..['protocolVersion'] = 'future'
                ..['supportedVersions'] = ['future'],
            ),
          );
        final result = await service.negotiate(session, era: era);
        expect(
          (result.failureOrNull as McpCoded).code,
          McpErrorCode.protocolVersionUnsupported,
        );
        expect(session.calls.last, 'close');
        expect(session.era, isNull);
      }
    },
  );

  test(
    'malformed handshake closes without exposing payload in errors',
    () async {
      final session = _Session()
        ..replies.add(
          Result.success(Map.of(_handshake)..['serverInfo'] = 'secret'),
        );
      final result = await service.negotiate(session);
      expect(result.failureOrNull!.message, isNot(contains('secret')));
      expect(session.calls, ['initialize', 'close']);
    },
  );

  test('configuration and initialized failures await cleanup', () async {
    const failure = AuthFailure('Account changed');
    for (final configure in [true, false]) {
      final session = _Session()..replies.add(const Result.success(_handshake));
      if (configure) {
        session.configuration = const Result.failure(failure);
      } else {
        session.ready = const Result.failure(failure);
      }
      expect((await service.negotiate(session)).failureOrNull, same(failure));
      expect(session.calls.last, 'close');
    }
  });

  test('modern authentication failure is preserved without fallback', () async {
    const failure = McpAuthFailure('Sign in');
    final session = _Session()..replies.add(const Result.failure(failure));
    expect(
      (await service.negotiate(
        session,
        era: McpProtocolEra.modern,
      )).failureOrNull,
      same(failure),
    );
    expect(session.calls, ['server/discover', 'close']);
  });

  test('cleanup failure remains visible', () async {
    const failure = NetworkFailure('DELETE failed');
    final session = _Session()
      ..replies.add(const Result.failure(AuthFailure('Account changed')))
      ..cleanup = const Result.failure(failure);
    expect((await service.negotiate(session)).failureOrNull, same(failure));
  });
}
