/// Wire models for the Hermes ACP (Agent Client Protocol) JSON-RPC
/// session. SPEC-ACPWireProtocol-v1.0.md §Dart Implementation.
library;

// ── Inbound discrimination ───────────────────────────────────────────────

enum AcpMessageKind { response, notification, serverRequest, unknown }

class AcpRawMessage {
  final String? jsonrpc;
  final int? id;
  final String? method;
  final Map<String, dynamic>? result;
  final AcpErrorPayload? error;
  final Map<String, dynamic>? params;

  const AcpRawMessage({
    this.jsonrpc,
    this.id,
    this.method,
    this.result,
    this.error,
    this.params,
  });

  /// Per spec: id+method? = response, no-id+method = notification,
  /// id+method = server-initiated request (e.g. permission ask).
  AcpMessageKind get kind {
    final hasId = id != null;
    final hasMethod = method != null;
    if (hasId && !hasMethod) return AcpMessageKind.response;
    if (!hasId && hasMethod) return AcpMessageKind.notification;
    if (hasId && hasMethod) return AcpMessageKind.serverRequest;
    return AcpMessageKind.unknown;
  }

  factory AcpRawMessage.fromJson(Map<String, dynamic> json) => AcpRawMessage(
        jsonrpc: json['jsonrpc'] as String?,
        id: (json['id'] as num?)?.toInt(),
        method: json['method'] as String?,
        result: json['result'] as Map<String, dynamic>?,
        error: json['error'] is Map<String, dynamic>
            ? AcpErrorPayload.fromJson(json['error'] as Map<String, dynamic>)
            : null,
        params: json['params'] as Map<String, dynamic>?,
      );
}

class AcpErrorPayload {
  final int code;
  final String message;
  const AcpErrorPayload({required this.code, required this.message});

  factory AcpErrorPayload.fromJson(Map<String, dynamic> json) =>
      AcpErrorPayload(
        code: (json['code'] as num?)?.toInt() ?? -32603,
        message: json['message'] as String? ?? 'Unknown error',
      );

  @override
  String toString() => 'ACP error $code: $message';
}

// ── Events (sealed hierarchy for switch exhaustiveness) ─────────────────

sealed class AcpEvent {
  final String sessionId;
  const AcpEvent({required this.sessionId});
}

class AcpMessageChunkEvent extends AcpEvent {
  final String text;
  const AcpMessageChunkEvent({required super.sessionId, required this.text});
}

class AcpThoughtChunkEvent extends AcpEvent {
  final String text;
  const AcpThoughtChunkEvent({required super.sessionId, required this.text});
}

class AcpToolCallStartEvent extends AcpEvent {
  final String toolCallId;
  final String title; // raw "functionName: summary"
  final String functionName;
  final String summary;
  final String kind; // 'read'|'edit'|'execute'|'fetch'|'search'|'think'|'other'
  final String status; // 'pending' on start
  final Map<String, dynamic>? rawInput;

  AcpToolCallStartEvent({
    required super.sessionId,
    required this.toolCallId,
    required this.title,
    required this.kind,
    required this.status,
    this.rawInput,
  })  : functionName = title.contains(':')
            ? title.split(':').first.trim()
            : title,
        summary = title.contains(':')
            ? title.substring(title.indexOf(':') + 1).trim()
            : '';
}

class AcpToolCallUpdateEvent extends AcpEvent {
  final String toolCallId;
  final String kind;
  final String status; // 'completed' | 'failed'
  final String content; // flattened from nested content array
  final String? rawOutput;

  const AcpToolCallUpdateEvent({
    required super.sessionId,
    required this.toolCallId,
    required this.kind,
    required this.status,
    required this.content,
    this.rawOutput,
  });

  bool get failed => status == 'failed';
}

class AcpPermissionRequestEvent extends AcpEvent {
  final int requestId; // must echo this id back when responding
  final String toolCallTitle;
  final String toolCallKind;
  final List<AcpPermissionOption> options;

  const AcpPermissionRequestEvent({
    required super.sessionId,
    required this.requestId,
    required this.toolCallTitle,
    required this.toolCallKind,
    required this.options,
  });
}

class AcpPermissionOption {
  final String optionId;
  final String name;
  const AcpPermissionOption({required this.optionId, required this.name});
}

class AcpPromptCompleteEvent extends AcpEvent {
  final String stopReason; // 'end_turn'|'max_tokens'|'cancelled'|'tool_use'
  final int inputTokens;
  final int outputTokens;
  final int thoughtTokens;
  final int cachedReadTokens;

  const AcpPromptCompleteEvent({
    required super.sessionId,
    required this.stopReason,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.thoughtTokens = 0,
    this.cachedReadTokens = 0,
  });

  int get totalTokens => inputTokens + outputTokens;
}

/// Catch-all for forward-compatibility when Hermes adds new sessionUpdate
/// types before this client recognises them.
class AcpUnknownEvent extends AcpEvent {
  final String type;
  const AcpUnknownEvent({required super.sessionId, required this.type});
}

/// Emitted when the SSH-exec'd `hermes acp` subprocess exits or the
/// channel closes for any reason.
class AcpDisconnectedEvent extends AcpEvent {
  const AcpDisconnectedEvent({required super.sessionId});
}
