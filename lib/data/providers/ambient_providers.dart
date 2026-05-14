/// Riverpod providers for the Ambient tab — Focus Sounds catalogue +
/// engine state, World Radio places + search + active channel.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/ambient/focus_sound_engine.dart';
import '../../core/ambient/radio_garden_service.dart';
import '../../features/ambient/models/radio_models.dart';
import '../../features/ambient/models/sound_scene.dart';

// ── Focus Sounds ─────────────────────────────────────────────────────────────

final soundCatalogueProvider = FutureProvider<List<SoundScene>>((ref) {
  return FocusSoundEngine.loadCatalogue();
});

final focusSoundStateProvider = StreamProvider<FocusSoundState>((ref) {
  return focusSoundEngine.stateStream;
});

final focusPlayingProvider = Provider<bool>((ref) {
  return ref.watch(focusSoundStateProvider).valueOrNull?.isPlaying ?? false;
});

// ── World Radio ──────────────────────────────────────────────────────────────

final radioPlacesProvider = FutureProvider<List<RadioPlace>>((ref) {
  return radioGardenService.listPlaces();
});

final radioSearchQueryProvider = StateProvider<String>((ref) => '');

final radioSearchResultsProvider =
    FutureProvider<List<RadioSearchHit>>((ref) async {
  final q = ref.watch(radioSearchQueryProvider).trim();
  if (q.length < 2) return const [];
  return radioGardenService.search(q);
});

/// Currently playing radio channel (null = nothing playing). Drives
/// the mini-player and the Play/Stop affordances on the World Radio
/// detail surface.
final activeRadioChannelProvider =
    StateProvider<RadioChannel?>((ref) => null);

/// Singleton AudioPlayer instance used for streaming radio. Kept
/// separate from `supertonicTtsService._player` so TTS bleeps don't
/// fight the radio stream. Disposed when the provider container is
/// torn down (app shutdown).
final radioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});
