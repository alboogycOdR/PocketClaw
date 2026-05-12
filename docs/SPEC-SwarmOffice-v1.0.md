# ClawCommander — Swarm/Conductor + Office View
## Developer Specification v1.0

**Date:** 2026-05-10  
**Author:** CARMEN PTY LTD  
**Source:** Verified from `hermes-workspace-main` source + live VPS Hermes config  
**Status:** Implementation-ready  
**Estimated effort:** 6–7 days total  

---

## How These Features Work (Demystified)

### Swarm/Conductor

The "too complex" dismissal was based on a misreading. The workspace Conductor is NOT spawning separate Claude Code processes. It is:

1. Building an orchestrator prompt that includes the `workspace-dispatch` skill
2. Sending it to Hermes via the existing REST API
3. Hermes's built-in delegation system (`delegation.orchestrator_enabled: true`) spawns child sessions
4. The UI polls `state.db` via SSH — already done — to show the session tree

Your live Hermes config already has delegation enabled with `max_concurrent_children: 3`. ClawCommander already stores `parentSessionId` in `HermesSession`. The infrastructure is complete. This sprint adds the compose UI and the tree/office display layer.

### Office View

Not 3D. Not a game engine. The workspace renders a 2D flat office using:
- SVG checkered floor (20×14 tiles)
- `div` elements with percentage-based absolute positioning for furniture
- Framer Motion `AnimatePresence` for smooth agent position transitions
- SVG pixel art characters (16×16 viewport, coloured rectangles + paths)

In Flutter this is a `Stack` with `AnimatedPositioned`, `CustomPainter` for floor + connection lines, and a `CustomPainter` pixel avatar. No Flutter Flame, no game engine, no sprite sheets.

---

## Part 1 — Swarm/Conductor

### 1.1 VPS Setup (Pre-Requisite — 30 minutes)

Before any Flutter code, install the `workspace-dispatch` skill on the VPS. This is the SKILL.md that teaches Hermes how to decompose a goal into worker tasks:

```bash
# SSH into VPS
mkdir -p ~/.hermes/skills/workspace-dispatch
cat > ~/.hermes/skills/workspace-dispatch/SKILL.md << 'SKILL'
---
name: workspace-dispatch
description: Orchestrate multi-worker missions by decomposing goals into parallel tasks
---

You are a mission orchestrator. When given a goal, decompose it into
independent worker tasks and delegate each using `delegate_task`.

Rules:
- Spawn workers with clear, self-contained prompts
- Label each worker: "worker-<task-slug>"
- Each prompt must include: task, success criteria, output path
- Do NOT do the work yourself — spawn workers
- Run up to 3 workers in parallel for independent tasks
- After spawning, report your plan and the worker IDs
- Workers write output to /tmp/swarm/<mission-slug>/

Worker prompt format:
  Task: <specific task>
  Goal: <exact end state>
  Output: /tmp/swarm/<slug>/<artifact>
  Done when: <verification command or artifact check>
SKILL
```

Reload skills:
```bash
hermes skills reload
# Verify it appears
hermes skills list | grep workspace-dispatch
```

---

### 1.2 Data Model — Swarm Session

Add to `lib/core/hermes/models/hermes_session.dart`:

```dart
// Add to HermesSession class:

/// True when this is a top-level orchestrator session (has children).
bool get isOrchestrator =>
    parentSessionId == null && displayTitle.contains('conductor');

/// Derived swarm status from session state + staleness.
SwarmStatus get swarmStatus {
  // Use title heuristics + token activity to derive a meaningful status
  final age = DateTime.now().difference(startedAt ?? DateTime(2020));
  if (endedAt != null) {
    return messageCount > 0 ? SwarmStatus.complete : SwarmStatus.failed;
  }
  if (age.inSeconds < 3) return SwarmStatus.running;
  // Distinguish thinking vs running by message count growth
  return SwarmStatus.running;
}

/// Short display name for the office view — strips raw UUIDs.
String get officeDisplayName {
  final t = title?.trim();
  if (t != null && t.isNotEmpty && !_looksLikeUuid(t)) return t;
  final prefix = source == 'telegram' ? 'Task' : 'Worker';
  final suffix = id.length >= 4 ? id.substring(id.length - 4).toUpperCase() : id;
  return '$prefix $suffix';
}

static bool _looksLikeUuid(String s) =>
    RegExp(r'^[0-9a-f-]{8,}$', caseSensitive: false).hasMatch(s);
```

New enum — add to `lib/core/hermes/models/hermes_session.dart`:

```dart
enum SwarmStatus { running, thinking, complete, failed, error, idle }
```

---

### 1.3 Swarm Session Provider

Add to `lib/data/providers/hermes_data_providers.dart`:

```dart
/// Groups active Hermes sessions into orchestrators + their workers.
/// Orchestrators have parentSessionId == null; workers have it set.
final swarmSessionsProvider = FutureProvider<SwarmTree>((ref) async {
  final svc = ref.watch(hermesDataServiceProvider);
  if (svc == null) return const SwarmTree(orchestrators: [], orphans: []);
  final sessions = await svc.getSessions(limit: 50);
  return SwarmTree.build(sessions);
});

/// All sessions that have been active in the last 5 minutes —
/// these appear in the office view.
final officeSessionsProvider = Provider<AsyncValue<List<HermesSession>>>((ref) {
  return ref.watch(swarmSessionsProvider).whenData((tree) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    return [
      ...tree.orchestrators,
      ...tree.workers,
    ].where((s) {
      final last = s.endedAt ?? s.startedAt;
      if (last == null) return true;
      return last.isAfter(cutoff);
    }).toList();
  });
});
```

New model — `lib/core/hermes/models/swarm_tree.dart`:

```dart
// lib/core/hermes/models/swarm_tree.dart
library;

import 'hermes_session.dart';

/// A tree of sessions: orchestrators at the root, workers as children.
class SwarmTree {
  final List<OrchestratorNode> orchestrators;
  final List<HermesSession> orphans; // workers with no matching parent

  const SwarmTree({required this.orchestrators, required this.orphans});

  List<HermesSession> get workers =>
      orchestrators.expand((o) => o.workers).toList();

  static SwarmTree build(List<HermesSession> sessions) {
    final byId = {for (final s in sessions) s.id: s};
    final workers = sessions.where((s) => s.parentSessionId != null).toList();
    final roots = sessions.where((s) => s.parentSessionId == null).toList();

    final nodes = roots.map((root) {
      final children = workers
          .where((w) => w.parentSessionId == root.id)
          .toList()
        ..sort((a, b) =>
            (a.startedAt ?? DateTime(2020))
                .compareTo(b.startedAt ?? DateTime(2020)));
      return OrchestratorNode(orchestrator: root, workers: children);
    }).toList()
      ..sort((a, b) => (b.orchestrator.startedAt ?? DateTime(2020))
          .compareTo(a.orchestrator.startedAt ?? DateTime(2020)));

    final assignedWorkerIds =
        nodes.expand((n) => n.workers.map((w) => w.id)).toSet();
    final orphans =
        workers.where((w) => !assignedWorkerIds.contains(w.id)).toList();

    return SwarmTree(orchestrators: nodes, orphans: orphans);
  }
}

class OrchestratorNode {
  final HermesSession orchestrator;
  final List<HermesSession> workers;

  const OrchestratorNode({
    required this.orchestrator,
    required this.workers,
  });

  int get doneCount =>
      workers.where((w) => w.swarmStatus == SwarmStatus.complete).length;
  int get failedCount =>
      workers.where((w) => w.swarmStatus == SwarmStatus.failed).length;
  int get runningCount =>
      workers.where((w) => w.swarmStatus == SwarmStatus.running).length;
}
```

