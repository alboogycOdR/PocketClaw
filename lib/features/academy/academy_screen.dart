/// Academy Mode — curriculum-aware tutoring shell (Sprint 11, spec).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

/// Placeholder state until full Academy packs land.
class AcademyModeState {
  final String subject;
  final String level;

  const AcademyModeState({
    this.subject = 'Biology',
    this.level = 'IGCSE',
  });

  AcademyModeState copyWith({String? subject, String? level}) {
    return AcademyModeState(
      subject: subject ?? this.subject,
      level: level ?? this.level,
    );
  }
}

class AcademyModeNotifier extends StateNotifier<AcademyModeState> {
  AcademyModeNotifier() : super(const AcademyModeState());

  void setSubject(String s) => state = state.copyWith(subject: s);

  void setLevel(String l) => state = state.copyWith(level: l);
}

final academyModeProvider =
    StateNotifierProvider<AcademyModeNotifier, AcademyModeState>(
  (_) => AcademyModeNotifier(),
);

class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(academyModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Academy Mode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Curriculum tutoring',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Subject: ${mode.subject} · Level: ${mode.level}\n'
            'Use Chat with /local or /server as needed. Full RAG and '
            'pack content will plug into this provider in a later sprint.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withAlpha(166),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
            value: mode.subject,
            items: const [
              DropdownMenuItem(value: 'Biology', child: Text('Biology')),
              DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
              DropdownMenuItem(value: 'Physics', child: Text('Physics')),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(academyModeProvider.notifier).setSubject(v);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Level',
              border: OutlineInputBorder(),
            ),
            value: mode.level,
            items: const [
              DropdownMenuItem(value: 'IGCSE', child: Text('IGCSE')),
              DropdownMenuItem(value: 'AS', child: Text('AS')),
              DropdownMenuItem(value: 'A2', child: Text('A2')),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(academyModeProvider.notifier).setLevel(v);
              }
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chat),
            label: const Text('Return to Chat'),
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
            ),
          ),
        ],
      ),
    );
  }
}
