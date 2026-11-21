import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_diagnostic_sanitizer.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_error_mapper.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_proxy.dart';

void main() {
  group('diagnostic boundary', () {
    test(
      'multiline credentials remain protected in individual stderr lines',
      () {
        final sanitizer = McpDiagnosticSanitizer(
          secretValues: ['first-private-line\nsecond-private-line'],
        );
        expect(sanitizer.text('first-private-line'), '[REDACTED]');
        expect(sanitizer.text('second-private-line'), '[REDACTED]');
      },
    );
    test('preserves unredacted wire formatting and extension fields', () {
      final sanitizer = McpDiagnosticSanitizer();
      const wire = ' { "jsonrpc":"2.0", "id":1, "result":{}, "x-extra":true } ';
      expect(sanitizer.frame(wire), (text: wire, redacted: false));
    });
    test(
      'redacts nested and encoded known secrets without mutating results',
      () {
        const secret = 'canary+private/value';
        final sanitizer = McpDiagnosticSanitizer(secretValues: [secret, '']);
        final original = {
          'result': {
            'content': [
              {'text': '$secret ${Uri.encodeComponent(secret)}'},
            ],
          },
        };
        final frame = sanitizer.frame(jsonEncode(original));
        expect(frame.redacted, isTrue);
        expect(frame.text, isNot(contains(secret)));
        expect(frame.text, isNot(contains(Uri.encodeComponent(secret))));
        expect(
          (original['result']!['content'] as List).first['text'],
          contains(secret),
        );
        expect(
          jsonDecode(frame.text)['result']['content'][0]['text'],
          contains('[REDACTED]'),
        );
        expect(
          sanitizer.text(Uri.encodeComponent(secret).replaceAll('%2F', '%2f')),
          '[REDACTED]',
        );
      },
    );
    test(
      'redacts credential query parameters including encoded parameter names',
      () {
        final sanitizer = McpDiagnosticSanitizer();
        final value = sanitizer.text(
          'https://example.test/?access%5Ftoken=unknown-token&CODE=unknown-code&safe=visible',
        );
        expect(value, isNot(contains('unknown-')));
        expect(value, contains('safe=visible'));
      },
    );
    test(
      'learns authorization and cookie credentials before sanitizing echoes',
      () {
        final sanitizer = McpDiagnosticSanitizer(
          headers: {
            'Authorization': ['Bearer bearer-canary'],
            'Cookie': ['a=cookie-canary; b=another-canary'],
          },
        );
        final clean = sanitizer.headers({
          'Set-Cookie': ['session=response-canary; Path=/'],
          'X-Team': ['visible'],
        });
        expect(clean['Set-Cookie'], ['[REDACTED]']);
        expect(clean['X-Team'], ['visible']);
        expect(
          sanitizer.text(
            'bearer-canary cookie-canary another-canary response-canary',
          ),
          '[REDACTED] [REDACTED] [REDACTED] [REDACTED]',
        );
        expect(
          sanitizer.text('https://example.test/path'),
          'https://example.test/path',
        );
      },
    );
    test('discovers JSON header secrets before earlier sibling echoes', () {
      final sanitizer = McpDiagnosticSanitizer();
      final clean = sanitizer.json({
        'echo': 'unknown-canary',
        'headers': {'X-Custom-Token': 'unknown-canary'},
      });
      expect(jsonEncode(clean), isNot(contains('unknown-canary')));
    });
    test('malformed JSON and stderr header lines are sanitized warnings', () {
      final sanitizer = McpDiagnosticSanitizer();
      expect(
        sanitizer.frame('{"Authorization":"unknown-canary", broken').text,
        isNot(contains('unknown-canary')),
      );
      expect(
        sanitizer.text('failure\nAuthorization: Bearer unknown-canary\nnext'),
        'failure\nAuthorization: [REDACTED]\nnext',
      );
    });
    test(
      'overlapping and short secrets do not corrupt the redaction marker',
      () {
        final sanitizer = McpDiagnosticSanitizer(
          secretValues: ['canary', 'canary-long', 'a'],
        );
        expect(sanitizer.text('canary-long canary'), '[REDACTED] [REDACTED]');
      },
    );
    test(
      'clears retained credentials and rejects use after session disposal',
      () {
        final sanitizer = McpDiagnosticSanitizer(secretValues: ['canary']);
        sanitizer.dispose();
        expect(() => sanitizer.text('canary'), throwsStateError);
        expect(() => sanitizer.frame('{}'), throwsStateError);
        expect(() => sanitizer.addSecrets(['new']), throwsStateError);
      },
    );
  });

  group('proxy precedence', () {
    final target = Uri.parse('https://api.example.test/mcp');
    test('Settings wins over environment and disabled Settings falls back', () {
      const env = {'HTTPS_PROXY': 'http://environment.test:8080'};
      expect(
        resolveMcpProxy(
          target,
          'http://settings.test:8081',
          env,
        ).valueOrNull!.host,
        'settings.test',
      );
      expect(
        resolveMcpProxy(target, null, env).valueOrNull!.host,
        'environment.test',
      );
      expect(
        resolveMcpProxy(Uri.parse('http://api.test'), null, {
          'HTTP_PROXY': 'http://http-proxy.test',
        }).valueOrNull!.host,
        'http-proxy.test',
      );
    });
    test('loopback and NO_PROXY bypass Settings as well as environment', () {
      for (final url in [
        'http://localhost/mcp',
        'http://127.0.0.1/mcp',
        'http://[::1]/mcp',
      ]) {
        final result = resolveMcpProxy(Uri.parse(url), 'http://proxy.test', {});
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      }
      expect(
        resolveMcpProxy(target, 'http://proxy.test', {
          'NO_PROXY': '.example.test',
        }).valueOrNull,
        isNull,
      );
    });
    test('NO_PROXY matches domain boundaries and optional ports', () {
      const proxy = 'http://proxy.test';
      expect(
        resolveMcpProxy(Uri.parse('https://notexample.test'), proxy, {
          'NO_PROXY': 'example.test',
        }).valueOrNull,
        isNotNull,
      );
      expect(
        resolveMcpProxy(target, proxy, {
          'NO_PROXY': 'api.example.test:8443',
        }).valueOrNull,
        isNotNull,
      );
      expect(
        resolveMcpProxy(target, proxy, {
          'NO_PROXY': 'api.example.test:443',
        }).valueOrNull,
        isNull,
      );
      expect(
        resolveMcpProxy(target, proxy, {'NO_PROXY': '*'}).valueOrNull,
        isNull,
      );
    });
    test(
      'NO_PROXY supports literal networks and lowercase environment names',
      () {
        expect(
          resolveMcpProxy(Uri.parse('http://10.1.2.3'), 'http://proxy.test', {
            'no_proxy': '10.0.0.0/8',
          }).valueOrNull,
          isNull,
        );
        expect(
          resolveMcpProxy(
            Uri.parse('http://[2001:db8::1]'),
            'http://proxy.test',
            {'NO_PROXY': '2001:db8::/32'},
          ).valueOrNull,
          isNull,
        );
        expect(
          resolveMcpProxy(target, null, {
            'https_proxy': 'http://lowercase.test',
          }).valueOrNull!.host,
          'lowercase.test',
        );
      },
    );
    test(
      'invalid proxy configurations fail rather than silently bypassing',
      () {
        expect(
          resolveMcpProxy(target, 'socks://proxy.test', {}).failureOrNull,
          isA<McpValidationFailure>(),
        );
      },
    );
  });

  group('failure mapping', () {
    late McpDiagnosticSanitizer sanitizer;
    late McpErrorMapper mapper;
    setUp(() {
      sanitizer = McpDiagnosticSanitizer(secretValues: ['canary']);
      mapper = McpErrorMapper(sanitizer);
    });
    test('maps tool and resource errors without exposing server messages', () {
      expect(
        (mapper.rpc(
          -32602,
          'Unknown tool canary',
        ) as McpValidationFailure).code,
        McpErrorCode.toolNotFound,
      );
      expect(
        (mapper.rpc(
          -32602,
          'Invalid input canary',
        ) as McpValidationFailure).code,
        McpErrorCode.invalidParams,
      );
      expect(
        mapper.rpc(-32002, 'canary', method: 'resources/read').message,
        'Resource not found.',
      );
      expect(
        mapper.rpc(-32602, 'Unknown tool canary').message,
        isNot(contains('canary')),
      );
    });
    test(
      'retains sanitized version metadata and modern error distinctions',
      () {
        expect(
          (mapper.rpc(-32020, '') as McpCoded).code,
          McpErrorCode.headerMismatch,
        );
        expect(
          (mapper.rpc(-32021, '') as McpCoded).code,
          McpErrorCode.missingCapability,
        );
        final failure = mapper.rpc(
          -32022,
          'canary',
          data: {
            'supported': ['2026-07-28', 'canary', 42],
          },
        ) as McpNetworkFailure;
        expect(failure.code, McpErrorCode.protocolVersionUnsupported);
        expect(failure.supportedVersions, ['2026-07-28', '[REDACTED]']);
      },
    );
    test('maps auth, rate limits and expired sessions', () {
      expect(mapper.http(401), isA<McpAuthFailure>());
      expect(mapper.http(403), isA<McpAuthFailure>());
      expect(
        (mapper.http(429, retryAfter: '12') as McpNetworkFailure).retryAfter,
        const Duration(seconds: 12),
      );
      final now = DateTime.utc(2026, 11, 16);
      expect(
        (mapper.http(
          429,
          retryAfter: HttpDate.format(now.add(const Duration(seconds: 30))),
          now: now,
        ) as McpNetworkFailure).retryAfter,
        const Duration(seconds: 30),
      );
      expect(
        (mapper.http(
          429,
          retryAfter: 'invalid',
        ) as McpNetworkFailure).retryAfter,
        isNull,
      );
      expect(mapper.http(404).message, contains('Reconnect'));
    });
    test(
      'malformed frames remain warnings and transport failures are safe',
      () {
        expect(mapper.exception(const FormatException('canary')), isNull);
        for (final error in [
          const SocketException('canary'),
          const ProcessException('canary', []),
          TimeoutException('canary'),
          DioException(requestOptions: RequestOptions(path: 'canary')),
        ]) {
          final failure = mapper.exception(error)!;
          expect(failure, isA<McpNetworkFailure>());
          expect(failure.message, isNot(contains('canary')));
        }
        expect(
          mapper.exception(StateError('canary')),
          isA<UnexpectedFailure>(),
        );
      },
    );
    test('sanitizes process stderr before retaining a bounded tail', () {
      final failure = mapper.processExited(7, '${'prefix ' * 2000}canary');
      expect(failure.code, McpErrorCode.processExited);
      expect(failure.exitCode, 7);
      expect(failure.stderrTail!.length, lessThanOrEqualTo(8192));
      expect(failure.stderrTail, isNot(contains('canary')));
    });
  });

  test(
    'connection targets reject workspace mismatches and unresolved stdio',
    () {
      const context = McpAccessContext(
        userId: 'user',
        workspaceId: 'workspace',
        generation: 1,
      );
      const server = McpServer(
        id: 'server',
        workspaceId: 'workspace',
        draft: McpServerDraft(
          name: 'Fixture',
          transport: McpTransport.stdio,
          command: 'dart',
        ),
      );
      expect(
        () => McpConnectTarget(
          context: context,
          server: server,
          timeout: const Duration(seconds: 5),
        ),
        throwsArgumentError,
      );
      final launch = McpLaunchSnapshot(
        command: 'dart',
        executable: '/sdk/dart',
        cwd: '/workspace',
        args: [],
        environment: {},
      );
      expect(
        () => McpConnectTarget(
          context: context,
          server: server.copyWith(workspaceId: 'other'),
          launch: launch,
          timeout: const Duration(seconds: 5),
        ),
        throwsArgumentError,
      );
      expect(
        McpConnectTarget(
          context: context,
          server: server,
          launch: launch,
          timeout: const Duration(seconds: 5),
        ).launch,
        same(launch),
      );
    },
  );
}