---

### 1.4 Swarm Compose Screen

**New file: `lib/features/swarm/swarm_compose_screen.dart`**

```dart
// lib/features/swarm/swarm_compose_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/hermes_client.dart';
import '../../data/providers/hermes_providers.dart';

class SwarmComposeScreen extends ConsumerStatefulWidget {
  const SwarmComposeScreen({super.key});

  @override
  ConsumerState<SwarmComposeScreen> createState() => _SwarmComposeScreenState();
}

class _SwarmComposeScreenState extends ConsumerState<SwarmComposeScreen> {
  final _goalCtrl = TextEditingController();
  int _maxParallel = 3;
  bool _supervised = false;
  bool _launching = false;
  String? _error;

  // Role presets — from workspace ROLES.md
  static const _presets = [
    _Preset('Research + Write',
        'Research [topic] thoroughly and produce a comprehensive written report',
        Icons.auto_stories_outlined),
    _Preset('Code Review',
        'Review the code in [path], identify issues, and produce a fix summary',
        Icons.code),
    _Preset('Data Analysis',
        'Analyse [dataset/topic] and produce charts, insights, and a summary',
        Icons.bar_chart),
    _Preset('Trading Analysis',
        'Analyse my XAUUSD session history and produce a performance report with recommendations',
        Icons.candlestick_chart_outlined),
    _Preset('Batch Processing',
        'Process [files/data] and produce [output] for each item',
        Icons.dynamic_feed_outlined),
  ];

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _launch() async {
    final goal = _goalCtrl.text.trim();
    if (goal.isEmpty) {
      setState(() => _error = 'Enter a goal to run');
      return;
    }

    setState(() { _launching = true; _error = null; });

    try {
      final client = ref.read(hermesClientProvider);
      if (client == null) throw Exception('Hermes not configured');

      // Build the orchestrator prompt (same logic as conductor-spawn.ts)
      final prompt = _buildOrchestratorPrompt(goal, _maxParallel, _supervised);

      await client.chat(
        prompt,
        maxTokens: 2048,
      );

      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _launching = false;
        _error = e.toString();
      });
    }
  }

  String _buildOrchestratorPrompt(
      String goal, int maxParallel, bool supervised) {
    return [
      'You are a mission orchestrator. Execute this mission autonomously.',
      '',
      '## Workspace Dispatch Instructions',
      '',
      'Decompose the goal into independent subtasks.',
      'Use delegate_task or create_task to spawn a worker for each subtask.',
      'Label workers as "worker-<task-slug>".',
      'Each worker gets a self-contained prompt with task + success criteria.',
      '',
      '## Mission',
      '',
      'Goal: $goal',
      '',
      'Run up to $maxParallel workers in parallel for independent tasks.',
      if (supervised)
        'Supervised mode: require approval before each worker is spawned.',
      '',
      '## Rules',
      '- Do NOT do the work yourself — spawn workers.',
      '- Do NOT ask for confirmation — start immediately.',
      '- After spawning all workers, report your plan summary.',
      '- Workers write output to /tmp/swarm/ directories.',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Launch Swarm',
            style: GoogleFonts.jetBrainsMono(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Presets ─────────────────────────────────────────────
          Text('Quick presets',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _presets.map((p) => ActionChip(
              avatar: Icon(p.icon, size: 14),
              label: Text(p.label,
                  style: const TextStyle(fontSize: 11)),
              onPressed: () =>
                  setState(() => _goalCtrl.text = p.prompt),
            )).toList(),
          ),
          const SizedBox(height: 20),

          // ── Goal field ───────────────────────────────────────────
          TextField(
            controller: _goalCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mission goal',
              hintText:
                  'Describe what you want the swarm to accomplish...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // ── Options ──────────────────────────────────────────────
          Row(children: [
            Text('Max parallel workers',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, color: Colors.white70)),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {_maxParallel},
              onSelectionChanged: (v) =>
                  setState(() => _maxParallel = v.first),
            ),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Supervised mode'),
            subtitle: const Text(
                'Require your approval before each worker spawns',
                style: TextStyle(fontSize: 12)),
            value: _supervised,
            onChanged: (v) => setState(() => _supervised = v),
            contentPadding: EdgeInsets.zero,
          ),

          // ── Error ────────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 24),

          // ── Launch ───────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _launching ? null : _launch,
            icon: _launching
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.rocket_launch_outlined),
            label: Text(_launching ? 'Launching…' : 'Launch Swarm'),
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preset {
  final String label;
  final String prompt;
  final IconData icon;
  const _Preset(this.label, this.prompt, this.icon);
}
```

---

### 1.5 Swarm Monitor Screen

**New file: `lib/features/swarm/swarm_monitor_screen.dart`**

