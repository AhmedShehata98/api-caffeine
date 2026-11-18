import 'dart:async';

import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_protocol_models.dart';
import '../models/mcp_uri_template_input.dart';
import 'mcp_primitive_services.dart';

class McpToolDraft {
  const McpToolDraft({
    this.tool,
    this.arguments = '{}',
    this.validateSchema = true,
    this.rawEditor = false,
  });
  final McpTool? tool;
  final String arguments;
  final bool validateSchema;
  final bool rawEditor;
}

class McpPromptDraft {
  McpPromptDraft({this.prompt, Map<String, String> arguments = const {}})
    : arguments = Map.unmodifiable(arguments);
  final McpPrompt? prompt;
  final Map<String, String> arguments;
}

class McpResourceTemplateDraft {
  McpResourceTemplateDraft({
    this.template,
    Map<String, McpUriTemplateInput> values = const {},
  }) : values = Map.unmodifiable(values);
  final String? template;
  final Map<String, McpUriTemplateInput> values;
}

/// Memory-only UI state. Submitted input remains distinct from later edits.
class McpOperationState<D, T> {
  const McpOperationState({
    this.draft,
    this.submitted,
    this.running = false,
    this.outcome,
    this.duration,
  });
  final D? draft;
  final D? submitted;
  final bool running;
  final Result<T>? outcome;
  final Duration? duration;
}

/// Last invocation wins. Clearing/disposal also invalidates pending completions;
/// it does not resend, retry or pretend to cancel a request on the transport.
class McpOperationController<D, T> {
  McpOperationController(D initialDraft, {required this.isAuthorized})
    : _draft = initialDraft;
  final bool Function() isAuthorized;
  final _changes = StreamController<McpOperationState<D, T>>.broadcast();
  D? _draft;
  D? _submitted;
  Result<T>? _outcome;
  Duration? _duration;
  bool _running = false;
  bool _disposed = false;
  int _revision = 0;
  Future<void>? _closing;
  McpOperationState<D, T> get state => !_active
      ? const McpOperationState()
      : McpOperationState(
          draft: _draft,
          submitted: _submitted,
          running: _running,
          outcome: _outcome,
          duration: _duration,
        );
  Stream<McpOperationState<D, T>> get changes => _changes.stream;
  bool get _active => !_disposed && isAuthorized();
  void _publish() {
    if (!_disposed) _changes.add(state);
  }

  Result<void> setDraft(D value) {
    if (!_active) return const Result.failure(_stale);
    _draft = value;
    _publish();
    return const Result.success(null);
  }

  Future<Result<T>> run(Future<Result<T>> Function(D draft) operation) async {
    final draft = _draft;
    if (!_active || draft == null) return const Result.failure(_stale);
    final revision = ++_revision;
    _submitted = draft;
    _outcome = null;
    _duration = null;
    _running = true;
    _publish();
    final watch = Stopwatch()..start();
    Result<T> outcome;
    try {
      outcome = await operation(draft);
    } on Object {
      outcome = const Result.failure(
        UnexpectedFailure('The MCP operation could not be completed.'),
      );
    }
    watch.stop();
    if (!_active) return const Result.failure(_stale);
    if (revision != _revision) return const Result.failure(_superseded);
    _outcome = outcome;
    _duration = watch.elapsed;
    _running = false;
    _publish();
    return outcome;
  }

  void clearResult() {
    _revision++;
    _submitted = null;
    _outcome = null;
    _duration = null;
    _running = false;
    _publish();
  }

  Future<void> dispose() {
    if (_closing != null) return _closing!;
    _disposed = true;
    clearResult();
    _draft = null;
    // Replace the last StreamProvider value before it merges a replacement
    // stream's loading state with previous data.
    _changes.add(const McpOperationState());
    // A paused UI listener must not hold up account/workspace shutdown.
    unawaited(_changes.close());
    return _closing = Future.value();
  }

  static const _stale = McpAuthFailure(
    'This MCP session is no longer active. Reconnect to continue.',
  );
  static const _superseded = McpValidationFailure(
    'A newer operation or clear action replaced this result.',
    code: McpErrorCode.invalidParams,
  );
}

class McpSessionWork {
  McpSessionWork({required bool Function() isAuthorized})
    : tools = McpOperationController(
        const McpToolDraft(),
        isAuthorized: isAuthorized,
      ),
      resources = McpOperationController('', isAuthorized: isAuthorized),
      resourceTemplate = McpOperationController(
        McpResourceTemplateDraft(),
        isAuthorized: isAuthorized,
      ),
      prompts = McpOperationController(
        McpPromptDraft(),
        isAuthorized: isAuthorized,
      );
  final McpOperationController<McpToolDraft, McpToolCall> tools;
  final McpOperationController<String, List<ResourceContents>> resources;
  final McpOperationController<McpResourceTemplateDraft, void> resourceTemplate;
  final McpOperationController<McpPromptDraft, McpPromptResult> prompts;
  Future<void> dispose() => Future.wait([
    tools.dispose(),
    resources.dispose(),
    resourceTemplate.dispose(),
    prompts.dispose(),
  ]);
}

class McpWorkActions {
  const McpWorkActions(this.work, this.services);
  final McpSessionWork work;
  final McpPrimitiveServices services;
  Future<Result<McpToolCall>> callTool() => work.tools.run((draft) async {
    final tool = draft.tool;
    if (tool == null) return const Result.failure(_selection);
    return draft.validateSchema
        ? services.tools.callWithSchema(tool, draft.arguments)
        : services.tools.callJson(tool.name, draft.arguments);
  });
  Future<Result<List<ResourceContents>>> readResource() =>
      work.resources.run(services.resources.read);
  Future<Result<McpPromptResult>> getPrompt() =>
      work.prompts.run((draft) async {
        final prompt = draft.prompt;
        if (prompt == null) return const Result.failure(_selection);
        return services.prompts.get(prompt, draft.arguments);
      });
  static const _selection = McpValidationFailure(
    'Select a tool or prompt first.',
    code: McpErrorCode.invalidParams,
  );
}
