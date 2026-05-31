/// StateNotifier that maintains per-session [AgentBehaviorState] for
/// the office view. A 1s tick drives:
///   - position lerp toward targetPosition (walking animation)
///   - session-status overrides (thinking / complete / failed)
///   - timed transitions (break expiry, celebrate timeout, chat-bubble
///     auto-clear after 4s)
///   - periodic chat visits — every 30–60s an agent on the floor goes
///     to talk to another one
///
/// Desk assignments are tracked separately so two agents don't get
/// the same desk slot.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hermes/models/hermes_session.dart';
import '../../data/providers/hermes_data_providers.dart';
import 'agent_behaviors.dart';

const _kTickMs = 1000;
const _kCodingMinMs = 15000;
const _kCodingMaxMs = 30000;
const _kBreakMinMs = 5000;
const _kBreakMaxMs = 12000;
const _kChatVisitMinMs = 30000;
const _kChatVisitMaxMs = 60000;
const _kChatBubbleMs = 4000;
const _kCelebrateMs = 5000;
const _kBreakIntervalMin = 90000;
const _kBreakIntervalMax = 210000;
const _kLerpFactor = 0.08;

int _now() => DateTime.now().millisecondsSinceEpoch;
int _rand(int min, int max) {
  if (max <= min) return min;
  return min + Random().nextInt(max - min);
}

class AgentBehaviorNotifier
    extends StateNotifier<Map<String, AgentBehaviorState>> {
  AgentBehaviorNotifier(this._ref) : super(const {}) {
    _startTick();
  }

  final Ref _ref;
  Timer? _timer;
  final _deskAssignments = <String, int>{};
  int _nextDesk = 0;
  int _nextChatVisitAt = _now() + _rand(_kChatVisitMinMs, _kChatVisitMaxMs);

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
    // All desks taken — wrap around.
    idx = _nextDesk++ % kDeskPositions.length;
    _deskAssignments[key] = idx;
    return idx;
  }

  AgentBehaviorState _seed(String key) {
    final deskIdx = _assignDesk(key);
    final desk = kDeskPositions[deskIdx];
    return AgentBehaviorState(
      activity: AgentActivity.idle,
      position: desk,
      targetPosition: desk,
      deskPosition: desk,
      expression: AgentExpression.neutral,
      lastBreakMs: _now(),
      breakIntervalMs: _rand(_kBreakIntervalMin, _kBreakIntervalMax),
      activityStartMs: _now(),
    );
  }

  void _tick() {
    final sessions = _ref.read(officeSessionsProvider).valueOrNull ?? const [];
    final activeKeys = {for (final s in sessions) s.id};

    final next = Map<String, AgentBehaviorState>.from(state);

    // Cull agents whose sessions are no longer on the office.
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
      _nextChatVisitAt = now + _rand(_kChatVisitMinMs, _kChatVisitMaxMs);
    }

    for (final session in sessions) {
      final key = session.id;
      var s = next[key] ?? _seed(key);

      // Move toward target (lerp). Walking flag is derived in
      // AgentBehaviorState.isWalking so we don't have to manage it
      // explicitly, but we DO set activity = walking while there's
      // still ground to cover.
      if (s.position.distanceTo(s.targetPosition) > 1.5) {
        s = s.copyWith(
          activity: AgentActivity.walking,
          position: s.position.lerp(s.targetPosition, _kLerpFactor),
          walkFrame: 1 - s.walkFrame, // 0 ↔ 1 each tick
        );
      } else if (s.activity == AgentActivity.walking) {
        // Arrived — drop back to coding (or whatever the prior
        // activity would imply).
        s = s.copyWith(activity: AgentActivity.coding);
      }

      // Session-status overrides take priority.
      if (session.swarmStatus == SwarmStatus.thinking) {
        if (s.activity != AgentActivity.thinking) {
          s = s.copyWith(
            activity: AgentActivity.thinking,
            chatMessage: randomMessage(kWorkingMessages),
            activityStartMs: now,
          );
        }
      } else if (session.swarmStatus == SwarmStatus.complete &&
          s.activity != AgentActivity.celebrating) {
        s = s.copyWith(
          activity: AgentActivity.celebrating,
          targetPosition: locationFor(
            AgentActivity.celebrating,
            _deskAssignments[key] ?? 0,
          ),
          chatMessage: randomMessage(kCompleteMessages),
          activityStartMs: now,
        );
      } else if (session.swarmStatus == SwarmStatus.failed &&
          s.activity != AgentActivity.frustrated) {
        s = s.copyWith(
          activity: AgentActivity.frustrated,
          chatMessage: randomMessage(kFailedMessages),
          activityStartMs: now,
        );
      }

      // Timed transitions.
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
          // Time for a break? Only if the session is actively running.
          if (now - s.lastBreakMs > s.breakIntervalMs &&
              session.swarmStatus == SwarmStatus.running) {
            final breakType = const [
              AgentActivity.waterBreak,
              AgentActivity.coffeeBreak,
              AgentActivity.lunch,
              AgentActivity.meeting,
            ][Random().nextInt(4)];
            s = s.copyWith(
              activity: breakType,
              targetPosition: locationFor(
                breakType,
                _deskAssignments[key] ?? 0,
              ),
              chatMessage: randomMessage(kBreakMessages),
              activityStartMs: now,
            );
          } else if (activityAge >
              _rand(_kCodingMinMs, _kCodingMaxMs)) {
            // Refresh the chat-bubble message occasionally.
            s = s.copyWith(
              chatMessage:
                  Random().nextBool() ? randomMessage(kWorkingMessages) : null,
              activityStartMs: now,
            );
          }
        default:
          break;
      }

      // Periodic chat visit.
      if (doChatVisit &&
          s.activity == AgentActivity.coding &&
          sessions.length >= 2) {
        final others = sessions.where((x) => x.id != key).toList();
        if (others.isNotEmpty) {
          final target = others[Random().nextInt(others.length)];
          s = s.copyWith(
            activity: AgentActivity.chatting,
            targetPosition: locationFor(
              AgentActivity.chatting,
              _deskAssignments[key] ?? 0,
            ),
            chatMessage: randomMessage(kChattingMessages),
            chatTarget: target.id,
            activityStartMs: now,
          );
        }
      }

      // Clear chat bubble after 4s except for celebrate / frustrated
      // — those carry their bubble until the activity itself ends.
      if (s.chatMessage != null &&
          now - s.activityStartMs > _kChatBubbleMs &&
          s.activity != AgentActivity.celebrating &&
          s.activity != AgentActivity.frustrated) {
        s = s.copyWith(clearChat: true);
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
