import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:api_caffeine/core/ui/theme/app_spacing.dart';
import 'package:api_caffeine/core/ui/widgets/code_view.dart';

class ResponseSchemaTab extends StatefulWidget {
  const ResponseSchemaTab({
    super.key,
    required this.enabled,
    required this.source,
    required this.focusNode,
    required this.onEnabled,
    required this.onSource,
  });
  final bool enabled;
  final String source;
  final FocusNode focusNode;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<String> onSource;

  @override
  State<ResponseSchemaTab> createState() => _ResponseSchemaTabState();
}

class _ResponseSchemaTabState extends State<ResponseSchemaTab> {
  late final _editor = CodeLineEditingController.fromText(widget.source);

  @override
  void initState() {
    super.initState();
    _editor.addListener(_changed);
  }

  void _changed() {
    if (_editor.text != widget.source) widget.onSource(_editor.text);
  }

  @override
  void didUpdateWidget(ResponseSchemaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source && widget.source != _editor.text) {
      _editor.text = widget.source;
    }
  }

  @override
  void dispose() {
    _editor.removeListener(_changed);
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        title: const Text(
          'Test schema',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text(
          'Validate the response against JSON Schema',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        value: widget.enabled,
        onChanged: widget.onEnabled,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Semantics(
            label: 'Response JSON schema',
            child: CodeView(
              controller: _editor,
              focusNode: widget.focusNode,
              highlightJson: true,
              hint: 'Enter JSON Schema',
            ),
          ),
        ),
      ),
    ],
  );
}
