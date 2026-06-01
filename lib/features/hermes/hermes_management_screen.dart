/// Hermes management surfaces gated by HermesCommander capabilities.
///
/// Two presentation modes:
///   - standalone — full Scaffold with own AppBar (legacy).
///   - embedded   — caller provides the AppBar (Phase 2 server-aware
///     Mission Control wraps this when active server is Hermes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_flavor.dart';
import '../../app/hermes_commander_theme.dart';
import '../../app/theme.dart';
import '../../data/providers/approvals_providers.dart';
import '../../data/providers/capability_providers.dart';
import '../../data/providers/chat_providers.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../data/providers/hermes_providers.dart';
import '../../data/providers/ssh_providers.dart';
import '../../shared/widgets/approvals_panel.dart';
import '../../shared/widgets/feature_not_available_card.dart';
import 'hermes_analytics_screen.dart';
import 'hermes_channels_screen.dart';
import 'hermes_cron_screen.dart';
import 'hermes_logs_screen.dart';
// Kept after Memory tab removal in v2.6.5 for the HermesNotConfigured
// fallback widget defined in this file — used when SSH host is set but
// the client failed to connect.
import 'hermes_memory_screen.dart';
import 'hermes_sessions_screen.dart';
import 'hermes_skills_screen.dart';

class HermesManagementScreen extends ConsumerWidget {
  /// When true, render only the TabBar + body without an outer
  /// Scaffold/AppBar — the parent (Mission Control router) supplies
  /// the chrome.
  final bool embeddedMode;

  const HermesManagementScreen({super.key, this.embeddedMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sshAsync = ref.watch(sshClientProvider);

    final tabs = TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: const [
        Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Home'),
        Tab(icon: Icon(Icons.history, size: 18), text: 'Sessions'),
        if (kHermesOnlyMode)
          Tab(
            icon: Icon(Icons.psychology_alt_outlined, size: 18),
            text: 'Memory',
          ),
        Tab(icon: Icon(Icons.schedule, size: 18), text: 'Cron'),
        Tab(icon: Icon(Icons.extension_outlined, size: 18), text: 'Skills'),
        Tab(icon: Icon(Icons.terminal, size: 18), text: 'Logs'),
        Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Analytics'),
        if (kHermesOnlyMode)
          Tab(icon: Icon(Icons.pending_actions, size: 18), text: 'Approvals')
        else
          Tab(icon: Icon(Icons.podcasts_outlined, size: 18), text: 'Channels'),
      ],
    );
    const tabCount = kHermesOnlyMode ? 8 : 7;

    final body = sshAsync.when(
      data: (client) {
        // If SSH is null AND no host configured, fall through to the
        // capability-gated tabs (each will render its own helpful card).
        // If SSH is null but a host IS configured, that's a connection
        // error — keep the existing HermesNotConfigured fallback for
        // clarity.
        if (client == null) {
          final sshHost = ref.watch(sshHostProvider);
          if (sshHost.isEmpty) {
            return const _GatedTabBarView();
          }
          return const HermesNotConfigured();
        }
        return const _GatedTabBarView();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 36,
                color: PocketClawTheme.lobsterRed,
              ),
              const SizedBox(height: 12),
              Text(
                'SSH unavailable',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '$e',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    if (embeddedMode) {
      return DefaultTabController(
        length: tabCount,
        child: Column(
          children: [
            // Pending approvals — only visible when there are any.
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ApprovalsPanel(),
            ),
            Material(color: PocketClawTheme.surfaceContainer, child: tabs),
            Expanded(child: body),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: AppBar(title: const Text('Control'), bottom: tabs),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ApprovalsPanel(),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The capability-gated TabBarView. Each child checks the relevant
/// capability and renders a [FeatureNotAvailableCard] when it's missing.
class _GatedTabBarView extends ConsumerWidget {
  const _GatedTabBarView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(serverCapabilitiesProvider);
    return TabBarView(
      children: [
        const _ControlHomeTab(),
        caps.hasSessions
            ? const HermesSessionsTab()
            : const FeatureNotAvailableCard(
                feature: 'Sessions',
                featureKey: 'sessions',
              ),
        if (kHermesOnlyMode)
          caps.hasMemory
              ? const HermesMemoryTab()
              : const FeatureNotAvailableCard(
                  feature: 'Memory',
                  featureKey: 'memory',
                ),
        caps.hasCron
            ? const HermesCronTab()
            : const FeatureNotAvailableCard(
                feature: 'Cron',
                featureKey: 'cron',
              ),
        caps.hasSkills
            ? const HermesSkillsTab()
            : const FeatureNotAvailableCard(
                feature: 'Skills',
                featureKey: 'skills',
              ),
        caps.hasLogs
            ? const HermesLogsTab()
            : const FeatureNotAvailableCard(
                feature: 'Logs',
                featureKey: 'logs',
              ),
        caps.hasAnalytics
            ? const HermesAnalyticsTab()
            : const FeatureNotAvailableCard(
                feature: 'Analytics',
                featureKey: 'analytics',
              ),
        if (kHermesOnlyMode)
          const _HermesApprovalsTab()
        else
          caps.hasChannels
              ? const HermesChannelsTab()
              : const FeatureNotAvailableCard(
                  feature: 'Channels',
                  featureKey: 'channels',
                ),
      ],
    );
  }
}

class _HermesApprovalsTab extends StatelessWidget {
  const _HermesApprovalsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(children: [ApprovalsPanel(), SizedBox(height: 96)]),
    );
  }
}

// ── Control Home ─────────────────────────────────────────────────────────────

class _ControlHomeTab extends ConsumerWidget {
  const _ControlHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Connection'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _RestStatusCard()),
              const SizedBox(width: 8),
              Expanded(child: _SshStatusCard()),
              const SizedBox(width: 8),
              Expanded(child: _AcpStatusCard()),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Agent'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _ModelCard()),
              const SizedBox(width: 8),
              Expanded(child: _ApprovalsCard()),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Activity'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _TodayUsageCard()),
              const SizedBox(width: 8),
              Expanded(child: _RecentSessionsCard()),
            ],
          ),
          const SizedBox(height: 8),
          _CronHealthCard(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: HCTheme.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? const Color(0xFF3FB950) : const Color(0xFFF85149),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.child,
  });
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HCTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HCTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: HCTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: HCTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
    );
  }
}

