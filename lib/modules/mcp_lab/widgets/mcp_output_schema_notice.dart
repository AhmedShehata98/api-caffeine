import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/ui/theme/http_colors.dart';

import '../models/mcp_protocol_models.dart';
import '../services/mcp_primitive_services.dart';
import '../services/mcp_output_diagnostics.dart';
import '../providers/mcp_output_diagnostics_provider.dart';

class McpOutputSchemaNotice extends ConsumerWidget {
  const McpOutputSchemaNotice({
    required this.tool,
    required this.call,
    super.key,
  });
  final McpTool tool;
  final McpToolCall call;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostic = ref.watch(
      mcpOutputDiagnosticsProvider((tool: tool, call: call)),
    );
    if (diagnostic.isLoading) return const Text('Checking output schema…');
    if (diagnostic.hasError) {
      return const Text(
        'Output schema check unavailable. The call result is unchanged.',
      );
    }
    final value = diagnostic.requireValue;
    final warning =
        value.status == McpOutputStatus.missing ||
        value.status == McpOutputStatus.invalid;
    final color = warning
        ? Theme.of(context).extension<HttpColors>()?.status4xx
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            value.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
          for (final entry in value.fields.entries.take(20))
            Text(
              '${entry.key}: ${entry.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (value.fields.length > 20)
            Text(
              '${value.fields.length - 20} more schema findings.',
              maxLines: 1,
            ),
        ],
      ),
    );
  }
}
