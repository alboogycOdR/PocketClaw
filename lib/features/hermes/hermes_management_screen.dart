/// Hermes management — 6-tab container backed by SSH + analytics.
/// Sessions, Cron, Skills, Logs, Analytics, Channels. Memory used to
/// live here but was redundant with bottom-nav → Memory (which routes
/// to the same HermesMemoryTab when active server is Hermes), removed
/// in v2.6.5. Each tab is gated by [serverCapabilitiesProvider] so the
/// surface stays informative when SSH is missing.
///
/// Two presentation modes:
///   - standalone — full Scaffold with own AppBar (legacy).
///   - embedded   — caller provides the AppBar (Phase 2 server-aware
///     Mission Control wraps this when active server is Hermes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/capability_providers.dart';
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
import 'hermes_memory_screen.dart' show HermesNotConfigured;
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

    const tabs = TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(icon: Icon(Icons.history, size: 18), text: 'Sessions'),
        Tab(icon: Icon(Icons.schedule, size: 18), text: 'Cron'),
        Tab(icon: Icon(Icons.extension_outlined, size: 18), text: 'Skills'),
        Tab(icon: Icon(Icons.terminal, size: 18), text: 'Logs'),
        Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Analytics'),
        Tab(icon: Icon(Icons.podcasts_outlined, size: 18), text: 'Channels'),
      ],
    );

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
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$e',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    if (embeddedMode) {
      return DefaultTabController(
        length: 6,
        child: Column(
          children: [
            // Pending approvals — only visible when there are any.
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ApprovalsPanel(),
            ),
            Material(
              color: PocketClawTheme.surfaceContainer,
              child: tabs,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Hermes Agent',
            style: GoogleFonts.jetBrainsMono(fontSize: 16),
          ),
          bottom: tabs,
        ),
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
        caps.hasSessions
            ? const HermesSessionsTab()
            : const FeatureNotAvailableCard(
                feature: 'Sessions', featureKey: 'sessions'),
        caps.hasCron
            ? const HermesCronTab()
            : const FeatureNotAvailableCard(
                feature: 'Cron', featureKey: 'cron'),
        caps.hasSkills
            ? const HermesSkillsTab()
            : const FeatureNotAvailableCard(
                feature: 'Skills', featureKey: 'skills'),
        caps.hasLogs
            ? const HermesLogsTab()
            : const FeatureNotAvailableCard(
                feature: 'Logs', featureKey: 'logs'),
        caps.hasCost
            ? const HermesAnalyticsTab()
            : const FeatureNotAvailableCard(
                feature: 'Analytics', featureKey: 'cost'),
        caps.hasChannels
            ? const HermesChannelsTab()
            : const FeatureNotAvailableCard(
                feature: 'Channels', featureKey: 'channels'),
      ],
    );
  }
}
