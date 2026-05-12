/// Office View — 2D floorplan showing swarm agents as 16×16 pixel-art
/// robots that wander between desks, the water cooler, the coffee
/// machine, lunch, and the meeting table. Position and activity are
/// driven by [agentBehaviorProvider]; visual rendering is
/// [PixelAvatarPainter]. Status overrides (running/thinking/
/// complete/failed) come straight from `HermesSession.swarmStatus`.
///
/// Why a per-agent Timer was avoided: the behavior notifier owns the
/// single 1s ticker that updates *all* agents — keeps the office view
/// rebuilding once a second regardless of how many agents are on
/// the floor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/hermes/models/hermes_session.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'agent_behavior_notifier.dart';
import 'agent_behaviors.dart';
import 'office_painters.dart';
import 'pixel_avatar_painter.dart';

class OfficeViewScreen extends ConsumerWidget {
  const OfficeViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(officeSessionsProvider);
    // Subscribe so the notifier instance is alive while this screen
    // is mounted, even though we read `behaviors` per-agent below.
    final behaviors = ref.watch(agentBehaviorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Office', style: GoogleFonts.jetBrainsMono(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(swarmSessionsProvider),
          ),
        ],
      ),
      body: agentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load office: $e',
        ),
        data: (agents) {
          if (agents.isEmpty) {
            return const EmptyState(
              icon: Icons.workspaces_outline,
              message: 'Office is empty.\nLaunch a swarm to see agents.',
            );
          }
          return LayoutBuilder(builder: (context, constraints) {
            final size = constraints.biggest;
            final chatLines = _buildChatLines(agents, behaviors);

            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: const FloorPainter()),
                ),
                Positioned.fill(child: _OfficeFurniture(size: size)),
                Positioned.fill(
                  child: CustomPaint(
                    painter: ChatLinesPainter(lines: chatLines),
                  ),
                ),
                for (final agent in agents)
                  _AgentNode(
                    key: ValueKey('office-${agent.id}'),
                    agent: agent,
                    state: behaviors[agent.id],
                    area: size,
                  ),
              ],
            );
          });
        },
      ),
    );
  }

  List<ChatLine> _buildChatLines(
    List<HermesSession> agents,
    Map<String, AgentBehaviorState> behaviors,
  ) {
    final lines = <ChatLine>[];
    final byId = {for (final a in agents) a.id: a};
    for (final a in agents) {
      final s = behaviors[a.id];
      if (s == null) continue;
      final tgt = s.chatTarget;
      if (tgt == null) continue;
      final target = byId[tgt];
      if (target == null) continue;
      final ts = behaviors[target.id];
      if (ts == null) continue;
      lines.add(ChatLine(from: s.position, to: ts.position));
    }
    return lines;
  }
}

/// Static labels for the named office areas (water / coffee / lunch /
/// meeting) and faint desk markers.
class _OfficeFurniture extends StatelessWidget {
  final Size size;
  const _OfficeFurniture({required this.size});

  static const _spots = <(OfficePoint, String, IconData)>[
    (kWaterCooler, 'Water', Icons.water_drop_outlined),
    (kCoffeeMachine, 'Coffee', Icons.coffee_outlined),
    (kLunchArea, 'Lunch', Icons.lunch_dining_outlined),
    (kMeetingTable, 'Meeting', Icons.meeting_room_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final desk in kDeskPositions)
          Positioned(
            left: desk.x / 100 * size.width - 7,
            top: desk.y / 100 * size.height - 7,
            child: const _Tag(
              icon: Icons.desktop_windows_outlined,
              label: '',
              dim: true,
            ),
          ),
        for (final spot in _spots)
          Positioned(
            left: spot.$1.x / 100 * size.width - 22,
            top: spot.$1.y / 100 * size.height - 10,
            child: _Tag(icon: spot.$3, label: spot.$2),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dim;
  const _Tag({required this.icon, required this.label, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final color = dim ? Colors.white24 : Colors.white38;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(fontSize: 9, color: color),
          ),
        ],
      ],
    );
  }
}

class _AgentNode extends StatelessWidget {
  final HermesSession agent;
  final AgentBehaviorState? state;
  final Size area;

  const _AgentNode({
    super.key,
    required this.agent,
    required this.state,
    required this.area,
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    final colors = personaFor(agent.id);
    const avatarSize = 56.0;
    final pos = s?.position ?? _fallback(agent.id);

    final left = pos.x / 100 * area.width - avatarSize / 2;
    final top = pos.y / 100 * area.height - avatarSize / 2;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s?.chatMessage != null) _Bubble(text: s!.chatMessage!),
          SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: CustomPaint(
              painter: PixelAvatarPainter(
                bodyColor: colors.body,
                accentColor: colors.accent,
                expression: s?.expression ?? AgentExpression.neutral,
                status: agent.swarmStatus,
                isWalking: s?.isWalking ?? false,
                flipHorizontal: s?.isFacingLeft ?? false,
                walkFrame: s?.walkFrame ?? 0,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              agent.officeDisplayName.length > 14
                  ? '${agent.officeDisplayName.substring(0, 13)}…'
                  : agent.officeDisplayName,
              style: const TextStyle(fontSize: 9, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Deterministic fallback while the behavior notifier seeds.
  OfficePoint _fallback(String id) {
    final hash =
        id.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
    final deskIdx = hash % kDeskPositions.length;
    return kDeskPositions[deskIdx];
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      constraints: const BoxConstraints(maxWidth: 110),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFBBF24).withAlpha(120)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
