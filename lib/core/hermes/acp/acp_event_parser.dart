/// Parses raw ACP JSON-RPC messages into typed events.
/// SPEC-ACPWireProtocol-v1.0.md §Server → Client: Notifications.
library;

import 'acp_models.dart';

class AcpEventParser {
  /// Parse a notification (id absent + method == "session/update") into a
  /// typed [AcpEvent]. Returns null if the message isn't a session update
  /// or doesn't carry the expected envelope.
  static AcpEvent? parseNotification(AcpRawMessage message) {
    if (message.method != 'session/update') return null;
    final params = message.params;
    final sessionId = params?['sessionId'] as String?;
    final update = params?['update'] as Map<String, dynamic>?;
    final type = update?['sessionUpdate'] as String?;
    if (sessionId == null || update == null || type == null) return null;

    return switch (type) {
      'agent_message_chunk' => AcpMessageChunkEvent(
          sessionId: sessionId,
          text: _extractContentText(update),
        ),
      'agent_thought_chunk' => AcpThoughtChunkEvent(
          sessionId: sessionId,
          text: _extractContentText(update),
        ),
      'tool_call' => AcpToolCallStartEvent(
          sessionId: sessionId,
          toolCallId: update['toolCallId'] as String? ?? '',
          title: update['title'] as String? ?? '',
          kind: update['kind'] as String? ?? 'other',
          status: update['status'] as String? ?? 'pending',
          rawInput: update['rawInput'] as Map<String, dynamic>?,
        ),
      'tool_call_update' => AcpToolCallUpdateEvent(
          sessionId: sessionId,
          toolCallId: update['toolCallId'] as String? ?? '',
          kind: update['kind'] as String? ?? 'other',
          status: update['status'] as String? ?? 'completed',
          content: _extractContentArrayText(update),
          rawOutput: update['rawOutput'] as String?,
        ),
      'available_commands_update' => null, // ignored — chat doesn't surface
      _ => AcpUnknownEvent(sessionId: sessionId, type: type),
    };
  }

  /// Parse a server-initiated request (id+method present) of method
  /// `session/request_permission` into an [AcpPermissionRequestEvent].
  /// Other server-request methods return null.
  static AcpPermissionRequestEvent? parsePermissionRequest(
    AcpRawMessage message,
  ) {
    if (message.method != 'session/request_permission') return null;
    final id = message.id;
    final params = message.params;
    final sessionId = params?['sessionId'] as String?;
    if (id == null || sessionId == null) return null;
    final toolCall =
        params?['toolCall'] as Map<String, dynamic>? ?? const {};
    final rawOptions = params?['options'] as List? ?? const [];
    return AcpPermissionRequestEvent(
      sessionId: sessionId,
      requestId: id,
      toolCallTitle: toolCall['title'] as String? ?? '',
      toolCallKind: toolCall['kind'] as String? ?? 'other',
      options: rawOptions
          .cast<Map<String, dynamic>>()
          .map((o) => AcpPermissionOption(
                optionId: o['optionId'] as String? ?? '',
                name: o['name'] as String? ?? '',
              ))
          .toList(),
    );
  }

  /// agent_message_chunk and agent_thought_chunk both carry
  /// `update.content.text` as a flat object.
  static String _extractContentText(Map<String, dynamic> update) {
    final c = update['content'];
    if (c is Map) {
      return c['text'] as String? ?? '';
    }
    return '';
  }

  /// tool_call_update wraps content in a list of `{content:{text:""}}`
  /// objects — flatten by joining the inner texts.
  static String _extractContentArrayText(Map<String, dynamic> update) {
    final arr = update['content'] as List?;
    if (arr == null) return '';
    return arr
        .cast<Map<String, dynamic>>()
        .map((item) => (item['content'] as Map?)?['text'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .join('\n');
  }
}
