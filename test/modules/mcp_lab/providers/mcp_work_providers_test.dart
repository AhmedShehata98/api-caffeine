import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';

class _Session implements McpSession {
  final requests = <Map<String, dynamic>>[];
  late Future<Result<Map<String, dynamic>>> Function() respond;
  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) {
    requests.add(params);
    return respond();
  }

  @override
  Future<Result<void>> close() async => const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'draft edits remain distinct from submitted input and result duration',
    () async {
      final controller = McpOperationController<String, String>(
        'first',
        isAuthorized: () => true,
      );
      final response = Completer<Result<String>>();
      final pending = controller.run((draft) {
        expect(draft, 'first');
        return response.future;
      });
      expect(controller.state.running, isTrue);
      controller.setDraft('edited');
      response.complete(const Result.success('result'));
      await pending;
      expect(controller.state.draft, 'edited');
      expect(controller.state.submitted, 'first');
      expect(controller.state.outcome!.valueOrNull, 'result');
      expect(controller.state.duration, isNotNull);
      expect(controller.state.running, isFalse);
      await controller.dispose();
    },
  );
  test(
    'new invocation supersedes late completion without overwriting state',
    () async {
      final controller = McpOperationController<String, String>(
        'first',
        isAuthorized: () => true,
      );
      final slow = Completer<Result<String>>();
      final first = controller.run((_) => slow.future);
      controller.setDraft('second');
      await controller.run((_) async => const Result.success('new'));
      slow.complete(const Result.success('old'));
      expect((await first).isSuccess, isFalse);
      expect(controller.state.outcome!.valueOrNull, 'new');
      await controller.dispose();
    },
  );
  test(
    'clear invalidates a pending result while preserving the current draft',
    () async {
      final controller = McpOperationController<String, String>(
        'draft',
        isAuthorized: () => true,
      );
      final response = Completer<Result<String>>();
      final pending = controller.run((_) => response.future);
      controller.clearResult();
      response.complete(const Result.success('secret-result'));
      expect((await pending).isSuccess, isFalse);
      expect(controller.state.draft, 'draft');
      expect(controller.state.submitted, isNull);
      expect(controller.state.outcome, isNull);
      await controller.dispose();
    },
  );
  test('revoked access hides state and blocks late payload return', () async {
    var active = true;
    final controller = McpOperationController<String, String>(
      'secret-draft',
      isAuthorized: () => active,
    );
    final response = Completer<Result<String>>();
    final pending = controller.run((_) => response.future);
    active = false;
    response.complete(const Result.success('secret-result'));
    expect((await pending).failureOrNull, isA<McpAuthFailure>());
    expect(controller.state.draft, isNull);
    expect(controller.state.outcome, isNull);
    await controller.dispose();
  });
  test('unexpected callback exceptions are sanitized', () async {
    final controller = McpOperationController<String, String>(
      'draft',
      isAuthorized: () => true,
    );
    final result = await controller.run(
      (_) async => throw StateError('secret-canary'),
    );
    expect(result.failureOrNull!.message, isNot(contains('secret-canary')));
    expect(controller.state.running, isFalse);
    await controller.dispose();
  });
  test('disposal does not wait for paused UI subscribers', () async {
    final controller = McpOperationController<String, String>(
      'draft',
      isAuthorized: () => true,
    );
    final subscription = controller.changes.listen((_) {})..pause();
    controller.setDraft('secret-draft');
    await controller.dispose();
    expect(controller.state.draft, isNull);
    expect(controller.setDraft('late').isSuccess, isFalse);
    await subscription.cancel();
  });
  test('prompt draft snapshots caller argument maps', () {
    final values = {'city': 'Cairo'};
    final draft = McpPromptDraft(arguments: values);
    values['city'] = 'changed';
    expect(draft.arguments, {'city': 'Cairo'});
    expect(() => draft.arguments.clear(), throwsUnsupportedError);
  });

  Future<(McpSessionOwner, ProviderContainer, _Session)> setup() async {
    final session = _Session()
      ..respond = () async =>
          const Result.success({'isError': true, 'content': []});
    final owner = McpSessionOwner();
    await owner.switchScope('u', 'w');
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          session,
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {
              'capabilities': {'tools': {}, 'resources': {}, 'prompts': {}},
            },
          ),
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [mcpSessionOwnerProvider.overrideWithValue(owner)],
    );
    container.listen(mcpToolCallProvider('s'), (_, _) {});
    container.listen(mcpWorkActionsProvider('s'), (_, _) {});
    await container.read(mcpSessionsProvider.future);
    await container.pump();
    addTearDown(() async {
      container.dispose();
      await owner.dispose();
    });
    return (owner, container, session);
  }

  test(
    'provider action retains tool-error success and separate primitive drafts',
    () async {
      final (owner, container, session) = await setup();
      final work = owner.workFor('s')!;
      work.tools.setDraft(
        const McpToolDraft(
          tool: McpTool(name: 'fail', inputSchema: {}),
          arguments: '{}',
        ),
      );
      work.resources.setDraft('test:///resource');
      final result = await container
          .read(mcpWorkActionsProvider('s'))!
          .callTool();
      expect(result.valueOrNull!.result.outcomeCode, 'tool_error');
      expect(work.tools.state.outcome!.isSuccess, isTrue);
      expect(work.resources.state.draft, 'test:///resource');
      expect(work.resources.state.outcome, isNull);
      expect(session.requests, hasLength(1));
      session.respond = () async => Result.success(
        session.requests.last.containsKey('uri')
            ? {
                'contents': [
                  {'uri': 'test:///resource', 'text': 'resource'},
                ],
              }
            : {
                'messages': [
                  {
                    'role': 'user',
                    'content': {'type': 'text', 'text': 'prompt'},
                  },
                ],
              },
      );
      final actions = container.read(mcpWorkActionsProvider('s'))!;
      expect(
        (await actions.readResource()).valueOrNull!.single.text,
        'resource',
      );
      work.prompts.setDraft(
        McpPromptDraft(prompt: const McpPrompt(name: 'prompt')),
      );
      expect(
        (await actions.getPrompt()).valueOrNull!.messages.single.content,
        const ContentBlock.text(text: 'prompt'),
      );
      expect(
        work.tools.state.outcome!.valueOrNull!.result.outcomeCode,
        'tool_error',
      );
      container.invalidate(mcpSessionWorkProvider('s'));
      await container.pump();
      expect(container.read(mcpSessionWorkProvider('s')), same(work));
    },
  );
  test('disconnect clears drafts/results and reconnect starts fresh', () async {
    final (owner, _, session) = await setup();
    final old = owner.workFor('s')!;
    old.tools.setDraft(const McpToolDraft(arguments: '{"secret":"draft"}'));
    await owner.disconnect('s');
    expect(old.tools.state.draft, isNull);
    expect(old.tools.state.outcome, isNull);
    expect(owner.workFor('s'), isNull);
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          session,
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {},
          ),
        ),
      ),
    );
    expect(owner.workFor('s'), isNot(same(old)));
    expect(owner.workFor('s')!.tools.state.draft!.arguments, '{}');
  });
  test(
    'account boundary releases pending work and rejects late results',
    () async {
      final (owner, container, session) = await setup();
      final work = owner.workFor('s')!;
      work.tools.setDraft(
        const McpToolDraft(
          tool: McpTool(name: 'tool', inputSchema: {}),
        ),
      );
      final response = Completer<Result<Map<String, dynamic>>>();
      session.respond = () => response.future;
      final pending = container.read(mcpWorkActionsProvider('s'))!.callTool();
      await owner.switchScope('next', 'new-workspace');
      await container.pump();
      expect(container.read(mcpToolCallProvider('s')).value?.draft, isNull);
      response.complete(
        const Result.success({
          'content': [
            {'type': 'text', 'text': 'secret-result'},
          ],
        }),
      );
      expect((await pending).failureOrNull, isA<McpAuthFailure>());
      expect(work.tools.state.draft, isNull);
      expect(work.tools.state.outcome, isNull);
    },
  );
}
