/// Chat session model
library;

class Session {
  final String key;
  final String agentId;
  final String source;
  final DateTime startedAt;
  final int messageCount;
  final int tokenCount;
  final bool isActive;

  const Session({
    required this.key,
    required this.agentId,
    this.source = 'pocket-claw',
    required this.startedAt,
    this.messageCount = 0,
    this.tokenCount = 0,
    this.isActive = false,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        key: json['key'] as String,
        agentId: json['agentId'] as String,
        source: json['source'] as String? ?? 'pocket-claw',
        startedAt: DateTime.parse(json['startedAt'] as String),
        messageCount: json['messageCount'] as int? ?? 0,
        tokenCount: json['tokenCount'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'agentId': agentId,
        'source': source,
        'startedAt': startedAt.toIso8601String(),
        'messageCount': messageCount,
        'tokenCount': tokenCount,
        'isActive': isActive,
      };
}
