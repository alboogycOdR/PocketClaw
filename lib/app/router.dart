/// App GoRouter configuration with bottom navigation shell
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_flavor.dart';
import '../data/providers/approvals_providers.dart';
import '../features/academy/academy_screen.dart';
import '../features/ambient/ambient_mini_player.dart';
import '../features/ambient/ambient_screen.dart';
import '../features/ambient/models/tv_channel.dart';
import '../features/ambient/tv_guide_screen.dart';
import '../features/ambient/tv_player_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/hermes/hermes_analytics_screen.dart';
import '../features/hermes/agent_memory_screen.dart';
import '../features/hermes/hermes_cron_screen.dart';
import '../features/hermes/hermes_logs_screen.dart';
import '../features/hermes/hermes_management_screen.dart';
import '../features/hermes/hermes_memory_screen.dart';
import '../features/hermes/open_notebook_screen.dart';
import '../features/hermes/hermes_sessions_screen.dart';
import '../features/hermes/hermes_skills_screen.dart';
import '../features/intel/intel_screen.dart';
import '../features/knowledge_base/knowledge_base_screen.dart';
import '../features/swarm/office_view_screen.dart';
import '../features/swarm/swarm_compose_screen.dart';
import '../features/swarm/swarm_monitor_screen.dart';
// Paperclip "Company" tab hidden 2026-05-08 — keep import out of tree
// while the surface is parked. Re-enable by restoring the branch +
// nav destination below if Paperclip earns its slot back.
// import '../features/company/company_screen.dart';
import '../features/life_architect/life_architect_screen.dart';
import '../features/memory/memory_screen.dart';
import '../features/packs/pack_picker_screen.dart';
import '../features/mission_control/activity_screen.dart';
import '../features/mission_control/agents_screen.dart';
import '../features/mission_control/channels_screen.dart';
import '../features/mission_control/cost_screen.dart';
import '../features/mission_control/cron_screen.dart';
import '../features/mission_control/dashboard_screen.dart';
import '../features/mission_control/sessions_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/osiris_settings.dart';
import '../features/settings/tts_settings_screen.dart';
import '../features/settings/tv_settings_screen.dart';
import '../features/skills/clawhub_browser.dart';
import '../features/skills/skill_detail.dart';
import '../features/skills/skills_screen.dart';
import '../shared/widgets/approvals_panel.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _rootNavigatorKey = rootNavigatorKey;

