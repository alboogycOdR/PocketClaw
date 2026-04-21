/// Security tab — Paperclip `GET /activity` (audit log) + OpenClaw device
/// pairing summary. Read-only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../data/models/gateway_event.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/empty_state.dart';

class SecurityDashboardTab extends ConsumerWidget {
  const SecurityDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(paperclipRestClientProvider);
    final activityAsync = ref.watch(paperclipActivityProvider);
    final gwState = ref.watch(gatewayStateProvider);

    if (client == null) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Paperclip not configured.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(paperclipActivityProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GatewayPairingCard(state: gwState),
          const SizedBox(height: 16),
          Text(
            'Audit activity',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          activityAsync.when(
            loading: () => const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  friendlyPaperclipError(e),
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return Card(
                  margin: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No audit entries yet.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                );
              }
              return Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final e in entries.take(30)) _ActivityRow(entry: e),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GatewayPairingCard extends StatelessWidget {
  final GatewayState state;

  const _GatewayPairingCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final paired = state == GatewayState.connected;
    final color = paired
        ? const Color(0xFF4CAF50)
        : state == GatewayState.pairingRequired
            ? const Color(0xFFFFB74D)
            : PocketClawTheme.lobsterRed;
    final label = switch (state) {
      GatewayState.connected => 'OpenClaw paired',
      GatewayState.pairingRequired => 'Awaiting pairing approval',
      GatewayState.connecting ||
      GatewayState.reconnecting =>
        'Connecting…',
      _ => 'Not connected',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Icon(
          paired ? Icons.verified_user : Icons.shield_outlined,
          color: color,
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Ed25519 device identity · ${paired ? "active" : "inactive"}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final PaperclipActivityEntry entry;

  const _ActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.history, size: 14, color: Colors.white38),
      title: Text(
        '${entry.actor ?? 'someone'} ${entry.action ?? '—'}',
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: entry.entityType != null
          ? Text(
              '${entry.entityType}${entry.entityId != null ? ' ${entry.entityId}' : ''}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: Colors.white38,
              ),
            )
          : null,
      trailing: entry.createdAt != null
          ? Text(
              entry.createdAt!.timeAgo,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: Colors.white38,
              ),
            )
          : null,
    );
  }
}
