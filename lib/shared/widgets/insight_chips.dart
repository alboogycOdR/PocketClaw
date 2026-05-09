/// Renders the row of insight chips at the top of the analytics tab.
library;

import 'package:flutter/material.dart';

import '../../core/hermes/hermes_insights.dart';

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
          InsightTone.warn => Icons.warning_amber_outlined,
          InsightTone.info => Icons.info_outline,
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
                    color: textColor.withAlpha(230),
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
