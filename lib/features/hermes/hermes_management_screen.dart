/// Hermes management — 5-tab container backed by SSH transport.
/// Sessions, Memory, Cron, Skills, Logs. SPEC-MultiTransport §11.1.
///
/// Two presentation modes:
///   - standalone (default) — full Scaffold with own AppBar; reached
///     via the legacy `/hermes` route.
///   - embedded — caller provides the AppBar (Phase 2 server-aware
///     Mission Control wraps this when active server is Hermes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/ssh_providers.dart';
import 'hermes_cron_screen.dart';
import 'hermes_logs_screen.dart';
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

    final tabs = const TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(icon: Icon(Icons.history, size: 18), text: 'Sessions'),
        Tab(icon: Icon(Icons.note_alt_outlined, size: 18), text: 'Memory'),
        Tab(icon: Icon(Icons.schedule, size: 18), text: 'Cron'),
        Tab(icon: Icon(Icons.extension_outlined, size: 18), text: 'Skills'),
        Tab(icon: Icon(Icons.terminal, size: 18), text: 'Logs'),
      ],
    );

    final body = sshAsync.when(
      data: (client) {
        if (client == null) return const HermesNotConfigured();
        return const TabBarView(
          children: [
            HermesSessionsTab(),
            HermesMemoryTab(),
            HermesCronTab(),
            HermesSkillsTab(),
            HermesLogsTab(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
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
      // Caller supplies the AppBar — render TabBar inline above the
      // tab content. Material expects a surface around the TabBar so
      // its underline ink-decoration anchors correctly.
      return DefaultTabController(
        length: 5,
        child: Column(
          children: [
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
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Hermes Agent',
            style: GoogleFonts.jetBrainsMono(fontSize: 16),
          ),
          bottom: tabs,
        ),
        body: body,
      ),
    );
  }
}
