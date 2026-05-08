/// Hermes management — 5-tab container backed by SSH transport.
/// Sessions, Memory, Cron, Skills, Logs. SPEC-MultiTransport §11.1.
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
  const HermesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sshAsync = ref.watch(sshClientProvider);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Hermes Agent',
            style: GoogleFonts.jetBrainsMono(fontSize: 16),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.history, size: 18), text: 'Sessions'),
              Tab(icon: Icon(Icons.note_alt_outlined, size: 18), text: 'Memory'),
              Tab(icon: Icon(Icons.schedule, size: 18), text: 'Cron'),
              Tab(
                  icon: Icon(Icons.extension_outlined, size: 18),
                  text: 'Skills'),
              Tab(icon: Icon(Icons.terminal, size: 18), text: 'Logs'),
            ],
          ),
        ),
        body: sshAsync.when(
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
        ),
      ),
    );
  }
}
