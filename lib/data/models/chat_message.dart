/// Chat message model
library;

enum MessageRole { user, assistant, system }

enum MessageSource { local, server, bridge, device }

enum ActionType { email, calendar, message, reminder, generic }

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
  });

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    FunctionCallInfo? functionCall,
    DraftAction? draftAction,
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
