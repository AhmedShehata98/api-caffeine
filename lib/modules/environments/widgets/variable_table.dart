import 'package:flutter/material.dart';
import 'package:test_point/core/ui/theme/app_fonts.dart';
import 'package:test_point/core/ui/theme/app_spacing.dart';
import 'package:test_point/modules/environments/models/environment_variable.dart';

/// Key / value / secret / enabled table. Secret values are masked.
class VariableTable extends StatelessWidget {
  const VariableTable({
    required this.variables,
    required this.onChanged,
    super.key,
  });

  final List<EnvironmentVariable> variables;
  final ValueChanged<List<EnvironmentVariable>> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        for (var i = 0; i < variables.length; i++)
          _VariableRow(
            key: ValueKey(i),
            variable: variables[i],
            onChanged: (v) => onChanged([...variables]..[i] = v),
            onDelete: () => onChanged([...variables]..removeAt(i)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                onChanged([...variables, const EnvironmentVariable()]),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add variable'),
          ),
        ),
      ],
    );
  }
}

class _VariableRow extends StatefulWidget {
  const _VariableRow({
    required this.variable,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  final EnvironmentVariable variable;
  final ValueChanged<EnvironmentVariable> onChanged;
  final VoidCallback onDelete;

  @override
  State<_VariableRow> createState() => _VariableRowState();
}

class _VariableRowState extends State<_VariableRow> {
  late final _key = TextEditingController(text: widget.variable.key);
  late final _value = TextEditingController(text: widget.variable.value);
  bool _revealed = false;

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    super.dispose();
  }

  /// Secret values stay on this device; turning the flag off syncs the
  /// value as plain text, so that direction asks first.
  Future<void> _toggleSecret() async {
    final variable = widget.variable;
    if (variable.secret && variable.value.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stop keeping this value secret?'),
          content: const Text(
            'The value will be saved to your workspace in plain text and '
            'shown to everyone who can open this environment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Make public'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _revealed = false);
    widget.onChanged(
      variable.copyWith(secret: !variable.secret, missingOnDevice: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variable = widget.variable;
    const mono = TextStyle(fontFamily: AppFonts.mono, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Checkbox(
            value: variable.enabled,
            onChanged: (v) =>
                widget.onChanged(variable.copyWith(enabled: v ?? true)),
          ),
          Expanded(
            child: TextField(
              controller: _key,
              style: mono,
              decoration: const InputDecoration(hintText: 'Key', isDense: true),
              onChanged: (v) => widget.onChanged(variable.copyWith(key: v)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _value,
              style: mono,
              obscureText: variable.secret && !_revealed,
              decoration: InputDecoration(
                hintText: variable.missingOnDevice
                    ? 'Not set on this device'
                    : 'Value',
                isDense: true,
                suffixIcon: variable.secret
                    ? IconButton(
                        tooltip: _revealed ? 'Hide value' : 'Show value',
                        iconSize: 18,
                        onPressed: () => setState(() => _revealed = !_revealed),
                        icon: Icon(
                          _revealed
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      )
                    : null,
              ),
              onChanged: (v) => widget.onChanged(
                variable.copyWith(value: v, missingOnDevice: false),
              ),
            ),
          ),
          IconButton(
            tooltip: variable.secret ? 'Secret (on)' : 'Secret (off)',
            iconSize: 18,
            isSelected: variable.secret,
            onPressed: _toggleSecret,
            icon: const Icon(Icons.lock_open_outlined),
            selectedIcon: const Icon(Icons.lock_outline),
          ),
          IconButton(
            tooltip: 'Delete',
            iconSize: 18,
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
