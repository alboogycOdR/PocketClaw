/// Chat message model
library;

enum MessageRole { user, assistant, system }

enum MessageSource { local, server, bridge, device }

enum ActionType { email, calendar, message, reminder, generic }

/// A tool call observed during a Hermes ACP turn. Carried by the chat
/// bubble so the UI can render an inline status card per call.
/// `kind` is the raw ACP kind string ('read'|'edit'|'execute'|'fetch'|
/// 'search'|'think'|'other'); `status` is 'pending'|'completed'|'failed'.
class ChatAcpToolCall {
  final String toolCallId;
  final String title; // raw "functionName: summary" or just "functionName"
  final String kind;
  final String status;
  final String content; // result text once completed
  final Map<String, dynamic>? rawInput;

  const ChatAcpToolCall({
    required this.toolCallId,
    required this.title,
    required this.kind,
    required this.status,
    this.content = '',
    this.rawInput,
  });

  String get functionName =>
      title.contains(':') ? title.split(':').first.trim() : title;
  String get summary => title.contains(':')
      ? title.substring(title.indexOf(':') + 1).trim()
      : '';

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  ChatAcpToolCall copyWith({String? status, String? content}) =>
      ChatAcpToolCall(
        toolCallId: toolCallId,
        title: title,
        kind: kind,
        status: status ?? this.status,
        content: content ?? this.content,
        rawInput: rawInput,
      );
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final MessageSource? source;
  final DateTime timestamp;
  final bool isStreaming;
  final FunctionCallInfo? functionCall;
  final DraftAction? draftAction;
  final String? imageUrl;
  final List<String> memoryCitations;

  /// Inline status shown while the agent is using a tool or transitioning
  /// lifecycle state (e.g. "Searching the web…"). Cleared when the final
  /// assistant text arrives.
  final String? statusText;

  /// OpenClaw run identifier this message is tied to (for abort/correlation).
  final String? runId;

  /// Tool calls emitted during this message's ACP turn. Empty for non-ACP
  /// paths and for user messages. Append-mutated via
  /// MessagesNotifier.addToolCall/updateToolCall.
  final List<ChatAcpToolCall> acpToolCalls;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.source,
    required this.timestamp,
    this.isStreaming = false,
    this.functionCall,
    this.draftAction,
    this.imageUrl,
    this.memoryCitations = const [],
    this.statusText,
    this.runId,
    this.acpToolCalls = const [],
  });

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    FunctionCallInfo? functionCall,
    DraftAction? draftAction,
    List<String>? memoryCitations,
    String? statusText,
    bool clearStatusText = false,
    String? runId,
    List<ChatAcpToolCall>? acpToolCalls,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        source: source,
        timestamp: timestamp,
        isStreaming: isStreaming ?? this.isStreaming,
        functionCall: functionCall ?? this.functionCall,
        draftAction: draftAction ?? this.draftAction,
        imageUrl: imageUrl,
        memoryCitations: memoryCitations ?? this.memoryCitations,
        statusText: clearStatusText ? null : (statusText ?? this.statusText),
        runId: runId ?? this.runId,
        acpToolCalls: acpToolCalls ?? this.acpToolCalls,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'source': source?.name,
        'timestamp': timestamp.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: MessageRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => MessageRole.user,
        ),
        content: json['content'] as String,
        source: json['source'] != null
            ? MessageSource.values.firstWhere(
                (s) => s.name == json['source'],
                orElse: () => MessageSource.local,
              )
            : null,
        timestamp: DateTime.parse(json['timestamp'] as String),
        imageUrl: json['imageUrl'] as String?,
      );
}

class FunctionCallInfo {
  final String name;
  final Map<String, dynamic> args;
  final bool isExecuting;
  final String? result;

  const FunctionCallInfo({
    required this.name,
    required this.args,
    this.isExecuting = false,
    this.result,
  });
}

class DraftAction {
  final ActionType type;
  final String title;
  final String body;
  final String? recipient;
  final bool isConfirmed;

  const DraftAction({
    required this.type,
    required this.title,
    required this.body,
    this.recipient,
    this.isConfirmed = false,
  });
}
