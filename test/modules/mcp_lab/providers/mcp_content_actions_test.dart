import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_resource_export_repository.dart';

class _Session implements McpSession {
  @override
  Future<Result<void>> close() async => const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Exports implements McpResourceExportRepository {
  final calls = <(Uint8List, String)>[];
  @override
  Future<Result<bool>> save(Uint8List bytes, String name, String mime) async {
    calls.add((bytes, name));
    return const Result.success(true);
  }
}

void main() {
  late McpSessionOwner owner;
  late McpSessionWork work;
  late ProviderContainer container;
  late _Exports exports;
  const audio = ContentBlock.audio(data: 'AID/AA==', mimeType: 'audio/wav');
  const link = ContentBlock.resourceLink(
    uri: 'weather://lisbon',
    name: 'Forecast',
  ) as ResourceLinkBlock;
  setUp(() async {
    owner = McpSessionOwner();
    await owner.switchScope('u', 'w');
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          _Session(),
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {
              'capabilities': {'tools': {}, 'prompts': {}, 'resources': {}},
            },
          ),
        ),
      ),
    );
    work = owner.workFor('s')!;
    exports = _Exports();
    container = ProviderContainer.test(
      overrides: [
        mcpSessionOwnerProvider.overrideWithValue(owner),
        mcpResourceExportRepositoryProvider.overrideWithValue(exports),
      ],
    );
    container.listen(mcpResourceExportProvider('s'), (_, _) {});
    container.listen(mcpContentActionsProvider('s'), (_, _) {});
    container.listen(mcpCanOpenResourceProvider('s'), (_, _) {});
    await container.pump();
  });
  tearDown(() => owner.dispose());
  Future<void> tool(List<ContentBlock> blocks) => work.tools
      .run(
        (_) async => Result.success(
          McpToolCall(ToolCallResult(content: blocks), {
            'content': blocks.map((block) => block.toJson()).toList(),
          }),
        ),
      )
      .then((_) {});
  Future<void> prompt(List<ContentBlock> blocks) => work.prompts
      .run(
        (_) async => Result.success(
          McpPromptResult(
            blocks
                .map(
                  (block) =>
                      PromptMessage(role: PromptRole.user, content: block),
                )
                .toList(),
            null,
          ),
        ),
      )
      .then((_) {});
  test('media mapping preserves original bytes, MIME and embedded resource identity', () {
    final resource = resourceForMcpContent(audio)!;
    expect(resource.blob, 'AID/AA==');
    expect(resource.mimeType, 'audio/wav');
    const embedded = ResourceContents(uri: 'fixture://file', text: 'hello');
    expect(
      identical(
        resourceForMcpContent(const ContentBlock.resource(resource: embedded)),
        embedded,
      ),
      isTrue,
    );
    expect(resourceForMcpContent(link), isNull);
  });
  test(
    'tool and prompt saves export only their exact current content',
    () async {
      await tool([audio]);
      await prompt([audio]);
      final action = container.read(mcpResourceExportProvider('s'));
      final content = resourceForMcpContent(audio)!;
      expect(
        (await action.save(
          content,
          origin: McpContentOrigin.tool,
          block: audio,
        )).valueOrNull,
        isTrue,
      );
      expect(
        (await action.save(
          content,
          origin: McpContentOrigin.prompt,
          block: audio,
        )).valueOrNull,
        isTrue,
      );
      expect(exports.calls.first.$1, [0, 128, 255, 0]);
      expect(exports.calls.first.$2, 'resource.wav');
      expect(
        (await action.save(
          content.copyWith(blob: 'AAAA'),
          origin: McpContentOrigin.tool,
          block: audio,
        )).isSuccess,
        isFalse,
      );
      expect(exports.calls.length, 2);
    },
  );
  test('cleared results and account changes block old exports', () async {
    await tool([audio]);
    final action = container.read(mcpResourceExportProvider('s'));
    work.tools.clearResult();
    expect(
      (await action.save(
        resourceForMcpContent(audio)!,
        origin: McpContentOrigin.tool,
        block: audio,
      )).isSuccess,
      isFalse,
    );
    await prompt([audio]);
    await owner.switchScope('other', 'w');
    expect(
      (await action.save(
        resourceForMcpContent(audio)!,
        origin: McpContentOrigin.prompt,
        block: audio,
      )).isSuccess,
      isFalse,
    );
    expect(exports.calls, isEmpty);
  });
  test('resource links seed the URI without invoking a read and clear old template drafts', () async {
    await tool([link]);
    work.resourceTemplate.setDraft(
      McpResourceTemplateDraft(
        template: 'weather://{city}',
        values: {'city': const McpUriTemplateInput('old')},
      ),
    );
    expect(
      container
          .read(mcpContentActionsProvider('s'))
          .openResource(link, McpContentOrigin.tool)
          .isSuccess,
      isTrue,
    );
    expect(work.resources.state.draft, 'weather://lisbon');
    expect(work.resources.state.outcome, isNull);
    expect(work.resourceTemplate.state.draft!.template, isNull);
    work.tools.clearResult();
    expect(
      container
          .read(mcpContentActionsProvider('s'))
          .openResource(link, McpContentOrigin.tool)
          .isSuccess,
      isFalse,
    );
  });
  test(
    'invalid resource links are rejected without changing the draft',
    () async {
      const invalid = ContentBlock.resourceLink(
        uri: 'relative/{city}',
        name: 'Invalid',
      ) as ResourceLinkBlock;
      await prompt([invalid]);
      expect(
        container
            .read(mcpContentActionsProvider('s'))
            .openResource(invalid, McpContentOrigin.prompt)
            .isSuccess,
        isFalse,
      );
      expect(work.resources.state.draft, '');
    },
  );
}