```dart
// lib/features/swarm/swarm_monitor_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../core/hermes/models/swarm_tree.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../hermes/hermes_session_detail_screen.dart';
import 'office_view.dart';

class SwarmMonitorScreen extends ConsumerWidget {
  const SwarmMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(swarmSessionsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Swarm', style: GoogleFonts.jetBrainsMono(fontSize: 16)),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.account_tree_outlined), text: 'Missions'),
              Tab(icon: Icon(Icons.business_outlined), text: 'Office'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New swarm',
              onPressed: () => context.push('/swarm/compose'),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(swarmSessionsProvider),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // ── Missions tab ─────────────────────────────────────────
            treeAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('$e',
                      style: const TextStyle(color: Colors.redAccent))),
              data: (tree) => tree.orchestrators.isEmpty
                  ? _EmptyState(
                      onLaunch: () => context.push('/swarm/compose'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: tree.orchestrators.length,
                      itemBuilder: (_, i) =>
                          _MissionCard(node: tree.orchestrators[i]),
                    ),
            ),
            // ── Office tab ───────────────────────────────────────────
            const OfficeView(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/swarm/compose'),
          icon: const Icon(Icons.rocket_launch_outlined),
          label: const Text('New Mission'),
          backgroundColor: PocketClawTheme.lobsterRed,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onLaunch;
  const _EmptyState({required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏢', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No active missions',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 8),
          const Text('Launch a swarm to coordinate multiple agents',
              style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onLaunch,
            icon: const Icon(Icons.add),
            label: const Text('Launch first mission'),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final OrchestratorNode node;
  const _MissionCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final orch = node.orchestrator;
    final total = node.workers.length;
    final done = node.doneCount;
    final failed = node.failedCount;
    final running = node.runningCount;
    final progress = total > 0 ? done / total : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(children: [
              const Icon(Icons.account_tree_outlined,
                  size: 16, color: Colors.deepPurpleAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(orch.officeDisplayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
              _StatusChip(status: orch.swarmStatus),
            ]),
          ),

          // Progress bar
          if (total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    color: failed > 0
                        ? PocketClawTheme.lobsterRed
                        : PocketClawTheme.electricTeal,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$done/$total done'
                    '${running > 0 ? " · $running running" : ""}'
                    '${failed > 0 ? " · $failed failed" : ""}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),

          // Workers
          if (node.workers.isNotEmpty) ...[
            const Divider(height: 16),
            ...node.workers.map((w) => _WorkerRow(session: w)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WorkerRow extends StatelessWidget {
  final HermesSession session;
  const _WorkerRow({required this.session});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              HermesSessionDetailScreen(sessionId: session.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor(session.swarmStatus),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(session.officeDisplayName,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70)),
          ),
          Text(
            '${session.totalTokens} tok',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ]),
      ),
    );
  }

  Color _statusColor(SwarmStatus s) => switch (s) {
    SwarmStatus.running   => Colors.blueAccent,
    SwarmStatus.thinking  => Colors.amber,
    SwarmStatus.complete  => Colors.tealAccent,
    SwarmStatus.failed    => Colors.redAccent,
    SwarmStatus.error     => Colors.red,
    SwarmStatus.idle      => Colors.white24,
  };
}

class _StatusChip extends StatelessWidget {
  final SwarmStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SwarmStatus.running  => ('running', Colors.blueAccent),
      SwarmStatus.thinking => ('thinking', Colors.amber),
      SwarmStatus.complete => ('done', Colors.tealAccent),
      SwarmStatus.failed   => ('failed', Colors.redAccent),
      SwarmStatus.error    => ('error', Colors.red),
      SwarmStatus.idle     => ('idle', Colors.white38),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
```

---

## Part 2 — Office View

### 2.1 Agent Behaviour Constants

**New file: `lib/features/swarm/agent_behaviors.dart`**

```dart
// lib/features/swarm/agent_behaviors.dart
library;

import 'dart:math';
import 'package:flutter/material.dart';

// ── Activity and Expression enums ─────────────────────────────────────────

enum AgentActivity {
  idle, walking, coding, thinking,
  waterBreak, coffeeBreak, lunch, meeting,
  chatting, celebrating, frustrated
}

enum AgentExpression { neutral, happy, focused, confused, tired, excited }

// ── Locations (percentage of container width/height) ─────────────────────

class OfficePoint {
  final double x;
  final double y;
  const OfficePoint(this.x, this.y);

  OfficePoint lerp(OfficePoint target, double t) =>
      OfficePoint(x + (target.x - x) * t, y + (target.y - y) * t);

  double distanceTo(OfficePoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
}

const kWaterCooler   = OfficePoint(5, 45);
const kCoffeeMachine = OfficePoint(90, 42);
const kLunchArea     = OfficePoint(88, 85);
const kMeetingTable  = OfficePoint(45, 52);

const kDeskPositions = [
  OfficePoint(18, 28), OfficePoint(42, 28), OfficePoint(66, 28),
  OfficePoint(18, 55), OfficePoint(42, 55), OfficePoint(66, 55),
  OfficePoint(30, 78), OfficePoint(55, 78),
];

// ── Expression map ────────────────────────────────────────────────────────

AgentExpression expressionFor(AgentActivity activity) => switch (activity) {
  AgentActivity.coding      => AgentExpression.focused,
  AgentActivity.thinking    => AgentExpression.confused,
  AgentActivity.waterBreak  => AgentExpression.tired,
  AgentActivity.coffeeBreak => AgentExpression.tired,
  AgentActivity.lunch       => AgentExpression.happy,
  AgentActivity.chatting    => AgentExpression.happy,
  AgentActivity.celebrating => AgentExpression.excited,
  AgentActivity.frustrated  => AgentExpression.confused,
  _                         => AgentExpression.neutral,
};

// ── Activity emoji ────────────────────────────────────────────────────────

String emojiFor(AgentActivity a) => switch (a) {
  AgentActivity.idle        => '🧍',
  AgentActivity.walking     => '🚶',
  AgentActivity.coding      => '💻',
  AgentActivity.thinking    => '💭',
  AgentActivity.waterBreak  => '💧',
  AgentActivity.coffeeBreak => '☕',
  AgentActivity.lunch       => '🍕',
  AgentActivity.meeting     => '🤝',
  AgentActivity.chatting    => '💬',
  AgentActivity.celebrating => '🎉',
  AgentActivity.frustrated  => '😤',
};

// ── Chat message pools ────────────────────────────────────────────────────

const kWorkingMessages = [
  'Almost done...', 'This is interesting', 'Compiling...',
  'Reading docs...', 'Found a bug!', 'Writing tests...',
  'Pushing code...', 'Reviewing PR...',
];
const kBreakMessages = [
  'Need water 💧', 'brb', 'Quick break', 'Coffee time ☕', 'Lunch break 🍕',
];
const kCompleteMessages = ['Done! 🎉', 'Ship it!', 'All green ✅', 'Nailed it!'];
const kFailedMessages = ['Hmm...', 'That\'s broken', 'Debugging...'];
const kChattingMessages = [
  'Check this out', 'Can you review?', 'Nice work!',
  'Need your help', 'What do you think?',
];

String randomMessage(List<String> pool) =>
    pool[Random().nextInt(pool.length)];

// ── Location resolver ─────────────────────────────────────────────────────

OfficePoint locationFor(AgentActivity activity, int deskIndex) {
  final idx = ((deskIndex % kDeskPositions.length) + kDeskPositions.length) %
      kDeskPositions.length;
  return switch (activity) {
    AgentActivity.waterBreak  => kWaterCooler,
    AgentActivity.coffeeBreak => kCoffeeMachine,
    AgentActivity.lunch       => kLunchArea,
    AgentActivity.meeting     => kMeetingTable,
    AgentActivity.chatting    => OfficePoint(
        kMeetingTable.x + cos(idx * 45 * pi / 180) * 6,
        kMeetingTable.y + sin(idx * 45 * pi / 180) * 4),
    AgentActivity.celebrating => OfficePoint(
        kMeetingTable.x + cos(idx * 45 * pi / 180) * 6,
        kMeetingTable.y + sin(idx * 45 * pi / 180) * 4),
    _                         => kDeskPositions[idx],
  };
}

// ── Persona colour assignments ────────────────────────────────────────────

class PersonaColors {
  final Color body;
  final Color accent;
  const PersonaColors(this.body, this.accent);
}

const _personaList = [
  PersonaColors(Color(0xFF3b82f6), Color(0xFF93c5fd)), // blue
  PersonaColors(Color(0xFFa855f7), Color(0xFFd8b4fe)), // purple
  PersonaColors(Color(0xFFf97316), Color(0xFFfdba74)), // orange
  PersonaColors(Color(0xFF10b981), Color(0xFF6ee7b7)), // emerald
  PersonaColors(Color(0xFFf59e0b), Color(0xFFfcd34d)), // amber
  PersonaColors(Color(0xFF06b6d4), Color(0xFF67e8f9)), // cyan
  PersonaColors(Color(0xFFeab308), Color(0xFFfde047)), // yellow
  PersonaColors(Color(0xFFef4444), Color(0xFFfca5a5)), // red
];

PersonaColors personaFor(String sessionId) {
  // Deterministic assignment from session ID hash
  final hash = sessionId.codeUnits.fold(0, (a, b) => a ^ b);
  return _personaList[hash.abs() % _personaList.length];
}

// ── Agent behavior state ──────────────────────────────────────────────────

class AgentBehaviorState {
  final AgentActivity activity;
  final OfficePoint position;
  final OfficePoint targetPosition;
  final OfficePoint deskPosition;
  final AgentExpression expression;
  final String? chatMessage;
  final String? chatTarget;
  final int lastBreakMs;
  final int breakIntervalMs;
  final int activityStartMs;

  const AgentBehaviorState({
    required this.activity,
    required this.position,
    required this.targetPosition,
    required this.deskPosition,
    required this.expression,
    this.chatMessage,
    this.chatTarget,
    required this.lastBreakMs,
    required this.breakIntervalMs,
    required this.activityStartMs,
  });

  bool get isWalking =>
      activity == AgentActivity.walking &&
      position.distanceTo(targetPosition) > 1.5;

  AgentBehaviorState copyWith({
    AgentActivity? activity,
    OfficePoint? position,
    OfficePoint? targetPosition,
    String? chatMessage,
    bool clearChat = false,
    String? chatTarget,
    int? lastBreakMs,
    int? activityStartMs,
  }) =>
      AgentBehaviorState(
        activity:         activity ?? this.activity,
        position:         position ?? this.position,
        targetPosition:   targetPosition ?? this.targetPosition,
        deskPosition:     deskPosition,
        expression:       expressionFor(activity ?? this.activity),
        chatMessage:      clearChat ? null : (chatMessage ?? this.chatMessage),
        chatTarget:       chatTarget ?? this.chatTarget,
        lastBreakMs:      lastBreakMs ?? this.lastBreakMs,
        breakIntervalMs:  breakIntervalMs,
        activityStartMs:  activityStartMs ?? this.activityStartMs,
      );
}
```

