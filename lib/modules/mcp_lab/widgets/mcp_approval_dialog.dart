import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mcp_session_providers.dart';
import '../services/mcp_connect_service.dart';
import '../services/mcp_approval_summary.dart';

/// null means declined; false approves once; true requests remembered approval.
Future<bool?> showMcpApprovalDialog(
  BuildContext context,
  McpNeedsApproval ticket,
) => showDialog<bool>(context: context, builder: (_) => _Approval(ticket));

class _Approval extends ConsumerStatefulWidget {
  const _Approval(this.ticket);
  final McpNeedsApproval ticket;
  @override
  ConsumerState<_Approval> createState() => _ApprovalState();
}

class _ApprovalState extends ConsumerState<_Approval> {
  bool _remember = false;
  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final summary = McpApprovalSummary(ticket);
    ref.listen(mcpSessionsProvider, (_, _) {
      if (!ref
              .read(mcpSessionOwnerProvider)
              .isAuthorized(ticket.target.context, ticket.target.server.id) &&
          mounted) {
        Navigator.pop(context);
      }
    });
    return AlertDialog(
      title: const Text('Allow local server launch?'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This program will run on your device with the arguments and environment keys below. Only approve a server you trust.',
              ),
              const SizedBox(height: 16),
              for (final field in [
                ('Executable', summary.executable),
                ('Arguments', summary.arguments),
                ('Working directory', summary.directory),
                ('Environment keys', summary.environmentKeys.join(', ')),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.$1,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SelectableText(field.$2),
                    ],
                  ),
                ),
              if (ticket.changedFields.isNotEmpty)
                Text(
                  'Changed since last approval: ${ticket.changedFields.join(', ')}',
                ),
              if (ticket.storageFailure != null)
                const Text(
                  'Device storage is unavailable. You can approve this launch once.',
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _remember,
                onChanged: ticket.storageFailure == null
                    ? (value) => setState(() => _remember = value ?? false)
                    : null,
                title: const Text(
                  'Remember on this device',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _remember),
          child: const Text('Approve and connect'),
        ),
      ],
    );
  }
}
