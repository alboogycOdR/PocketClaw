/// Providers for chat mode selection and per-mode session keys.
/// Each mode has its own isolated session key; switching modes loads
/// that mode's last session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chat/chat_mode.dart';
import '../../core/llm/models/local_model_config.dart' as llm;
import '../../core/llm/models/model_format.dart';
import '../../core/llm/services/api_key_service.dart';
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
      // Fall through to auto-detect
    }
  }

  // User-set default execution path takes precedence over autodetect.
  final preferred = prefs.getString('default_execution_path');
  if (preferred == 'hermes') {
    final url = ref.read(hermesBaseUrlProvider);
    final key = ref.read(hermesApiKeyProvider);
    if (url.isNotEmpty && key.isNotEmpty) return ChatMode.hermes;
  }

  // Auto-detect based on what is configured
  return _detectDefaultMode(ref);
});

ChatMode _detectDefaultMode(Ref ref) {
  // 1. If a local model is selected and is .task format → Local
  try {
    final model = ref.read(selectedModelConfigProvider);
    if (model.format == ModelFormat.task) {
      return ChatMode.local;
    }
    if (model.format == ModelFormat.cloud) {
      return ChatMode.cloud;
    }
  } catch (_) {}

  // 2. OpenClaw gateway configured?
  try {
    final url = ref.read(gatewayUrlProvider);
    if (url.isNotEmpty) return ChatMode.openclaw;
  } catch (_) {}

  // 3. Fall back to local
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
    ChatMode.local    => _localAvailable(ref),
    ChatMode.cloud    => _cloudAvailable(ref),
    ChatMode.openclaw => _openclawAvailable(ref),
    ChatMode.hermes   => _hermesAvailable(ref),
  };
});

ModeAvailability _localAvailable(Ref ref) {
  try {
    final model = ref.watch(selectedModelConfigProvider);
    // Local mode runs any on-device model. GGUF (via fllama) is the
    // current runtime; .task (flutter_gemma) was removed in the Gemma
    // cleanup. Anything that is NOT cloud is treated as local.
    if (model.isCloud) {
      return ModeAvailability.unavailable(
        'Current selection is a cloud model. Pick a local GGUF model in '
        'Settings \u2192 Models to use Local mode.',
      );
    }
    // We can't synchronously verify the model file is downloaded from here
    // — the chat send path will handle that case with a clearer error.
    return ModeAvailability.available(
      subtitle: 'Model: ${model.displayName}',
      modelConfig: model,
    );
  } catch (_) {
    return ModeAvailability.unavailable('Select a local model in Settings.');
  }
}

ModeAvailability _cloudAvailable(Ref ref) {
  try {
    final model = ref.watch(selectedModelConfigProvider);
    if (model.format != ModelFormat.cloud) {
      // User has a local model selected but wants Cloud
      // → pick the first cloud model in the registry as a hint
      return ModeAvailability.unavailable(
        'Pick a cloud model (Claude, GPT, or Gemini) in Settings \u2192 Models.',
      );
    }
    final cloudProvider = ApiKeyService.providerFor(model.provider);
    if (cloudProvider == null) {
      return ModeAvailability.unavailable(
        'Unsupported cloud provider.',
      );
    }
    final hasKey = ref
            .watch(hasCloudKeyProvider(cloudProvider))
            .whenOrNull(data: (v) => v) ??
        false;
    if (!hasKey) {
      return ModeAvailability.unavailable(
        'No API key for ${model.provider.toString().split('.').last}. '
        'Add it in Settings \u2192 Models.',
      );
    }
    return ModeAvailability.available(
      subtitle: 'Model: ${model.displayName}',
      modelConfig: model,
    );
  } catch (_) {
    return ModeAvailability.unavailable('Pick a cloud model in Settings.');
  }
}

ModeAvailability _openclawAvailable(Ref ref) {
  try {
    final url = ref.watch(gatewayUrlProvider);
    final token = ref.watch(gatewayTokenProvider);
    if (url.isEmpty) {
      return ModeAvailability.unavailable(
        'OpenClaw gateway not configured. Set it in Settings.',
      );
    }
    if (token.isEmpty) {
      return ModeAvailability.unavailable('OpenClaw gateway token missing.');
    }
    return const ModeAvailability.available(
      subtitle: 'Agent team + Paperclip',
    );
  } catch (_) {
    return ModeAvailability.unavailable('Configure OpenClaw in Settings.');
  }
}

ModeAvailability _hermesAvailable(Ref ref) {
  try {
    final url = ref.watch(hermesBaseUrlProvider);
    final key = ref.watch(hermesApiKeyProvider);
    if (url.isEmpty) {
      return ModeAvailability.unavailable(
        'Hermes not configured. Set base URL in Settings → Hermes Agent.',
      );
    }
    if (key.isEmpty) {
      return ModeAvailability.unavailable(
        'Hermes API key missing. Set it in Settings → Hermes Agent.',
      );
    }
    return const ModeAvailability.available(
      subtitle: 'Hermes toolset · streaming',
    );
  } catch (_) {
    return ModeAvailability.unavailable('Configure Hermes in Settings.');
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
