/// 7-day area chart of input + output token usage. Lives in the Hermes
/// Analytics tab. Backed by [hermesDailyStatsProvider].
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/hermes/models/hermes_analytics.dart';
import '../../../data/providers/hermes_data_providers.dart';
import '../../../shared/utils/analytics_formatters.dart';

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
          child: Text(
            'Chart unavailable: $e',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
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
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();

    final inputSpots = <FlSpot>[];
    final outputSpots = <FlSpot>[];
    for (var i = 0; i < stats.length; i++) {
      inputSpots
          .add(FlSpot(i.toDouble(), stats[i].inputTokens.toDouble()));
      outputSpots
          .add(FlSpot(i.toDouble(), stats[i].outputTokens.toDouble()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _LegendDot(color: PocketClawTheme.electricTeal, label: 'Input'),
            SizedBox(width: 16),
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
              maxY: maxTokens > 0 ? maxTokens * 1.15 : 1,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxTokens > 0 ? maxTokens / 4 : 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withAlpha(13),
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
                LineChartBarData(
                  spots: inputSpots,
                  isCurved: true,
                  color: PocketClawTheme.electricTeal,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: PocketClawTheme.electricTeal.withAlpha(31),
                  ),
                ),
                LineChartBarData(
                  spots: outputSpots,
                  isCurved: true,
                  color: PocketClawTheme.lobsterRed,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: PocketClawTheme.lobsterRed.withAlpha(26),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withAlpha(204)),
        ),
      ],
    );
  }
}
