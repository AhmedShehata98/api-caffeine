import 'package:freezed_annotation/freezed_annotation.dart';

part 'http_response_result.freezed.dart';

@freezed
abstract class HttpResponseResult with _$HttpResponseResult {
  const factory HttpResponseResult({
    required int statusCode,
    required Map<String, List<String>> headers,
    required String body,
    required Duration duration,
    required int sizeBytes,
    String? reason,

    /// Whether the original response bytes were valid UTF-8.
    @Default(true) bool validUtf8,

    /// Content-type-aware source, set when a Pretty view is available.
    String? prettyBody,
  }) = _HttpResponseResult;
}
