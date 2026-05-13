/// Riverpod providers for TTS state — Supertonic model readiness,
/// active voice selection (persisted to SharedPreferences), and a
/// lazy-load hook that auto-warms the engine when the voice changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tts/supertonic_model_manager.dart';
import '../../core/tts/supertonic_tts_service.dart';
import 'core_providers.dart';

const _activeVoicePrefKey = 'supertonic_voice_id';
const _autoSpeakPrefKey = 'tts_auto_speak_replies';
const _voiceLoopPrefKey = 'tts_voice_loop_mode';

final supertonicModelsReadyProvider = FutureProvider<bool>((ref) async {
  return supertonicModelManager.areModelsDownloaded();
});

/// Currently selected voice ID. Persisted to SharedPreferences.
class ActiveVoiceIdNotifier extends StateNotifier<String> {
  ActiveVoiceIdNotifier(this._ref) : super(_initial(_ref));
  final Ref _ref;

  static String _initial(Ref ref) {
    try {
      return ref.read(sharedPrefsProvider).getString(_activeVoicePrefKey) ?? 'M1';
    } catch (_) {
      return 'M1';
    }
  }

  Future<void> setVoice(String id) async {
    if (id == state) return;
    state = id;
    try {
      await _ref.read(sharedPrefsProvider).setString(_activeVoicePrefKey, id);
    } catch (_) {}
  }
}

final activeVoiceIdProvider =
    StateNotifierProvider<ActiveVoiceIdNotifier, String>((ref) {
  return ActiveVoiceIdNotifier(ref);
});

/// Auto-speak assistant replies whenever they finish streaming.
/// Persisted to SharedPreferences. Default off.
class AutoSpeakRepliesNotifier extends StateNotifier<bool> {
  AutoSpeakRepliesNotifier(this._ref) : super(_initial(_ref));
  final Ref _ref;

  static bool _initial(Ref ref) {
    try {
      return ref.read(sharedPrefsProvider).getBool(_autoSpeakPrefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> set(bool value) async {
    if (value == state) return;
    state = value;
    try {
      await _ref.read(sharedPrefsProvider).setBool(_autoSpeakPrefKey, value);
    } catch (_) {}
  }
}

final autoSpeakRepliesProvider =
    StateNotifierProvider<AutoSpeakRepliesNotifier, bool>((ref) {
  return AutoSpeakRepliesNotifier(ref);
});

/// Voice-loop mode: when the mic widget delivers a final transcription,
/// auto-send the message instead of leaving it in the input field.
/// Combined with [autoSpeakRepliesProvider] this closes the hands-free
/// chat loop. Persisted to SharedPreferences. Default off.
class VoiceLoopModeNotifier extends StateNotifier<bool> {
  VoiceLoopModeNotifier(this._ref) : super(_initial(_ref));
  final Ref _ref;

  static bool _initial(Ref ref) {
    try {
      return ref.read(sharedPrefsProvider).getBool(_voiceLoopPrefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> set(bool value) async {
    if (value == state) return;
    state = value;
    try {
      await _ref.read(sharedPrefsProvider).setBool(_voiceLoopPrefKey, value);
    } catch (_) {}
  }
}

final voiceLoopModeProvider =
    StateNotifierProvider<VoiceLoopModeNotifier, bool>((ref) {
  return VoiceLoopModeNotifier(ref);
});

/// Message id currently being spoken aloud. ChatBubble watches this
/// to flip its speaker icon between play and stop states; the chat
/// screen sets it when the user taps the speaker and clears it when
/// `TtsService.speak()` resolves. null = nothing speaking.
final speakingMessageIdProvider = StateProvider<String?>((ref) => null);

/// Watch this from `tts_service.dart` to lazy-load the engine whenever
/// the active voice or model-readiness state changes. Returns true when
/// the engine is loaded and ready to synthesise.
final ttsModelLoadedProvider = FutureProvider<bool>((ref) async {
  final voiceId = ref.watch(activeVoiceIdProvider);
  final modelsReady = await ref.watch(supertonicModelsReadyProvider.future);
  if (!modelsReady) return false;

  try {
    final voiceReady = await supertonicModelManager.isVoiceDownloaded(voiceId);
    if (!voiceReady) return false;
    if (!supertonicTtsService.isLoaded ||
        supertonicTtsService.loadedVoiceId != voiceId) {
      await supertonicTtsService.loadModel(voiceId: voiceId);
    }
    return true;
  } catch (_) {
    return false;
  }
});
