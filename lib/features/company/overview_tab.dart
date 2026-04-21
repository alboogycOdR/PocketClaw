/// Overview tab — single `GET /dashboard` call + company name header.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/stat_card.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(paperclipRestClientProvider);
    final async = ref.watch(paperclipProvider);

    if (client == null) {
      return _NotConfiguredView();
    }

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        message: friendlyPaperclipError(e),
        actionLabel: 'Retry',
        onAction: () => ref.read(paperclipProvider.notifier).refresh(),
      ),
      data: (state) {
        if (state.company == null) {
          return const EmptyState(
            icon: Icons.business_outlined,
            message: 'No company found.\nCreate one in the Paperclip dashboard.',
          );
        }
        return _OverviewContent(state: state);
      },
    );
  }
}

class _OverviewContent extends ConsumerWidget {
  final PaperclipState state;

  const _OverviewContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = state.company!;
    final dashboard = state.dashboard;

    return RefreshIndicator(
      onRefresh: () => ref.read(paperclipProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            company.name,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (company.description != null &&
              company.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              company.description!,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.smart_toy_outlined,
                  title: 'Agents',
                  value: '${dashboard?.totalAgents ?? 0}',
                  subtitle: '${dashboard?.activeAgents ?? 0} active',
                  iconColor: PocketClawTheme.electricTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.task_alt,
                  title: 'Issues',
                  value: '${dashboard?.totalIssues ?? 0}',
                  subtitle:
                      '${dashboard?.inProgressIssues ?? 0} in progress',
                  iconColor: PocketClawTheme.lobsterRed,
                ),
              ),
            ],
          ),

          if (dashboard?.staleTaskCount != null &&
              dashboard!.staleTaskCount > 0) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 18, color: PocketClawTheme.lobsterRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${dashboard.staleTaskCount} stale task${dashboard.staleTaskCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (dashboard?.costs != null) ...[
            const SizedBox(height: 16),
            _CostCard(summary: dashboard!.costs!),
          ],

          if (dashboard != null && dashboard.recentActivity.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recent activity',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final e in dashboard.recentActivity.take(6))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.history,
                          size: 14, color: Colors.white38),
                      title: Text(
                        '${e.actor ?? 'someone'} ${e.action ?? 'did something'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: e.entityType != null
                          ? Text(
                              '${e.entityType}${e.entityId != null ? ' ${e.entityId}' : ''}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  final PaperclipCostSummary summary;

  const _CostCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = (summary.utilisation * 100).clamp(0, 100).toInt();
    final isHot = pct >= 80;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: isHot
                      ? PocketClawTheme.lobsterRed
                      : const Color(0xFFFFB74D),
                ),
                const SizedBox(width: 6),
                Text(
                  'This month',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const Spacer(),
                Text(
                  '$pct%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isHot
                        ? PocketClawTheme.lobsterRed
                        : Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: summary.utilisation.clamp(0, 1).toDouble(),
              backgroundColor: Colors.white10,
              color: isHot
                  ? PocketClawTheme.lobsterRed
                  : const Color(0xFFFFB74D),
            ),
            const SizedBox(height: 6),
            Text(
              '\$${summary.spentDollars.toStringAsFixed(2)} of '
              '\$${summary.budgetDollars.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotConfiguredView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined,
                size: 64,
                color: PocketClawTheme.electricTeal.withAlpha(80)),
            const SizedBox(height: 16),
            Text(
              'Paperclip not configured',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your Paperclip base URL and agent API key in Settings → '
              'Paperclip Company.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
