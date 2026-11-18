import 'package:flutter/material.dart';
import 'package:test_point/core/error/result.dart';

import '../services/mcp_primitive_services.dart';

/// Field-local, memory-only suggestions. Editing any context argument or
/// changing the session invalidates both visible and pending results.
class McpCompletionTextInput extends StatefulWidget {
  const McpCompletionTextInput({
    required this.name,
    required this.value,
    required this.contextToken,
    required this.sessionToken,
    required this.complete,
    required this.enabled,
    required this.onChanged,
    this.label,
    this.helperText,
    this.errorText,
    this.validator,
    this.maxLength = 4096,
    super.key,
  });
  final String name;
  final String value;
  final Object contextToken;
  final Object? sessionToken;
  final Future<Result<McpCompletion>> Function()? complete;
  final String? label;
  final String? helperText;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  State<McpCompletionTextInput> createState() => _McpCompletionTextInputState();
}

class _McpCompletionTextInputState extends State<McpCompletionTextInput> {
  late final _text = TextEditingController(text: widget.value);
  Result<McpCompletion>? _result;
  bool _loading = false;
  int _revision = 0;

  void _clear() {
    _revision++;
    _loading = false;
    _result = null;
  }

  @override
  void didUpdateWidget(McpCompletionTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextToken != widget.contextToken ||
        !identical(oldWidget.sessionToken, widget.sessionToken) ||
        oldWidget.value != widget.value ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.name != widget.name) {
      _clear();
      final text = widget.value;
      if (_text.text != text) {
        // Updating a controller can notify the enclosing Form. Wait until
        // build completes when a parent replaces a field's external value.
        final revision = _revision;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && revision == _revision && widget.value == text) {
            _setText(text);
          }
        });
      }
    }
  }

  void _setText(String text) {
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _load() async {
    final complete = widget.complete;
    if (complete == null) return;
    final session = widget.sessionToken;
    final context = widget.contextToken;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _result = null;
    });
    final result = await complete();
    if (!mounted ||
        revision != _revision ||
        !widget.enabled ||
        !identical(widget.sessionToken, session) ||
        widget.contextToken != context) {
      return;
    }
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completion = _result?.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _text,
          enabled: widget.enabled,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            labelText: widget.label ?? widget.name,
            helperText: widget.helperText,
            errorText: widget.errorText,
          ),
          validator: widget.validator,
          onChanged: (value) {
            setState(_clear);
            widget.onChanged(value);
          },
        ),
        if (widget.complete != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: !widget.enabled || _loading ? null : _load,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _loading ? 'Loading suggestions…' : 'Suggest ${widget.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_result?.failureOrNull case final failure?) Text(failure.message),
          if (completion != null) ...[
            Text(
              completion.values.isEmpty
                  ? 'No suggestions returned.'
                  : '${completion.values.length} suggestions${completion.total == null ? '' : ' of ${completion.total}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (completion.values.isNotEmpty)
              SizedBox(
                height: (completion.values.length * 48.0).clamp(0, 192),
                child: ListView.builder(
                  itemCount: completion.values.length,
                  itemBuilder: (context, index) {
                    final value = completion.values[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        value.isEmpty ? '(empty text)' : value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: !widget.enabled
                          ? null
                          : () {
                              setState(_clear);
                              _setText(value);
                              widget.onChanged(value);
                            },
                    );
                  },
                ),
              ),
            if (completion.hasMore)
              const Text(
                'More matches are available. Refine the text and request suggestions again.',
              ),
          ],
        ],
      ],
    );
  }
}
