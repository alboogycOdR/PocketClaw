/// OpenClaw session — one row from the `sessions.usage` RPC response.
library;

class OpenClawSession {
  final String id;
  final String? agentId;
  final String? model;
  final String? platform; // 'telegram', 'cli', 'pocket-claw', etc.
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int messageCount;
  final int inputTokens;
  final int outputTokens;
  final double? costUSD;

  const OpenClawSession({
    required this.id,
    this.agentId,
    this.model,
    this.platform,
    this.startedAt,
    this.endedAt,
    this.messageCount = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.costUSD,
  });

  int get totalTokens => inputTokens + outputTokens;

  Duration? get duration {
    if (startedAt == null) return null;
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  factory OpenClawSession.fromJson(Map<String, dynamic> json) =>
      OpenClawSession(
        id: json['id'] as String? ?? '',
        agentId: json['agentId'] as String?,
        model: json['model'] as String?,
        platform: json['platform'] as String?,
        startedAt: _parseDate(json['startedAt'] ?? json['started_at']),
        endedAt: _parseDate(json['endedAt'] ?? json['ended_at']),
        messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
        inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
        costUSD: (json['costUsd'] as num?)?.toDouble() ??
            (json['costUSD'] as num?)?.toDouble(),
      );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}
