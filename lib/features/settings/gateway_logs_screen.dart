/// OpenClaw gateway log viewer — tails `journalctl -u openclaw-gateway`
/// over SSH. Matches the colour-coding used by the Hermes log viewer.
/// SPEC-OpenClaw-Improvements §6.1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/ssh_providers.dart';
import '../../shared/widgets/empty_state.dart';

class GatewayLogsScreen extends ConsumerWidget {
  const GatewayLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLines = ref.watch(openClawLogsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gateway Logs',
          style: GoogleFonts.jetBrainsMono(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(openClawLogsProvider),
          ),
        ],
      ),
      body: asyncLines.when(
        data: (lines) {
          if (lines.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(openClawLogsProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.terminal,
                    message: 'No log lines (or SSH not configured)',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(openClawLogsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: lines.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: SelectableText(
                  lines[i],
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: _colourForLine(lines[i]),
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to read log: $e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(openClawLogsProvider),
        ),
      ),
    );
  }

  Color _colourForLine(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('error') ||
        lower.contains('fatal') ||
        lower.contains(' err ')) {
      return PocketClawTheme.lobsterRed;
    }
    if (lower.contains('warn')) return PocketClawTheme.warning;
    if (lower.contains('info')) return Colors.white70;
    return Colors.white60;
  }
}
