import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_resource_export_repository.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_stdio_connection_repository.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_stdio_launcher.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_diagnostic_buffer.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_resource_export_service.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_resource_preview.dart';

import '../../fixtures/mcp/binary_payload.dart';
import '../../fixtures/mcp/http_peer.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class _FileExport implements McpResourceExportRepository {
  _FileExport(this.file);
  final File file;
  @override
  Future<Result<bool>> save(Uint8List bytes, String name, String mime) async {
    check(bytes.length == fixtureBinarySize, 'Decoded binary size changed');
    for (var index = 0; index < bytes.length; index++) {
      final expected = index == 0
          ? 85
          : index == bytes.length ~/ 2
          ? 127
          : index == bytes.length - 1
          ? 170
          : 0;
      check(bytes[index] == expected, 'Decoded binary content changed');
    }
    check(
      name == 'resource.bin' && mime == 'application/octet-stream',
      'Export metadata changed',
    );
    await file.writeAsBytes(bytes, flush: true);
    final savedDigest = await sha256.bind(file.openRead()).single;
    check(savedDigest == sha256.convert(bytes), 'Saved file content changed');
    return const Result.success(true);
  }
}

Future<void> main() async {
  const context = McpAccessContext(
    userId: 'u',
    workspaceId: 'w',
    generation: 1,
  );
  final output = File('.dart_tool/mcp_large_payload.bin');
  for (final mode in ['stdio', 'json', 'sse']) {
    final peer = mode == 'stdio' ? null : await McpHttpPeer.start();
    if (peer != null) peer.sse = mode == 'sse';
    final launcher = McpStdioLauncher();
    final launch = mode == 'stdio'
        ? (await launcher.resolve(
            command: Platform.resolvedExecutable,
            args: [File('test/fixtures/mcp/stdio_peer.dart').absolute.path],
            environment: const {},
            inheritedEnvironment: Platform.environment,
          )).valueOrNull!
        : null;
    final draft = mode == 'stdio'
        ? McpServerDraft(
            name: mode,
            transport: McpTransport.stdio,
            command: launch!.command,
          )
        : McpServerDraft(
            name: mode,
            transport: McpTransport.http,
            url: peer!.url.toString(),
          );
    final McpConnectionRepository repository = mode == 'stdio'
        ? McpStdioConnectionRepository(
            launcher,
            isAuthorized: (_, _) => true,
            clientVersion: 'test',
          )
        : McpHttpConnectionRepository(
            isAuthorized: (_, _) => true,
            clientVersion: 'test',
          );
    final opened = await repository.connect(
      McpConnectTarget(
        context: context,
        server: McpServer(id: mode, workspaceId: 'w', draft: draft),
        launch: launch,
        timeout: const Duration(seconds: 60),
      ),
    );
    check(opened.isSuccess, '$mode session failed to open');
    final session = opened.valueOrNull!;
    final protocol = McpDiagnosticBuffer();
    final network = McpDiagnosticBuffer();
    final frames = session.frames.listen(protocol.addFrame);
    final entries = session.network.listen(network.addNetwork);
    try {
      final negotiated = await const McpNegotiationService(
        clientVersion: 'test',
      ).negotiate(session, era: McpProtocolEra.legacy);
      check(negotiated.isSuccess, '$mode negotiation failed');
      final response = await session.request('tools/call', {
        'name': 'binary-20-mib',
        'arguments': <String, dynamic>{},
      });
      check(
        response.isSuccess,
        '$mode 20 MiB response failed: ${response.failureOrNull?.message}',
      );
      final block =
          ToolCallResult.fromJson(response.valueOrNull!).content.single
              as EmbeddedResourceBlock;
      final preview = await prepareMcpResourcePreview(block.resource);
      check(
        preview.byteLength == fixtureBinarySize &&
            preview.imageBytes == null &&
            preview.text == null,
        '$mode large binary was decoded inline or lost its size',
      );
      final saved = await McpResourceExportService(_FileExport(output))
          .save(block.resource, isCurrent: () => true);
      check(
        saved.valueOrNull == true && await output.length() == fixtureBinarySize,
        '$mode binary save failed',
      );
      // The response frame is fully retained in protocol diagnostics, but its
      // preview is bounded. Network retention intentionally remains 16 MiB.
      final captured = protocol.entries.lastWhere(
        (entry) => entry.frame?.kind == RpcFrameKind.response,
      );
      check(
        captured.size > 26 * 1024 * 1024 && captured.text.length <= 256 * 1024,
        '$mode protocol preview or full-frame retention failed',
      );
      if (peer != null) {
        final capture = network.entries.last;
        check(
          !capture.fullAvailable &&
              capture.truncated &&
              capture.size <= 16 * 1024 * 1024,
          '$mode network partial capture was misrepresented',
        );
        check(
          !(await network.loadFullJson(capture.sequence)).isSuccess,
          '$mode partial network body allowed Load full',
        );
      }
      protocol.clear();
      network.clear();
      check(
        protocol.retainedBodyBytes == 0 && network.retainedBodyBytes == 0,
        '$mode clear retained large bodies',
      );
      if (mode == 'stdio') {
        final oversized = await session.request('tools/call', {
          'name': 'oversized-frame',
        });
        check(!oversized.isSuccess, 'Stdio accepted a frame over 32 MiB');
        check(
          !(await session.request('tools/call', {'name': 'echo'})).isSuccess,
          'Stdio continued after a framing overflow',
        );
      }
      stdout.writeln(
        'PASS: $mode 20 MiB binary transport, bounded diagnostics, metadata preview and byte-exact Save',
      );
    } finally {
      await session.close();
      await frames.cancel();
      await entries.cancel();
      protocol.dispose();
      network.dispose();
      await peer?.close();
      if (await output.exists()) await output.delete();
    }
  }
}
