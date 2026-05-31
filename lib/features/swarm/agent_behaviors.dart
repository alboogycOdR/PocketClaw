/// Office-view behavior model — activity / expression enums, named
/// locations (desks + break areas), per-persona colour assignments,
/// chat-bubble message pools, and `AgentBehaviorState` carrying the
/// current activity, position, and target.
///
/// All positions are in the spec's 0–100 percentage space so the
/// office view can lay out on any container size by multiplying.
library;

import 'dart:math';

import 'package:flutter/material.dart';

enum AgentActivity {
  idle,
  walking,
  coding,
  thinking,
  waterBreak,
  coffeeBreak,
  lunch,
  meeting,
  chatting,
  celebrating,
  frustrated,
}

enum AgentExpression { neutral, happy, focused, confused, tired, excited }

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

// Named locations (% of office area).
const kWaterCooler = OfficePoint(5, 45);
const kCoffeeMachine = OfficePoint(90, 42);
const kLunchArea = OfficePoint(88, 85);
const kMeetingTable = OfficePoint(45, 52);

// 8 desks laid out as a 3-2-3 grid roughly mirroring the workspace SVG.
const kDeskPositions = <OfficePoint>[
  OfficePoint(18, 28), OfficePoint(42, 28), OfficePoint(66, 28),
  OfficePoint(18, 55), OfficePoint(42, 55), OfficePoint(66, 55),
  OfficePoint(30, 78), OfficePoint(55, 78),
];

AgentExpression expressionFor(AgentActivity activity) => switch (activity) {
      AgentActivity.coding => AgentExpression.focused,
      AgentActivity.thinking => AgentExpression.confused,
      AgentActivity.waterBreak => AgentExpression.tired,
      AgentActivity.coffeeBreak => AgentExpression.tired,
      AgentActivity.lunch => AgentExpression.happy,
      AgentActivity.chatting => AgentExpression.happy,
      AgentActivity.celebrating => AgentExpression.excited,
      AgentActivity.frustrated => AgentExpression.confused,
      _ => AgentExpression.neutral,
    };

String emojiFor(AgentActivity a) => switch (a) {
      AgentActivity.idle => '🧍',
      AgentActivity.walking => '🚶',
      AgentActivity.coding => '💻',
      AgentActivity.thinking => '💭',
      AgentActivity.waterBreak => '💧',
      AgentActivity.coffeeBreak => '☕',
      AgentActivity.lunch => '🍕',
      AgentActivity.meeting => '🤝',
      AgentActivity.chatting => '💬',
      AgentActivity.celebrating => '🎉',
      AgentActivity.frustrated => '😤',
    };

const kWorkingMessages = <String>[
  'Almost done...',
  'This is interesting',
  'Compiling...',
  'Reading docs...',
  'Found a bug!',
  'Writing tests...',
  'Pushing code...',
  'Reviewing PR...',
];
const kBreakMessages = <String>[
  'Need water 💧',
  'brb',
  'Quick break',
  'Coffee time ☕',
  'Lunch break 🍕',
];
const kCompleteMessages = <String>[
  'Done! 🎉',
  'Ship it!',
  'All green ✅',
  'Nailed it!',
];
const kFailedMessages = <String>[
  'Hmm...',
  "That's broken",
  'Debugging...',
];
const kChattingMessages = <String>[
  'Check this out',
  'Can you review?',
  'Nice work!',
  'Need your help',
  'What do you think?',
];

String randomMessage(List<String> pool) =>
    pool[Random().nextInt(pool.length)];

/// Resolve an activity to its on-floor coordinates. For `chatting` and
/// `celebrating` the agent stands on a deterministic point around the
/// meeting table indexed by their desk slot so multiple agents don't
/// stack on top of each other.
OfficePoint locationFor(AgentActivity activity, int deskIndex) {
  final idx = deskIndex.abs() % kDeskPositions.length;
  return switch (activity) {
    AgentActivity.waterBreak => kWaterCooler,
    AgentActivity.coffeeBreak => kCoffeeMachine,
    AgentActivity.lunch => kLunchArea,
    AgentActivity.meeting => kMeetingTable,
    AgentActivity.chatting => OfficePoint(
        kMeetingTable.x + cos(idx * 45 * pi / 180) * 6,
        kMeetingTable.y + sin(idx * 45 * pi / 180) * 4,
      ),
    AgentActivity.celebrating => OfficePoint(
        kMeetingTable.x + cos(idx * 45 * pi / 180) * 6,
        kMeetingTable.y + sin(idx * 45 * pi / 180) * 4,
      ),
    _ => kDeskPositions[idx],
  };
}

class PersonaColors {
  final Color body;
  final Color accent;
  const PersonaColors(this.body, this.accent);
}

const _personaList = <PersonaColors>[
  PersonaColors(Color(0xFF3B82F6), Color(0xFF93C5FD)), // blue
  PersonaColors(Color(0xFFA855F7), Color(0xFFD8B4FE)), // purple
  PersonaColors(Color(0xFFF97316), Color(0xFFFDBA74)), // orange
  PersonaColors(Color(0xFF10B981), Color(0xFF6EE7B7)), // emerald
  PersonaColors(Color(0xFFF59E0B), Color(0xFFFCD34D)), // amber
  PersonaColors(Color(0xFF06B6D4), Color(0xFF67E8F9)), // cyan
  PersonaColors(Color(0xFFEAB308), Color(0xFFFDE047)), // yellow
  PersonaColors(Color(0xFFEF4444), Color(0xFFFCA5A5)), // red
];

PersonaColors personaFor(String sessionId) {
  final hash = sessionId.codeUnits.fold(0, (a, b) => a ^ b);
  return _personaList[hash.abs() % _personaList.length];
}

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
  final int walkFrame; // 0 or 1, alternated by the tick

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
    this.walkFrame = 0,
  });

  bool get isWalking =>
      activity == AgentActivity.walking &&
      position.distanceTo(targetPosition) > 1.5;

  /// True when the agent is facing left (moving west). The pixel
  /// painter flips the canvas when this is true.
  bool get isFacingLeft => targetPosition.x < position.x;

  AgentBehaviorState copyWith({
    AgentActivity? activity,
    OfficePoint? position,
    OfficePoint? targetPosition,
    OfficePoint? deskPosition,
    String? chatMessage,
    bool clearChat = false,
    String? chatTarget,
    int? lastBreakMs,
    int? activityStartMs,
    int? walkFrame,
  }) =>
      AgentBehaviorState(
        activity: activity ?? this.activity,
        position: position ?? this.position,
        targetPosition: targetPosition ?? this.targetPosition,
        deskPosition: deskPosition ?? this.deskPosition,
        expression: expressionFor(activity ?? this.activity),
        chatMessage: clearChat ? null : (chatMessage ?? this.chatMessage),
        chatTarget: chatTarget ?? this.chatTarget,
        lastBreakMs: lastBreakMs ?? this.lastBreakMs,
        breakIntervalMs: breakIntervalMs,
        activityStartMs: activityStartMs ?? this.activityStartMs,
        walkFrame: walkFrame ?? this.walkFrame,
      );
}
