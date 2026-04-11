/// GROW coaching state machine — Goal, Reality, Options, Will, Review
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Phase Enum ──

enum GrowPhase { goal, reality, options, will, review }

// ── Phase Entry ──

class GrowPhaseEntry {
  final GrowPhase phase;
  final String content;
  final DateTime timestamp;

  const GrowPhaseEntry({
    required this.phase,
    required this.content,
    required this.timestamp,
  });
}

// ── Session ──

class GrowSession {
  final GrowPhase currentPhase;
  final String? sessionGoal;
  final List<String> realityNotes;
  final List<String> options;
  final List<String> commitments;
  final DateTime startedAt;
  final List<GrowPhaseEntry> phaseHistory;

  const GrowSession({
    this.currentPhase = GrowPhase.goal,
    this.sessionGoal,
    this.realityNotes = const [],
    this.options = const [],
    this.commitments = const [],
    required this.startedAt,
    this.phaseHistory = const [],
  });

  static final _phasePrompts = <GrowPhase, String>{
    GrowPhase.goal:
        'What would you like to focus on or achieve in this session?',
    GrowPhase.reality:
        'Where are you right now with this? What have you already tried?',
    GrowPhase.options:
        'What options do you see? What else could you do?',
    GrowPhase.will:
        'What specifically will you commit to? By when?',
    GrowPhase.review:
        'Looking back at your commitments — what happened? What did you learn?',
  };

  /// Returns the coaching question for the current phase.
  String getPhasePrompt() => _phasePrompts[currentPhase]!;

  /// Moves to the next phase. Returns false if already at review.
  bool advance() {
    if (currentPhase == GrowPhase.review) return false;
    return true; // Actual mutation is handled by the notifier
  }

  /// Records a response for the current phase.
  GrowSession addResponse(String response) {
    final entry = GrowPhaseEntry(
      phase: currentPhase,
      content: response,
      timestamp: DateTime.now(),
    );

    String? updatedGoal = sessionGoal;
    List<String> updatedReality = List.of(realityNotes);
    List<String> updatedOptions = List.of(options);

    switch (currentPhase) {
      case GrowPhase.goal:
        updatedGoal = response;
      case GrowPhase.reality:
        updatedReality.add(response);
      case GrowPhase.options:
        updatedOptions.add(response);
      case GrowPhase.will:
      case GrowPhase.review:
        break;
    }

    return GrowSession(
      currentPhase: currentPhase,
      sessionGoal: updatedGoal,
      realityNotes: updatedReality,
      options: updatedOptions,
      commitments: commitments,
      startedAt: startedAt,
      phaseHistory: [...phaseHistory, entry],
    );
  }

  /// Adds a commitment to the list.
  GrowSession addCommitment(String commitment) {
    return GrowSession(
      currentPhase: currentPhase,
      sessionGoal: sessionGoal,
      realityNotes: realityNotes,
      options: options,
      commitments: [...commitments, commitment],
      startedAt: startedAt,
      phaseHistory: phaseHistory,
    );
  }

  /// Returns a formatted session summary.
  String getSummary() {
    final buf = StringBuffer()
      ..writeln('=== GROW Session Summary ===')
      ..writeln('Started: $startedAt')
      ..writeln()
      ..writeln('GOAL: ${sessionGoal ?? "(not set)"}')
      ..writeln();

    if (realityNotes.isNotEmpty) {
      buf.writeln('REALITY:');
      for (final note in realityNotes) {
        buf.writeln('  - $note');
      }
      buf.writeln();
    }

    if (options.isNotEmpty) {
      buf.writeln('OPTIONS:');
      for (final opt in options) {
        buf.writeln('  - $opt');
      }
      buf.writeln();
    }

    if (commitments.isNotEmpty) {
      buf.writeln('COMMITMENTS:');
      for (final c in commitments) {
        buf.writeln('  - $c');
      }
      buf.writeln();
    }

    buf.writeln('Phases completed: ${phaseHistory.length}');
    return buf.toString();
  }

  /// True if phase is review and has at least one response in that phase.
  bool get isComplete =>
      currentPhase == GrowPhase.review &&
      phaseHistory.any((e) => e.phase == GrowPhase.review);

  /// Resets back to the goal phase.
  GrowSession reset() {
    return GrowSession(startedAt: DateTime.now());
  }

  /// Returns a copy advanced to the next phase.
  GrowSession _advancedCopy() {
    final nextIndex = currentPhase.index + 1;
    if (nextIndex >= GrowPhase.values.length) return this;
    return GrowSession(
      currentPhase: GrowPhase.values[nextIndex],
      sessionGoal: sessionGoal,
      realityNotes: realityNotes,
      options: options,
      commitments: commitments,
      startedAt: startedAt,
      phaseHistory: phaseHistory,
    );
  }
}

// ── Notifier ──

class GrowSessionNotifier extends StateNotifier<GrowSession> {
  GrowSessionNotifier()
      : super(GrowSession(startedAt: DateTime.now()));

  /// Starts a fresh session.
  void startSession() {
    state = GrowSession(startedAt: DateTime.now());
  }

  /// Records the user's response and advances to the next phase.
  void respondToPhase(String response) {
    state = state.addResponse(response);
    if (state.currentPhase != GrowPhase.review) {
      state = state._advancedCopy();
    }
  }

  /// Adds a commitment (typically during the "will" phase).
  void addCommitment(String commitment) {
    state = state.addCommitment(commitment);
  }

  /// Marks the session as complete by recording a final review entry
  /// if the session is already in the review phase.
  void endSession() {
    if (state.currentPhase == GrowPhase.review &&
        !state.phaseHistory.any((e) => e.phase == GrowPhase.review)) {
      state = state.addResponse('Session ended.');
    }
  }
}

// ── Provider ──

final growSessionProvider =
    StateNotifierProvider<GrowSessionNotifier, GrowSession>(
  (_) => GrowSessionNotifier(),
);
