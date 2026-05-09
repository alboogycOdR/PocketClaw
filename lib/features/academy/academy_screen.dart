/// Academy Mode — overlay toggle, subject + level pickers, streak,
/// "launch session" entry into chat. Per SPEC-AcademyMode-v1.0 §7.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/academy_providers.dart';

class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  static const _subjects = [
    'Mathematics',
    'Physical Sciences',
    'Life Sciences',
    'English Home Language',
    'English First Additional Language',
    'History',
    'Geography',
    'Accounting',
    'Business Studies',
    'Economics',
    'Computer Applications Technology',
    'Information Technology',
    'Visual Arts',
    'Music',
  ];

  static const _levels = [
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12 (Matric)',
    'IGCSE',
    'AS Level',
    'A2 Level',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(academyProvider);
    final notifier = ref.read(academyProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Academy Mode',
            style: GoogleFonts.jetBrainsMono(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Academy Mode'),
            subtitle: Text(
              state.isActive
                  ? 'Active — chat is in ${state.subject} tutor mode'
                  : 'Off — tap to activate subject tutoring',
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

          if (state.isActive) ...[
            const Divider(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.streakDays} day streak',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          state.streakDays > 0
                              ? 'Keep it up!'
                              : 'Start your streak today',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
            initialValue: state.subject,
            items: _subjects
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) notifier.setSubject(v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Curriculum Level',
              border: OutlineInputBorder(),
            ),
            initialValue: state.level,
            items: _levels
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              if (v != null) notifier.setLevel(v);
            },
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              if (!state.isActive) await notifier.setActive(true);
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.school),
            label: Text(
              state.isActive
                  ? 'Continue ${state.subject} Session'
                  : 'Start ${state.subject} Session',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How it works',
                      style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '• The AI acts as your personal ${state.subject} tutor\n'
                    "• It guides you to answers — doesn't give them away\n"
                    '• British English throughout\n'
                    '• Works with any active chat mode (Local, Cloud, OpenClaw, Hermes)\n'
                    '• Switch subject or level anytime — takes effect immediately',
                    style:
                        const TextStyle(fontSize: 12, height: 1.5),
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