---

### 2.2 Agent Behavior Notifier

**New file: `lib/features/swarm/agent_behavior_notifier.dart`**

```dart
// lib/features/swarm/agent_behavior_notifier.dart
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../data/providers/hermes_data_providers.dart';
import 'agent_behaviors.dart';

const _kTickMs       = 1000;
const _kCodingMinMs  = 15000;
const _kCodingMaxMs  = 30000;
const _kBreakMinMs   = 5000;
const _kBreakMaxMs   = 12000;
const _kChatMinMs    = 30000;
const _kChatMaxMs    = 60000;
const _kChatBubbleMs = 4000;
const _kCelebrateMs  = 5000;

int _now() => DateTime.now().millisecondsSinceEpoch;
int _rand(int min, int max) => min + Random().nextInt(max - min);

class AgentBehaviorNotifier
    extends StateNotifier<Map<String, AgentBehaviorState>> {
  AgentBehaviorNotifier(this._ref) : super({}) {
    _startTick();
  }

  final Ref _ref;
  Timer? _timer;
  final _deskAssignments = <String, int>{};
  int _nextDesk = 0;
  int _nextChatVisitAt = _now() + _rand(_kChatMinMs, _kChatMaxMs);

  void _startTick() {
    _timer = Timer.periodic(
      const Duration(milliseconds: _kTickMs),
      (_) => _tick(),
    );
  }

  int _assignDesk(String key) {
    var idx = _deskAssignments[key];
    if (idx != null) return idx;
    final taken = _deskAssignments.values.toSet();
    for (var i = 0; i < kDeskPositions.length; i++) {
      final candidate = (_nextDesk + i) % kDeskPositions.length;
      if (!taken.contains(candidate)) {
        _deskAssignments[key] = candidate;
        _nextDesk = candidate + 1;
        return candidate;
      }
    }
    idx = _nextDesk++ % kDeskPositions.length;
    _deskAssignments[key] = idx;
    return idx;
  }

  AgentBehaviorState _getOrCreate(String key) {
    var s = state[key];
    if (s != null) return s;
    final deskIdx = _assignDesk(key);
    final desk = kDeskPositions[deskIdx];
    s = AgentBehaviorState(
      activity:        AgentActivity.idle,
      position:        desk,
      targetPosition:  desk,
      deskPosition:    desk,
      expression:      AgentExpression.neutral,
      lastBreakMs:     _now(),
      breakIntervalMs: _rand(90000, 210000),
      activityStartMs: _now(),
    );
    return s;
  }

  void _tick() {
    final officeAsync = _ref.read(officeSessionsProvider);
    final sessions = officeAsync.valueOrNull ?? [];
    final activeKeys = {for (final s in sessions) s.id};

    // Remove stale
    final next = Map<String, AgentBehaviorState>.from(state);
    next.removeWhere((k, _) {
      if (!activeKeys.contains(k)) {
        _deskAssignments.remove(k);
        return true;
      }
      return false;
    });

    final now = _now();
    final doChatVisit = now >= _nextChatVisitAt && sessions.length >= 2;
    if (doChatVisit) {
      _nextChatVisitAt = now + _rand(_kChatMinMs, _kChatMaxMs);
    }

    for (final session in sessions) {
      final key = session.id;
      var s = _getOrCreate(key);

      // ── Move toward target ───────────────────────────────────────
      if (s.position.distanceTo(s.targetPosition) > 1.5) {
        s = s.copyWith(
          activity: AgentActivity.walking,
          position: s.position.lerp(s.targetPosition, 0.08),
        );
      } else if (s.activity == AgentActivity.walking) {
        s = s.copyWith(activity: AgentActivity.coding);
      }

      // ── Session-driven overrides ─────────────────────────────────
      if (session.swarmStatus == SwarmStatus.thinking) {
        if (s.activity != AgentActivity.thinking) {
          s = s.copyWith(
            activity: AgentActivity.thinking,
            chatMessage: randomMessage(kWorkingMessages),
          );
        }
      } else if (session.swarmStatus == SwarmStatus.complete &&
          s.activity != AgentActivity.celebrating) {
        s = s.copyWith(
          activity: AgentActivity.celebrating,
          targetPosition: locationFor(AgentActivity.celebrating,
              _deskAssignments[key] ?? 0),
          chatMessage: randomMessage(kCompleteMessages),
          activityStartMs: now,
        );
      } else if (session.swarmStatus == SwarmStatus.failed &&
          s.activity != AgentActivity.frustrated) {
        s = s.copyWith(
          activity: AgentActivity.frustrated,
          chatMessage: randomMessage(kFailedMessages),
        );
      }

      // ── Timed transitions ────────────────────────────────────────
      final activityAge = now - s.activityStartMs;
      switch (s.activity) {
        case AgentActivity.celebrating:
          if (activityAge > _kCelebrateMs) {
            s = s.copyWith(
              activity: AgentActivity.coding,
              targetPosition: s.deskPosition,
              clearChat: true,
              activityStartMs: now,
            );
          }
        case AgentActivity.waterBreak:
        case AgentActivity.coffeeBreak:
        case AgentActivity.lunch:
        case AgentActivity.meeting:
          if (activityAge > _rand(_kBreakMinMs, _kBreakMaxMs)) {
            s = s.copyWith(
              activity: AgentActivity.walking,
              targetPosition: s.deskPosition,
              clearChat: true,
              lastBreakMs: now,
              activityStartMs: now,
            );
          }
        case AgentActivity.coding:
        case AgentActivity.idle:
          // Time for a break?
          if (now - s.lastBreakMs > s.breakIntervalMs &&
              session.swarmStatus == SwarmStatus.running) {
            final breakType = [
              AgentActivity.waterBreak,
              AgentActivity.coffeeBreak,
              AgentActivity.lunch,
              AgentActivity.meeting,
            ][Random().nextInt(4)];
            s = s.copyWith(
              activity: breakType,
              targetPosition: locationFor(breakType,
                  _deskAssignments[key] ?? 0),
              chatMessage: randomMessage(kBreakMessages),
              activityStartMs: now,
            );
          } else if (activityAge > _rand(_kCodingMinMs, _kCodingMaxMs)) {
            // Refresh work chat message
            s = s.copyWith(
              chatMessage: Random().nextBool()
                  ? randomMessage(kWorkingMessages)
                  : null,
              activityStartMs: now,
            );
          }
        default:
          break;
      }

      // ── Chat visit ───────────────────────────────────────────────
      if (doChatVisit &&
          s.activity == AgentActivity.coding &&
          sessions.length >= 2) {
        final others = sessions.where((x) => x.id != key).toList();
        if (others.isNotEmpty) {
          final target = others[Random().nextInt(others.length)];
          s = s.copyWith(
            activity: AgentActivity.chatting,
            targetPosition: locationFor(AgentActivity.chatting,
                _deskAssignments[key] ?? 0),
            chatMessage: randomMessage(kChattingMessages),
            chatTarget: target.id,
            activityStartMs: now,
          );
        }
      }

      // Clear chat bubble after 4s
      if (s.chatMessage != null && now - s.activityStartMs > _kChatBubbleMs) {
        if (s.activity != AgentActivity.celebrating &&
            s.activity != AgentActivity.frustrated) {
          s = s.copyWith(clearChat: true);
        }
      }

      next[key] = s;
    }

    state = next;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final agentBehaviorProvider = StateNotifierProvider<AgentBehaviorNotifier,
    Map<String, AgentBehaviorState>>(
  (ref) => AgentBehaviorNotifier(ref),
);
```

