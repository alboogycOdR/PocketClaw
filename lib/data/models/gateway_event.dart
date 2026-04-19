/// Gateway WebSocket event models
library;

enum GatewayState { disconnected, connecting, connected, reconnecting, error }

enum EventType { agentStart, agentEnd, agentError, taskProgress, heartbeat }

class ServerResponse {
  final String sessionKey;
  final String chunk;
  final bool done;

  /// OpenClaw run identifier (uuid). Lets the chat layer correlate
  /// streaming deltas to the specific `chat.send` that started them,
  /// and distinguish proactive agent pushes from our in-flight reply.
  final String? runId;

  /// Transient inline status, e.g. "Searching the web for 'flutter ed25519'"
  /// or "Reading memory: skills/...". Rendered below the bubble content.
  /// Only set on tool / lifecycle events — never on actual assistant tokens.
  final String? statusText;

  /// True if this response originated from an agent push that we did NOT
  /// solicit (no matching in-flight runId on the client side). Chat layer
  /// renders these as fresh bubbles instead of appending to a streaming
  /// placeholder.
  final bool proactive;

  const ServerResponse({
    required this.sessionKey,
    required this.chunk,
    this.done = false,
    this.runId,
    this.statusText,
    this.proactive = false,
  });

  factory ServerResponse.fromJson(Map<String, dynamic> json) => ServerResponse(
        sessionKey: json['sessionKey'] as String? ?? '',
        chunk: json['chunk'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        runId: json['runId'] as String?,
        statusText: json['statusText'] as String?,
        proactive: json['proactive'] as bool? ?? false,
      );
}

class AgentEvent {
  final EventType type;
  final String? agentId;
  final String? taskId;
  final String? sessionKey;
  final String? message;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const AgentEvent({
    required this.type,
    this.agentId,
    this.taskId,
    this.sessionKey,
    this.message,
    this.data = const {},
    required this.timestamp,
  });

  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    final action = json['action'] as String? ?? '';
    return AgentEvent(
      type: _parseEventType(action),
      agentId: json['agentId'] as String?,
      taskId: json['taskId'] as String?,
      sessionKey: json['sessionKey'] as String?,
      message: json['message'] as String?,
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.now(),
    );
  }

  factory AgentEvent.heartbeat(Map<String, dynamic> json) => AgentEvent(
        type: EventType.heartbeat,
        agentId: json['agentId'] as String?,
        message: json['message'] as String?,
        timestamp: DateTime.now(),
      );

  static EventType _parseEventType(String action) {
    switch (action) {
      case 'start':
        return EventType.agentStart;
      case 'end':
        return EventType.agentEnd;
      case 'error':
        return EventType.agentError;
      case 'progress':
        return EventType.taskProgress;
      default:
        return EventType.heartbeat;
    }
  }
}

class ActivityEvent {
  final String id;
  final String message;
  final String? agentId;
  final DateTime timestamp;

  const ActivityEvent({
    required this.id,
    required this.message,
    this.agentId,
    required this.timestamp,
  });

  factory ActivityEvent.fromHeartbeat(AgentEvent event) => ActivityEvent(
        id: '${event.agentId}-${event.timestamp.millisecondsSinceEpoch}',
        message: event.message ?? 'Heartbeat',
        agentId: event.agentId,
        timestamp: event.timestamp,
      );
}
