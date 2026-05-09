/// Academy Mode — overlay state + system-prompt builder.
///
/// Per SPEC-AcademyMode-v1.0. Academy is NOT a new ChatMode: when its
/// `isActive` switch is on, the academy-tutor system prompt is prepended
/// to every chat send regardless of the active ChatMode (local / cloud /
/// openclaw / hermes).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

class AcademyState {
  final bool isActive;
  final String subject;
  final String level;
  final int streakDays;
  final DateTime? lastActive;

  const AcademyState({
    this.isActive = false,
    this.subject = 'Mathematics',
    this.level = 'IGCSE',
    this.streakDays = 0,
    this.lastActive,
  });

  AcademyState copyWith({
    bool? isActive,
    String? subject,
    String? level,
    int? streakDays,
    DateTime? lastActive,
  }) =>
      AcademyState(
        isActive: isActive ?? this.isActive,
        subject: subject ?? this.subject,
        level: level ?? this.level,
        streakDays: streakDays ?? this.streakDays,
        lastActive: lastActive ?? this.lastActive,
      );
}

class AcademyNotifier extends StateNotifier<AcademyState> {
  AcademyNotifier(this._ref) : super(const AcademyState()) {
    _load();
  }

  final Ref _ref;

  void _load() {
    final p = _ref.read(sharedPrefsProvider);
    final lastStr = p.getString('academy_last_active');
    state = AcademyState(
      isActive: p.getBool('academy_mode_active') ?? false,
      subject: p.getString('academy_subject') ?? 'Mathematics',
      level: p.getString('academy_level') ?? 'IGCSE',
      streakDays: p.getInt('academy_streak_days') ?? 0,
      lastActive: lastStr != null ? DateTime.tryParse(lastStr) : null,
    );
  }

  Future<void> setActive(bool value) async {
    final p = _ref.read(sharedPrefsProvider);
    await p.setBool('academy_mode_active', value);
    if (value) {
      _updateStreak();
    } else {
      state = state.copyWith(isActive: value);
    }
  }

  Future<void> setSubject(String subject) async {
    await _ref.read(sharedPrefsProvider).setString('academy_subject', subject);
    state = state.copyWith(subject: subject);
  }

  Future<void> setLevel(String level) async {
    await _ref.read(sharedPrefsProvider).setString('academy_level', level);
    state = state.copyWith(level: level);
  }

  /// Increment streak when activating on a consecutive day; reset to 1
  /// when more than a day has passed; leave alone when already counted
  /// today.
  void _updateStreak() {
    final now = DateTime.now();
    final last = state.lastActive;
    final p = _ref.read(sharedPrefsProvider);

    int newStreak;
    if (last == null) {
      newStreak = 1;
    } else {
      final days = _wholeDayDifference(last, now);
      if (days == 0) {
        newStreak = state.streakDays > 0 ? state.streakDays : 1;
      } else if (days == 1) {
        newStreak = state.streakDays + 1;
      } else {
        newStreak = 1;
      }
    }

    p.setInt('academy_streak_days', newStreak);
    p.setString('academy_last_active', now.toIso8601String());
    state = state.copyWith(
      isActive: true,
      streakDays: newStreak,
      lastActive: now,
    );
  }

  int _wholeDayDifference(DateTime a, DateTime b) {
    final aDay = DateTime(a.year, a.month, a.day);
    final bDay = DateTime(b.year, b.month, b.day);
    return bDay.difference(aDay).inDays;
  }
}

final academyProvider =
    StateNotifierProvider<AcademyNotifier, AcademyState>(
  (ref) => AcademyNotifier(ref),
);

final academyActiveProvider = Provider<bool>(
  (ref) => ref.watch(academyProvider).isActive,
);

/// Returns the academy system prompt with subject/level injected, or
/// null when the overlay is off. The chat send path consumes this.
final academySystemPromptProvider = Provider<String?>((ref) {
  final state = ref.watch(academyProvider);
  if (!state.isActive) return null;

  final registry = ref.watch(skillRegistryProvider);
  // The bundled skill name is `personal-ai-academy` per the Skills tab
  // catalogue. Fall back to a minimal prompt if the skill went missing
  // so Academy still does *something* useful.
  final skill = registry.skills.cast<dynamic>().firstWhere(
        (s) => s.name == 'personal-ai-academy',
        orElse: () => null,
      );

  final body = skill?.cachedBody as String? ??
      skill?.description as String? ??
      'You are a personal AI academy tutor for South African and IGCSE/A-level students. '
          'Use British English. Guide the student to answers — do not just give them.';

  final filled = body
      .replaceAll('{subject}', state.subject)
      .replaceAll('{level}', state.level);

  return '$filled\n\n'
      'Current student subject: ${state.subject}\n'
      'Curriculum level: ${state.level}\n'
      "Always refer to the student's subject when giving examples.\n"
      'Keep explanations appropriate for ${state.level} standard.';
});
