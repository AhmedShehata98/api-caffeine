import 'dart:convert';

import 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;

import 'package:test_point/core/error/result.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_protocol_models.dart';
import '../models/mcp_schema_form.dart';
import '../repositories/mcp_connection_repository.dart';
import 'mcp_negotiation_service.dart';
import 'schema_form_builder.dart';

class McpPage<T> {
  McpPage(List<T> items, this.nextCursor) : items = List.unmodifiable(items);
  final List<T> items;
  final String? nextCursor;
}

/// An operation result, never a diagnostic cache or automatically persisted data.
class McpToolCall {
  McpToolCall(this.result, Map<String, dynamic> raw)
    : raw = Map.unmodifiable(raw);
  final ToolCallResult result;
  final Map<String, dynamic> raw;
  String? get notice => result.resultType == ToolResultType.complete
      ? null
      : 'This server needs interaction support (coming in a later version)';
}

class McpPromptResult {
  McpPromptResult(List<PromptMessage> messages, this.description)
    : messages = List.unmodifiable(messages);
  final List<PromptMessage> messages;
  final String? description;
}

/// Shared request/decoding boundary for the three S1 server primitives.
class McpPrimitiveServices {
  McpPrimitiveServices(
    McpSession session,
    McpNegotiation negotiation, {
    required bool Function() isAuthorized,
  }) : _client = _PrimitiveClient(session, negotiation, isAuthorized);
  final _PrimitiveClient _client;
  late final tools = McpToolService._(_client);
  late final resources = McpResourceService._(_client);
  late final prompts = McpPromptService._(_client);
  bool supports(String capability) => _client.supports(capability);
}

class _PrimitiveClient {
  _PrimitiveClient(this.session, this.negotiation, this.isAuthorized);
  final McpSession session;
  final McpNegotiation negotiation;
  final bool Function() isAuthorized;
  bool supports(String capability) {
    final capabilities = negotiation.discovery['capabilities'];
    return capabilities is Map && capabilities[capability] is Map;
  }

  Future<Result<T>> request<T>(
    String capability,
    String method,
    Map<String, dynamic> params,
    T Function(Map<String, dynamic>) decode,
  ) async {
    if (!isAuthorized()) return const Result.failure(_stale);
    if (!supports(capability)) {
      return const Result.failure(
        McpValidationFailure(
          'This server does not advertise the required capability.',
          code: McpErrorCode.missingCapability,
        ),
      );
    }
    final response = await session.request(method, params);
    if (!isAuthorized()) return const Result.failure(_stale);
    if (response case Err(:final failure)) return Result.failure(failure);
    try {
      return Result.success(decode(response.valueOrNull!));
    } on FormatException {
      return const Result.failure(_malformed);
    } on TypeError {
      return const Result.failure(_malformed);
    } on ArgumentError {
      return const Result.failure(_malformed);
    } on CheckedFromJsonException {
      return const Result.failure(_malformed);
    }
  }

  Future<Result<McpPage<T>>> page<T>(
    String capability,
    String method,
    String key,
    T Function(Map<String, dynamic>) decode,
    String? cursor,
  ) => request(capability, method, {'cursor': ?cursor}, (value) {
    final next = value['nextCursor'];
    if (next != null && next is! String) throw const FormatException();
    final items = value[key] as List;
    return McpPage(
      items
          .map((item) => decode(Map<String, dynamic>.from(item as Map)))
          .toList(),
      next as String?,
    );
  });

  Future<Result<List<T>>> all<T>(
    String capability,
    String method,
    String key,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final items = <T>[];
    final seen = <String>{};
    String? cursor;
    for (var pages = 0; pages < 1000; pages++) {
      final response = await page(capability, method, key, decode, cursor);
      if (response case Err(:final failure)) return Result.failure(failure);
      final value = response.valueOrNull!;
      if (items.length + value.items.length > 10000) break;
      items.addAll(value.items);
      cursor = value.nextCursor;
      if (cursor == null) return Result.success(List.unmodifiable(items));
      if (!seen.add(cursor)) break;
    }
    return const Result.failure(
      McpValidationFailure(
        'The MCP list exceeded its pagination limit or repeated a cursor.',
        code: McpErrorCode.invalidParams,
      ),
    );
  }

  static const _stale = McpAuthFailure(
    'This MCP session is no longer active. Reconnect to continue.',
  );
  static const _malformed = McpValidationFailure(
    'The MCP server returned an invalid result.',
    code: McpErrorCode.invalidParams,
  );
}

class McpToolService {
  McpToolService._(this._client);
  final _PrimitiveClient _client;

