# ClawCommander — Sprint C: Hermes Analytics Dashboard
## Developer Specification v1.0

**Date:** 2026-05-09  
**Author:** CARMEN PTY LTD  
**Verified against:** `PocketClaw-source-2026-05-09` + `hermes-workspace-main` (dashboard aggregator + analytics cards)  
**Status:** Implementation-ready  
**Estimated effort:** 2 days  
**Depends on:** SSH transport operational (already complete as of May 9). Sprint A + B are independent.

---

## Overview

Three analytics features for the Hermes Management screen, all backed by SQL queries against `~/.hermes/state.db` via the existing SSH transport:

1. **7-Day Token Chart** — area chart of daily input/output token usage over the last 7 days
2. **Per-Model Cost Ledger** — breakdown of spend by model, separating paid from local/free providers
3. **Insights Engine** — 2–3 plain-language sentences summarising usage patterns (peak day, cache trend, cron health)

All three feed a new **Analytics tab** added to `HermesManagementScreen`. No new dependencies — `fl_chart: ^0.70.2` is already in `pubspec.yaml`.

---

## Item 1 — New SQL Queries

Both the chart and the cost ledger need new queries. Add them to `HermesDataService`.

**File:** `lib/core/hermes/hermes_data_service.dart`

```dart
// Add after the existing getCostSummary() method:

/// Daily token breakdown for the last [days] days.
/// Used by the 7-day area chart.
Future<List<HermesDailyStats>> getDailyStats({int days = 7}) async {
  final rows = await _db.query('''
    SELECT
      date(started_at, 'unixepoch') AS day,
      COALESCE(SUM(input_tokens), 0)  AS input_tokens,
      COALESCE(SUM(output_tokens), 0) AS output_tokens,
      COUNT(*) AS sessions,
      COALESCE(SUM(
        COALESCE(actual_cost_usd, estimated_cost_usd)
      ), 0.0) AS cost_usd
    FROM sessions
    WHERE started_at > strftime('%s', 'now', '-$days days')
    GROUP BY day
    ORDER BY day ASC
  ''');
  return rows.map(HermesDailyStats.fromRow).toList();
}

/// Per-model breakdown of token usage and cost.
/// Used by the cost ledger card.
Future<List<HermesModelStats>> getCostByModel() async {
  final rows = await _db.query('''
    SELECT
      COALESCE(model, 'unknown') AS model,
      COALESCE(SUM(input_tokens + output_tokens), 0) AS total_tokens,
      COALESCE(SUM(
        COALESCE(actual_cost_usd, estimated_cost_usd)
      ), 0.0) AS cost_usd,
      COUNT(*) AS session_count
    FROM sessions
    GROUP BY model
    ORDER BY cost_usd DESC
  ''');
  return rows.map(HermesModelStats.fromRow).toList();
}
```

**New models** — add to `lib/core/hermes/models/hermes_analytics.dart` (new file):

```dart
// lib/core/hermes/models/hermes_analytics.dart
library;

/// One day's aggregate stats for the token usage chart.
class HermesDailyStats {
  final String day;           // 'YYYY-MM-DD'
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
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[ts.month - 1]} ${ts.day}';
  }

  factory HermesDailyStats.fromRow(Map<String, dynamic> row) =>
      HermesDailyStats(
        day:          row['day'] as String? ?? '',
        inputTokens:  (row['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (row['output_tokens'] as num?)?.toInt() ?? 0,
        sessions:     (row['sessions'] as num?)?.toInt() ?? 0,
        costUsd:      (row['cost_usd'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Per-model aggregate for the cost ledger.
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

  /// True when this model incurs real API cost.
  /// Local/embedded models and subscription models show tokens only.
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

  /// Display name — strips provider prefix if present.
  String get displayName {
    // 'anthropic/claude-haiku-4-5-20251001' → 'claude-haiku-4-5'
    final parts = model.split('/');
    final base = parts.last;
    // Strip trailing date stamps: '-20251001'
    return base.replaceAll(RegExp(r'-\d{8}$'), '');
  }

  factory HermesModelStats.fromRow(Map<String, dynamic> row) =>
      HermesModelStats(
        model:        row['model'] as String? ?? 'unknown',
        totalTokens:  (row['total_tokens'] as num?)?.toInt() ?? 0,
        costUsd:      (row['cost_usd'] as num?)?.toDouble() ?? 0.0,
        sessionCount: (row['session_count'] as num?)?.toInt() ?? 0,
      );
}
```

---

## Item 2 — New Providers

