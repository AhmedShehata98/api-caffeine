import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';

class _Session implements McpSession {
  final calls = <(String, Map<String, dynamic>)>[];
  late Future<Result<Map<String, dynamic>>> Function(
    String,
    Map<String, dynamic>,
  )
  respond;
  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) {
    calls.add((method, params));
    return respond(method, params);
  }

  @override
  Future<Result<void>> close() async => const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final negotiation = McpNegotiation(
    era: NegotiatedEra.legacy,
    version: '2025-11-25',
    discovery: {
      'capabilities': {'tools': {}, 'resources': {}, 'prompts': {}},
    },
  );
  late _Session session;
  late McpPrimitiveServices services;
  var current = true;
  setUp(() {
    current = true;
    session = _Session();
    services = McpPrimitiveServices(
      session,
      negotiation,
      isAuthorized: () => current,
    );
  });
  McpPrimitiveServices completions({
    NegotiatedEra era = NegotiatedEra.legacy,
  }) => McpPrimitiveServices(
    session,
    McpNegotiation(
      era: era,
      version: era == NegotiatedEra.legacy ? '2025-11-25' : '2026-07-28',
      discovery: {
        'capabilities': {'completions': {}},
      },
    ),
    isAuthorized: () => current,
  );

  test(
    'resource completion requires an advertised capability before sending',
    () async {
      final result = await services.resources.completeTemplate(
        'weather://{city}',
        'city',
        {'city': const McpUriTemplateInput('Li')},
      );
      expect(
        (result.failureOrNull as McpCoded).code,
        McpErrorCode.missingCapability,
      );
      expect(session.calls, isEmpty);
    },
  );
  for (final era in NegotiatedEra.values) {
    test(
      '$era resource completion uses the template reference and text context',
      () async {
        final input = <String, McpUriTemplateInput>{
          'city': const McpUriTemplateInput('Li'),
          'country': const McpUriTemplateInput('Portugal'),
          'blank': const McpUriTemplateInput(''),
          'tags': const McpUriTemplateInput(
            '["warm"]',
            kind: McpUriTemplateInputKind.list,
          ),
        };
        session.respond = (_, _) async => Result.success({
          if (era == NegotiatedEra.modern) 'resultType': 'complete',
          'completion': {
            'values': ['Lisbon', 'Lille', ''],
            'total': 10,
            'hasMore': true,
          },
        });
        final result = await completions(era: era).resources.completeTemplate(
          'weather://{city}{?country,blank,tags*}',
          'city',
          input,
        );
        expect(result.valueOrNull!.values, ['Lisbon', 'Lille', '']);
        expect(result.valueOrNull!.total, 10);
        expect(result.valueOrNull!.hasMore, isTrue);
        expect(
          () => result.valueOrNull!.values.add('x'),
          throwsUnsupportedError,
        );
        expect(session.calls.single.$1, 'completion/complete');
        expect(session.calls.single.$2, {
          'ref': {
            'type': 'ref/resource',
            'uri': 'weather://{city}{?country,blank,tags*}',
          },
          'argument': {'name': 'city', 'value': 'Li'},
          'context': {
            'arguments': {'country': 'Portugal', 'blank': ''},
          },
        });
        input['country'] = const McpUriTemplateInput('changed');
        expect(session.calls.single.$2['context'], {
          'arguments': {'country': 'Portugal', 'blank': ''},
        });
      },
    );
  }
  test('invalid completion inputs fail locally and never send', () async {
    final resource = completions().resources;
    for (final inputs in <Map<String, McpUriTemplateInput>>[
      {},
      {
        'city': const McpUriTemplateInput(
          '[]',
          kind: McpUriTemplateInputKind.list,
        ),
      },
      {'city': McpUriTemplateInput('x' * 4097)},
      {'city': McpUriTemplateInput('雪' * 1400)},
      {
        'city': const McpUriTemplateInput(''),
        'extra': const McpUriTemplateInput(''),
      },
      {
        'city': const McpUriTemplateInput(''),
        'tags': const McpUriTemplateInput(
          '[',
          kind: McpUriTemplateInputKind.list,
        ),
      },
    ]) {
      expect(
        (await resource.completeTemplate(
          'weather://{city}{?tags}',
          'city',
          inputs,
        )).isSuccess,
        isFalse,
      );
    }
    expect(
      (await resource.completeTemplate('weather://{city}', 'unknown', {
        'unknown': const McpUriTemplateInput(''),
      })).isSuccess,
      isFalse,
    );
    expect(
      (await resource.completeTemplate('weather://{', 'city', {
        'city': const McpUriTemplateInput(''),
      })).isSuccess,
      isFalse,
    );
    expect(session.calls, isEmpty);
  });
  test(
    'malformed or oversized completion results return typed failures',
    () async {
      for (final completion in <Object?>[
        null,
        [],
        {},
        {'values': 'x'},
        {
          'values': [1],
        },
        {'values': List.filled(101, 'x')},
        {
          'values': ['x' * 4097],
        },
        {
          'values': ['雪' * 1400],
        },
        {'values': List.filled(17, 'x' * 4096)},
        {'values': [], 'total': -1},
        {'values': [], 'total': 1.5},
        {'values': [], 'hasMore': 'true'},
      ]) {
        session.respond = (_, _) async =>
            Result.success({'completion': completion});
        final result = await completions().resources.completeTemplate(
          'weather://{city}',
          'city',
          {'city': const McpUriTemplateInput('')},
        );
        expect(
          (result.failureOrNull as McpCoded).code,
          McpErrorCode.invalidParams,
        );
      }
      session.respond = (_, _) async => const Result.success({
        'resultType': 'input_required',
        'completion': {'values': []},
      });
      expect(
        (await completions().resources.completeTemplate(
          'weather://{city}',
          'city',
          {'city': const McpUriTemplateInput('')},
        )).isSuccess,
        isFalse,
      );
    },
  );
  test(
    'empty completion defaults and transport failures are preserved',
    () async {
      final resource = completions().resources;
      session.respond = (_, _) async => const Result.success({
        'completion': {'values': []},
      });
      final empty = (await resource.completeTemplate(
        'weather://{city}',
        'city',
        {'city': const McpUriTemplateInput('')},
      )).valueOrNull!;
      expect(empty.values, isEmpty);
      expect(empty.hasMore, isFalse);
      expect(empty.total, isNull);
      const failure = McpValidationFailure(
        'Method not found',
        code: McpErrorCode.invalidParams,
      );
      session.respond = (_, _) async => const Result.failure(failure);
      expect(
        (await resource.completeTemplate('weather://{city}', 'city', {
          'city': const McpUriTemplateInput(''),
        })).failureOrNull,
        same(failure),
      );
    },
  );
  test(
    'completion rejects stale requests and discards replies after revocation',
    () async {
      final pending = Completer<Result<Map<String, dynamic>>>();
      session.respond = (_, _) => pending.future;
      final resource = completions().resources;
      final request = resource.completeTemplate('weather://{city}', 'city', {
        'city': const McpUriTemplateInput(''),
      });
      current = false;
      pending.complete(
        const Result.success({
          'completion': {
            'values': ['private city'],
          },
        }),
      );
      expect((await request).isSuccess, isFalse);
      expect(
        (await resource.completeTemplate('weather://{city}', 'city', {
          'city': const McpUriTemplateInput(''),
        })).isSuccess,
        isFalse,
      );
      expect(session.calls, hasLength(1));
    },
  );
  test(
    'schema-aware form calls block invalid fields and normalize before send',
    () async {
      const tool = McpTool(
        name: 'add',
        inputSchema: {
          'type': 'object',
          'required': ['count'],
          'properties': {
            'count': {'type': 'integer'},
          },
        },
      );
      final invalid = await services.tools.callWithSchema(tool, {});
      expect(invalid.failureOrNull, isA<SchemaArgumentFailure>());
      expect(session.calls, isEmpty);
      session.respond = (_, _) async => const Result.success({'content': []});
      expect(
        (await services.tools.callWithSchema(tool, {
          'count': '3',
        }, coerce: true)).isSuccess,
        isTrue,
      );
      expect(session.calls.single.$2['arguments'], {'count': 3});
    },
  );
  test('unsupported form schemas require explicit raw JSON fallback', () async {
    const tool = McpTool(
      name: 'raw',
      inputSchema: {'type': 'object', 'allOf': []},
    );
    final result = await services.tools.callWithSchema(tool, {});
    expect(
      (result.failureOrNull as McpCoded).code,
      McpErrorCode.schemaUnportable,
    );
    expect(session.calls, isEmpty);
    session.respond = (_, _) async => const Result.success({'content': []});
    expect((await services.tools.callJson(tool.name, '{}')).isSuccess, isTrue);
  });
  test(
    'duplicate tool names fail without creating ambiguous selection',
    () async {
      session.respond = (_, _) async => const Result.success({
        'tools': [
          {'name': 'same', 'inputSchema': {}},
          {'name': 'same', 'inputSchema': {}},
        ],
      });
      expect((await services.tools.list()).isSuccess, isFalse);
    },
  );
  test('tools aggregate cursor pages in server order', () async {
    session.respond = (_, params) async => Result.success({
      'tools': [
        {
          'name': params.isEmpty ? 'first' : 'second',
          'inputSchema': <String, dynamic>{},
        },
      ],
      if (params.isEmpty) 'nextCursor': 'page-2',
    });
    expect(
      (await services.tools.list()).valueOrNull!.map((tool) => tool.name),
      ['first', 'second'],
    );
    expect(session.calls.map((call) => call.$2), [
      {},
      {'cursor': 'page-2'},
    ]);
  });
  test(
    'repeated cursors fail without looping or returning partial success',
    () async {
      session.respond = (_, _) async =>
          const Result.success({'tools': [], 'nextCursor': 'same'});
      expect((await services.tools.list()).isSuccess, isFalse);
      expect(session.calls, hasLength(2));
    },
  );
  test('missing capability fails without sending any request', () async {
    final missing = McpPrimitiveServices(
      session,
      McpNegotiation(
        era: NegotiatedEra.legacy,
        version: '2025-11-25',
        discovery: {},
      ),
      isAuthorized: () => true,
    );
    final result = await missing.tools.list();
    expect(
      (result.failureOrNull as McpCoded).code,
      McpErrorCode.missingCapability,
    );
    expect(session.calls, isEmpty);
  });
  test('tool error remains a successful operation with content', () async {
    session.respond = (_, _) async => const Result.success({
      'isError': true,
      'content': [
        {'type': 'text', 'text': 'Tool failed'},
      ],
    });
    final result = (await services.tools.call('tool', {})).valueOrNull!;
    expect(result.result.outcomeCode, 'tool_error');
    expect(result.result.resultType, ToolResultType.complete);
    expect(
      result.result.content.single,
      const ContentBlock.text(text: 'Tool failed'),
    );
    expect(result.notice, isNull);
  });
  test(
    'intermediate results keep raw data and never send another round',
    () async {
      for (final type in ['input_required', 'task']) {
        session.respond = (_, _) async => Result.success({
          'resultType': type,
          'interaction': {'id': 'pending'},
        });
        final result = (await services.tools.call('tool', {})).valueOrNull!;
        expect(result.notice, contains('interaction support'));
        expect(result.raw['interaction'], {'id': 'pending'});
      }
      expect(session.calls, hasLength(2));
    },
  );
  test('invalid JSON and non-object arguments fail before send', () async {
    for (final text in ['{', '[]', 'null', '123']) {
      expect((await services.tools.callJson('tool', text)).isSuccess, isFalse);
    }
    expect(
      (await services.tools.call('tool', {'value': double.nan})).isSuccess,
      isFalse,
    );
    expect(session.calls, isEmpty);
  });
  test('tool call freezes JSON arguments at invocation', () async {
    final response = Completer<Result<Map<String, dynamic>>>();
    session.respond = (_, _) => response.future;
    final arguments = {
      'nested': <String, dynamic>{'value': 'original'},
    };
    final pending = services.tools.call('tool', arguments);
    arguments['nested']!['value'] = 'changed';
    response.complete(const Result.success({'content': []}));
    await pending;
    expect(session.calls.single.$2['arguments'], {
      'nested': {'value': 'original'},
    });
  });
  test(
    'resource paging is explicit and templates use the protocol key',
    () async {
      session.respond = (method, _) async => Result.success(
        method == 'resources/list'
            ? {
                'resources': [
                  {'uri': 'test:///one', 'name': 'one'},
                ],
                'nextCursor': 'next',
              }
            : {
                'resourceTemplates': [
                  {'uriTemplate': 'test:///{id}', 'name': 'template'},
                ],
              },
      );
      expect((await services.resources.list()).valueOrNull!.nextCursor, 'next');
      expect(session.calls, hasLength(1));
      await services.resources.list(cursor: 'next');
      expect(session.calls.last.$2, {'cursor': 'next'});
      expect(
        (await services.resources.templates()).valueOrNull!.items.single.name,
        'template',
      );
    },
  );
  test(
    'resource read handles text and blobs without decoding binary data',
    () async {
      session.respond = (_, _) async => const Result.success({
        'contents': [
          {'uri': 'test:///one', 'text': 'text'},
          {
            'uri': 'test:///two',
            'blob': 'AAEC',
            'mimeType': 'application/octet-stream',
          },
        ],
      });
      final contents = (await services.resources.read('test:///one'))
          .valueOrNull!;
      expect(contents.first.text, 'text');
      expect(contents.last.blob, 'AAEC');
    },
  );
  test('malformed result errors do not echo server payloads', () async {
    session.respond = (_, _) async => const Result.success({
      'tools': [
        {'name': 'secret-canary', 'inputSchema': 'invalid'},
      ],
    });
    final result = await services.tools.list();
    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull!.message, isNot(contains('secret-canary')));
    session.respond = (_, _) async => const Result.success({
      'content': [
        {'type': 'unknown-secret-canary'},
      ],
    });
    final unknown = await services.tools.call('tool', {});
    expect(unknown.isSuccess, isFalse);
    expect(unknown.failureOrNull!.message, isNot(contains('secret-canary')));
  });
  test(
    'transport failures and resource-not-found failures are preserved',
    () async {
      const failure = McpValidationFailure(
        'Resource not found.',
        code: McpErrorCode.invalidParams,
      );
      session.respond = (_, _) async => const Result.failure(failure);
      expect(
        (await services.resources.read('test:///gone')).failureOrNull,
        same(failure),
      );
    },
  );
  test('prompt required arguments are checked before sending', () async {
    const prompt = McpPrompt(
      name: 'city',
      arguments: [PromptArgument(name: 'city', required: true)],
    );
    expect((await services.prompts.get(prompt, {})).isSuccess, isFalse);
    expect(
      (await services.prompts.get(prompt, {'city': ' '})).isSuccess,
      isFalse,
    );
    expect(session.calls, isEmpty);
    session.respond = (_, _) async => const Result.success({
      'description': 'Greeting',
      'messages': [
        {
          'role': 'user',
          'content': {'type': 'text', 'text': 'Cairo'},
        },
        {
          'role': 'assistant',
          'content': {'type': 'text', 'text': 'Hello'},
        },
      ],
    });
    final result = (await services.prompts.get(prompt, {
      'city': 'Cairo',
    })).valueOrNull!;
    expect(result.messages.map((message) => message.role), [
      PromptRole.user,
      PromptRole.assistant,
    ]);
    expect(result.description, 'Greeting');
    expect(session.calls.single.$2['arguments'], {'city': 'Cairo'});
  });
  test(
    'account change during a call prevents late operation data escaping',
    () async {
      session.respond = (_, _) async {
        current = false;
        return const Result.success({'content': []});
      };
      expect(
        (await services.tools.call('tool', {})).failureOrNull,
        isA<McpAuthFailure>(),
      );
    },
  );
  test('provider services reject retained handles after disconnect', () async {
    final owner = McpSessionOwner();
    await owner.switchScope('u', 'w');
    await owner.run(
      's',
      (_) async => Result.success(McpConnected(session, negotiation)),
    );
    final container = ProviderContainer(
      overrides: [mcpSessionOwnerProvider.overrideWithValue(owner)],
    );
    container.listen(mcpPrimitiveServicesProvider('s'), (_, _) {});
    await container.read(mcpSessionsProvider.future);
    await container.pump();
    final retained = container.read(mcpPrimitiveServicesProvider('s'))!;
    await owner.disconnect('s');
    expect((await retained.tools.list()).failureOrNull, isA<McpAuthFailure>());
    expect(session.calls, isEmpty);
    container.dispose();
    await owner.dispose();
  });
}