class _RestStatusCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hermesReachableProvider);
    return _SummaryCard(
      icon: Icons.cloud_outlined,
      label: 'REST',
      child: async.when(
        data: (online) => Row(
          children: [
            _StatusDot(online: online),
            const SizedBox(width: 6),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: online
                    ? const Color(0xFF3FB950)
                    : const Color(0xFFF85149),
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        error: (_, _) => const Row(
          children: [
            _StatusDot(online: false),
            SizedBox(width: 6),
            Text('Error', style: TextStyle(fontSize: 13, color: Color(0xFFF85149))),
          ],
        ),
      ),
    );
  }
}

class _SshStatusCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sshReachableProvider);
    return _SummaryCard(
      icon: Icons.terminal_outlined,
      label: 'SSH',
      child: async.when(
        data: (online) => Row(
          children: [
            _StatusDot(online: online),
            const SizedBox(width: 6),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: online
                    ? const Color(0xFF3FB950)
                    : const Color(0xFFF85149),
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        error: (_, _) => const Row(
          children: [
            _StatusDot(online: false),
            SizedBox(width: 6),
            Text('Error', style: TextStyle(fontSize: 13, color: Color(0xFFF85149))),
          ],
        ),
      ),
    );
  }
}

class _AcpStatusCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acp = ref.watch(activeAcpClientProvider);
    final connected = acp != null;
    return _SummaryCard(
      icon: Icons.bolt_outlined,
      label: 'ACP',
      child: Row(
        children: [
          _StatusDot(online: connected),
          const SizedBox(width: 6),
          Text(
            connected ? 'Active' : 'Idle',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: connected
                  ? const Color(0xFF3FB950)
                  : HCTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hermesModelIdProvider);
    return _SummaryCard(
      icon: Icons.auto_awesome_outlined,
      label: 'Model',
      child: async.when(
        data: (id) {
          final display = id == null
              ? '—'
              : id
                  .split('/')
                  .last
                  .replaceAll(RegExp(r'-\d{8}$'), '');
          return Text(
            display,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HCTheme.gold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
        loading: () => const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        error: (_, _) => const Text('—',
            style: TextStyle(fontSize: 13, color: HCTheme.textSecondary)),
      ),
    );
  }
}

class _ApprovalsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingApprovalCountProvider);
    return _SummaryCard(
      icon: Icons.pending_actions_outlined,
      label: 'Pending Approvals',
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: count > 0 ? HCTheme.gold : HCTheme.textSecondary,
        ),
      ),
    );
  }
}

