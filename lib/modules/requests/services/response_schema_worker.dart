import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:api_caffeine/modules/requests/models/http_request_draft.dart';
import 'package:api_caffeine/modules/requests/models/http_response_result.dart';
import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';
import 'package:api_caffeine/modules/requests/repositories/http_request_repository.dart';
import 'package:api_caffeine/modules/requests/services/response_schema_validator.dart';

class ResponseSchemaWorker {
  final _queue = Queue<_Job>();
  bool _running = false;

  Future<SchemaTestResult?> validate(
    HttpRequestDraft draft,
    HttpResponseResult response,
    CancelSignal signal,
  ) {
    if (signal.isCancelled) return Future.value(null);
    if (draft.responseSchemaSource.length >
        ResponseSchemaValidator.maxSchemaBytes) {
      return Future.value(
        SchemaTestResult(
          status: SchemaTestStatus.incomplete,
          schemaSource: draft.responseSchemaSource,
        ),
      );
    }
    if (_running && _queue.length >= 3) {
      return Future.value(
        SchemaTestResult(
          status: SchemaTestStatus.incomplete,
          schemaSource: draft.responseSchemaSource,
        ),
      );
    }
    final job = _Job(draft, response, signal);
    _queue.add(job);
    unawaited(
      signal.whenCancelled.then((_) {
        if (_queue.remove(job)) job.completer.complete(null);
      }),
    );
    unawaited(_drain());
    return job.completer.future;
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeFirst();
        if (job.signal.isCancelled) {
          job.completer.complete(null);
          continue;
        }
        await _run(job);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _run(_Job job) async {
    final port = ReceivePort();
    Isolate? isolate;
    SchemaIssue? firstIssue;
    final completed = Completer<SchemaTestResult>();
    final subscription = port.listen((message) {
      if (message is SchemaIssue) firstIssue = message;
      if (message is SchemaTestResult && !completed.isCompleted) {
        completed.complete(message);
      }
    });
    try {
      isolate = await Isolate.spawn(_evaluate, (
        port.sendPort,
        job.draft.responseSchemaSource,
        job.response.sizeBytes > ResponseSchemaValidator.maxBodyBytes
            ? ''
            : job.response.body,
        job.response.sizeBytes,
        job.response.validUtf8,
        job.draft.method.label,
        job.response.statusCode,
      ));
      final result = await Future.any<Object?>([
        completed.future,
        job.signal.whenCancelled.then((_) => null),
        Future<Object?>.delayed(const Duration(milliseconds: 500), () => false),
      ]);
      job.completer.complete(
        result is SchemaTestResult
            ? result
            : result == null
            ? null
            : SchemaTestResult(
                status: firstIssue == null
                    ? SchemaTestStatus.incomplete
                    : SchemaTestStatus.failed,
                schemaSource: job.draft.responseSchemaSource,
                issues: firstIssue == null ? const [] : [firstIssue!],
                incomplete: firstIssue != null,
              ),
      );
    } on Object {
      job.completer.complete(
        SchemaTestResult(
          status: SchemaTestStatus.incomplete,
          schemaSource: job.draft.responseSchemaSource,
        ),
      );
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      await subscription.cancel();
      port.close();
    }
  }
}

class _Job {
  _Job(this.draft, this.response, this.signal);
  final HttpRequestDraft draft;
  final HttpResponseResult response;
  final CancelSignal signal;
  final completer = Completer<SchemaTestResult?>();
}

void _evaluate((SendPort, String, String, int, bool, String, int) input) {
  final (port, schema, body, bytes, validUtf8, method, status) = input;
  port.send(
    ResponseSchemaValidator().validate(
      schemaSource: schema,
      body: body,
      bodyBytes: bytes,
      validUtf8: validUtf8,
      method: method,
      statusCode: status,
      onMismatch: port.send,
    ),
  );
}
