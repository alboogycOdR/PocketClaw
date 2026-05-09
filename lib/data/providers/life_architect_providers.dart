/// Life Architect — overlay state, GROW context, system-prompt builder.
///
/// Per SPEC-LifeArchitect-v1.0. Like Academy, Life Architect is NOT a
/// new ChatMode — it's an overlay on the active ChatMode. It composes
/// three runtime layers:
///   1. Master architect skill body (always when active)
///   2. Active facet coach selections (filter chips on the screen)
///   3. Saved Living Life Blueprint (free-form Markdown)
///
/// The chat send path consumes [lifeArchitectSystemPromptProvider] for
/// the layered system prompt and [growContextProvider] for the per-turn
/// GROW phase nudge.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/coaching/facet_coach.dart';
import '../../core/coaching/grow_state_machine.dart';
import 'core_providers.dart';

class LifeArchitectState {
  final bool isActive;
  final bool growInChat;
  final List<FacetCoach> activeFacets;
  final String lifeBlueprint;
  final DateTime? lastSession;

  const LifeArchitectState({
    this.isActive = false,
    this.growInChat = false,
    this.activeFacets = const [],
    this.lifeBlueprint = '',
    this.lastSession,
  });

  LifeArchitectState copyWith({
    bool? isActive,
    bool? growInChat,
    List<FacetCoach>? activeFacets,
    String? lifeBlueprint,
    DateTime? lastSession,
  }) =>
      LifeArchitectState(
        isActive: isActive ?? this.isActive,
        growInChat: growInChat ?? this.growInChat,
        activeFacets: activeFacets ?? this.activeFacets,
        lifeBlueprint: lifeBlueprint ?? this.lifeBlueprint,
        lastSession: lastSession ?? this.lastSession,
      );
}

class LifeArchitectNotifier extends StateNotifier<LifeArchitectState> {
  LifeArchitectNotifier(this._ref) : super(const LifeArchitectState()) {
    _load();
  }

  final Ref _ref;

  void _load() {
    final p = _ref.read(sharedPrefsProvider);
    final facetsJson = p.getString('life_architect_facets');
    var facets = <FacetCoach>[];
    if (facetsJson != null) {
      try {
        final ids = (jsonDecode(facetsJson) as List).cast<String>();
        facets = [
          for (final id in ids)
            ...FacetCoach.values.where((f) => f.name == id),
        ];
      } catch (_) {/* ignore corrupt JSON */}
    }
    final lastStr = p.getString('life_architect_last_session');
    state = LifeArchitectState(
      isActive: p.getBool('life_architect_active') ?? false,
      growInChat: p.getBool('grow_chat_mode') ?? false,
      activeFacets: facets,
      lifeBlueprint: p.getString('life_blueprint') ?? '',
      lastSession: lastStr != null ? DateTime.tryParse(lastStr) : null,
    );
  }

  Future<void> setActive(bool value) async {
    final p = _ref.read(sharedPrefsProvider);
    await p.setBool('life_architect_active', value);
    if (value) {
      final now = DateTime.now();
      await p.setString('life_architect_last_session', now.toIso8601String());
      state = state.copyWith(isActive: value, lastSession: now);
    } else {
      state = state.copyWith(isActive: value);
    }
  }

  Future<void> setGrowInChat(bool value) async {
    await _ref.read(sharedPrefsProvider).setBool('grow_chat_mode', value);
    // Mirror to the legacy growChatModeProvider so older chat-screen
    // code paths see the flip too.
    _ref.read(growChatModeProvider.notifier).state = value;
    state = state.copyWith(growInChat: value);
  }

  Future<void> toggleFacet(FacetCoach facet) async {
    final current = List<FacetCoach>.from(state.activeFacets);
    if (current.contains(facet)) {
      current.remove(facet);
    } else {
      current.add(facet);
    }
    final ids = current.map((f) => f.name).toList();
    await _ref
        .read(sharedPrefsProvider)
        .setString('life_architect_facets', jsonEncode(ids));
    state = state.copyWith(activeFacets: current);
  }

  Future<void> saveBlueprint(String content) async {
    await _ref
        .read(sharedPrefsProvider)
        .setString('life_blueprint', content);
    state = state.copyWith(lifeBlueprint: content);
  }
}

final lifeArchitectProvider =
    StateNotifierProvider<LifeArchitectNotifier, LifeArchitectState>(
  (ref) => LifeArchitectNotifier(ref),
);

final lifeArchitectActiveProvider = Provider<bool>(
  (ref) => ref.watch(lifeArchitectProvider).isActive,
);

final growInChatActiveProvider = Provider<bool>(
  (ref) => ref.watch(lifeArchitectProvider).growInChat,
);

/// The full Life Architect system prompt: master architect base +
/// active facet coaches + Life Blueprint snippet. Returns null when
/// the overlay is off.
final lifeArchitectSystemPromptProvider = Provider<String?>((ref) {
  final state = ref.watch(lifeArchitectProvider);
  if (!state.isActive) return null;

  final registry = ref.watch(skillRegistryProvider);
  final master = registry.skills.cast<dynamic>().firstWhere(
        (s) => s.name == 'master-life-architect',
        orElse: () => null,
      );
  final facetSkill = registry.skills.cast<dynamic>().firstWhere(
        (s) => s.name == 'life-architect',
        orElse: () => null,
      );

  final base = (master?.cachedBody as String?) ??
      (master?.description as String?) ??
      (facetSkill?.cachedBody as String?) ??
      (facetSkill?.description as String?) ??
      'You are the Master Life Architect. You coach the user across all '
          'major life facets using the GROW methodology. British English. '
          'Ask, do not tell. Maintain a strong safety layer.';

  final buf = StringBuffer()
    ..writeln(base.trim())
    ..writeln();

  if (state.activeFacets.isNotEmpty) {
    buf.writeln('## Active Facet Coaches This Session');
    for (final facet in state.activeFacets) {
      buf.writeln('- ${facet.icon} ${facet.displayName}');
    }
    buf.writeln();
  }

  if (state.lifeBlueprint.trim().isNotEmpty) {
    buf.writeln('## Current Life Blueprint');
    buf.writeln(state.lifeBlueprint.trim());
    buf.writeln();
  }

  return buf.toString();
});

/// Per-turn GROW phase nudge: tells the model which phase question to
/// ask next without advancing the phase itself. Returns null when GROW
/// in Chat is off.
final growContextProvider = Provider<String?>((ref) {
  final active = ref.watch(growInChatActiveProvider);
  if (!active) return null;
  final session = ref.watch(growSessionProvider);
  final goalLine = session.sessionGoal != null
      ? 'Session goal: ${session.sessionGoal}\n'
      : '';
  return 'You are in a GROW coaching session.\n'
      'Current phase: ${session.currentPhase.name.toUpperCase()}\n'
      'Phase question: ${session.getPhasePrompt()}\n'
      '$goalLine'
      'Stay in the ${session.currentPhase.name} phase — ask the phase '
      'question and listen. Do not advance the phase in your response.\n\n';
});
