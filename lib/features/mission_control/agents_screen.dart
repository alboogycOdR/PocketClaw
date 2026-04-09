/// Agents list with status indicators and action buttons
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/agent.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'mission_control_providers.dart';

class AgentsScreen extends ConsumerWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restClient = ref.watch(gatewayRestClientProvider);
    final agentsAsync = ref.watch(mcAgentsProvider);

    if (restClient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agents')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Not connected to Gateway',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(mcAgentsProvider),
          ),
        ],
      ),
      body: agentsAsync.when(
        data: (agents) {
          if (agents.isEmpty) {
            return const EmptyState(
              icon: Icons.smart_toy_outlined,
              message: 'No agents configured',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mcAgentsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: agents.length,
              itemBuilder: (context, index) {
                return _AgentCard(agent: agents[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load agents\n$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(mcAgentsProvider),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final Agent agent;

  const _AgentCard({required this.agent});

  Color get _statusColor => switch (agent.status) {
        AgentStatus.active => const Color(0xFF4CAF50),
        AgentStatus.idle => const Color(0xFFFFB74D),
        AgentStatus.error => const Color(0xFFE53935),
        AgentStatus.paused => const Color(0xFF7A7A90),
      };

  String get _statusLabel => switch (agent.status) {
        AgentStatus.active => 'Active',
        AgentStatus.idle => 'Idle',
        AgentStatus.error => 'Error',
        AgentStatus.paused => 'Paused',
      };

  String get _tokensFormatted {
    if (agent.tokensToday >= 1000) {
      return '${(agent.tokensToday / 1000).toStringAsFixed(1)}k';
    }
    return '${agent.tokensToday}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PocketClawTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      agent.emoji ?? '🤖',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & model
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        agent.model,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _statusColor.withAlpha(80),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _MiniStat(
                  icon: Icons.token,
                  label: 'Tokens today',
                  value: _tokensFormatted,
                ),
                const SizedBox(width: 16),
                if (agent.currentSession != null)
                  _MiniStat(
                    icon: Icons.link,
                    label: 'Session',
                    value: agent.currentSession!,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: agent.status == AgentStatus.paused
                      ? Icons.play_arrow
                      : Icons.pause,
                  label: agent.status == AgentStatus.paused
                      ? 'Resume'
                      : 'Pause',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.list_alt,
                  label: 'Sessions',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: PocketClawTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF3A3A50).withAlpha(80),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
