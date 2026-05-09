/// Life Architect — GROW + facets + Living Life Blueprint, with the
/// safety classifier always-on at the chat send path.
/// Per SPEC-LifeArchitect-v1.0 §9.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/coaching/facet_coach.dart';
import '../../core/coaching/grow_state_machine.dart';
import '../../data/providers/life_architect_providers.dart';

class LifeArchitectScreen extends ConsumerWidget {
  const LifeArchitectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lifeArchitectProvider);
    final notifier = ref.read(lifeArchitectProvider.notifier);
    final grow = ref.watch(growSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Life Architect',
            style: GoogleFonts.jetBrainsMono(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Life Architect Mode'),
            subtitle: Text(
              state.isActive
                  ? 'Active — GROW coaching + safety gate'
                  : 'Off',
              style: TextStyle(
                color: state.isActive
                    ? PocketClawTheme.electricTeal
                    : Colors.white54,
              ),
            ),
            value: state.isActive,
            activeColor: PocketClawTheme.electricTeal,
            onChanged: notifier.setActive,
          ),

          const Divider(height: 24),

          SwitchListTile(
            title: const Text('GROW in Chat'),
            subtitle: Text(
              state.growInChat
                  ? 'Phase: ${grow.currentPhase.name.toUpperCase()} — '
                      '${grow.getPhasePrompt()}'
                  : 'Routes chat through the GROW coaching framework',
              style: const TextStyle(fontSize: 12),
            ),
            value: state.growInChat,
            activeColor: PocketClawTheme.lobsterRed,
            onChanged: notifier.setGrowInChat,
          ),

          if (state.growInChat) ...[
            const SizedBox(height: 8),
            _GrowPhaseBar(phase: grow.currentPhase),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () =>
                      ref.read(growSessionProvider.notifier).startSession(),
                  child: const Text('Reset Session'),
                ),
              ],
            ),
          ],

          const Divider(height: 24),

          Text('Facet Coaches',
              style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Select which coaching areas to activate. Trigger them by '
            'mentioning the relevant topic in chat.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FacetCoach.values.map((facet) {
              final active = state.activeFacets.contains(facet);
              return FilterChip(
                avatar: Text(facet.icon),
                label: Text(facet.displayName),
                selected: active,
                selectedColor: PocketClawTheme.lobsterRed.withAlpha(80),
                checkmarkColor: PocketClawTheme.lobsterRed,
                onSelected: (_) => notifier.toggleFacet(facet),
              );
            }).toList(),
          ),

          const Divider(height: 24),

          Text('Life Blueprint',
              style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'A brief note about your current life priorities. The coach '
            'reads this at the start of every session.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 8),
          _BlueprintEditor(
            initial: state.lifeBlueprint,
            onSave: (content) => notifier.saveBlueprint(content),
          ),

          const Divider(height: 24),

          FilledButton.icon(
            onPressed: () async {
              if (!state.isActive) await notifier.setActive(true);
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.psychology),
            label: const Text('Start Coaching Session'),
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.deepPurple.withAlpha(40),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 18, color: Colors.deepPurpleAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Safety classifier is always active. Crisis, '
                      'high-risk, and therapy-drift messages are '
                      'intercepted and receive appropriate safe responses '
                      'regardless of Life Architect mode being on or off.',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowPhaseBar extends StatelessWidget {
  final GrowPhase phase;
  const _GrowPhaseBar({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: GrowPhase.values.map((p) {
        final isActive = p.index <= phase.index;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? PocketClawTheme.electricTeal
                  : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BlueprintEditor extends StatefulWidget {
  final String initial;
  final void Function(String) onSave;
  const _BlueprintEditor({required this.initial, required this.onSave});

  @override
  State<_BlueprintEditor> createState() => _BlueprintEditorState();
}

class _BlueprintEditorState extends State<_BlueprintEditor> {
  late final TextEditingController _ctrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
    _ctrl.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'e.g. Focus this quarter: finishing the app, daily '
                'exercise, reading 1 book/month. Main challenge: time management.',
            border: OutlineInputBorder(),
          ),
        ),
        if (_dirty)
          TextButton(
            onPressed: () {
              widget.onSave(_ctrl.text);
              setState(() => _dirty = false);
            },
            child: const Text('Save blueprint'),
          ),
      ],
    );
  }
}
