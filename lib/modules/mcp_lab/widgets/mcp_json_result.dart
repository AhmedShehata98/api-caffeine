import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:test_point/core/ui/widgets/code_view.dart';

// Keep the isolate closure outside State: closures in a State method may also
// capture its native editor controller through a shared closure context.
Future<String> _formatResultJson(Object? value) =>
    Isolate.run(() => const JsonEncoder.withIndent('  ').convert(value));

/// Formatting an explicitly viewed operation result stays off the UI isolate.
class McpJsonResult extends StatefulWidget {
  const McpJsonResult({required this.value, super.key});
  final Object? value;
  @override
  State<McpJsonResult> createState() => _McpJsonResultState();
}

class _McpJsonResultState extends State<McpJsonResult> {
  final _editor = CodeLineEditingController();
  String? _full;
  bool _expanded = false;
  bool _failed = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _format();
  }

  @override
  void didUpdateWidget(covariant McpJsonResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.value, oldWidget.value)) _format();
  }

  Future<void> _format() async {
    final revision = ++_revision;
    final value = widget.value;
    _full = null;
    _failed = false;
    _expanded = false;
    try {
      final text = await _formatResultJson(value);
      if (!mounted || revision != _revision) return;
      _full = text;
      var end = text.length.clamp(0, 256 * 1024);
      if (end > 0 &&
          end < text.length &&
          text.codeUnitAt(end - 1) >= 0xd800 &&
          text.codeUnitAt(end - 1) <= 0xdbff) {
        end--;
      }
      _editor.text = text.substring(0, end);
      setState(() {});
    } on Object {
      if (mounted && revision == _revision) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Text('Could not format this result.');
    if (_full == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: _full!)),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy result JSON'),
            ),
            if (!_expanded && _full!.length > _editor.text.length)
              TextButton(
                onPressed: () => setState(() {
                  _expanded = true;
                  _editor.text = _full!;
                }),
                child: const Text('Load full result'),
              ),
          ],
        ),
        SizedBox(
          height: 240,
          child: CodeView(
            controller: _editor,
            readOnly: true,
            highlightJson: true,
          ),
        ),
      ],
    );
  }
}
