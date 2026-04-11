/// Execution path indicator chip — shows LOCAL / SERVER / BRIDGE routing
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

/// Which execution path the last message was routed through.
enum ExecutionPath { local, server, bridge }

/// Tracks the execution path chosen by SmartRouter for the most recent message.
final executionPathProvider = StateProvider<ExecutionPath?>((ref) => null);

/// User can override the execution path (e.g. via long-press on the chip).
final executionPathOverrideProvider = StateProvider<ExecutionPath?>((ref) => null);

class ExecutionPathChip extends ConsumerWidget {
  const ExecutionPathChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(executionPathOverrideProvider);
    final detected = ref.watch(executionPathProvider);
    final path = override ?? detected;

    if (path == null) return const SizedBox.shrink();

    final (label, color, icon) = switch (path) {
      ExecutionPath.local => ('LOCAL', PocketClawTheme.electricTeal, Icons.phone_android),
      ExecutionPath.server => ('SERVER', PocketClawTheme.lobsterRed, Icons.cloud_outlined),
      ExecutionPath.bridge => ('BRIDGE', const Color(0xFFFFB74D), Icons.sync_alt),
    };

    return GestureDetector(
      onLongPress: () => _showOverrideMenu(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(60), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            if (override != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.lock_outline, size: 9, color: color.withAlpha(150)),
            ],
          ],
        ),
      ),
    );
  }

  void _showOverrideMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PocketClawTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final current = ref.read(executionPathOverrideProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Override execution path',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.auto_awesome,
                    color: current == null
                        ? PocketClawTheme.lobsterRed
                        : Colors.white54,
                  ),
                  title: const Text('Auto (SmartRouter decides)'),
                  selected: current == null,
                  onTap: () {
                    ref.read(executionPathOverrideProvider.notifier).state = null;
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.phone_android,
                    color: current == ExecutionPath.local
                        ? PocketClawTheme.electricTeal
                        : Colors.white54,
                  ),
                  title: const Text('Local (on-device LLM)'),
                  selected: current == ExecutionPath.local,
                  onTap: () {
                    ref.read(executionPathOverrideProvider.notifier).state =
                        ExecutionPath.local;
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.cloud_outlined,
                    color: current == ExecutionPath.server
                        ? PocketClawTheme.lobsterRed
                        : Colors.white54,
                  ),
                  title: const Text('Server (OpenClaw gateway)'),
                  selected: current == ExecutionPath.server,
                  onTap: () {
                    ref.read(executionPathOverrideProvider.notifier).state =
                        ExecutionPath.server;
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.sync_alt,
                    color: current == ExecutionPath.bridge
                        ? const Color(0xFFFFB74D)
                        : Colors.white54,
                  ),
                  title: const Text('Bridge (local + server)'),
                  selected: current == ExecutionPath.bridge,
                  onTap: () {
                    ref.read(executionPathOverrideProvider.notifier).state =
                        ExecutionPath.bridge;
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
