/// Aggregates derived from Hermes' `state.db` for the Analytics tab —
/// daily token totals (chart) and per-model spend (cost ledger).
/// SPEC-SprintC-HermesAnalytics §1.
library;

class HermesDailyStats {
  /// 'YYYY-MM-DD' from sqlite's `date(unixepoch)`.
  final String day;
  final int inputTokens;
  final int outputTokens;
  final int sessions;
  final double costUsd;

  const HermesDailyStats({
    required this.day,
    required this.inputTokens,
    required this.outputTokens,
    required this.sessions,
    required this.costUsd,
  });

  int get totalTokens => inputTokens + outputTokens;

  /// Short axis label: 'Apr 18', 'May 1', etc.
  String get shortLabel {
    final ts = DateTime.tryParse(day);
    if (ts == null) return day;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[ts.month - 1]} ${ts.day}';
  }

  factory HermesDailyStats.fromRow(Map<String, dynamic> row) =>
      HermesDailyStats(
        day: row['day'] as String? ?? '',
        inputTokens: (row['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (row['output_tokens'] as num?)?.toInt() ?? 0,
        sessions: (row['sessions'] as num?)?.toInt() ?? 0,
        costUsd: (row['cost_usd'] as num?)?.toDouble() ?? 0.0,
      );
}

class HermesModelStats {
  final String model;
  final int totalTokens;
  final double costUsd;
  final int sessionCount;

  const HermesModelStats({
    required this.model,
    required this.totalTokens,
    required this.costUsd,
    required this.sessionCount,
  });

  /// True when this row represents real API spend. Local/embedded
  /// runtimes (Ollama, llama.cpp, gemma, qwen, lmstudio) never charge,
  /// even when costUsd has stale numbers.
  bool get isPaidModel {
    final lower = model.toLowerCase();
    if (lower.contains('ollama')) return false;
    if (lower.contains('local')) return false;
    if (lower.contains('llama')) return false;
    if (lower.contains('gemma')) return false;
    if (lower.contains('qwen')) return false;
    if (lower.contains('lmstudio')) return false;
    return costUsd > 0;
  }

  /// Display name — strips provider prefix and trailing date stamp.
  /// 'anthropic/claude-haiku-4-5-20251001' → 'claude-haiku-4-5'
  String get displayName {
    final parts = model.split('/');
    final base = parts.last;
    return base.replaceAll(RegExp(r'-\d{8}$'), '');
  }

  factory HermesModelStats.fromRow(Map<String, dynamic> row) =>
      HermesModelStats(
        model: row['model'] as String? ?? 'unknown',
        totalTokens: (row['total_tokens'] as num?)?.toInt() ?? 0,
        costUsd: (row['cost_usd'] as num?)?.toDouble() ?? 0.0,
        sessionCount: (row['session_count'] as num?)?.toInt() ?? 0,
      );
}