**File:** `lib/data/providers/hermes_data_providers.dart` — add at the bottom:

```dart
// Add to existing hermes_data_providers.dart:

import '../core/hermes/models/hermes_analytics.dart';

final hermesDailyStatsProvider =
    FutureProvider<List<HermesDailyStats>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getDailyStats(days: 7);
});

final hermesModelStatsProvider =
    FutureProvider<List<HermesModelStats>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getCostByModel();
});
```

---

## Item 3 — Formatters (shared utility)

**New file: `lib/shared/utils/analytics_formatters.dart`**

```dart
// lib/shared/utils/analytics_formatters.dart
library;

/// Format token count with K/M/B suffix.
String formatTokens(int n) {
  if (n <= 0) return '0';
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(2)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Format USD cost with appropriate precision.
String formatCostUsd(double usd) {
  if (usd <= 0) return r'$0';
  if (usd < 0.01) return r'<$0.01';
  if (usd < 1) return '\$${usd.toStringAsFixed(3)}';
  if (usd < 100) return '\$${usd.toStringAsFixed(2)}';
  return '\$${usd.round()}';
}
```

---

## Item 4 — 7-Day Token Chart

**New file: `lib/features/hermes/widgets/hermes_token_chart.dart`**

```dart
// lib/features/hermes/widgets/hermes_token_chart.dart
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/hermes/models/hermes_analytics.dart';
import '../../../data/providers/hermes_data_providers.dart';
import '../../../shared/utils/analytics_formatters.dart';

/// 7-day area chart of input + output token usage.
/// Rendered in the Hermes Analytics tab.
class HermesTokenChart extends ConsumerWidget {
  const HermesTokenChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(hermesDailyStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => SizedBox(
        height: 60,
        child: Center(
          child: Text('Chart unavailable: $e',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ),
      data: (stats) {
        if (stats.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'No session data yet',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          );
        }
        return _Chart(stats: stats);
      },
    );
  }
}

class _Chart extends StatelessWidget {
  final List<HermesDailyStats> stats;
  const _Chart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxTokens = stats
        .map((s) => s.totalTokens)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();

    // Build spot lists
    final inputSpots = <FlSpot>[];
    final outputSpots = <FlSpot>[];
    for (var i = 0; i < stats.length; i++) {
      inputSpots.add(FlSpot(i.toDouble(), stats[i].inputTokens.toDouble()));
      outputSpots.add(FlSpot(i.toDouble(), stats[i].outputTokens.toDouble()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _LegendDot(color: PocketClawTheme.electricTeal, label: 'Input'),
            const SizedBox(width: 16),
            _LegendDot(color: PocketClawTheme.lobsterRed, label: 'Output'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (stats.length - 1).toDouble(),
              minY: 0,
              maxY: maxTokens * 1.15,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxTokens > 0 ? maxTokens / 4 : 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withOpacity(0.05),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: maxTokens > 0 ? maxTokens / 4 : 1,
                    getTitlesWidget: (val, _) => Text(
                      formatTokens(val.toInt()),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (val, _) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= stats.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        stats[idx].shortLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: Colors.white38,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final isInput = s.barIndex == 0;
                    return LineTooltipItem(
                      formatTokens(s.y.toInt()),
                      TextStyle(
                        color: isInput
                            ? PocketClawTheme.electricTeal
                            : PocketClawTheme.lobsterRed,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                // Input tokens — teal
                LineChartBarData(
                  spots: inputSpots,
                  isCurved: true,
                  color: PocketClawTheme.electricTeal,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: PocketClawTheme.electricTeal.withOpacity(0.12),
                  ),
                ),
                // Output tokens — red
                LineChartBarData(
                  spots: outputSpots,
                  isCurved: true,
                  color: PocketClawTheme.lobsterRed,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: PocketClawTheme.lobsterRed.withOpacity(0.10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}
```

---

## Item 5 — Per-Model Cost Ledger

**New file: `lib/features/hermes/widgets/hermes_cost_ledger.dart`**

