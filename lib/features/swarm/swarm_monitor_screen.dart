/// Swarm monitor — tree view of orchestrators and their workers,
/// auto-refreshing every 3s while at least one worker is active.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../core/hermes/models/swarm_tree.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../hermes/hermes_session_detail_screen.dart';

class SwarmMonitorScreen extends ConsumerStatefulWidget {
  const SwarmMonitorScreen({super.key});

  @override
  ConsumerState<SwarmMonitorScreen> createState() =>
      _SwarmMonitorScreenState();
}

class _SwarmMonitorScreenState extends ConsumerState<SwarmMonitorScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => ref.invalidate(swarmSessionsProvider),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(swarmSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Swarm', style: GoogleFonts.jetBrainsMono(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Office view',
            icon: const Icon(Icons.business_center_outlined, size: 20),
            onPressed: () => context.push('/office'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(swarmSessionsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/swarm/compose'),
        icon: const Icon(Icons.rocket_launch_outlined),
        label: const Text('Launch'),
      ),
      body: treeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load swarm: $e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(swarmSessionsProvider),
        ),
        data: (tree) {
          if (tree.orchestrators.isEmpty && tree.orphans.isEmpty) {
            return const EmptyState(
              icon: Icons.workspaces_outline,
              message: 'No swarms running.\nTap Launch to start one.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(swarmSessionsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                for (final node in tree.orchestrators)
                  _OrchestratorCard(node: node),
                if (tree.orphans.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'ORPHAN WORKERS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 0.14,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final w in tree.orphans)
                    _WorkerTile(session: w, indented: false),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrchestratorCard extends StatelessWidget {
  final OrchestratorNode node;
  const _OrchestratorCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final orch = node.orchestrator;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined,
                    size: 16, color: PocketClawTheme.electricTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    orch.officeDisplayName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(status: orch.swarmStatus),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Meta(
                  icon: Icons.bolt_outlined,
                  text: '${node.runningCount}/${node.totalCount} active',
                ),
                if (node.doneCount > 0)
                  _Meta(
                    icon: Icons.check_circle_outline,
                    text: '${node.doneCount} done',
                    color: PocketClawTheme.success,
                  ),
                if (node.failedCount > 0)
                  _Meta(
                    icon: Icons.error_outline,
                    text: '${node.failedCount} failed',
                    color: PocketClawTheme.lobsterRed,
                  ),
              ],
            ),
            if (node.workers.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final w in node.workers)
                _WorkerTile(session: w, indented: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkerTile extends StatelessWidget {
  final HermesSession session;
  final bool indented;
  const _WorkerTile({required this.session, required this.indented});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HermesSessionDetailScreen(session: session),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: indented ? 22 : 0,
          right: 0,
          top: 6,
          bottom: 6,
        ),
        child: Row(
          children: [
            Icon(
              indented ? Icons.subdirectory_arrow_right : Icons.person_outline,
              size: 14,
              color: Colors.white38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                session.officeDisplayName,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _StatusPill(status: session.swarmStatus, compact: true),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final SwarmStatus status;
  final bool compact;
  const _StatusPill({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      SwarmStatus.running => ('running', Colors.deepPurpleAccent, Icons.bolt),
      SwarmStatus.thinking => (
          'thinking',
          PocketClawTheme.amber,
          Icons.psychology_outlined,
        ),
      SwarmStatus.complete => ('done', PocketClawTheme.success, Icons.check),
      SwarmStatus.failed => (
          'failed',
          PocketClawTheme.lobsterRed,
          Icons.close,
        ),
      SwarmStatus.error => (
          'error',
          PocketClawTheme.lobsterRed,
          Icons.error_outline,
        ),
      SwarmStatus.idle => ('idle', Colors.white38, Icons.pause),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 9 : 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Meta({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: c),
        ),
      ],
    );
  }
}