---

### 2.3 Pixel Avatar Painter

**New file: `lib/features/swarm/pixel_avatar_painter.dart`**

```dart
// lib/features/swarm/pixel_avatar_painter.dart
library;

import 'package:flutter/material.dart';
import 'agent_behaviors.dart';

/// Paints a 16×16 pixel art robot avatar onto a [CustomPainter] canvas.
/// Direct translation of PixelAvatar.tsx SVG path commands.
///
/// Pixel grid: 0–15 in both axes. Pass a [size] to scale.
class PixelAvatarPainter extends CustomPainter {
  final Color bodyColor;
  final Color accentColor;
  final AgentExpression expression;
  final SwarmStatus status;
  final bool isWalking;
  final bool flipHorizontal;
  final int walkFrame; // 0 or 1, alternated externally

  const PixelAvatarPainter({
    required this.bodyColor,
    required this.accentColor,
    required this.expression,
    required this.status,
    required this.isWalking,
    required this.flipHorizontal,
    required this.walkFrame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16.0;
    final paint = Paint()..style = PaintingStyle.fill;

    // Flip for direction
    if (flipHorizontal) {
      canvas.scale(-1, 1);
      canvas.translate(-size.width, 0);
    }

    void rect(double x, double y, double w, double h, Color c,
        {double rx = 0}) {
      paint.color = c;
      if (rx > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale),
            Radius.circular(rx * scale),
          ),
          paint,
        );
      } else {
        canvas.drawRect(
            Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale),
            paint);
      }
    }

    void dot(double cx, double cy, double r, Color c) {
      paint.color = c;
      canvas.drawCircle(Offset(cx * scale, cy * scale), r * scale, paint);
    }

    // ── Head ────────────────────────────────────────────────────
    rect(4, 1, 8, 6, bodyColor, rx: 1);

    // ── Antenna ─────────────────────────────────────────────────
    rect(7, 0, 2, 1, accentColor);

    // ── Eyes (expression-dependent) ────────────────────────────
    _paintExpression(canvas, scale, paint, expression);

    // ── Body ────────────────────────────────────────────────────
    rect(3, 7, 10, 5, bodyColor, rx: 1);

    // ── Chest detail ─────────────────────────────────────────────
    rect(6, 8, 4, 3, accentColor.withOpacity(0.6), rx: 0.5);

    // ── Arms ─────────────────────────────────────────────────────
    final leftArmY = isWalking ? (walkFrame == 0 ? 7.0 : 9.0) : 8.0;
    final rightArmY = isWalking ? (walkFrame == 0 ? 9.0 : 7.0) : 8.0;
    rect(1, leftArmY, 2, 3, bodyColor, rx: 0.5);
    rect(13, rightArmY, 2, 3, bodyColor, rx: 0.5);

    // ── Legs ──────────────────────────────────────────────────────
    final leftLegY = isWalking ? (walkFrame == 0 ? 11.0 : 13.0) : 12.0;
    final rightLegY = isWalking ? (walkFrame == 0 ? 13.0 : 11.0) : 12.0;
    rect(5, leftLegY, 2, 3, bodyColor, rx: 0.5);
    rect(9, rightLegY, 2, 3, bodyColor, rx: 0.5);

    // ── Feet ──────────────────────────────────────────────────────
    rect(4, leftLegY + 2, 3, 2, accentColor, rx: 0.5);
    rect(9, rightLegY + 2, 3, 2, accentColor, rx: 0.5);

    // ── Status dot ────────────────────────────────────────────────
    final dotColor = switch (status) {
      SwarmStatus.thinking => Colors.amber,
      SwarmStatus.complete => const Color(0xFF34d399),
      SwarmStatus.failed   => const Color(0xFFf87171),
      SwarmStatus.error    => Colors.red,
      _                    => null,
    };
    if (dotColor != null) dot(14, 2, 1.5, dotColor);
  }

  void _paintExpression(
      Canvas canvas, double scale, Paint paint, AgentExpression expr) {
    void rect(double x, double y, double w, double h, Color c) {
      paint.color = c;
      canvas.drawRect(
          Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale), paint);
    }

    void dot(double cx, double cy, double r, Color c) {
      paint.color = c;
      canvas.drawCircle(Offset(cx * scale, cy * scale), r * scale, paint);
    }

    const white = Colors.white;
    const dark = Color(0xFF1e293b);
    const yellow = Color(0xFFfde047);
    const gray = Color(0xFF94a3b8);

    switch (expr) {
      case AgentExpression.happy:
        // ^ ^ eyes
        final eyePath1 = Path()
          ..moveTo(5 * scale, 4 * scale)
          ..lineTo(6 * scale, 3 * scale)
          ..lineTo(7 * scale, 4 * scale);
        final eyePath2 = Path()
          ..moveTo(9 * scale, 4 * scale)
          ..lineTo(10 * scale, 3 * scale)
          ..lineTo(11 * scale, 4 * scale);
        paint.color = white;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 0.8 * scale;
        canvas.drawPath(eyePath1, paint);
        canvas.drawPath(eyePath2, paint);
        // Smile
        final smilePath = Path();
        smilePath.moveTo(6.5 * scale, 5.5 * scale);
        smilePath.quadraticBezierTo(
            8 * scale, 7 * scale, 9.5 * scale, 5.5 * scale);
        paint.strokeWidth = 0.6 * scale;
        canvas.drawPath(smilePath, paint);
        paint.style = PaintingStyle.fill;
      case AgentExpression.focused:
        // — — narrow eyes
        paint.style = PaintingStyle.fill;
        rect(5, 3.5, 2, 0.8, white);
        rect(9, 3.5, 2, 0.8, white);
      case AgentExpression.confused:
        // Asymmetric eyes
        paint.style = PaintingStyle.fill;
        rect(5, 3, 2, 2, white);
        rect(6, 3, 1, 1, dark);
        rect(9, 4, 2, 2, white);
        rect(10, 4, 1, 1, dark);
        // ? mark — just a dot above right eye
        dot(13.5, 1.5, 0.8, yellow);
      case AgentExpression.tired:
        // Half-closed eyes
        paint.style = PaintingStyle.fill;
        paint.color = white.withOpacity(0.7);
        canvas.drawRect(
            Rect.fromLTWH(5 * scale, 4 * scale, 2 * scale, 1 * scale),
            paint);
        canvas.drawRect(
            Rect.fromLTWH(9 * scale, 4 * scale, 2 * scale, 1 * scale),
            paint);
        // z dots
        dot(12.5, 1.5, 0.6, gray);
        dot(13.5, 0.5, 0.5, gray);
      case AgentExpression.excited:
        // ★ ★ star eyes — approximate with yellow dots
        paint.style = PaintingStyle.fill;
        dot(6, 4, 1.5, yellow);
        dot(10, 4, 1.5, yellow);
        // Open mouth
        dot(8, 6, 0.8, white);
      default: // neutral
        paint.style = PaintingStyle.fill;
        rect(5, 3, 2, 2, white);
        rect(9, 3, 2, 2, white);
        rect(6, 3, 1, 1, dark);
        rect(10, 3, 1, 1, dark);
    }
  }

  @override
  bool shouldRepaint(covariant PixelAvatarPainter old) =>
      old.expression != expression ||
      old.status != status ||
      old.isWalking != isWalking ||
      old.walkFrame != walkFrame ||
      old.flipHorizontal != flipHorizontal;
}
```

