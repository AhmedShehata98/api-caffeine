/// Captured account/workspace generation; never reuse after a boundary change.
class McpAccessContext {
  const McpAccessContext({
    required this.userId,
    required this.workspaceId,
    required this.generation,
  });
  final String userId;
  final String workspaceId;
  final int generation;
}

/// The launcher must execute this exact snapshot after explicit approval.
/// Contains credentials in memory: never log, serialize or persist it.
class McpLaunchSnapshot {
  McpLaunchSnapshot({
    required this.command,
    required this.executable,
    required this.cwd,
    required List<String> args,
    required Map<String, String> environment,
  }) : args = List.unmodifiable(args),
       environment = Map.unmodifiable(environment);
  final String command;
  final String executable;
  final String cwd;
  final List<String> args;
  final Map<String, String> environment;
}

/// Only HMAC digests and field labels may enter preferences.
class McpTrustRecord {
  McpTrustRecord(Map<String, String> fields)
    : fields = Map.unmodifiable(fields);
  final Map<String, String> fields;

  Map<String, dynamic> toJson() => {'version': 1, 'fields': fields};

  factory McpTrustRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['fields'] is! Map) {
      throw const FormatException('Unsupported trust record');
    }
    final fields = Map<String, String>.from(json['fields'] as Map);
    const mandatory = {'command', 'executable', 'cwd', 'args'};
    if (!fields.keys.toSet().containsAll(mandatory) ||
        fields.entries.any(
          (entry) =>
              (!mandatory.contains(entry.key) &&
                  !entry.key.startsWith('env.')) ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.value),
        )) {
      throw const FormatException('Invalid trust record');
    }
    return McpTrustRecord(fields);
  }
}

class McpTrustCheck {
  McpTrustCheck({required this.approved, List<String> changedFields = const []})
    : changedFields = List.unmodifiable(changedFields);
  final bool approved;
  final List<String> changedFields;
}
