/// Life Architect — GROW + safety status (Sprint 12, spec).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/coaching/grow_state_machine.dart';
import '../../core/coaching/safety_classifier.dart';
import '../../data/providers/core_providers.dart';

class LifeArchitectScreen extends ConsumerStatefulWidget {
  const LifeArchitectScreen({super.key});

  @override
  ConsumerState<LifeArchitectScreen> createState() =>
      _LifeArchitectScreenState();
}

class _LifeArchitectScreenState extends ConsumerState<LifeArchitectScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grow = ref.watch(growSessionProvider);
    final classifier = ref.watch(safetyClassifierProvider);
    final growInChat = ref.watch(growChatModeProvider);

    final sample = _controller.text.isEmpty
        ? 'I want to build a morning routine.'
        : _controller.text;
    final safety = classifier.classifyLocally(sample);

    return Scaffold(
      appBar: AppBar(title: const Text('Life Architect')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('GROW in Chat'),
            subtitle: const Text(
              'Routes the Chat tab through the GROW loop (safety still runs first).',
            ),
            value: growInChat,
            onChanged: (v) async {
              ref.read(growChatModeProvider.notifier).state = v;
              await ref.read(sharedPrefsProvider).setBool('grow_chat_mode', v);
            },
          ),
          const Divider(),
          Text(
            'GROW session',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Phase: ${grow.currentPhase.name.toUpperCase()}',
            style: TextStyle(color: PocketClawTheme.electricTeal),
          ),
          const SizedBox(height: 8),
          Text(
            grow.getPhasePrompt(),
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Your reflection',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: () {
                  final t = _controller.text.trim();
                  if (t.isEmpty) return;
                  ref.read(growSessionProvider.notifier).respondToPhase(t);
                  _controller.clear();
                  setState(() {});
                },
                child: const Text('Submit phase'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () =>
                    ref.read(growSessionProvider.notifier).startSession(),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Safety check (local keyword pre-filter)',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sample classification: $safety',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withAlpha(179),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Turn on GROW in Chat to use the same loop on the Chat tab. '
            'Safety classification runs before every send.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withAlpha(115),
            ),
          ),
        ],
      ),
    );
  }
}
