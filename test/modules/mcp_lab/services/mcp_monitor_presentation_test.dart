import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_diagnostic_sanitizer.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_monitor_presentation.dart';

void main() {
  McpMonitorEntry entry(
    int index, {
    RpcFrameKind kind = RpcFrameKind.request,
    RpcDirection direction = RpcDirection.outgoing,
    Object id = 1,
    String? method = 'tools/call',
  }) => McpMonitorEntry(
    sequence: index,
    text: '{"secretResult":"not searchable"}',
    size: 1,
    truncated: false,
    frame: RpcFrame(
      direction: direction,
      timestamp: DateTime.utc(2026),
      kind: kind,
      id: id,
      method: method,
      rawJson: '{}',
      size: 2,
    ),
  );
  test('filters metadata, direction and kind while keeping capture order', () {
    final entries = [
      entry(0),
      entry(
        1,
        kind: RpcFrameKind.response,
        direction: RpcDirection.incoming,
        method: null,
      ),
      entry(2, kind: RpcFrameKind.notification),
    ];
    expect(
      filterMcpMonitorEntries(entries, query: 'TOOLS/').map((e) => e.sequence),
      [0, 2],
    );
    expect(
      filterMcpMonitorEntries(
        entries,
        direction: RpcDirection.incoming,
      ).single.sequence,
      1,
    );
    expect(
      filterMcpMonitorEntries(
        entries,
        kind: RpcFrameKind.notification,
      ).single.sequence,
      2,
    );
    expect(filterMcpMonitorEntries(entries, query: 'secretResult'), isEmpty);
    expect(identical(filterMcpMonitorEntries(entries), entries), isTrue);
  });
  test('ids retain types and console titles use bounded first lines', () {
    expect(mcpMonitorTitle(entry(0, id: '1')), contains('id "1"'));
    expect(mcpMonitorTitle(entry(0)), contains('id 1'));
    expect(
      mcpMonitorTitle(
        const McpMonitorEntry(
          sequence: 1,
          text: 'first\nsecond',
          size: 12,
          truncated: false,
        ),
      ),
      'first',
    );
    expect(
      mcpMonitorTitle(
        McpMonitorEntry(
          sequence: 1,
          text: 'x' * 100000,
          size: 100000,
          truncated: false,
        ),
      ).length,
      1024,
    );
  });
  test('sentinel header display is decoded only after diagnostic sanitization', () {
    final sanitizer = McpDiagnosticSanitizer(secretValues: ['canary']);
    final wire =
        '=?base64?${base64Encode(utf8.encode('{"path":"prefix canary suffix","authorization":"private"}'))}?=';
    final clean = sanitizer.headers({
      'Mcp-Param-Echo': [
        '=?base64?${base64Encode(utf8.encode('echo private'))}?=',
      ],
      'Mcp-Param-Data': [wire],
      'Authorization': ['Bearer canary'],
    });
    final displayed = mcpDiagnosticHeaderDisplay(
      clean['Mcp-Param-Data']!.single,
    );
    expect(displayed, isNot(contains('canary')));
    expect(displayed, isNot(contains('private')));
    expect(displayed, contains('[REDACTED]'));
    expect(
      mcpDiagnosticHeaderDisplay(clean['Mcp-Param-Echo']!.single),
      'echo [REDACTED]',
    );
    expect(clean['Authorization'], ['[REDACTED]']);
    expect(mcpDiagnosticHeaderDisplay('=?base64?***?='), '=?base64?***?=');
  });
}
