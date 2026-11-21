import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/settings/providers/settings_providers.dart';

class McpLabPreferences {
  const McpLabPreferences({
    this.monitorPinned = false,
    this.confirmDestructiveTools = true,
    this.sidebarRatio = 0.25,
    this.rawToolEditor = false,
  });
  final bool monitorPinned;
  final bool confirmDestructiveTools;
  final double sidebarRatio;
  final bool rawToolEditor;
  McpLabPreferences copyWith({
    bool? monitorPinned,
    bool? confirmDestructiveTools,
    double? sidebarRatio,
    bool? rawToolEditor,
  }) => McpLabPreferences(
    monitorPinned: monitorPinned ?? this.monitorPinned,
    confirmDestructiveTools:
        confirmDestructiveTools ?? this.confirmDestructiveTools,
    sidebarRatio: sidebarRatio ?? this.sidebarRatio,
    rawToolEditor: rawToolEditor ?? this.rawToolEditor,
  );
}

final mcpLabPreferencesProvider =
    NotifierProvider<McpLabPreferencesNotifier, McpLabPreferences>(
      McpLabPreferencesNotifier.new,
    );

class McpLabPreferencesNotifier extends Notifier<McpLabPreferences> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  static const _pinKey = 'mcp-lab.monitor-pinned.v1';
  static const _confirmKey = 'mcp-lab.confirm-destructive-tools.v1';
  static const _sidebarKey = 'mcp-lab.sidebar-ratio.v1';
  static const _toolEditorKey = 'mcp-lab.tool-editor-json.v1';

  @override
  McpLabPreferences build() => McpLabPreferences(
    monitorPinned: _prefs.getBool(_pinKey) ?? false,
    confirmDestructiveTools: _prefs.getBool(_confirmKey) ?? true,
    sidebarRatio: (_prefs.getDouble(_sidebarKey) ?? 0.25).clamp(0.2, 0.55),
    rawToolEditor: _prefs.getBool(_toolEditorKey) ?? false,
  );

  Future<Result<void>> _set(
    String key,
    bool value,
    McpLabPreferences next,
  ) async {
    try {
      final saved = await _prefs.setBool(key, value);
      if (!saved) {
        return const Result.failure(
          StorageFailure('Could not save MCP Lab preferences.'),
        );
      }
      state = next;
      return const Result.success(null);
    } on Object {
      return const Result.failure(
        StorageFailure('Could not save MCP Lab preferences.'),
      );
    }
  }

  Future<Result<void>> setMonitorPinned(bool value) =>
      _set(_pinKey, value, state.copyWith(monitorPinned: value));
  Future<Result<void>> setConfirmDestructiveTools(bool value) =>
      _set(_confirmKey, value, state.copyWith(confirmDestructiveTools: value));
  Future<Result<void>> setRawToolEditor(bool value) =>
      _set(_toolEditorKey, value, state.copyWith(rawToolEditor: value));

  Future<Result<void>> setSidebarRatio(double value) {
    final ratio = value.clamp(0.2, 0.55);
    return _setDouble(_sidebarKey, ratio, state.copyWith(sidebarRatio: ratio));
  }

  Future<Result<void>> _setDouble(
    String key,
    double value,
    McpLabPreferences next,
  ) async {
    try {
      final saved = await _prefs.setDouble(key, value);
      if (!saved) {
        return const Result.failure(
          StorageFailure('Could not save MCP Lab preferences.'),
        );
      }
      state = next;
      return const Result.success(null);
    } on Object {
      return const Result.failure(
        StorageFailure('Could not save MCP Lab preferences.'),
      );
    }
  }
}
