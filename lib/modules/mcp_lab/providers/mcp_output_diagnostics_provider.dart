import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_protocol_models.dart';
import '../services/mcp_primitive_services.dart';
import '../services/mcp_output_diagnostics.dart';

final mcpOutputDiagnosticsProvider = FutureProvider.autoDispose
    .family<McpOutputDiagnostics, ({McpTool tool, McpToolCall call})>(
      (ref, value) => diagnoseMcpOutput(
        value.tool.outputSchema,
        value.call.result.structuredContent,
        present: value.call.raw.containsKey('structuredContent'),
        complete: value.call.result.resultType == ToolResultType.complete,
      ),
      retry: (_, _) => null,
    );
