/// Per-model token + cost breakdown. Splits paid (real $) from local /
/// subscription rows so the user can see what's actually costing money.
/// Ported from hermes-workspace `cost-ledger-card.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/hermes/models/hermes_analytics.dart';
import '../../../data/providers/hermes_data_providers.dart';
import '../../../shared/utils/analytics_formatters.dart';

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
              const _SectionHeader(
                label: 'PAID',
                color: PocketClawTheme.lobsterRed,
              ),
              ...paid.map((m) => _ModelRow(stats: m, showCost: true)),
            ],
            if (free.isNotEmpty) ...[
              if (paid.isNotEmpty) const SizedBox(height: 12),
              const _SectionHeader(
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
          color: color.withAlpha(153),
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
          Text(
            formatTokens(stats.totalTokens),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(
              showCost ? formatCostUsd(stats.costUsd) : 'free',
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(
                fontSize: showCost ? 12 : 11,
                fontWeight: showCost ? FontWeight.w600 : FontWeight.normal,
                color: showCost
                    ? PocketClawTheme.lobsterRed
                    : Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