  /// Form calls validate the supported subset. Raw JSON remains available via
  /// callJson when a schema explicitly requires the raw editor.
  Future<Result<McpToolCall>> callWithSchema(
    McpTool tool,
    Object? input, {
    bool coerce = false,
  }) async {
    const builder = SchemaFormBuilder();
    final plan = builder.build(tool.inputSchema);
    if (plan is RawJsonOnly) {
      return Result.failure(
        McpValidationFailure(plan.reason, code: McpErrorCode.schemaUnportable),
      );
    }
    final arguments = builder.arguments(
      plan as FormSpec,
      input,
      coerce: coerce,
    );
    if (arguments case Err(:final failure)) return Result.failure(failure);
    return call(tool.name, arguments.valueOrNull!);
  }

  Future<Result<List<McpTool>>> list() async {
    final result = await _client.all(
      'tools',
      'tools/list',
      'tools',
      McpTool.fromJson,
    );
    if (result case Success(:final value)) {
      if (value.map((tool) => tool.name).toSet().length != value.length) {
        return const Result.failure(
          McpValidationFailure(
            'The server returned duplicate tool names.',
            code: McpErrorCode.invalidParams,
          ),
        );
      }
    }
    return result;
  }

  Future<Result<McpToolCall>> call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    if (name.trim().isEmpty) return const Result.failure(_invalidArguments);
    Map<String, dynamic> frozen;
    try {
      frozen = jsonDecode(jsonEncode(arguments)) as Map<String, dynamic>;
    } on Object {
      return const Result.failure(_invalidArguments);
    }
    return _client.request(
      'tools',
      'tools/call',
      {'name': name, 'arguments': frozen},
      (value) {
        final type = value['resultType'];
        // S1 stops after intermediate results; their full payload remains an
        // operation result and in the sanitized transcript. Never drive MRTR.
        final result = type == 'input_required' || type == 'task'
            ? ToolCallResult(
                resultType: type == 'task'
                    ? ToolResultType.task
                    : ToolResultType.inputRequired,
              )
            : ToolCallResult.fromJson(value);
        return McpToolCall(result, value);
      },
    );
  }

  Future<Result<McpToolCall>> callJson(String name, String json) async {
    try {
      final value = jsonDecode(json);
      if (value is! Map<String, dynamic>) {
        return const Result.failure(_invalidArguments);
      }
      return await call(name, value);
    } on FormatException {
      return const Result.failure(_invalidArguments);
    }
  }

  static const _invalidArguments = McpValidationFailure(
    'Provide a tool name and valid JSON object arguments.',
    code: McpErrorCode.invalidParams,
  );
}

class McpResourceService {
  McpResourceService._(this._client);
  final _PrimitiveClient _client;
  Future<Result<McpPage<McpResource>>> list({String? cursor}) => _client.page(
    'resources',
    'resources/list',
    'resources',
    McpResource.fromJson,
    cursor,
  );
  Future<Result<McpPage<McpResourceTemplate>>> templates({String? cursor}) =>
      _client.page(
        'resources',
        'resources/templates/list',
        'resourceTemplates',
        McpResourceTemplate.fromJson,
        cursor,
      );
  Future<Result<List<ResourceContents>>> read(String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null || !parsed.hasScheme) {
      return const Result.failure(
        McpValidationFailure(
          'Provide an absolute resource URI.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    return _client.request('resources', 'resources/read', {'uri': uri}, (
      value,
    ) {
      final contents = (value['contents'] as List).map((item) {
        final result = ResourceContents.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        if ((result.text == null) == (result.blob == null)) {
          throw const FormatException();
        }
        return result;
      }).toList();
      return List.unmodifiable(contents);
    });
  }
}

class McpPromptService {
  McpPromptService._(this._client);
  final _PrimitiveClient _client;
  Future<Result<List<McpPrompt>>> list() async {
    final result = await _client.all(
      'prompts',
      'prompts/list',
      'prompts',
      McpPrompt.fromJson,
    );
    if (result case Success(:final value)) {
      if (value.map((prompt) => prompt.name).toSet().length != value.length ||
          value.any(
            (prompt) =>
                prompt.arguments.map((arg) => arg.name).toSet().length !=
                prompt.arguments.length,
          )) {
        return const Result.failure(
          McpValidationFailure(
            'The server returned duplicate prompt or argument names.',
            code: McpErrorCode.invalidParams,
          ),
        );
      }
    }
    return result;
  }

  Future<Result<McpPromptResult>> get(
    McpPrompt prompt,
    Map<String, String> arguments,
  ) async {
    if (prompt.name.trim().isEmpty ||
        prompt.arguments.any(
          (argument) =>
              argument.required &&
              (arguments[argument.name]?.trim().isEmpty ?? true),
        )) {
      return const Result.failure(
        McpValidationFailure(
          'Fill all required prompt arguments.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    return _client.request(
      'prompts',
      'prompts/get',
      {
        'name': prompt.name,
        'arguments': Map<String, String>.unmodifiable(arguments),
      },
      (value) {
        return McpPromptResult(
          (value['messages'] as List)
              .map(
                (item) => PromptMessage.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
          value['description'] as String?,
        );
      },
    );
  }
}