/// Set by `main()` from SharedPreferences before the router is built.
/// When false, the router redirects first-run users to /onboarding.
bool hasOnboarded = true;

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    if (kHermesOnlyMode) return null;
    final loc = state.matchedLocation;
    // Allow the onboarding flow + its sub-screens through.
    if (loc.startsWith('/onboarding') || loc.startsWith('/packs')) {
      return null;
    }
    if (!hasOnboarded) return '/onboarding';
    return null;
  },
  routes: [
    // Onboarding (outside shell)
    if (!kHermesOnlyMode)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const WelcomeScreen(),
      ),

    // Pack picker (outside shell — used from Company Overview + onboarding)
    if (!kHermesOnlyMode)
      GoRoute(
        path: '/packs',
        builder: (context, state) =>
            PackPickerScreen(onComplete: () => Navigator.of(context).pop()),
      ),

    // Hermes management used to live at /hermes; Phase 2 made it a
    // tab in Mission Control when active server is Hermes (see
    // dashboard_screen.dart::_HermesDashboardEmbed). The standalone
    // route was removed once embedded mode was confirmed on device.

    // Academy Mode + Life Architect — coaching overlays. Full-screen
    // outside the bottom-nav shell so they own the chrome.
    if (!kHermesOnlyMode)
      GoRoute(
        path: '/settings/academy',
        builder: (context, state) => const AcademyScreen(),
      ),
    GoRoute(
      path: '/settings/tts',
      builder: (context, state) => const TtsSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/tv',
      builder: (context, state) => const TvSettingsScreen(),
    ),
    GoRoute(
      path: '/ambient/tv',
      builder: (context, state) {
        final channel = state.extra;
        if (channel is TvChannel) {
          return TvPlayerScreen(channel: channel);
        }
        return const AmbientScreen();
      },
    ),
    GoRoute(
      path: '/ambient/tv/guide',
      builder: (context, state) => const TvGuideScreen(),
    ),
    GoRoute(
      path: '/settings/hermes',
      builder: (context, state) =>
          const SettingsScreen(initialSection: 'hermes'),
    ),
    GoRoute(
      path: '/settings/ssh',
      builder: (context, state) => const SettingsScreen(initialSection: 'ssh'),
    ),
    GoRoute(
      path: '/settings/voice',
      builder: (context, state) =>
          const SettingsScreen(initialSection: 'voice'),
    ),
    GoRoute(
      path: '/settings/security',
      builder: (context, state) =>
          const SettingsScreen(initialSection: 'security'),
    ),
    GoRoute(
      path: '/settings/backup',
      builder: (context, state) =>
          const SettingsScreen(initialSection: 'backup'),
    ),
    if (kHermesOnlyMode)
      GoRoute(
        path: '/settings/osiris',
        builder: (context, state) => const OsirisSettings(),
      ),
    // Settings root — pushed onto the shell from the AppBar gear icon
    // on every top-level screen. Moved out of the bottom nav in v2.8.0
    // to make room for the Ambient tab.
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    if (!kHermesOnlyMode)
      GoRoute(
        path: '/knowledge-base',
        builder: (context, state) => const KnowledgeBaseScreen(),
      ),
    if (!kHermesOnlyMode)
      GoRoute(
        path: '/swarm',
        builder: (context, state) => const SwarmMonitorScreen(),
        routes: [
          GoRoute(
            path: 'compose',
            builder: (context, state) => const SwarmComposeScreen(),
          ),
        ],
      ),
    GoRoute(
      path: '/office',
      builder: (context, state) => const OfficeViewScreen(),
    ),
    if (!kHermesOnlyMode)
      GoRoute(
        path: '/settings/life-architect',
        builder: (context, state) => const LifeArchitectScreen(),
      ),

    // Main app shell with bottom navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return _AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Chat tab
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const ChatScreen()),
          ],
        ),

        // Mission Control tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/control',
              builder: (context, state) => kHermesOnlyMode
                  ? const HermesManagementScreen()
                  : const DashboardScreen(),
              routes: [
                if (kHermesOnlyMode) ...[
                  GoRoute(
                    path: 'sessions',
                    builder: (context, state) => const _HermesControlScaffold(
                      title: 'Sessions',
                      child: HermesSessionsTab(),
                    ),
                  ),
                  GoRoute(
                    path: 'memory',
                    builder: (context, state) => const _HermesControlScaffold(
                      title: 'Memory',
                      child: HermesMemoryTab(),
                    ),
                  ),
                  GoRoute(
                    path: 'cron',
                    builder: (context, state) => const _HermesControlScaffold(
                      title: 'Cron',
                      child: HermesCronTab(),
                    ),
                  ),
                  GoRoute(
                    path: 'skills',
                    builder: (context, state) => const _HermesControlScaffold(
                      title: 'Skills',
                      child: HermesSkillsTab(),
                    ),
                  ),
                  GoRoute(
                    path: 'logs',
                    builder: (context, state) => const _HermesControlScaffold(
                      title: 'Logs',
                      child: HermesLogsTab(),
                    ),
                  ),
                  GoRoute(
                    path: 'analytics',
                    builder: (context, state) => const _HermesControlScaffold(
                      title: 'Analytics',
                      child: HermesAnalyticsTab(),
                    ),
                  ),
                  GoRoute(
                    path: 'approvals',
                    builder: (context, state) => const _HermesApprovalsScreen(),
                  ),
                  GoRoute(
                    path: 'agent-memory',
                    builder: (context, state) => const AgentMemoryScreen(),
                  ),
                  GoRoute(
                    path: 'notebook',
                    builder: (context, state) => const OpenNotebookScreen(),
                  ),
                ] else ...[
                  GoRoute(
                    path: 'agents',
                    builder: (context, state) => const AgentsScreen(),
                  ),
                  GoRoute(
                    path: 'sessions',
                    builder: (context, state) => const SessionsScreen(),
                  ),
                  GoRoute(
                    path: 'cost',
                    builder: (context, state) => const CostScreen(),
                  ),
                  GoRoute(
                    path: 'cron',
                    builder: (context, state) => const CronScreen(),
                  ),
                  GoRoute(
                    path: 'activity',
                    builder: (context, state) => const ActivityScreen(),
                  ),
                  GoRoute(
                    path: 'channels',
                    builder: (context, state) => const ChannelsScreen(),
                  ),
                ],
              ],
            ),
          ],
        ),

        // Memory tab
        if (!kHermesOnlyMode)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/memory',
                builder: (context, state) => const MemoryScreen(),
              ),
            ],
          ),

        // Skills tab
        if (!kHermesOnlyMode)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/skills',
                builder: (context, state) => const SkillsScreen(),
                routes: [
                  GoRoute(
                    path: 'clawhub',
                    builder: (context, state) => const ClawHubBrowser(),
                  ),
                  GoRoute(
                    path: ':name',
                    builder: (context, state) {
                      final name = state.pathParameters['name'] ?? '';
                      return SkillDetailScreen(skillName: name);
                    },
                  ),
                ],
              ),
            ],
          ),

        if (kHermesOnlyMode)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/swarm',
                builder: (context, state) => const SwarmMonitorScreen(),
                routes: [
                  GoRoute(
                    path: 'compose',
                    builder: (context, state) => const SwarmComposeScreen(),
                  ),
                ],
              ),
            ],
          ),

        if (kHermesOnlyMode)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/intel',
                builder: (context, state) => const IntelScreen(),
              ),
            ],
          ),

        // Company tab — HIDDEN 2026-05-08. Paperclip is parked while we
        // focus on OpenClaw + Hermes polish. Restore by uncommenting
        // both this branch and the matching NavigationDestination below.
        //
        // StatefulShellBranch(
        //   routes: [
        //     GoRoute(
        //       path: '/company',
        //       builder: (context, state) => const CompanyScreen(),
        //     ),
        //   ],
        // ),

        // Ambient tab — Focus Sounds + World Radio. Replaces the
        // old Settings shell branch as of v2.8.0; Settings moved out
        // of the bottom nav to a per-screen AppBar gear icon (and a
        // top-level /settings route outside the shell).
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/ambient',
              builder: (context, state) => const AmbientScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const _AppShell({required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalCount = ref.watch(pendingApprovalCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini-player — sits above the nav bar when Focus or Radio
          // is active. Collapses to zero height otherwise.
          const AmbientMiniPlayer(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.chat_outlined),
                selectedIcon: Icon(Icons.chat),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: _NavIconWithBadge(
                  icon: Icons.tune_outlined,
                  count: approvalCount,
                ),
                selectedIcon: _NavIconWithBadge(
                  icon: Icons.tune,
                  count: approvalCount,
                ),
                label: 'Control',
              ),
              if (kHermesOnlyMode) ...[
                const NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree),
                  label: 'Swarm',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public),
                  label: 'Intel',
                ),
              ] else ...[
                const NavigationDestination(
                  icon: Icon(Icons.memory_outlined),
                  selectedIcon: Icon(Icons.memory),
                  label: 'Memory',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.extension_outlined),
                  selectedIcon: Icon(Icons.extension),
                  label: 'Skills',
                ),
              ],
              const NavigationDestination(
                icon: Icon(Icons.headphones_outlined),
                selectedIcon: Icon(Icons.headphones),
                label: 'Ambient',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HermesControlScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _HermesControlScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _HermesApprovalsScreen extends StatelessWidget {
  const _HermesApprovalsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approvals')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [ApprovalsPanel(), SizedBox(height: 96)]),
      ),
    );
  }
}

/// Material icon with a small numeric badge. Used on the Control tab
/// to count pending approvals; the badge collapses when count == 0.
class _NavIconWithBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  const _NavIconWithBadge({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 1),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
