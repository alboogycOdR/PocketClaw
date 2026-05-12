/// Office View — 2D floorplan showing active swarm agents as
/// animated avatars. Simplified from the spec's full pixel-art
/// CustomPainter:
///
///   - Floor: CustomPainter drawing a 20×14 checkerboard
///   - Agents: AnimatedPositioned circle avatars (initials inside),
///     coloured by SwarmStatus, status pill above the head
///   - Parent → child connections: dashed lines drawn by another
///     CustomPainter overlay
///
/// Position policy is deterministic so an agent stays put across
/// rebuilds — hash the session id to grid coordinates inside the
/// "working area" rectangle.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';

class OfficeViewScreen extends ConsumerStatefulWidget {
  const OfficeViewScreen({super.key});

  @override
  ConsumerState<OfficeViewScreen> createState() => _OfficeViewScreenState();
}

class _OfficeViewScreenState extends ConsumerState<OfficeViewScreen> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(
      const Duration(seconds: 3),
      (_) => ref.invalidate(swarmSessionsProvider),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(swarmSessionsProvider);

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
      body: tree.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load: $e',
        ),
        data: (t) {
          final agents = <HermesSession>[
            for (final node in t.orchestrators) ...[
              node.orchestrator,
              ...node.workers,
            ],
            ...t.orphans,
          ];
          if (agents.isEmpty) {
            return const EmptyState(
              icon: Icons.workspaces_outline,
              message: 'Office is empty.\nLaunch a swarm to see agents.',
            );
          }
          return LayoutBuilder(builder: (_, constraints) {
            return Stack(
              children: [
                // Checker floor.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FloorPainter(),
                  ),
                ),
                // Connection lines.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConnectionPainter(
                      agents: agents,
                      size: constraints.biggest,
                    ),
                  ),
                ),
                // Avatars.
                for (final agent in agents)
                  _agentPositioned(agent, constraints.biggest),
              ],
            );
          });
        },
      ),
    );
  }

  Widget _agentPositioned(HermesSession agent, Size area) {
    final (xFrac, yFrac) = _positionFor(agent);
    const avatarSize = 56.0;
    final left = (area.width * xFrac) - avatarSize / 2;
    final top = (area.height * yFrac) - avatarSize / 2;
    return AnimatedPositioned(
      key: ValueKey('office-${agent.id}'),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      child: _AgentAvatar(agent: agent),
    );
  }
}

/// Hash session id to a position inside the working area (15-85%
/// of the screen on each axis). Same id → same spot, every time.
(double, double) _positionFor(HermesSession s) {
  final hash = s.id.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
  final xRaw = (hash & 0xFFFF) / 0xFFFF;
  final yRaw = ((hash >> 16) & 0xFFFF) / 0xFFFF;
  // Map raw 0..1 into 0.12..0.88 so avatars stay off the edges.
  final x = 0.12 + xRaw * 0.76;
  final y = 0.18 + yRaw * 0.62;
  return (x, y);
}

class _AgentAvatar extends StatelessWidget {
  final HermesSession agent;
  const _AgentAvatar({required this.agent});

  Color _colorFor(SwarmStatus status) => switch (status) {
        SwarmStatus.running => Colors.deepPurpleAccent,
        SwarmStatus.thinking => PocketClawTheme.amber,
        SwarmStatus.complete => PocketClawTheme.success,
        SwarmStatus.failed => PocketClawTheme.lobsterRed,
        SwarmStatus.error => PocketClawTheme.lobsterRed,
        SwarmStatus.idle => Colors.white38,
      };

  String get _initials {
    final name = agent.officeDisplayName.trim();
    if (name.isEmpty) return '·';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, math.min(2, parts.first.length))
          .toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(agent.swarmStatus);
    final isOrch = agent.isOrchestrator;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(38),
            border: Border.all(color: color, width: isOrch ? 2.5 : 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(64),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(150),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            agent.officeDisplayName.length > 14
                ? '${agent.officeDisplayName.substring(0, 13)}…'
                : agent.officeDisplayName,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _FloorPainter extends CustomPainter {
  const _FloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xFF14110D);
    final light = Paint()..color = const Color(0xFF1A1611);
    canvas.drawRect(Offset.zero & size, dark);

    const cols = 20;
    const rows = 14;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isEven) {
          final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
          canvas.drawRect(rect, light);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPainter oldDelegate) => false;
}

class _ConnectionPainter extends CustomPainter {
  final List<HermesSession> agents;
  final Size size;
  const _ConnectionPainter({required this.agents, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(50)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final byId = {for (final a in agents) a.id: a};
    for (final agent in agents) {
      final parentId = agent.parentSessionId;
      if (parentId == null) continue;
      final parent = byId[parentId];
      if (parent == null) continue;
      final (cx, cy) = _positionFor(agent);
      final (px, py) = _positionFor(parent);
      _drawDashedLine(
        canvas,
        Offset(canvasSize.width * px, canvasSize.height * py),
        Offset(canvasSize.width * cx, canvasSize.height * cy),
        paint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 6.0;
    const gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final start = a + dir * t;
      final end = a + dir * math.min(t + dash, total);
      canvas.drawLine(start, end, p);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) =>
      oldDelegate.agents != agents || oldDelegate.size != size;
}
