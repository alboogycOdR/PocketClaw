/// Budgets tab — `GET /costs/summary` + `GET /costs/by-agent`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

class BudgetsTab extends ConsumerWidget {
  const BudgetsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(paperclipRestClientProvider);
    final summaryAsync = ref.watch(paperclipCostSummaryProvider);
    final byAgentAsync = ref.watch(paperclipCostByAgentProvider);

    if (client == null) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Paperclip not configured.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(paperclipCostSummaryProvider);
        ref.invalidate(paperclipCostByAgentProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          summaryAsync.when(
            loading: () => const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  friendlyPaperclipError(e),
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            ),
            data: (summary) {
              if (summary == null) {
                return const EmptyState(
                  icon: Icons.attach_money,
                  message: 'No cost data yet.',
                );
              }
              return _SummaryCard(summary: summary);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'By agent',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          byAgentAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text(
              friendlyPaperclipError(e),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            data: (agents) {
              if (agents.isEmpty) {
                return Card(
                  margin: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No per-agent spend yet.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                );
              }
              return Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final a in agents) _AgentRow(row: a),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final PaperclipCostSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = (summary.utilisation * 100).clamp(0, 100).toInt();
    final hot = pct >= 80;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Monthly spend',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  '$pct%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hot
                        ? PocketClawTheme.lobsterRed
                        : PocketClawTheme.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: summary.utilisation.clamp(0, 1).toDouble(),
              backgroundColor: Colors.white10,
              color: hot
                  ? PocketClawTheme.lobsterRed
                  : PocketClawTheme.warning,
              minHeight: 6,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white54),
                ),
                Text(
                  '\$${summary.spentDollars.toStringAsFixed(2)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white54),
                ),
                Text(
                  '\$${summary.budgetDollars.toStringAsFixed(2)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Remaining',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white54),
                ),
                Text(
                  '\$${summary.remainingDollars.toStringAsFixed(2)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: PocketClawTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  final PaperclipAgentCost row;

  const _AgentRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final hot = row.budgetCents > 0 &&
        (row.spentCents / row.budgetCents) >= 0.8;
    return ListTile(
      dense: true,
      title: Text(
        row.agentName ?? row.agentId,
        style: const TextStyle(fontSize: 13, color: Colors.white),
      ),
      trailing: Text(
        '\$${row.spentDollars.toStringAsFixed(2)}'
        '${row.budgetCents > 0 ? ' / \$${row.budgetDollars.toStringAsFixed(2)}' : ''}',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: hot ? PocketClawTheme.lobsterRed : Colors.white70,
        ),
      ),
    );
  }
}