class _TodayUsageCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hermesDailyStatsProvider);
    return _SummaryCard(
      icon: Icons.token_outlined,
      label: "Today's Tokens",
      child: async.when(
        data: (stats) {
          final today = DateTime.now();
          final todayKey =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          final row = stats.where((s) => s.day == todayKey).firstOrNull;
          if (row == null) {
            return const Text('—',
                style: TextStyle(
                    fontSize: 13, color: HCTheme.textSecondary));
          }
          final tokens = row.totalTokens;
          final display = tokens >= 1000
              ? '${(tokens / 1000).toStringAsFixed(1)}k'
              : '$tokens';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: HCTheme.textPrimary,
                ),
              ),
              if (row.costUsd > 0)
                Text(
                  '\$${row.costUsd.toStringAsFixed(4)}',
                  style: const TextStyle(
                      fontSize: 11, color: HCTheme.textSecondary),
                ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        error: (_, _) => const Text('—',
            style: TextStyle(fontSize: 13, color: HCTheme.textSecondary)),
      ),
    );
  }
}

class _RecentSessionsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hermesSessionsProvider);
    return _SummaryCard(
      icon: Icons.history_outlined,
      label: 'Recent Sessions',
      child: async.when(
        data: (sessions) {
          final cutoff = DateTime.now().subtract(const Duration(days: 1));
          final recent = sessions
              .where((s) =>
                  s.startedAt != null && s.startedAt!.isAfter(cutoff))
              .length;
          return Text(
            '$recent',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: HCTheme.textPrimary,
            ),
          );
        },
        loading: () => const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        error: (_, _) => const Text('—',
            style: TextStyle(fontSize: 13, color: HCTheme.textSecondary)),
      ),
    );
  }
}

class _CronHealthCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hermesCronJobsProvider);
    return _SummaryCard(
      icon: Icons.schedule_outlined,
      label: 'Cron Health',
      child: async.when(
        data: (file) {
          final jobs = file.jobs;
          if (jobs.isEmpty) {
            return const Text(
              'No jobs',
              style: TextStyle(fontSize: 13, color: HCTheme.textSecondary),
            );
          }
          final failed = jobs.where((j) => j.hasFailed).toList();
          final disabled =
              jobs.where((j) => !j.enabled && !j.hasFailed).length;
          if (failed.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: Color(0xFFF85149)),
                    const SizedBox(width: 4),
                    Text(
                      '${failed.length} failed',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF85149),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  failed.first.name,
                  style: const TextStyle(
                      fontSize: 11, color: HCTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          }
          return Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 14, color: Color(0xFF3FB950)),
              const SizedBox(width: 6),
              Text(
                '${jobs.length} jobs healthy',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3FB950),
                ),
              ),
              if (disabled > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '($disabled paused)',
                  style: const TextStyle(
                      fontSize: 11, color: HCTheme.textSecondary),
                ),
              ],
            ],
          );
        },
        loading: () => const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        error: (_, _) => const Text(
          'SSH required',
          style: TextStyle(fontSize: 13, color: HCTheme.textSecondary),
        ),
      ),
    );
  }
}
