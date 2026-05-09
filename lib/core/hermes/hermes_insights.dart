/// Derives short plain-language sentences from Hermes analytics.
/// Pure computation on daily stats + model totals + cron health —
/// no AI calls. Ported from hermes-workspace `lib/insights.ts`.
library;

import 'models/hermes_analytics.dart';
import '../../shared/utils/analytics_formatters.dart';

enum InsightTone { info, positive, warn }

class DashboardInsight {
  final String text;
  final InsightTone tone;

  const DashboardInsight({required this.text, required this.tone});
}

class HermesInsightsEngine {
  static List<DashboardInsight> build({
    required List<HermesDailyStats> daily,
    required List<HermesModelStats> models,
    int? failedCronCount,
  }) {
    final insights = <DashboardInsight>[];

    // Peak usage day — needs ≥3 days of data to be meaningful
    if (daily.length >= 3) {
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

    // Cost trend — first half vs second half of the window
    if (daily.length >= 6) {
      final mid = daily.length ~/ 2;
      var priorCost = 0.0;
      var recentCost = 0.0;
      for (var i = 0; i < mid; i++) {
        priorCost += daily[i].costUsd;
      }
      for (var i = mid; i < daily.length; i++) {
        recentCost += daily[i].costUsd;
      }

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

    // Cron health
    if (failedCronCount != null && failedCronCount > 0) {
      insights.add(DashboardInsight(
        tone: InsightTone.warn,
        text: '$failedCronCount cron '
            '${failedCronCount == 1 ? 'job' : 'jobs'} '
            'failed recently — check the Cron tab.',
      ));
    }

    // Activity streak
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
