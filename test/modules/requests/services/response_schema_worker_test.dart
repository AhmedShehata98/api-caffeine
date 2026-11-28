import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/requests/models/http_request_draft.dart';
import 'package:api_caffeine/modules/requests/models/http_response_result.dart';
import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';
import 'package:api_caffeine/modules/requests/repositories/http_request_repository.dart';
import 'package:api_caffeine/modules/requests/services/response_schema_worker.dart';

void main() {
  test('validates a completed response in a worker', () async {
    final result = await ResponseSchemaWorker().validate(
      const HttpRequestDraft(
        responseSchemaEnabled: true,
        responseSchemaSource: '{"type":"integer"}',
      ),
      const HttpResponseResult(
        statusCode: 200,
        headers: {},
        body: '2',
        duration: Duration.zero,
        sizeBytes: 1,
      ),
      CancelSignal(),
    );
    expect(result?.status, SchemaTestStatus.passed);
  });

  test('cancels pending validation', () async {
    final signal = CancelSignal()..cancel();
    final result = await ResponseSchemaWorker().validate(
      const HttpRequestDraft(
        responseSchemaEnabled: true,
        responseSchemaSource: 'true',
      ),
      const HttpResponseResult(
        statusCode: 200,
        headers: {},
        body: '2',
        duration: Duration.zero,
        sizeBytes: 1,
      ),
      signal,
    );
    expect(result, isNull);
  });
}
