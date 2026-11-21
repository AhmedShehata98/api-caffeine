import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';

void main() {
  const base = McpServerDraft(
    name: '  Fixture  ',
    transport: McpTransport.http,
    command: ' dart ',
    cwd: ' ',
  );
  test(
    'normalizes targets, infers transport and keeps server arguments intact',
    () {
      final stdio = validateMcpServerDraft(
        base.copyWith(args: ['--help', '--era=modern']),
      ).valueOrNull!;
      expect(stdio.name, 'Fixture');
      expect(stdio.command, 'dart');
      expect(stdio.cwd, isNull);
      expect(stdio.transport, McpTransport.stdio);
      expect(stdio.args, ['--help', '--era=modern']);
      expect(stdio.settings.protocolEra, McpProtocolEra.legacy);
      final http = validateMcpServerDraft(
        base.copyWith(
          command: null,
          url: ' https://example.test/mcp ',
          transport: McpTransport.stdio,
        ),
      ).valueOrNull!;
      expect(http.transport, McpTransport.http);
      expect(
        validateMcpServerDraft(http.copyWith(transport: McpTransport.sse))
            .valueOrNull!
            .transport,
        McpTransport.sse,
      );
    },
  );
  test('rejects invalid targets, names, timeouts and header injection', () {
    for (final invalid in [
      base.copyWith(name: ' '),
      base.copyWith(command: null),
      base.copyWith(url: 'https://example.test'),
      base.copyWith(command: null, url: 'file:///server'),
      base.copyWith(command: null, url: 'https://user:pass@example.test'),
      base.copyWith(command: null, url: 'https://@example.test'),
      base.copyWith(settings: const McpServerSettings(timeoutSeconds: 0)),
      base.copyWith(headers: {'X-Team': 'one', 'x-team': 'two'}),
      base.copyWith(headers: {'X-Team': 'one\r\nOther: injected'}),
      base.copyWith(secretKeys: ['TOKEN']),
      base.copyWith(secretKeys: ['env.MISSING']),
      base.copyWith(env: {'BAD KEY': 'value'}),
    ]) {
      expect(
        validateMcpServerDraft(invalid).failureOrNull,
        isA<McpValidationFailure>(),
      );
    }
  });
  test('canonicalizes headers and automatically protects credential names', () {
    final valid = validateMcpServerDraft(
      base.copyWith(
        headers: {
          'Authorization': 'a',
          'Proxy-Authorization': 'b',
          'Cookie': 'c',
          'X-Api-Key': 'd',
          'X-Github-Token': 'e',
          'X-Service-Key': 'f',
          'X-Service-Secret': 'g',
          'X-Team': 'public',
        },
      ),
    ).valueOrNull!;
    expect(valid.secretKeys, hasLength(7));
    expect(valid.secretKeys, isNot(contains('header.x-team')));
    expect(valid.headers.keys.every((key) => key == key.toLowerCase()), isTrue);
  });
  test(
    'credential header unmarking requires an explicit confirmed override',
    () {
      final draft = base.copyWith(headers: {'Authorization': 'a'});
      expect(validateMcpServerDraft(draft).valueOrNull!.secretKeys, [
        'header.authorization',
      ]);
      expect(
        validateMcpServerDraft(
          draft,
          confirmedPlaintextHeaders: {'Authorization'},
        ).valueOrNull!.secretKeys,
        isEmpty,
      );
    },
  );
}
