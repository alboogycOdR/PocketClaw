/// Mission compose screen — builds an orchestrator prompt and sends
/// it to Hermes via the REST chat endpoint. Hermes's built-in
/// delegation (`delegation.orchestrator_enabled: true` in the
/// server's config) does the actual worker spawning; the UI just
/// fires the seed prompt and points the user at the monitor view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/hermes_providers.dart';

class SwarmComposeScreen extends ConsumerStatefulWidget {
  const SwarmComposeScreen({super.key});

  @override
  ConsumerState<SwarmComposeScreen> createState() =>
      _SwarmComposeScreenState();
}

class _SwarmComposeScreenState extends ConsumerState<SwarmComposeScreen> {
  final _goalCtrl = TextEditingController();
  int _maxParallel = 3;
  bool _supervised = false;
  bool _launching = false;
  String? _error;

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
    setState(() {
      _launching = true;
      _error = null;
    });
    try {
      final client = ref.read(hermesClientProvider);
      if (client == null) throw Exception('Hermes not configured');

      final prompt = _buildOrchestratorPrompt(
        goal: goal,
        maxParallel: _maxParallel,
        supervised: _supervised,
      );

      // Drain the response stream so the orchestrator session actually
      // starts; we don't display the response (the user moves to the
      // monitor screen to watch worker tree).
      await for (final _ in client.chatStream(
        prompt,
        maxTokens: 2048,
      )) {
        // Consume only — first SseTextToken means the orchestrator
        // started talking; we can pop and let the user watch.
      }

      if (mounted) context.go('/swarm');
    } catch (e) {
      if (mounted) {
        setState(() {
          _launching = false;
          _error = '$e';
        });
      }
    }
  }

  String _buildOrchestratorPrompt({
    required String goal,
    required int maxParallel,
    required bool supervised,
  }) =>
      [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Launch swarm',
            style: GoogleFonts.jetBrainsMono(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Quick presets',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              letterSpacing: 0.14,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _presets
                .map((p) => ActionChip(
                      avatar: Icon(p.icon, size: 14),
                      label: Text(p.label,
                          style: const TextStyle(fontSize: 11)),
                      onPressed: () =>
                          setState(() => _goalCtrl.text = p.prompt),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _goalCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mission goal',
              hintText:
                  'Describe what you want the swarm to accomplish…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Text('Max parallel workers',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white70,
                )),
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
              'Require approval before each worker spawns',
              style: TextStyle(fontSize: 12),
            ),
            value: _supervised,
            onChanged: (v) => setState(() => _supervised = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PocketClawTheme.lobsterRed.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: PocketClawTheme.lobsterRed.withAlpha(102)),
              ),
              child: Text(_error!,
                  style: TextStyle(
                    color: PocketClawTheme.lobsterRed,
                    fontSize: 12,
                  )),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _launching ? null : _launch,
            icon: _launching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.rocket_launch_outlined),
            label: Text(_launching ? 'Launching…' : 'Launch swarm'),
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
