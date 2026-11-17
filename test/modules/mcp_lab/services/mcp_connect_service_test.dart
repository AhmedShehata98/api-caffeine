import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_transport_repository.dart';

class _Connections extends Mock implements McpConnectionRepository {}

class _Trust extends Mock implements McpTrustRepository {}

class _Session extends Mock implements McpSession {}

void main() {
  const context = McpAccessContext(
    userId: 'u',
    workspaceId: 'w',
    generation: 1,
  );
  late _Connections connections;
  late _Trust trust;
  late _Session session;
  late McpConnectService service;
  late McpConnectTarget target;
  late bool authorized;

  McpConnectTarget makeTarget({McpTransport transport = McpTransport.stdio}) =>
      McpConnectTarget(
        context: context,
        server: McpServer(
          id: 's',
          workspaceId: 'w',
          draft: McpServerDraft(
            name: 'Fixture',
            transport: transport,
            command: transport == McpTransport.stdio ? 'dart' : null,
            url: transport == McpTransport.stdio
                ? null
                : 'https://example.test/mcp',
          ),
        ),
        timeout: const Duration(seconds: 5),
        launch: transport == McpTransport.stdio
            ? McpLaunchSnapshot(
                command: 'dart',
                executable: '/resolved/dart',
                cwd: '/work',
                args: ['fixture.dart'],
                environment: {'PATH': '/bin'},
              )
            : null,
      );

  setUp(() {
    authorized = true;
    target = makeTarget();
    connections = _Connections();
    trust = _Trust();
    session = _Session();
    service = McpConnectService(
      connections,
      trust,
      const McpNegotiationService(clientVersion: '1'),
      isAuthorized: (_, _) => authorized,
    );
    when(() => trust.check(context, 's', target.launch!)).thenAnswer(
      (_) async => Result.success(
        McpTrustCheck(approved: false, changedFields: ['args']),
      ),
    );
    when(() => connections.connect(target))
        .thenAnswer((_) async => Result.success(session));
    when(() => session.request('initialize', any())).thenAnswer(
      (_) async => const Result.success({
        'protocolVersion': '2025-11-25',
        'capabilities': <String, dynamic>{},
        'serverInfo': {'name': 'Fixture', 'version': '1'},
      }),
    );
    when(
      () => session.configureProtocol(
        era: NegotiatedEra.legacy,
        version: '2025-11-25',
      ),
    ).thenReturn(const Result.success(null));
    when(() => session.notify('notifications/initialized', any()))
        .thenAnswer((_) async => const Result.success(null));
    when(() => session.close())
        .thenAnswer((_) async => const Result.success(null));
  });

  Future<McpNeedsApproval> ticket() async =>
      (await service.connect(target)).valueOrNull! as McpNeedsApproval;

  test(
    'untrusted launch waits for approval and uses the exact target once',
    () async {
      final pending = await ticket();
      expect(pending.changedFields, ['args']);
      verifyNever(() => connections.connect(target));
      expect((await service.approve(pending)).valueOrNull, isA<McpConnected>());
      verify(() => connections.connect(target)).called(1);
      expect((await service.approve(pending)).isSuccess, isFalse);
      verifyNoMoreInteractions(connections);
      verifyNever(() => trust.approve(context, 's', target.launch!));
    },
  );

  test('remembered exact snapshot connects without asking again', () async {
    when(() => trust.check(context, 's', target.launch!))
        .thenAnswer((_) async => Result.success(McpTrustCheck(approved: true)));
    expect((await service.connect(target)).valueOrNull, isA<McpConnected>());
  });

  test('unavailable trust storage still requires explicit approval', () async {
    const failure = McpStorageFailure('Keyring unavailable');
    when(() => trust.check(context, 's', target.launch!))
        .thenAnswer((_) async => const Result.failure(failure));
    final pending = await ticket();
    expect(pending.storageFailure, same(failure));
    verifyNever(() => connections.connect(target));
    when(() => trust.approve(context, 's', target.launch!))
        .thenAnswer((_) async => const Result.failure(failure));
    final outcome =
        (await service.approve(pending, remember: true)).valueOrNull!
            as McpConnected;
    expect(outcome.rememberFailure, same(failure));
  });

  test('remember choice persists the exact displayed snapshot', () async {
    final pending = await ticket();
    when(() => trust.approve(context, 's', target.launch!))
        .thenAnswer((_) async => const Result.success(null));
    expect((await service.approve(pending, remember: true)).isSuccess, isTrue);
    verify(() => trust.approve(context, 's', target.launch!)).called(1);
  });

  test('account change during trust read prevents launch', () async {
    when(() => trust.check(context, 's', target.launch!)).thenAnswer((_) async {
      authorized = false;
      return Result.success(McpTrustCheck(approved: true));
    });
    expect(
      (await service.connect(target)).failureOrNull,
      isA<McpAuthFailure>(),
    );
    verifyNever(() => connections.connect(target));
  });

  test('stale or foreign approval tickets cannot launch', () async {
    final pending = await ticket();
    final other = McpConnectService(
      connections,
      trust,
      const McpNegotiationService(clientVersion: '1'),
      isAuthorized: (_, _) => true,
    );
    expect((await other.approve(pending)).isSuccess, isFalse);
    authorized = false;
    expect(
      (await service.approve(pending)).failureOrNull,
      isA<McpAuthFailure>(),
    );
    verifyNever(() => connections.connect(target));
  });

  test('account change while opening awaits session close', () async {
    final pending = await ticket();
    when(() => connections.connect(target)).thenAnswer((_) async {
      authorized = false;
      return Result.success(session);
    });
    expect(
      (await service.approve(pending)).failureOrNull,
      isA<McpAuthFailure>(),
    );
    verify(() => session.close()).called(1);
    verifyNever(() => session.request('initialize', any()));
  });

  test('account change while remembering approval prevents launch', () async {
    final pending = await ticket();
    when(() => trust.approve(context, 's', target.launch!))
        .thenAnswer((_) async {
          authorized = false;
          return const Result.success(null);
        });
    expect(
      (await service.approve(pending, remember: true)).failureOrNull,
      isA<McpAuthFailure>(),
    );
    verifyNever(() => connections.connect(target));
  });

  test(
    'account change during negotiation closes before returning results',
    () async {
      final pending = await ticket();
      when(() => session.notify('notifications/initialized', any()))
          .thenAnswer((_) async {
            authorized = false;
            return const Result.success(null);
          });
      expect(
        (await service.approve(pending)).failureOrNull,
        isA<McpAuthFailure>(),
      );
      verify(() => session.close()).called(1);
    },
  );

  test('missing secrets fail before trust or transport calls', () async {
    final missing = McpConnectTarget(
      context: context,
      server: target.server.copyWith(
        draft: target.server.draft.copyWith(
          secretKeys: ['env.TOKEN'],
          env: {'TOKEN': ''},
        ),
      ),
      timeout: target.timeout,
      launch: target.launch,
    );
    final result = await service.connect(missing);
    expect(result.failureOrNull, isA<McpValidationFailure>());
    verifyZeroInteractions(trust);
    verifyZeroInteractions(connections);
  });

  test(
    'failed handshake closes and never returns a connected outcome',
    () async {
      final pending = await ticket();
      when(() => session.request('initialize', any())).thenAnswer(
        (_) async => const Result.failure(McpAuthFailure('Sign in')),
      );
      expect(
        (await service.approve(pending)).failureOrNull,
        isA<McpAuthFailure>(),
      );
      verify(() => session.close()).called(1);
    },
  );

  test('HTTP bypasses process trust; dispatch never falls back to another transport', () async {
    final http = makeTarget(transport: McpTransport.http);
    final sse = makeTarget(transport: McpTransport.sse);
    final stdioRepository = _Connections();
    final httpRepository = _Connections();
    final dispatch = McpTransportRepository(
      stdio: stdioRepository,
      http: httpRepository,
    );
    when(() => stdioRepository.connect(target))
        .thenAnswer((_) async => Result.success(session));
    when(() => httpRepository.connect(http))
        .thenAnswer((_) async => Result.success(session));
    expect((await dispatch.connect(target)).isSuccess, isTrue);
    expect((await dispatch.connect(http)).isSuccess, isTrue);
    expect((await dispatch.connect(sse)).isSuccess, isFalse);
    final httpService = McpConnectService(
      dispatch,
      trust,
      const McpNegotiationService(clientVersion: '1'),
      isAuthorized: (_, _) => true,
    );
    expect((await httpService.connect(http)).valueOrNull, isA<McpConnected>());
    verifyZeroInteractions(trust);
    verify(() => stdioRepository.connect(target)).called(1);
    verify(() => httpRepository.connect(http)).called(2);
    verifyNoMoreInteractions(stdioRepository);
    verifyNoMoreInteractions(httpRepository);
  });
}
