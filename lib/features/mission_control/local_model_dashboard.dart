/// Server-aware Mission Control view for `ActiveServer.local`.
///
/// Hermes/OpenClaw both run server-side; Local doesn't have agents,
/// sessions, cron, etc. — it just runs the selected GGUF on-device.
/// This dashboard surfaces the only thing worth showing: which model
/// is loaded, its size, and a path into Settings → Models for swaps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/agent_scope_badge.dart';
import '../../shared/widgets/empty_state.dart';

class LocalModelDashboard extends ConsumerWidget {
  const LocalModelDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(selectedModelConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Model'),
        actions: const [
          AgentScopeBadge(),
          SizedBox(width: 8),
        ],
      ),
      body: model == null
          ? EmptyState(
              icon: Icons.phone_android,
              message: 'No on-device model selected.\n'
                  'Pick one in Settings → Models.',
              actionLabel: 'Open Models',
              onAction: () => context.go('/settings'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.phone_android,
                              size: 20,
                              color: PocketClawTheme.electricTeal,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active model',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          model.displayName,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          model.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Stat(
                              label: 'Size',
                              value:
                                  '${(model.sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
                            ),
                            const SizedBox(width: 24),
                            _Stat(
                              label: 'Min RAM',
                              value:
                                  '${(model.minRamBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: const Text('Switch model'),
                    subtitle: const Text(
                      'Browse the catalogue and download a different one',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.white38),
                    onTap: () => context.go('/settings'),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Local mode runs entirely on this device.\n'
                    'No sessions, agents, or cron — switch to OpenClaw or '
                    'Hermes for those.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: Colors.white38,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