```dart
// lib/features/hermes/widgets/hermes_cost_ledger.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/hermes/models/hermes_analytics.dart';
import '../../../data/providers/hermes_data_providers.dart';
import '../../../shared/utils/analytics_formatters.dart';

/// Per-model breakdown of token usage and cost.
/// Separates paid models (real $$$) from local/subscription models
/// so the operator immediately sees what's costing money.
///
/// Ported from hermes-workspace `cost-ledger-card.tsx`.
class HermesCostLedger extends ConsumerWidget {
  const HermesCostLedger({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(hermesModelStatsProvider);

    return statsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text(
        'Ledger unavailable: $e',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      data: (models) {
        if (models.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No model data yet',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        final paid = models.where((m) => m.isPaidModel).toList();
        final free = models.where((m) => !m.isPaidModel).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (paid.isNotEmpty) ...[
              _SectionHeader(
                label: 'PAID',
                color: PocketClawTheme.lobsterRed,
              ),
              ...paid.map((m) => _ModelRow(stats: m, showCost: true)),
            ],
            if (free.isNotEmpty) ...[
              if (paid.isNotEmpty) const SizedBox(height: 12),
              _SectionHeader(
                label: 'LOCAL / SUBSCRIPTION',
                color: Colors.white38,
              ),
              ...free.map((m) => _ModelRow(stats: m, showCost: false)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          letterSpacing: 0.14,
          fontWeight: FontWeight.w600,
          color: color.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  final HermesModelStats stats;
  final bool showCost;
  const _ModelRow({required this.stats, required this.showCost});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Model name
          Expanded(
            child: Text(
              stats.displayName,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Token count
          Text(
            formatTokens(stats.totalTokens),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
          // Cost (paid only)
          if (showCost) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 56,
              child: Text(
                formatCostUsd(stats.costUsd),
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PocketClawTheme.lobsterRed,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 56,
              child: Text(
                'free',
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.white24,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## Item 6 — Insights Engine

**New file: `lib/core/hermes/hermes_insights.dart`**

```dart
// lib/core/hermes/hermes_insights.dart
library;

import '../../../core/hermes/models/hermes_analytics.dart';
import '../../../shared/utils/analytics_formatters.dart';

enum InsightTone { info, positive, warn }

class DashboardInsight {
  final String text;
  final InsightTone tone;

  const DashboardInsight({required this.text, required this.tone});
}

/// Derives 2–3 plain-language sentences from analytics data.
/// No AI calls — pure computation on the daily stats list.
///
/// Ported from hermes-workspace `lib/insights.ts`.
class HermesInsightsEngine {
  static List<DashboardInsight> build({
    required List<HermesDailyStats> daily,
    required List<HermesModelStats> models,
    int? failedCronCount,
  }) {
    final insights = <DashboardInsight>[];

    // Need at least 3 days for meaningful peak analysis
    if (daily.length >= 3) {
      // 1. Peak usage day
      var peakIdx = 0;
      var peakVal = 0;
      for (var i = 0; i < daily.length; i++) {
        if (daily[i].totalTokens > peakVal) {
          peakVal = daily[i].totalTokens;
          peakIdx = i;
        }
      }
      if (peakVal > 0) {
        final topModel = models.isNotEmpty ? models.first.displayName : null;
        final driver = topModel != null ? ', driven by $topModel' : '';
        insights.add(DashboardInsight(
          tone: InsightTone.info,
          text: 'Usage peaked ${daily[peakIdx].shortLabel} '
              '(${formatTokens(peakVal)} tokens)$driver.',
        ));
      }
    }

    // 2. Cost trend: compare first half vs second half of window
    if (daily.length >= 6) {
      final mid = daily.length ~/ 2;
      var priorCost = 0.0;
      var recentCost = 0.0;
      for (var i = 0; i < mid; i++) priorCost += daily[i].costUsd;
      for (var i = mid; i < daily.length; i++) recentCost += daily[i].costUsd;

      if (priorCost > 0.001) {
        final delta = ((recentCost - priorCost) / priorCost) * 100;
        if (delta.abs() >= 10) {
          final direction = delta > 0 ? 'up' : 'down';
          insights.add(DashboardInsight(
            tone: delta > 0 ? InsightTone.warn : InsightTone.positive,
            text: 'API spend $direction '
                '${delta.abs().toStringAsFixed(0)}% '
                'vs the prior period.',
          ));
        }
      }
    }

    // 3. Cron health
    if (failedCronCount != null && failedCronCount > 0) {
      insights.add(DashboardInsight(
        tone: InsightTone.warn,
        text: '$failedCronCount cron '
            '${failedCronCount == 1 ? 'job' : 'jobs'} '
            'failed recently — check the Cron tab.',
      ));
    }

    // 4. Positive: consecutive active days
    if (daily.length >= 5) {
      final activeDays = daily.where((d) => d.sessions > 0).length;
      if (activeDays == daily.length) {
        insights.add(DashboardInsight(
          tone: InsightTone.positive,
          text: 'Active every day for ${daily.length} days — great streak!',
        ));
      }
    }

    return insights;
  }
}
```

**New file: `lib/shared/widgets/insight_chips.dart`**

```dart
// lib/shared/widgets/insight_chips.dart
library;

