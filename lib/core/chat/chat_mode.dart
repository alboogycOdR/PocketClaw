/// Chat mode — explicit user selection for where messages go.
/// Replaces the previous auto-routing Smart Router for send decisions.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The distinct chat modes. Each has an isolated message history and
/// never shares context with the others.
///
/// Cloud was removed 2026-05-09 — Anthropic / OpenAI / Google all have
/// their own dedicated mobile apps and PocketClaw is now exclusively
/// for agentic systems (OpenClaw, Hermes) and on-device local models.
enum ChatMode {
  /// On-device inference via the selected local GGUF model (fllama).
  /// Messages NEVER leave the device.
  local,

  /// Full agentic session via OpenClaw gateway.
  /// Includes Paperclip governance, tools, agent team, project memory.
  openclaw,

  /// Hermes Agent (Nous Research) — REST chat against the user's
  /// self-hosted Hermes gateway. Carries Hermes' own toolset + memory.
  hermes,
}

extension ChatModeLabel on ChatMode {
  String get displayName => switch (this) {
        ChatMode.local => 'Local',
        ChatMode.openclaw => 'OpenClaw',
        ChatMode.hermes => 'Hermes',
      };

  String get tagline => switch (this) {
        ChatMode.local => 'Offline · Private',
        ChatMode.openclaw => 'Full agent team',
        ChatMode.hermes => 'Nous Research agent',
      };

  IconData get icon => switch (this) {
        ChatMode.local => Icons.phone_android,
        ChatMode.openclaw => Icons.hub_outlined,
        ChatMode.hermes => Icons.psychology_outlined,
      };

  Color get color => switch (this) {
        ChatMode.local => PocketClawTheme.amber,
        ChatMode.openclaw => PocketClawTheme.bronze,
        ChatMode.hermes => const Color(0xFF7C3AED),
      };

  String get storageKey => 'chat_mode_session_$name';
}