---

### 2.4 Office Floor and Connection Line Painters

```dart
// lib/features/swarm/office_painters.dart
library;

import 'package:flutter/material.dart';
import 'agent_behaviors.dart';

/// Checkered floor — 20 columns × 14 rows of alternating dark tiles.
class FloorPainter extends CustomPainter {
  const FloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 20;
    const rows = 14;
    final tileW = size.width / cols;
    final tileH = size.height / rows;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        paint.color = (r + c) % 2 == 0
            ? const Color(0xFF1a1a2e)
            : const Color(0xFF16213e);
        canvas.drawRect(
            Rect.fromLTWH(c * tileW, r * tileH, tileW, tileH), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FloorPainter _) => false;
}

/// Dashed yellow lines connecting agents that are chatting.
class ChatLinesPainter extends CustomPainter {
  final List<({OfficePoint from, OfficePoint to})> lines;

  const ChatLinesPainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final line in lines) {
      final p1 = Offset(line.from.x / 100 * size.width,
          line.from.y / 100 * size.height);
      final p2 = Offset(
          line.to.x / 100 * size.width, line.to.y / 100 * size.height);
      // Draw dashed line manually
      const dashLen = 6.0;
      const gapLen = 4.0;
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final length = (dx * dx + dy * dy).abs() > 0
          ? (dx * dx + dy * dy) < 0 ? 0.0 : _sqrt(dx * dx + dy * dy)
          : 0.0;
      if (length == 0) continue;
      final ux = dx / length;
      final uy = dy / length;
      var dist = 0.0;
      var drawing = true;
      while (dist < length) {
        final segLen = drawing ? dashLen : gapLen;
        final end = dist + segLen > length ? length : dist + segLen;
        if (drawing) {
          canvas.drawLine(
            Offset(p1.dx + ux * dist, p1.dy + uy * dist),
            Offset(p1.dx + ux * end, p1.dy + uy * end),
            paint,
          );
        }
        dist += segLen;
        drawing = !drawing;
      }
    }
  }

  double _sqrt(double v) {
    // Newton's method — avoids dart:math import here
    if (v <= 0) return 0;
    double x = v;
    for (var i = 0; i < 10; i++) x = (x + v / x) / 2;
    return x;
  }

  @override
  bool shouldRepaint(covariant ChatLinesPainter old) => old.lines != lines;
}
```

---

### 2.5 Office View Screen

**New file: `lib/features/swarm/office_view.dart`**

