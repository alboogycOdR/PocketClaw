/// Scrollable event log with timestamps and agent badges
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/gateway_event.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/empty_state.dart';
import 'mission_control_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsClient = ref.watch(gatewayClientProvider);
    final activityAsync = ref.watch(mcActivityProvider);

    if (wsClient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity Log')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Not connected to Gateway.\nLive events require a WebSocket connection.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          // Indicator showing live connection
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: PocketClawTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: PocketClawTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: activityAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              message: 'No recent activity\nWaiting for events...',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = events[index];
              return _ActivityTile(event: event);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to connect to event stream\n$e',
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityEvent event;

  const _ActivityTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          SizedBox(
            width: 52,
            child: Text(
              event.timestamp.timeAgo,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: Colors.white38,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Dot
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: event.agentId != null
                  ? PocketClawTheme.electricTeal
                  : Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),

          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.message,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
                if (event.agentId != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PocketClawTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      event.agentId!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
