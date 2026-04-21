/// Org Chart tab — agents roster via Paperclip `GET /agents`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

class OrgChartTab extends ConsumerWidget {
  const OrgChartTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(paperclipRestClientProvider);
    final async = ref.watch(paperclipAgentsProvider);

    if (client == null) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Paperclip not configured.\nSettings → Paperclip Company.',
      );
    }

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        message: friendlyPaperclipError(e),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(paperclipAgentsProvider),
      ),
      data: (agents) {
        if (agents.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(paperclipAgentsProvider),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: EmptyState(
                    icon: Icons.account_tree_outlined,
                    message: 'No agents in this company yet.',
                  ),
                ),
              ],
            ),
          );
        }

        // Group by role for a simple hierarchical feel.
        final byRole = <String, List<PaperclipAgent>>{};
        for (final a in agents) {
          byRole.putIfAbsent(a.role, () => []).add(a);
        }
        final orderedRoles = [
          'ceo',
          'coo',
          'cto',
          'manager',
          'engineer',
          'analyst',
          'designer',
          'ops',
          'member',
        ];
        final sortedKeys = byRole.keys.toList()
          ..sort((a, b) {
            final ia = orderedRoles.indexOf(a);
            final ib = orderedRoles.indexOf(b);
            if (ia == -1 && ib == -1) return a.compareTo(b);
            if (ia == -1) return 1;
            if (ib == -1) return -1;
            return ia.compareTo(ib);
          });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(paperclipAgentsProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final role in sortedKeys) ...[
                _RoleHeader(role: role, count: byRole[role]!.length),
                for (final a in byRole[role]!) _AgentCard(agent: a),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _RoleHeader extends StatelessWidget {
  final String role;
  final int count;

  const _RoleHeader({required this.role, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: PocketClawTheme.electricTeal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            role.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $count',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends ConsumerWidget {
  final PaperclipAgent agent;

  const _AgentCard({required this.agent});

  Color get _statusColor => switch (agent.status) {
        'running' || 'active' => const Color(0xFF4CAF50),
        'paused' => const Color(0xFF7A7A90),
        'error' => PocketClawTheme.lobsterRed,
        'idle' => const Color(0xFFFFB74D),
        _ => Colors.white38,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _statusColor.withAlpha(40),
                  child: Icon(Icons.smart_toy,
                      size: 16, color: _statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      if (agent.title != null)
                        Text(
                          agent.title!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    agent.status,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (agent.budgetMonthlyCents > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: agent.budgetUsageRatio,
                backgroundColor: Colors.white10,
                color: agent.budgetUsageRatio >= 0.8
                    ? PocketClawTheme.lobsterRed
                    : PocketClawTheme.electricTeal,
                minHeight: 3,
              ),
              const SizedBox(height: 4),
              Text(
                '\$${(agent.spentMonthlyCents / 100).toStringAsFixed(2)} '
                '/ \$${(agent.budgetMonthlyCents / 100).toStringAsFixed(2)} '
                'this month',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
