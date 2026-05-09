/// Providers for chat mode selection and per-mode session keys.
/// Each mode has its own isolated session key; switching modes loads
/// that mode's last session.
///
/// Cloud mode was dropped 2026-05-09 — PocketClaw routes only to
/// local / OpenClaw / Hermes now.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chat/chat_mode.dart';
import '../../core/llm/models/local_model_config.dart' as llm;
import 'core_providers.dart';
import 'hermes_providers.dart';

/// Current active chat mode. Persisted in SharedPreferences.
/// Defaults to whichever mode is first-available on launch.
final chatModeProvider = StateProvider<ChatMode>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final stored = prefs.getString('chat_mode');
  if (stored != null) {
    try {
      return ChatMode.values.byName(stored);
    } catch (_) {
      // Stored mode is no longer valid (e.g. legacy 'cloud' from a
      // previous build) — fall through to auto-detect.
    }
  }

  // User-set default execution path takes precedence over autodetect.
  final preferred = prefs.getString('default_execution_path');
  if (preferred == 'hermes') {
    final url = ref.read(hermesBaseUrlProvider);
    final key = ref.read(hermesApiKeyProvider);
    if (url.isNotEmpty && key.isNotEmpty) return ChatMode.hermes;
  }

  return _detectDefaultMode(ref);
});

ChatMode _detectDefaultMode(Ref ref) {
  // 1. OpenClaw gateway configured?
  try {
    final url = ref.read(gatewayUrlProvider);
    if (url.isNotEmpty) return ChatMode.openclaw;
  } catch (_) {}

  // 2. Hermes configured?
  try {
    final url = ref.read(hermesBaseUrlProvider);
    final key = ref.read(hermesApiKeyProvider);
    if (url.isNotEmpty && key.isNotEmpty) return ChatMode.hermes;
  } catch (_) {}

  // 3. Fall back to local.
  return ChatMode.local;
}

/// Per-mode session key. Stored per mode in prefs.
/// Returns null if no session has been started in this mode yet.
final sessionKeyForModeProvider =
    StateProvider.family<String?, ChatMode>((ref, mode) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString(mode.storageKey);
});

/// Whether each mode is currently *available* (configured + ready).
/// A mode that is unavailable can still be selected, but the send
/// pipeline will show a clear error pointing to the missing config.
final modeAvailabilityProvider =
    Provider.family<ModeAvailability, ChatMode>((ref, mode) {
  return switch (mode) {
    ChatMode.local => _localAvailable(ref),
    ChatMode.openclaw => _openclawAvailable(ref),
    ChatMode.hermes => _hermesAvailable(ref),
  };
});

ModeAvailability _localAvailable(Ref ref) {
  try {
    final model = ref.watch(selectedModelConfigProvider);
    if (model == null) {
      return const ModeAvailability.unavailable(
        'Select a local model in Settings.',
      );
    }
    return ModeAvailability.available(
      subtitle: 'Model: ${model.displayName}',
      modelConfig: model,
    );
  } catch (_) {
    return const ModeAvailability.unavailable(
      'Select a local model in Settings.',
    );
  }
}

ModeAvailability _openclawAvailable(Ref ref) {
  try {
    final url = ref.watch(gatewayUrlProvider);
    final token = ref.watch(gatewayTokenProvider);
    if (url.isEmpty) {
      return const ModeAvailability.unavailable(
        'OpenClaw gateway not configured. Set it in Settings.',
      );
    }
    if (token.isEmpty) {
      return const ModeAvailability.unavailable(
        'OpenClaw gateway token missing.',
      );
    }
    return const ModeAvailability.available(
      subtitle: 'Agent team',
    );
  } catch (_) {
    return const ModeAvailability.unavailable(
      'Configure OpenClaw in Settings.',
    );
  }
}

ModeAvailability _hermesAvailable(Ref ref) {
  try {
    final url = ref.watch(hermesBaseUrlProvider);
    final key = ref.watch(hermesApiKeyProvider);
    if (url.isEmpty) {
      return const ModeAvailability.unavailable(
        'Hermes not configured. Set base URL in Settings → Hermes Agent.',
      );
    }
    if (key.isEmpty) {
      return const ModeAvailability.unavailable(
        'Hermes API key missing. Set it in Settings → Hermes Agent.',
      );
    }
    return const ModeAvailability.available(
      subtitle: 'Hermes toolset · streaming',
    );
  } catch (_) {
    return const ModeAvailability.unavailable(
      'Configure Hermes in Settings.',
    );
  }
}

/// Result of checking whether a mode is ready to send messages.
class ModeAvailability {
  final bool isAvailable;
  final String? subtitle;
  final String? reasonUnavailable;
  final llm.LocalModelConfig? modelConfig;

  const ModeAvailability.available({
    this.subtitle,
    this.modelConfig,
  })  : isAvailable = true,
        reasonUnavailable = null;

  const ModeAvailability.unavailable(this.reasonUnavailable)
      : isAvailable = false,
        subtitle = null,
        modelConfig = null;
}
