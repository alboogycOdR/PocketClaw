/// Hermes session — one row from the `sessions` table on the remote
/// state.db. Translated from Scarf's HermesSession.swift.
/// SPEC-MultiTransport §8.1.
library;

/// Status used by Swarm Monitor + Office View. Derived from row state
/// (`endedAt`, `messageCount`) and clock since the server has no
/// `state` column.
enum SwarmStatus { running, thinking, complete, failed, error, idle }

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

  /// True when this is a top-level orchestrator session (no parent
  /// and a "conductor"/"swarm" marker in its title).
  bool get isOrchestrator {
    if (parentSessionId != null) return false;
    final t = (title ?? '').toLowerCase();
    return t.contains('conductor') ||
        t.contains('orchestrator') ||
        t.contains('swarm');
  }

  /// Status used by the Swarm Monitor + Office View. Pure function of
  /// the row + clock — server doesn't expose a `state` column.
  SwarmStatus get swarmStatus {
    if (endedAt != null) {
      return messageCount > 0 ? SwarmStatus.complete : SwarmStatus.failed;
    }
    // Active sessions. Without per-turn signals we can only call it
    // "running"; UI can layer a "thinking" state on top when it sees
    // streaming events from chat.
    final age = DateTime.now().difference(startedAt ?? DateTime(2020));
    if (age.inSeconds < 0) return SwarmStatus.idle;
    return SwarmStatus.running;
  }

  /// Short display name for the office view — strips raw UUIDs and
  /// gives orchestrators / workers distinct labels.
  String get officeDisplayName {
    final t = title?.trim();
    if (t != null && t.isNotEmpty && !_looksLikeUuid(t)) return t;
    final prefix = isOrchestrator
        ? 'Conductor'
        : (source == 'telegram' ? 'Task' : 'Worker');
    final suffix =
        id.length >= 4 ? id.substring(id.length - 4).toUpperCase() : id;
    return '$prefix $suffix';
  }

  static bool _looksLikeUuid(String s) =>
      RegExp(r'^[0-9a-f-]{8,}$', caseSensitive: false).hasMatch(s);

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