```dart
// lib/features/swarm/office_view.dart
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../data/providers/hermes_data_providers.dart';
import 'agent_behavior_notifier.dart';
import 'agent_behaviors.dart';
import 'office_painters.dart';
import 'pixel_avatar_painter.dart';

class OfficeView extends ConsumerStatefulWidget {
  const OfficeView({super.key});

  @override
  ConsumerState<OfficeView> createState() => _OfficeViewState();
}

class _OfficeViewState extends State<OfficeView> {
  // Walk frame oscillates for leg animation
  int _walkFrame = 0;
  Timer? _walkTimer;

  @override
  void initState() {
    super.initState();
    _walkTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      setState(() => _walkFrame = (_walkFrame + 1) % 2);
    });
  }

  @override
  void dispose() {
    _walkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final officeAsync = ref.watch(officeSessionsProvider);
      final behaviors = ref.watch(agentBehaviorProvider);
      final sessions = officeAsync.valueOrNull ?? [];

      // Build chat connection lines
      final chatLines = <({OfficePoint from, OfficePoint to})>[];
      for (final e in behaviors.entries) {
        final b = e.value;
        if (b.activity == AgentActivity.chatting && b.chatTarget != null) {
          final target = behaviors[b.chatTarget!];
          if (target != null) {
            chatLines.add((from: b.position, to: target.position));
          }
        }
      }

      return LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // ── Floor ──────────────────────────────────────────────
            const Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: FloorPainter())),
            ),

            // ── Radial atmosphere glow ────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.7,
                    colors: [
                      const Color(0xFF3b82f6).withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Ambient particles ─────────────────────────────────
            const _AmbientParticles(),

            // ── Top wall ──────────────────────────────────────────
            Positioned(
              left: 0, top: 0, right: 0,
              height: h * 0.08,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0x66374151),
                  border: Border(
                      bottom: BorderSide(color: Color(0x4D4B5563))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    8,
                    (_) => Container(
                      width: w / 14,
                      height: h * 0.04,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x4D4B5563),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Desks ─────────────────────────────────────────────
            for (final pos in kDeskPositions)
              _OfficeFurniture.desk(pos, w, h),

            // ── Meeting table ─────────────────────────────────────
            _OfficeFurniture.meetingTable(kMeetingTable, w, h),

            // ── Decorations ───────────────────────────────────────
            _OfficeFurniture.waterCooler(kWaterCooler, w, h),
            _OfficeFurniture.coffeeMachine(kCoffeeMachine, w, h),
            _OfficeFurniture.lunchArea(kLunchArea, w, h),
            _OfficeFurniture.plant(const OfficePoint(3, 20), w, h),
            _OfficeFurniture.plant(const OfficePoint(93, 20), w, h),
            _OfficeFurniture.plant(const OfficePoint(3, 75), w, h),
            _OfficeFurniture.plant(const OfficePoint(93, 75), w, h),

            // ── Chat lines ────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: ChatLinesPainter(lines: chatLines),
              ),
            ),

            // ── Whiteboard ────────────────────────────────────────
            Positioned(
              left: w * 0.08,
              top: h * 0.10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xB2111827),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x4D4B5563)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📋 Tasks: ${sessions.length}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 8, color: const Color(0xFF9CA3AF))),
                    Text(
                        '🏃 Active: ${behaviors.values.where((b) => b.activity == AgentActivity.coding || b.activity == AgentActivity.thinking).length}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 8, color: const Color(0xFF9CA3AF))),
                    Text(
                        '✅ Done: ${sessions.where((s) => s.swarmStatus == SwarmStatus.complete).length}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 8, color: const Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),

            // ── Clock ─────────────────────────────────────────────
            Positioned(
              right: w * 0.08,
              top: h * 0.10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xB2111827),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x4D4B5563)),
                ),
                child: Text(
                  _timeNow(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: const Color(0xCC4ADE80),
                  ),
                ),
              ),
            ),

            // ── Agents ───────────────────────────────────────────
            for (final session in sessions)
              _buildAgent(session, behaviors[session.id], w, h),

            // ── Empty state ───────────────────────────────────────
            if (sessions.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏢', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text('Virtual office is empty',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 13, color: Colors.white54)),
                    const SizedBox(height: 4),
                    const Text('Spawn agents to see them work here',
                        style: TextStyle(
                            fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ),

            // ── Footer ────────────────────────────────────────────
            Positioned(
              bottom: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '🦞 ClawCommander Office',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 8, color: Colors.white24),
                ),
              ),
            ),
            Positioned(
              bottom: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${behaviors.length} agents',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 8, color: Colors.white38),
                ),
              ),
            ),
          ],
        );
      });
    });
  }

  Widget _buildAgent(
    HermesSession session,
    AgentBehaviorState? behavior,
    double w,
    double h,
  ) {
    if (behavior == null) return const SizedBox.shrink();
    final persona = personaFor(session.id);
    final leftPct = behavior.position.x / 100;
    final topPct = behavior.position.y / 100;
    const avatarSize = 44.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      left: w * leftPct - avatarSize / 2,
      top: h * topPct - avatarSize / 2,
      child: SizedBox(
        width: avatarSize * 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Activity emoji ─────────────────────────────────
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              builder: (_, t, __) => Transform.translate(
                offset: Offset(0, -3 * (0.5 - (t - 0.5).abs()) * 2),
                child: Text(emojiFor(behavior.activity),
                    style: const TextStyle(fontSize: 12)),
              ),
            ),

            // ── Chat bubble ────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: behavior.chatMessage != null
                  ? Container(
                      key: ValueKey(behavior.chatMessage),
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      constraints: const BoxConstraints(maxWidth: 90),
                      decoration: BoxDecoration(
                        color: const Color(0xE6111827),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0x33FFFFFF)),
                      ),
                      child: Text(
                        behavior.chatMessage!,
                        style: const TextStyle(
                            fontSize: 8, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Pixel avatar ───────────────────────────────────
            CustomPaint(
              size: const Size(avatarSize, avatarSize),
              painter: PixelAvatarPainter(
                bodyColor: persona.body,
                accentColor: persona.accent,
                expression: behavior.expression,
                status: session.swarmStatus,
                isWalking: behavior.isWalking,
                flipHorizontal: behavior.targetPosition.x < behavior.position.x,
                walkFrame: _walkFrame,
              ),
            ),

            // ── Name ──────────────────────────────────────────
            Text(
              session.officeDisplayName,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: persona.body,
                  shadows: const [Shadow(blurRadius: 2)]),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            // ── Status dot + role ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(session.swarmStatus),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  session.source ?? 'agent',
                  style: const TextStyle(
                      fontSize: 7, color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(SwarmStatus s) => switch (s) {
    SwarmStatus.running   => Colors.blueAccent,
    SwarmStatus.thinking  => Colors.amber,
    SwarmStatus.complete  => Colors.tealAccent,
    SwarmStatus.failed    => Colors.redAccent,
    SwarmStatus.error     => Colors.red,
    SwarmStatus.idle      => Colors.white24,
  };

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

// ── Furniture widgets ────────────────────────────────────────────────────────

class _OfficeFurniture extends StatelessWidget {
  final double leftPct;
  final double topPct;
  final Widget child;

  const _OfficeFurniture({
    required this.leftPct,
    required this.topPct,
    required this.child,
  });

  factory _OfficeFurniture.desk(OfficePoint pos, double w, double h) =>
      _OfficeFurniture(
        leftPct: pos.x / 100,
        topPct: pos.y / 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Monitor
            Container(
              width: 40, height: 28,
              decoration: BoxDecoration(
                color: const Color(0x99475569),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2)),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            Container(width: 4, height: 5,
                color: const Color(0x806B7280)),
            Container(
              width: 48, height: 12,
              decoration: BoxDecoration(
                color: const Color(0x664B5563),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );

  factory _OfficeFurniture.meetingTable(OfficePoint pos, double w, double h) =>
      _OfficeFurniture(
        leftPct: pos.x / 100,
        topPct: pos.y / 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90, height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x4D6B7280),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6)],
              ),
            ),
            const Text('Meeting',
                style: TextStyle(fontSize: 7, color: Color(0x994B5563))),
          ],
        ),
      );

  factory _OfficeFurniture.waterCooler(OfficePoint pos, double w, double h) =>
      _OfficeFurniture(
        leftPct: pos.x / 100,
        topPct: pos.y / 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 12, height: 16,
                decoration: BoxDecoration(
                    color: Colors.sky.shade300.withOpacity(0.6),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2)))),
            Container(
                width: 16, height: 24,
                color: const Color(0x66475569)),
            const Text('💧', style: TextStyle(fontSize: 7)),
          ],
        ),
      );

  factory _OfficeFurniture.coffeeMachine(OfficePoint pos, double w, double h) =>
      _OfficeFurniture(
        leftPct: pos.x / 100,
        topPct: pos.y / 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 18, height: 20,
                decoration: BoxDecoration(
                    color: Colors.brown.shade800.withOpacity(0.6),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2)))),
            Container(
                width: 22, height: 7,
                color: Colors.brown.shade700.withOpacity(0.4)),
            const Text('☕', style: TextStyle(fontSize: 7)),
          ],
        ),
      );

  factory _OfficeFurniture.lunchArea(OfficePoint pos, double w, double h) =>
      _OfficeFurniture(
        leftPct: pos.x / 100,
        topPct: pos.y / 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40, height: 10,
                decoration: BoxDecoration(
                    color: const Color(0x4D475569),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 2),
            const Text('🍕 Lunch',
                style: TextStyle(fontSize: 7, color: Color(0x996B7280))),
          ],
        ),
      );

  factory _OfficeFurniture.plant(OfficePoint pos, double w, double h) =>
      _OfficeFurniture(
        leftPct: pos.x / 100,
        topPct: pos.y / 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                    color: Colors.green.shade700.withOpacity(0.6),
                    shape: BoxShape.circle)),
            Container(
                width: 5, height: 6,
                color: Colors.brown.withOpacity(0.4)),
            Container(
                width: 18, height: 10,
                decoration: BoxDecoration(
                    color: Colors.brown.shade600.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final pw = constraints.maxWidth;
      final ph = constraints.maxHeight;
      return Positioned(
        left: pw * leftPct,
        top: ph * topPct,
        child: Transform.translate(
          offset: const Offset(-20, -20),
          child: child,
        ),
      );
    });
  }
}

// Need extension on Colors for sky
extension _SkyColor on Colors {
  static MaterialColor get sky => const MaterialColor(0xFF0EA5E9, {});
}

// ── Ambient particles ────────────────────────────────────────────────────────

class _AmbientParticles extends StatefulWidget {
  const _AmbientParticles();
  @override
  State<_AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<_AmbientParticles>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  static const _count = 12;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _count,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(
            milliseconds: 3000 + (i * 400) % 4000),
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rng = List.generate(_count, (i) => i * 7919 % 100);
    return Stack(
      children: List.generate(_count, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) => Positioned(
            left: MediaQuery.of(context).size.width *
                (rng[i] / 100),
            top: MediaQuery.of(context).size.height *
                    ((rng[(i + 3) % _count]) / 100) -
                _controllers[i].value * 40,
            child: Opacity(
              opacity: _controllers[i].value * 0.6,
              child: Container(
                width: 3, height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
```

