/// Mission Control — server-aware. Top-level [DashboardScreen]
/// switches on [activeServerProvider]:
///   - OpenClaw → [_OpenClawDashboard] (the existing stat cards + health
///     + activity + cron + Channels dashboard)
///   - Hermes   → [_HermesDashboardEmbed] (HermesManagementScreen tabs
///     embedded inline; Sessions / Memory / Cron / Skills / Logs)
///   - Local    → [LocalModelDashboard] (active model + RAM stats)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/server_providers.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/agent_scope_badge.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/stat_card.dart';
import '../hermes/hermes_management_screen.dart';
import 'health_widget.dart';
import 'local_model_dashboard.dart';
import 'mission_control_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    return switch (server) {
      ActiveServer.openclaw => const _OpenClawDashboard(),
      ActiveServer.hermes => const _HermesDashboardEmbed(),
      ActiveServer.local => const LocalModelDashboard(),
    };
  }
}

class _HermesDashboardEmbed extends StatelessWidget {
  const _HermesDashboardEmbed();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Control'),
        actions: const [
          AgentScopeBadge(),
          SizedBox(width: 8),
        ],
      ),
      body: const HermesManagementScreen(embeddedMode: true),
    );
  }
}

class _OpenClawDashboard extends ConsumerWidget {
  const _OpenClawDashboard();

  void _refresh(WidgetRef ref) {
    ref.invalidate(mcHealthProvider);
    ref.invalidate(mcUsageProvider);
    ref.invalidate(mcAgentsProvider);
    ref.invalidate(mcSessionsCountProvider);
    ref.invalidate(mcCronJobsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restClient = ref.watch(gatewayRestClientProvider);
    final healthAsync = ref.watch(mcHealthProvider);
    final usageAsync = ref.watch(mcUsageProvider);
    final agentsAsync = ref.watch(mcAgentsProvider);
    final sessionsAsync = ref.watch(mcSessionsCountProvider);
    final cronsAsync = ref.watch(mcCronJobsProvider);

    if (restClient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mission Control')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Not connected to Gateway.\nConfigure your server in Settings.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Control'),
        actions: [
          const AgentScopeBadge(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stat cards row
            Row(
              children: [
                Expanded(
                  child: agentsAsync.when(
                    data: (agents) {
                      final active = agents
                          .where((a) => a.status.name == 'active')
                          .length;
                      return StatCard(
                        icon: Icons.smart_toy,
                        title: 'Agents',
                        value: '${agents.length}',
                        subtitle: '$active active',
                        iconColor: PocketClawTheme.success,
                        onTap: () => context.go('/control/agents'),
                      );
                    },
                    loading: () => const _ShimmerCard(),
                    error: (_, __) => StatCard(
                      icon: Icons.smart_toy,
                      title: 'Agents',
                      value: '--',
                      subtitle: 'error',
                      iconColor: PocketClawTheme.lobsterRed,
                      onTap: () => context.go('/control/agents'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: sessionsAsync.when(
                    data: (count) => StatCard(
                      icon: Icons.chat_bubble_outline,
                      title: 'Sessions',
                      value: '$count',
                      subtitle: 'recent',
                      iconColor: PocketClawTheme.electricTeal,
                      onTap: () => context.go('/control/sessions'),
                    ),
                    loading: () => const _ShimmerCard(),
                    error: (_, __) => StatCard(
                      icon: Icons.chat_bubble_outline,
                      title: 'Sessions',
                      value: '--',
                      subtitle: 'error',
                      iconColor: PocketClawTheme.lobsterRed,
                      onTap: () => context.go('/control/sessions'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: usageAsync.when(
                    data: (usage) => StatCard(
                      icon: Icons.attach_money,
                      title: 'Cost Today',
                      value: usage.costToday.asCurrency,
                      subtitle: '${usage.costMonth.asCurrency}/mo',
                      iconColor: PocketClawTheme.warning,
                      onTap: () => context.go('/control/cost'),
                    ),
                    loading: () => const _ShimmerCard(),
                    error: (_, __) => StatCard(
                      icon: Icons.attach_money,
                      title: 'Cost Today',
                      value: '--',
                      subtitle: 'error',
                      iconColor: PocketClawTheme.lobsterRed,
                      onTap: () => context.go('/control/cost'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // System health
            healthAsync.when(
              data: (health) => HealthWidget(health: health),
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
                  child: Text('Failed to load health: $e',
                      style: const TextStyle(color: Colors.white38)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Recent Activity (from WebSocket stream)
            _SectionHeader(
              title: 'Recent Activity',
              onViewAll: () => context.go('/control/activity'),
            ),
            const SizedBox(height: 8),
            _buildRecentActivity(ref),

            const SizedBox(height: 16),

            // Next Cron Jobs
            _SectionHeader(
              title: 'Upcoming Jobs',
              onViewAll: () => context.go('/control/cron'),
            ),
            const SizedBox(height: 8),
            cronsAsync.when(
              data: (crons) {
                final enabled = crons.where((c) => c.enabled).take(3).toList();
                if (enabled.isEmpty) {
                  return Card(
                    margin: EdgeInsets.zero,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text('No upcoming jobs',
                            style: TextStyle(color: Colors.white38)),
                      ),
                    ),
                  );
                }
                return Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: enabled.map((job) {
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.schedule,
                          size: 16,
                          color: PocketClawTheme.electricTeal,
                        ),
                        title: Text(
                          job.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: Text(
                          job.nextRunAt != null
                              ? job.nextRunAt!.toLocal().toString().split('.').first
                              : '',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => Card(
                margin: EdgeInsets.zero,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('Failed to load cron jobs',
                        style: TextStyle(color: Colors.white38)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick links row
            Row(
              children: [
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.podcasts_outlined,
                          size: 18, color: PocketClawTheme.electricTeal),
                      title: const Text(
                        'Channels',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          size: 16, color: Colors.white38),
                      onTap: () => context.go('/control/channels'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(WidgetRef ref) {
    final activityAsync = ref.watch(mcActivityProvider);
    return activityAsync.when(
      data: (events) {
        final display = events.take(5).toList();
        if (display.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No recent activity',
                    style: TextStyle(color: Colors.white38)),
              ),
            ),
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: display.map((event) {
              return ListTile(
                dense: true,
                leading: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: event.agentId != null
                        ? PocketClawTheme.electricTeal
                        : Colors.white38,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  event.message,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: Text(
                  event.timestamp.timeAgo,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: Colors.white38,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => Card(
        margin: EdgeInsets.zero,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('Waiting for events...',
                style: TextStyle(color: Colors.white38)),
          ),
        ),
      ),
      error: (_, __) => Card(
        margin: EdgeInsets.zero,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No live connection',
                style: TextStyle(color: Colors.white38)),
          ),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white70,
              ),
        ),
        const Spacer(),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All'),
          ),
      ],
    );
  }
}
