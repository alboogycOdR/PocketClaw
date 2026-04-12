/// Chat mode — explicit user selection for where messages go.
/// Replaces the previous auto-routing Smart Router for send decisions.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The three distinct chat modes. Each has an isolated message history
/// and never shares context with the others.
enum ChatMode {
  /// On-device inference via the selected local model (Gemma .task).
  /// Messages NEVER leave the device.
  local,

  /// Direct API call to a cloud LLM (Claude, GPT, Gemini).
  /// User's API key + current conversation only.
  cloud,

  /// Full agentic session via OpenClaw gateway.
  /// Includes Paperclip governance, tools, agent team, project memory.
  openclaw,
}

extension ChatModeLabel on ChatMode {
  String get displayName => switch (this) {
    ChatMode.local    => 'Local',
    ChatMode.cloud    => 'Cloud',
    ChatMode.openclaw => 'OpenClaw',
  };

  String get tagline => switch (this) {
    ChatMode.local    => 'Offline \u00b7 Private',
    ChatMode.cloud    => 'Direct to your API key',
    ChatMode.openclaw => 'Full agent team',
  };

  IconData get icon => switch (this) {
    ChatMode.local    => Icons.phone_android,
    ChatMode.cloud    => Icons.cloud_outlined,
    ChatMode.openclaw => Icons.hub_outlined,
  };

  Color get color => switch (this) {
    ChatMode.local    => PocketClawTheme.electricTeal,
    ChatMode.cloud    => const Color(0xFFD4A574), // Anthropic-ish amber
    ChatMode.openclaw => PocketClawTheme.lobsterRed,
  };

  String get storageKey => 'chat_mode_session_${name}';
}
