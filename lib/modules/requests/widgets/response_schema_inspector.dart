import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:api_caffeine/core/ui/theme/app_fonts.dart';
import 'package:api_caffeine/core/ui/theme/app_spacing.dart';
import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';

String schemaIssuePath(List<Object> segments) {
  final output = StringBuffer(r'$');
  for (final segment in segments) {
    if (segment is int) {
      output.write('[$segment]');
    } else if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$')
        .hasMatch(segment as String)) {
      output.write('.$segment');
    } else {
      output.write('[${jsonEncode(segment)}]');
    }
  }
  return output.toString();
}

class ResponseSchemaInspector extends StatefulWidget {
  const ResponseSchemaInspector({
    super.key,
    required this.result,
    required this.currentSource,
    required this.validUtf8,
    required this.onEdit,
    required this.onIssue,
  });
  final SchemaTestResult? result;
  final String currentSource;
  final bool validUtf8;
  final VoidCallback onEdit;
  final ValueChanged<SchemaIssue> onIssue;

  @override
  State<ResponseSchemaInspector> createState() =>
      _ResponseSchemaInspectorState();
}

class _ResponseSchemaInspectorState extends State<ResponseSchemaInspector> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    if (result == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final status = switch (result.status) {
      SchemaTestStatus.checking => 'Checking schema…',
      SchemaTestStatus.passed => 'Schema passed',
      SchemaTestStatus.failed => 'Schema failed',
      SchemaTestStatus.skipped => 'Skipped · No body expected',
      SchemaTestStatus.invalidSchema => 'Test couldn’t run · Invalid schema',
      SchemaTestStatus.invalidResponse =>
        widget.validUtf8
            ? 'Test couldn’t run · Invalid JSON'
            : 'Test couldn’t run · Invalid UTF-8',
      SchemaTestStatus.incomplete => 'Test couldn’t complete',
    };
    final failed =
        result.status == SchemaTestStatus.failed ||
        result.status == SchemaTestStatus.invalidSchema ||
        result.status == SchemaTestStatus.invalidResponse ||
        result.status == SchemaTestStatus.incomplete;
    final color = failed ? scheme.error : scheme.onSurface;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 300;
                  final actions = <Widget>[
                    if (result.issues.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => expanded = !expanded),
                        child: Text(
                          expanded ? 'Hide issues' : 'Show issues',
                          maxLines: 1,
                        ),
                      ),
                    if (result.status == SchemaTestStatus.invalidSchema ||
                        result.status == SchemaTestStatus.failed)
                      TextButton(
                        onPressed: widget.onEdit,
                        child: const Text('Edit schema', maxLines: 1),
                      ),
                  ];
                  final statusRow = Row(
                    children: [
                      Icon(
                        failed
                            ? Icons.error_outline
                            : result.status == SchemaTestStatus.passed
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 18,
                        color: color,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!compact) ...actions,
                    ],
                  );
                  return compact && actions.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            statusRow,
                            Wrap(children: actions),
                          ],
                        )
                      : statusRow;
                },
              ),
            ),
          ),
          if (result.schemaSource != widget.currentSource)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'Schema changed since this response',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          if (result.incomplete)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'Issue list is incomplete',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          if (expanded && result.issues.isNotEmpty) _issueList(result, scheme),
        ],
      ),
    );
  }

  Widget _issueList(
    SchemaTestResult result,
    ColorScheme scheme,
  ) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 120),
    child: ListView.builder(
      shrinkWrap: true,
      itemCount: result.issues.length,
      itemBuilder: (context, index) {
        final issue = result.issues[index];
        final missing = issue.path.length > issue.anchor.length;
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: () => widget.onIssue(issue),
          leading: Icon(
            Icons.subdirectory_arrow_right,
            size: 18,
            color: scheme.error,
          ),
          title: Text(
            schemaIssuePath(issue.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: AppFonts.mono),
          ),
          subtitle: Text(
            missing
                ? '${issue.condition} · Linked to ${schemaIssuePath(issue.anchor)}'
                : issue.condition,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    ),
  );
}
