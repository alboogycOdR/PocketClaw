/// Session History — browsable list of OpenClaw sessions backed by the
/// `sessions.usage` RPC. Replaces the old kanban-style Tasks screen
/// (OpenClaw has no `tasks.*` RPC). See SPEC-OpenClaw-Improvements §3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/gateway_rest.dart';
import '../../data/models/openclaw_session.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/session_providers.dart';
import '../../shared/utils/date_grouping.dart';
import '../../shared/widgets/empty_state.dart';
import 'mission_control_providers.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(gatewayClientProvider);
    final sessionsAsync = ref.watch(mcSessionsProvider);

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sessions')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Not connected to Gateway',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(mcSessionsProvider),
          ),
        ],
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(mcSessionsProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.history_toggle_off,
                    message: 'No sessions yet',
                  ),
                ],
              ),
            );
          }
          final grouped = groupByDate<OpenClawSession>(
            sessions,
            (s) => s.startedAt,
          );
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mcSessionsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in grouped.entries) ...[
                  _GroupHeader(label: entry.key.label),
                  for (final s in entry.value) ...[
                    _SessionCard(session: s),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: friendlyGatewayError(e),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(mcSessionsProvider),
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final OpenClawSession session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the auto-generated title from the title store (Sprint B);
    // fall back to agentId, then to a shortened session id.
    final stored = ref.watch(sessionTitleProvider(session.id));
    final displayTitle = stored ??
        session.agentId ??
        (session.id.length > 12
            ? 'Session ${session.id.substring(0, 8)}…'
            : session.id);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _platformIcon(session.platform),
                  size: 16,
                  color: PocketClawTheme.electricTeal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (session.costUSD != null)
                  Text(
                    '\$${session.costUSD!.toStringAsFixed(4)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: PocketClawTheme.lobsterRed,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (session.model != null)
                  _MetaChip(icon: Icons.memory, text: session.model!),
                _MetaChip(
                  icon: Icons.chat_bubble_outline,
                  text: '${session.messageCount} msg',
                ),
                _MetaChip(
                  icon: Icons.token,
                  text: _fmtTokens(session.totalTokens),
                ),
                if (session.duration != null)
                  _MetaChip(
                    icon: Icons.schedule,
                    text: _fmtDuration(session.duration!),
                  ),
              ],
            ),
            if (session.startedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _fmtStarted(session.startedAt!),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

IconData _platformIcon(String? platform) => switch (platform?.toLowerCase()) {
      'telegram' => Icons.send,
      'cli' => Icons.terminal,
      'pocket-claw' || 'pocketclaw' || 'mobile' => Icons.phone_android,
      'web' => Icons.public,
      _ => Icons.bolt,
    };

String _fmtTokens(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M tok';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k tok';
  return '$n tok';
}

String _fmtDuration(Duration d) {
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  return '${d.inSeconds}s';
}

String _fmtStarted(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          letterSpacing: 0.14,
          fontWeight: FontWeight.w600,
          color: Colors.white38,
        ),
      ),
    );
  }
}
