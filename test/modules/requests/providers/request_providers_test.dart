import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/requests/models/prepared_request.dart';
import 'package:api_caffeine/modules/requests/models/send_state.dart';
import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';
import 'package:api_caffeine/modules/requests/services/response_schema_worker.dart';
import 'package:api_caffeine/modules/requests/requests.dart';

import '../../../support/fake_backend.dart';

class MockHttpRequestRepository extends Mock implements HttpRequestRepository {}

class PendingSchemaWorker extends ResponseSchemaWorker {
  final pending = <Completer<SchemaTestResult?>>[];

  @override
  Future<SchemaTestResult?> validate(
    HttpRequestDraft draft,
    HttpResponseResult response,
    CancelSignal signal,
  ) {
    final completer = Completer<SchemaTestResult?>();
    pending.add(completer);
    return completer.future;
  }
}

const _ok = HttpResponseResult(
  statusCode: 200,
  headers: {},
  body: 'ok',
  duration: Duration(milliseconds: 1),
  sizeBytes: 2,
);

/// A container with one open (empty) request tab, like after "New request".
ProviderContainer _container(HttpRequestRepository repository) {
  final container = ProviderContainer.test(
    overrides: [
      httpRequestRepositoryProvider.overrideWithValue(repository),
      ...fakeBackend(),
    ],
  );
  container.read(requestTabsProvider.notifier).openNew();
  return container;
}

void main() {
  late MockHttpRequestRepository repository;

  setUpAll(() {
    registerFallbackValue(PreparedRequest(method: 'GET', url: Uri()));
    registerFallbackValue(CancelSignal());
  });

  setUp(() => repository = MockHttpRequestRepository());

  group('draft', () {
    test('editing the URL rebuilds the params table', () {
      final container = _container(repository);
      final notifier = container.read(requestDraftProvider.notifier);

      notifier.setUrl('http://a.test?x=1&y=2');

      expect(container.read(requestDraftProvider).params, const [
        KeyValue(key: 'x', value: '1'),
        KeyValue(key: 'y', value: '2'),
      ]);
    });

    test('editing params rewrites the URL and keeps disabled ones', () {
      final container = _container(repository);
      final notifier = container.read(requestDraftProvider.notifier)
        ..setUrl('http://a.test/p');

      notifier.setParams(const [
        KeyValue(key: 'a', value: '1'),
        KeyValue(key: 'off', value: '2', enabled: false),
      ]);

      final draft = container.read(requestDraftProvider);
      expect(draft.url, 'http://a.test/p?a=1');
      expect(draft.params, hasLength(2));
    });
  });

  group('send', () {
    test('publishes the response before validation and ignores a superseded verdict', () async {
      when(() => repository.send(any(), any()))
          .thenAnswer((_) async => const Result.success(_ok));
      final worker = PendingSchemaWorker();
      final container = ProviderContainer.test(
        overrides: [
          httpRequestRepositoryProvider.overrideWithValue(repository),
          responseSchemaWorkerProvider.overrideWithValue(worker),
          ...fakeBackend(),
        ],
      );
      final tabs = container.read(requestTabsProvider.notifier);
      tabs.openDraft(
        const HttpRequestDraft(
          url: 'http://a.test',
          responseSchemaEnabled: true,
          responseSchemaSource: 'true',
        ),
      );
      final notifier = container.read(sendStateProvider.notifier);
      final first = notifier.send();
      await Future<void>.delayed(Duration.zero);
      final checking = container.read(sendStateProvider) as SendSuccess;
      expect(checking.response, same(_ok));
      expect(checking.schemaTest!.status, SchemaTestStatus.checking);
      final second = notifier.send();
      await Future<void>.delayed(Duration.zero);
      worker.pending.first.complete(
        const SchemaTestResult(
          status: SchemaTestStatus.failed,
          schemaSource: 'true',
        ),
      );
      await first;
      expect(
        (container.read(sendStateProvider) as SendSuccess).schemaTest!.status,
        SchemaTestStatus.checking,
      );
      worker.pending.last.complete(
        const SchemaTestResult(
          status: SchemaTestStatus.passed,
          schemaSource: 'true',
        ),
      );
      await second;
      expect(
        (container.read(sendStateProvider) as SendSuccess).schemaTest!.status,
        SchemaTestStatus.passed,
      );
    });
    test('success stores the response', () async {
      when(() => repository.send(any(), any()))
          .thenAnswer((_) async => const Result.success(_ok));
      final container = _container(repository);
      container.read(requestDraftProvider.notifier).setUrl('http://a.test');

      await container.read(sendStateProvider.notifier).send();

      final state = container.read(sendStateProvider);
      expect(state, isA<SendSuccess>());
      expect((state as SendSuccess).response, _ok);
    });

    test('an invalid URL ends in a failed state', () async {
      final container = _container(repository);

      await container.read(sendStateProvider.notifier).send();

      final state = container.read(sendStateProvider);
      expect(state, isA<SendFailed>());
      expect((state as SendFailed).failure, isA<ValidationFailure>());
    });

    test('cancel returns to idle and ignores the late result', () async {
      final pending = Completer<Result<HttpResponseResult>>();
      when(() => repository.send(any(), any()))
          .thenAnswer((_) => pending.future);
      final container = _container(repository);
      container.read(requestDraftProvider.notifier).setUrl('http://a.test');
      final notifier = container.read(sendStateProvider.notifier);

      final sending = notifier.send();
      expect(container.read(sendStateProvider), isA<SendLoading>());

      notifier.cancel();
      expect(container.read(sendStateProvider), isA<SendIdle>());

      pending.complete(const Result.success(_ok));
      await sending;
      expect(container.read(sendStateProvider), isA<SendIdle>());
    });

    test('the cancel signal reaches the repository', () async {
      CancelSignal? received;
      when(() => repository.send(any(), any())).thenAnswer((invocation) {
        received = invocation.positionalArguments[1] as CancelSignal;
        return Completer<Result<HttpResponseResult>>().future;
      });
      final container = _container(repository);
      container.read(requestDraftProvider.notifier).setUrl('http://a.test');
      final notifier = container.read(sendStateProvider.notifier);

      unawaited(notifier.send());
      await Future<void>.delayed(Duration.zero);
      notifier.cancel();

      expect(received!.isCancelled, isTrue);
    });

    test('a second send while loading is ignored', () async {
      final pending = Completer<Result<HttpResponseResult>>();
      when(() => repository.send(any(), any()))
          .thenAnswer((_) => pending.future);
      final container = _container(repository);
      container.read(requestDraftProvider.notifier).setUrl('http://a.test');
      final notifier = container.read(sendStateProvider.notifier);

      final first = notifier.send();
      await notifier.send();
      pending.complete(const Result.success(_ok));
      await first;

      verify(() => repository.send(any(), any())).called(1);
    });
  });
}
