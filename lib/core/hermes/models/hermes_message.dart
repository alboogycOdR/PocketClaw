/// Hermes message + tool call — one row from the `messages` table on
/// the remote state.db. Translated from Scarf's HermesMessage.swift.
/// SPEC-MultiTransport §8.2.
library;

import 'dart:convert';

import 'hermes_session.dart' show epochToDate;

enum ToolKind { read, edit, execute, fetch, search, think, other }

class HermesToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const HermesToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
  });

  ToolKind get kind => switch (name) {
        'read_file' ||
        'list_dir' ||
        'search_files' ||
        'glob' =>
          ToolKind.read,
        'write_file' ||
        'edit_file' ||
        'delete_file' ||
        'replace_in_file' =>
          ToolKind.edit,
        'terminal' || 'execute_code' || 'run_script' => ToolKind.execute,
        'web_search' || 'browser' || 'fetch_url' || 'scrape' => ToolKind.fetch,
        'search_sessions' || 'search_memory' => ToolKind.search,
        'think' || 'analyze' => ToolKind.think,
        _ => ToolKind.other,
      };

  factory HermesToolCall.fromJson(Map<String, dynamic> json) {
    final fn = json['function'] as Map<String, dynamic>? ?? const {};
    Map<String, dynamic> args = const {};
    try {
      final rawArgs = fn['arguments'];
      if (rawArgs is String && rawArgs.isNotEmpty) {
        final decoded = jsonDecode(rawArgs);
        if (decoded is Map) args = decoded.cast<String, dynamic>();
      } else if (rawArgs is Map) {
        args = rawArgs.cast<String, dynamic>();
      }
    } catch (_) {}
    return HermesToolCall(
      id: json['id'] as String? ?? '',
      name: fn['name'] as String? ?? '',
      arguments: args,
    );
  }
}

class HermesMessage {
  final int id;
  final String sessionId;
  final String role;
  final String content;
  final String? toolName;
  final List<HermesToolCall> toolCalls;
  final DateTime? timestamp;

  const HermesMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.toolName,
    this.toolCalls = const [],
    this.timestamp,
  });

  bool get isAssistant => role == 'assistant';
  bool get isUser => role == 'user';
  bool get hasToolCalls => toolCalls.isNotEmpty;

  factory HermesMessage.fromSqliteRow(Map<String, dynamic> row) {
    List<HermesToolCall> calls = const [];
    try {
      final raw = row['tool_calls'];
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          calls = decoded
              .cast<Map<String, dynamic>>()
              .map(HermesToolCall.fromJson)
              .toList();
        }
      }
    } catch (_) {}
    return HermesMessage(
      id: (row['id'] as num?)?.toInt() ?? 0,
      sessionId: row['session_id'] as String? ?? '',
      role: row['role'] as String? ?? 'user',
      content: row['content'] as String? ?? '',
      toolName: row['tool_name'] as String?,
      toolCalls: calls,
      timestamp: epochToDate(row['timestamp']),
    );
  }
}
