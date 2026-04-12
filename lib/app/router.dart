/// Pocket Claw GoRouter configuration with bottom navigation shell
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/chat/chat_screen.dart';
import '../features/company/company_screen.dart';
import '../features/memory/memory_screen.dart';
import '../features/packs/pack_picker_screen.dart';
import '../features/mission_control/agents_screen.dart';
import '../features/mission_control/cost_screen.dart';
import '../features/mission_control/dashboard_screen.dart';
import '../features/mission_control/tasks_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/skills/clawhub_browser.dart';
import '../features/skills/skill_detail.dart';
import '../features/skills/skills_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _rootNavigatorKey = rootNavigatorKey;

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Onboarding (outside shell)
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const WelcomeScreen(),
    ),

    // Pack picker (outside shell — used from Company Overview + onboarding)
    GoRoute(
      path: '/packs',
      builder: (context, state) => PackPickerScreen(
        onComplete: () => Navigator.of(context).pop(),
      ),
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
            GoRoute(
              path: '/',
              builder: (context, state) => const ChatScreen(),
            ),
          ],
        ),

        // Mission Control tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/control',
              builder: (context, state) => const DashboardScreen(),
              routes: [
                GoRoute(
                  path: 'agents',
                  builder: (context, state) => const AgentsScreen(),
                ),
                GoRoute(
                  path: 'tasks',
                  builder: (context, state) => const TasksScreen(),
                ),
                GoRoute(
                  path: 'cost',
                  builder: (context, state) => const CostScreen(),
                ),
              ],
            ),
          ],
        ),

        // Memory tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/memory',
              builder: (context, state) => const MemoryScreen(),
            ),
          ],
        ),

        // Skills tab
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

        // Company tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/company',
              builder: (context, state) => const CompanyScreen(),
            ),
          ],
        ),

        // Settings tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _AppShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Control',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: 'Memory',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension),
            label: 'Skills',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Company',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
