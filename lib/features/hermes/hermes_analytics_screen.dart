/// Analytics tab for the Hermes management screen — KPI summary,
/// 7-day token chart, per-model cost ledger, and a small insights
/// section. SPEC-SprintC-HermesAnalytics §7.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/hermes/hermes_data_service.dart';
import '../../core/hermes/hermes_insights.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/utils/analytics_formatters.dart';
import '../../shared/widgets/insight_chips.dart';
import 'widgets/hermes_cost_ledger.dart';
import 'widgets/hermes_token_chart.dart';

class HermesAnalyticsTab extends ConsumerWidget {
  const HermesAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costAsync = ref.watch(hermesCostSummaryProvider);
    final dailyAsync = ref.watch(hermesDailyStatsProvider);
    final modelsAsync = ref.watch(hermesModelStatsProvider);
    final cronAsync = ref.watch(hermesCronJobsProvider);

    final insights = dailyAsync.maybeWhen(
      data: (daily) => modelsAsync.maybeWhen(
        data: (models) {
          final failedCrons = cronAsync.maybeWhen(
            data: (file) => file.jobs.where((j) => j.hasFailed).length,
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
        ref.invalidate(hermesCronJobsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (insights.isNotEmpty) InsightChips(insights: insights),
          costAsync.when(
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox.shrink(),
            data: (cost) => _KpiRow(cost: cost),
          ),
          const SizedBox(height: 20),
          const _SectionTitle(title: '7-Day Token Usage'),
          const SizedBox(height: 12),
          const HermesTokenChart(),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Model Breakdown'),
          const SizedBox(height: 12),
          const HermesCostLedger(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

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
          color:
              cost.totalCostUSD > 1 ? const Color(0xFFE53935) : Colors.white70,
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
