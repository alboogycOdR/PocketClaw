/// Budgets tab — spend vs limit with progress bar from Paperclip
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/health_bar.dart';

class BudgetsTab extends ConsumerWidget {
  const BudgetsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);

    if (!state.isConnected) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Not connected to Paperclip.',
      );
    }

    final budget = state.budget;
    if (budget == null) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: 'No budget data available.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total budget summary card
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget Overview',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                HealthBar(
                  label: 'Spent / Total',
                  percentage: budget.usagePercent,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _budgetFigure(
                      'Total',
                      budget.totalBudget,
                      Colors.white70,
                    ),
                    _budgetFigure(
                      'Spent',
                      budget.spent,
                      PocketClawTheme.lobsterRed,
                    ),
                    _budgetFigure(
                      'Remaining',
                      budget.remaining,
                      PocketClawTheme.electricTeal,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Category breakdown
        if (budget.categoryBreakdown.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'By Category',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          ...budget.categoryBreakdown.entries.map((entry) {
            final pct = budget.totalBudget > 0
                ? (entry.value / budget.totalBudget * 100)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HealthBar(
                    label: entry.key,
                    percentage: pct,
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _budgetFigure(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