import 'package:flutter/material.dart';
import '../../core/hermes/hermes_insights.dart';

/// Renders a row of insight chips at the top of the analytics tab.
class InsightChips extends StatelessWidget {
  final List<DashboardInsight> insights;
  const InsightChips({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      children: insights.map((insight) {
        final (bg, border, textColor) = switch (insight.tone) {
          InsightTone.positive => (
              const Color(0xFF0F2A1A),
              const Color(0xFF1A5C2A),
              const Color(0xFF4ADE80),
            ),
          InsightTone.warn => (
              const Color(0xFF2A1A0F),
              const Color(0xFF5C3010),
              const Color(0xFFFBBF24),
            ),
          InsightTone.info => (
              const Color(0xFF0F1A2A),
              const Color(0xFF1A3050),
              const Color(0xFF60A5FA),
            ),
        };

        final icon = switch (insight.tone) {
          InsightTone.positive => Icons.trending_up,
          InsightTone.warn     => Icons.warning_amber_outlined,
          InsightTone.info     => Icons.info_outline,
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
```

---

## Item 7 — Analytics Tab Screen

**New file: `lib/features/hermes/hermes_analytics_screen.dart`**

```dart
// lib/features/hermes/hermes_analytics_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/hermes/hermes_data_service.dart';
import '../../core/hermes/hermes_insights.dart';
import '../../core/hermes/models/hermes_cron_job.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/utils/analytics_formatters.dart';
import '../../shared/widgets/insight_chips.dart';
import 'widgets/hermes_cost_ledger.dart';
import 'widgets/hermes_token_chart.dart';

class HermesAnalyticsTab extends ConsumerWidget {
  const HermesAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costAsync   = ref.watch(hermesCostSummaryProvider);
    final dailyAsync  = ref.watch(hermesDailyStatsProvider);
    final modelsAsync = ref.watch(hermesModelStatsProvider);
    final cronAsync   = ref.watch(hermesCronJobsProvider);

    // Compute insights when all data is available
    final insights = dailyAsync.maybeWhen(
      data: (daily) => modelsAsync.maybeWhen(
        data: (models) {
          final failedCrons = cronAsync.maybeWhen(
            data: (file) =>
                file.jobs.where((j) => j.hasFailed).length,
            orElse: () => null,
          );
          return HermesInsightsEngine.build(
            daily: daily,
            models: models,
            failedCronCount: failedCrons,
          );
        },
        orElse: () => <DashboardInsight>[],
      ),
      orElse: () => <DashboardInsight>[],
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(hermesCostSummaryProvider);
        ref.invalidate(hermesDailyStatsProvider);
        ref.invalidate(hermesModelStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Insight chips ─────────────────────────────────────────
          if (insights.isNotEmpty)
            InsightChips(insights: insights),

          // ── KPI summary row ───────────────────────────────────────
          costAsync.when(
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox.shrink(),
            data: (cost) => _KpiRow(cost: cost),
          ),
          const SizedBox(height: 20),

          // ── 7-day token chart ─────────────────────────────────────
          _SectionTitle(title: '7-Day Token Usage'),
          const SizedBox(height: 12),
          const HermesTokenChart(),
          const SizedBox(height: 24),

          // ── Cost ledger ───────────────────────────────────────────
          _SectionTitle(title: 'Model Breakdown'),
          const SizedBox(height: 12),
          const HermesCostLedger(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── KPI row: Total cost · Total tokens · Sessions ──────────────────────────

class _KpiRow extends StatelessWidget {
  final HermesCostSummary cost;
  const _KpiRow({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Kpi(
          label: '30-day cost',
          value: formatCostUsd(cost.totalCostUSD),
          color: cost.totalCostUSD > 1
              ? const Color(0xFFE53935)
              : Colors.white70,
        ),
        const SizedBox(width: 12),
        _Kpi(
          label: 'Total tokens',
          value: formatTokens(cost.totalTokens),
          color: Colors.white70,
        ),
        const SizedBox(width: 12),
        _Kpi(
          label: 'Sessions',
          value: '${cost.sessionCount}',
          color: Colors.white70,
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Kpi({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1525),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2D2840)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white54,
        letterSpacing: 0.1,
      ),
    );
  }
}
```

---

## Item 8 — Add Analytics Tab to `HermesManagementScreen`

**File:** `lib/features/hermes/hermes_management_screen.dart`

```dart
// Add import:
import 'hermes_analytics_screen.dart';

// Change length from 5 to 6:
DefaultTabController(
  length: 6,  // was 5

// Add to TabBar tabs list:
  Tab(
    icon: Icon(Icons.bar_chart_outlined, size: 18),
    text: 'Analytics',
  ),

// Add to TabBarView children (last position, or second after Sessions):
  Consumer(builder: (_, ref, __) {
    final caps = ref.watch(serverCapabilitiesProvider);
    return caps.hasCost
        ? const HermesAnalyticsTab()
        : const FeatureNotAvailableCard(
            feature: 'Analytics', featureKey: 'cost');
  }),
```

---

## Files Changed Summary

| File | Change |
|---|---|
| `lib/core/hermes/hermes_data_service.dart` | Add `getDailyStats()` + `getCostByModel()` |
| `lib/core/hermes/models/hermes_analytics.dart` | **New** — `HermesDailyStats` + `HermesModelStats` |
| `lib/core/hermes/hermes_insights.dart` | **New** — `HermesInsightsEngine` |
| `lib/data/providers/hermes_data_providers.dart` | Add `hermesDailyStatsProvider` + `hermesModelStatsProvider` |
| `lib/shared/utils/analytics_formatters.dart` | **New** — `formatTokens` + `formatCostUsd` |
| `lib/shared/widgets/insight_chips.dart` | **New** — insight chip row |
| `lib/features/hermes/widgets/hermes_token_chart.dart` | **New** — 7-day area chart |
| `lib/features/hermes/widgets/hermes_cost_ledger.dart` | **New** — per-model cost table |
| `lib/features/hermes/hermes_analytics_screen.dart` | **New** — Analytics tab screen |
| `lib/features/hermes/hermes_management_screen.dart` | Add Analytics tab (6th tab) |

---

## Implementation Order

| Step | Task | Time |
|---|---|---|
| 1 | Create `hermes_analytics.dart` models | 20 min |
| 2 | Add `getDailyStats` + `getCostByModel` to `HermesDataService` | 20 min |
| 3 | Add providers to `hermes_data_providers.dart` | 10 min |
| 4 | Create `analytics_formatters.dart` | 10 min |
| 5 | Test SQL queries on live VPS via SSH | 20 min |
| 6 | Create `hermes_token_chart.dart` | 1.5 hours |
| 7 | Test chart with real data | 20 min |
| 8 | Create `hermes_cost_ledger.dart` | 1 hour |
| 9 | Test ledger — verify paid vs free split is correct | 20 min |
| 10 | Create `hermes_insights.dart` | 45 min |
| 11 | Create `insight_chips.dart` | 30 min |
| 12 | Create `hermes_analytics_screen.dart` | 45 min |
| 13 | Add Analytics tab to `HermesManagementScreen` | 15 min |
| 14 | Full end-to-end test on device with live VPS | 30 min |

**Total: ~2 days**

---

## New Files Summary

```
lib/core/hermes/
├── models/hermes_analytics.dart         ← DailyStats + ModelStats models
└── hermes_insights.dart                 ← Insights engine

lib/shared/utils/
└── analytics_formatters.dart            ← formatTokens + formatCostUsd

lib/shared/widgets/
└── insight_chips.dart                   ← Insight chip row

lib/features/hermes/
├── hermes_analytics_screen.dart         ← Analytics tab container
└── widgets/
    ├── hermes_token_chart.dart          ← 7-day area chart
    └── hermes_cost_ledger.dart          ← Per-model cost table
```

---

## Test Scenarios

**Chart:**
- 7 days of sessions → chart shows 7 data points
- Only 2 days of sessions → chart shows 2 points, no crash
- Zero sessions → empty state message, no crash

**Cost Ledger:**
- `claude-haiku-4-5-20251001` with actual_cost_usd set → appears in PAID section
- `kimi-k2.6:cloud` (Ollama) → appears in LOCAL/SUBSCRIPTION section
- `neurometric/clawpack` with cost → appears in PAID section
- No sessions → empty state message

**Insights:**
- 3 days of data → peak day insight only
- 7 days with cost increase → peak day + spend trend insights
- Failed cron jobs → cron health warning shown
- Zero data → no insights shown (no crash)

---

*CARMEN PTY LTD — ClawCommander Sprint C: Hermes Analytics Dashboard Spec v1.0*  
*Verified against PocketClaw-source-2026-05-09 and hermes-workspace-main dashboard-aggregator.ts*  
*2026-05-09*
