/// Hermes session — one row from the `sessions` table on the remote
/// state.db. Translated from Scarf's HermesSession.swift.
/// SPEC-MultiTransport §8.1.
library;

class HermesSession {
  final String id;
  final String source;
  final String? model;
  final String? title;
  final String? parentSessionId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int messageCount;
  final int toolCallCount;
  final int inputTokens;
  final int outputTokens;
  final double? estimatedCostUSD;
  final double? actualCostUSD;
  final String? billingProvider;

  const HermesSession({
    required this.id,
    required this.source,
    this.model,
    this.title,
    this.parentSessionId,
    this.startedAt,
    this.endedAt,
    this.messageCount = 0,
    this.toolCallCount = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.estimatedCostUSD,
    this.actualCostUSD,
    this.billingProvider,
  });

  bool get isSubagent => parentSessionId != null;
  int get totalTokens => inputTokens + outputTokens;
  double? get displayCostUSD => actualCostUSD ?? estimatedCostUSD;
  String get displayTitle => title?.isNotEmpty == true ? title! : id;

  String get sourceIcon => switch (source) {
        'telegram' => '📱',
        'discord' => '💬',
        'slack' => '💼',
        'cli' => '⌨️',
        'whatsapp' => '📞',
        _ => '🤖',
      };

  factory HermesSession.fromSqliteRow(Map<String, dynamic> row) =>
      HermesSession(
        id: row['id'] as String? ?? '',
        source: row['source'] as String? ?? 'cli',
        model: row['model'] as String?,
        title: row['title'] as String?,
        parentSessionId: row['parent_session_id'] as String?,
        startedAt: epochToDate(row['started_at']),
        endedAt: epochToDate(row['ended_at']),
        messageCount: (row['message_count'] as num?)?.toInt() ?? 0,
        toolCallCount: (row['tool_call_count'] as num?)?.toInt() ?? 0,
        inputTokens: (row['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (row['output_tokens'] as num?)?.toInt() ?? 0,
        estimatedCostUSD: (row['estimated_cost_usd'] as num?)?.toDouble(),
        actualCostUSD: (row['actual_cost_usd'] as num?)?.toDouble(),
        billingProvider: row['billing_provider'] as String?,
      );
}

/// Hermes stores timestamps as unix-epoch seconds (sometimes a fractional
/// double). Shared by HermesMessage too.
DateTime? epochToDate(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
  }
  if (v is String) return DateTime.tryParse(v);
  return null;
}
