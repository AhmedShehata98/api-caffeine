import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:api_caffeine/core/ui/widgets/code_view.dart';

import '../models/mcp_protocol_models.dart';
import '../services/mcp_resource_preview.dart';
import '../providers/mcp_resource_export_provider.dart';
import '../services/mcp_content_presentation.dart';

class McpResourceContentView extends ConsumerStatefulWidget {
  const McpResourceContentView({
    required this.contents,
    required this.serverId,
    this.origin = McpContentOrigin.resource,
    this.block,
    this.label,
    super.key,
  });
  final ResourceContents contents;
  final String serverId;
  final McpContentOrigin origin;
  final ContentBlock? block;
  final String? label;
  @override
  ConsumerState<McpResourceContentView> createState() =>
      _McpResourceContentViewState();
}

class _McpResourceContentViewState
    extends ConsumerState<McpResourceContentView> {
  final _editor = CodeLineEditingController();
  McpResourcePreview? _preview;
  bool _failed = false;
  bool _expanded = false;
  int _revision = 0;
  ImageProvider? _image;
  bool _saving = false;
  String? _saveMessage;
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
    _saveMessage = null;
    _saving = false;
    final oldImage = _image;
    _image = null;
    if (oldImage != null) unawaited(oldImage.evict());
    try {
      final preview = await prepareMcpResourcePreview(widget.contents);
      if (!mounted || revision != _revision) return;
      if (preview.imageBytes case final bytes?) {
        _image = ResizeImage(
          MemoryImage(bytes),
          width: 1024,
          height: 1024,
          policy: ResizeImagePolicy.fit,
        );
      }
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
    if (_image case final image?) unawaited(image.evict());
    super.dispose();
  }

  Future<void> _save(McpResourceExportActions exporter) async {
    final revision = _revision;
    setState(() {
      _saving = true;
      _saveMessage = null;
    });
    final result = await exporter.save(
      widget.contents,
      origin: widget.origin,
      block: widget.block,
    );
    if (!mounted || revision != _revision) return;
    setState(() {
      _saving = false;
      _saveMessage = result.when(
        success: (saved) => saved ? 'Resource saved.' : null,
        failure: (failure) => failure.message,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final exporter = ref.watch(mcpResourceExportProvider(widget.serverId));
    final preview = _preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label ?? widget.contents.uri,
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
          if (preview.byteLength != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : () => _save(exporter),
                icon: const Icon(Icons.save_alt),
                label: Text(
                  _saving ? 'Saving resource…' : 'Save resource',
                  maxLines: 1,
                ),
              ),
            ),
          if (_saveMessage case final message?) Text(message),
          if (_image case final image?)
            SizedBox(
              height: 240,
              child: Image(
                image: image,
                fit: BoxFit.contain,
                semanticLabel: 'Image resource preview',
                frameBuilder: (context, child, frame, synchronous) =>
                    synchronous || frame != null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'Could not display this image. You can still save the original resource.',
                  ),
                ),
              ),
            ),
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
