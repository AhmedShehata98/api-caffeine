import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:api_caffeine/core/database/supabase_failure_mapper.dart';
import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_server.dart';
import 'mcp_server_repository.dart';
import 'mcp_server_row.dart';

class McpServerRepositoryImpl implements McpServerRepository {
  McpServerRepositoryImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<Result<List<McpServer>>> list(String workspaceId) async {
    try {
      final rows = await _client
          .from('mcp_servers')
          .select()
          .eq('workspace_id', workspaceId)
          .order('position', nullsFirst: false)
          .order('created_at')
          .order('id');
      return Result.success(rows.map(mcpServerFromRow).toList());
    } on Object catch (error) {
      return Result.failure(mapSupabaseError(error));
    }
  }

  @override
  Future<Result<McpServer>> create({
    required String workspaceId,
    required McpServerDraft draft,
    int? position,
  }) async {
    try {
      final row = await _client
          .from('mcp_servers')
          .insert({
            ...mcpServerValues(draft),
            'workspace_id': workspaceId,
            'position': position,
          })
          .select()
          .single();
      return Result.success(mcpServerFromRow(row));
    } on Object catch (error) {
      return Result.failure(mapSupabaseError(error));
    }
  }

  @override
  Future<Result<McpServer>> update({
    required String workspaceId,
    required String id,
    required McpServerDraft draft,
    int? position,
  }) async {
    try {
      final row = await _client
          .from('mcp_servers')
          .update({...mcpServerValues(draft), 'position': ?position})
          .eq('workspace_id', workspaceId)
          .eq('id', id)
          .select()
          .single();
      return Result.success(mcpServerFromRow(row));
    } on Object catch (error) {
      return Result.failure(mapSupabaseError(error));
    }
  }

  @override
  Future<Result<void>> delete({
    required String workspaceId,
    required String id,
  }) async {
    try {
      await _client
          .from('mcp_servers')
          .delete()
          .eq('workspace_id', workspaceId)
          .eq('id', id);
      return const Result.success(null);
    } on Object catch (error) {
      return Result.failure(mapSupabaseError(error));
    }
  }
}
