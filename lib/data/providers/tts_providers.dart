/// Riverpod providers for TTS state — Supertonic model readiness,
/// active voice selection (persisted to SharedPreferences), and a
/// lazy-load hook that auto-warms the engine when the voice changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tts/supertonic_model_manager.dart';
import '../../core/tts/supertonic_tts_service.dart';
import 'core_providers.dart';

const _activeVoicePrefKey = 'supertonic_voice_id';

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
