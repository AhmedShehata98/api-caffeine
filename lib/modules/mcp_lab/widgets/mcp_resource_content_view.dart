import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:test_point/core/ui/widgets/code_view.dart';

import '../models/mcp_protocol_models.dart';
import '../services/mcp_resource_preview.dart';

class McpResourceContentView extends StatefulWidget {
  const McpResourceContentView({required this.contents, super.key});
  final ResourceContents contents;
  @override
  State<McpResourceContentView> createState() => _McpResourceContentViewState();
}

class _McpResourceContentViewState extends State<McpResourceContentView> {
  final _editor = CodeLineEditingController();
  McpResourcePreview? _preview;
  bool _failed = false;
  bool _expanded = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant McpResourceContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contents != widget.contents) _prepare();
  }

  Future<void> _prepare() async {
    final revision = ++_revision;
    _preview = null;
    _failed = false;
    _expanded = false;
    try {
      final preview = await prepareMcpResourcePreview(widget.contents);
      if (!mounted || revision != _revision) return;
      final text = preview.text ?? '';
      var end = text.length.clamp(0, 256 * 1024);
      if (end > 0 &&
          end < text.length &&
          text.codeUnitAt(end - 1) >= 0xd800 &&
          text.codeUnitAt(end - 1) <= 0xdbff) {
        end--;
      }
      _editor.text = text.substring(0, end);
      setState(() => _preview = preview);
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
    final preview = _preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.contents.uri,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          widget.contents.mimeType ?? 'Unknown MIME type',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        if (_failed)
          const Text('Could not prepare this resource.')
        else if (preview == null)
          const LinearProgressIndicator()
        else ...[
          if (preview.notice != null) Text(preview.notice!),
          if (preview.byteLength != null)
            Text('Binary resource · ${preview.byteLength} bytes', maxLines: 1),
          if (preview.text != null) ...[
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy resource text'),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: widget.contents.text!),
                  ),
                ),
                if (!_expanded && preview.text!.length > _editor.text.length)
                  TextButton(
                    onPressed: () => setState(() {
                      _expanded = true;
                      _editor.text = preview.text!;
                    }),
                    child: const Text('Load full content'),
                  ),
              ],
            ),
            SizedBox(
              height: 240,
              child: CodeView(
                controller: _editor,
                readOnly: true,
                highlightJson: preview.json,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