---

## Part 3 — Routing + Navigation

### 3.1 New Routes

In `lib/app/router.dart`:

```dart
// Add imports:
import '../features/swarm/swarm_monitor_screen.dart';
import '../features/swarm/swarm_compose_screen.dart';

// Add routes inside the shell:
GoRoute(
  path: '/swarm',
  builder: (_, __) => const SwarmMonitorScreen(),
  routes: [
    GoRoute(
      path: 'compose',
      builder: (_, __) => const SwarmComposeScreen(),
    ),
  ],
),
```

### 3.2 Add Swarm to Bottom Nav

In `_AppShell`, add a Swarm tab to the `NavigationBar`:

```dart
// Add to NavigationBar destinations:
NavigationDestination(
  icon: const Icon(Icons.account_tree_outlined),
  selectedIcon: const Icon(Icons.account_tree),
  label: 'Swarm',
),

// Add path to _tabs list:
'/swarm',  // after '/control'
```

---

## Part 4 — New Files Summary

```
lib/core/hermes/models/
├── swarm_tree.dart              ← OrchestratorNode + SwarmTree + SwarmStatus

lib/data/providers/
└── hermes_data_providers.dart  ← Add swarmSessionsProvider, officeSessionsProvider
    (update existing file)

lib/features/swarm/
├── swarm_compose_screen.dart    ← Goal entry + presets + launch
├── swarm_monitor_screen.dart    ← Missions tree + Office tabs
├── office_view.dart             ← Full office rendering
├── agent_behaviors.dart         ← Constants, enums, state models
├── agent_behavior_notifier.dart ← State machine + ticker
├── pixel_avatar_painter.dart    ← CustomPainter pixel robot
└── office_painters.dart         ← FloorPainter + ChatLinesPainter
```

## Changed Files

| File | Change |
|---|---|
| `lib/app/router.dart` | Add `/swarm` + `/swarm/compose` routes, Swarm bottom nav tab |
| `lib/core/hermes/models/hermes_session.dart` | Add `SwarmStatus`, `swarmStatus`, `officeDisplayName` |
| `lib/data/providers/hermes_data_providers.dart` | Add `swarmSessionsProvider`, `officeSessionsProvider` |

---

## Implementation Order

| Step | Task | Time |
|---|---|---|
| 1 | Install `workspace-dispatch` skill on VPS | 30 min |
| 2 | Add `SwarmStatus`, `swarmStatus`, `officeDisplayName` to `HermesSession` | 20 min |
| 3 | Create `swarm_tree.dart` | 30 min |
| 4 | Add `swarmSessionsProvider` + `officeSessionsProvider` | 20 min |
| 5 | Create `swarm_compose_screen.dart` | 1 hour |
| 6 | Create `swarm_monitor_screen.dart` | 1 hour |
| 7 | Add routes + nav tab | 20 min |
| 8 | **Test swarm launch end-to-end on VPS** | 30 min |
| 9 | Create `agent_behaviors.dart` | 30 min |
| 10 | Create `agent_behavior_notifier.dart` | 1.5 hours |
| 11 | Create `office_painters.dart` | 45 min |
| 12 | Create `pixel_avatar_painter.dart` | 1.5 hours |
| 13 | Create `office_view.dart` | 2 hours |
| 14 | **Test office view with live sessions on device** | 30 min |

**Total: ~6–7 days**

---

*CARMEN PTY LTD — ClawCommander Swarm + Office View Spec v1.0*  
*Verified from hermes-workspace-main source — 2026-05-10*
