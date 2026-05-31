/// Riverpod providers for the Ambient tab — Focus Sounds catalogue +
/// engine state, World Radio places + search + active channel.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/ambient/focus_sound_engine.dart';
import '../../core/ambient/radio_garden_service.dart';
import '../../features/ambient/models/favorite_station.dart';
import '../../features/ambient/models/radio_models.dart';
import '../../features/ambient/models/sound_scene.dart';
import 'core_providers.dart';

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

/// Latest "now playing" line surfaced by the active stream's ICY
/// metadata, if the broadcaster emits any. Null when no ICY info has
/// arrived (most broadcasters either don't send it or only update it
/// every ~10s). Cleared automatically when the active channel changes.
final radioNowPlayingProvider = StateProvider<String?>((ref) => null);

const _radioFavoritesPrefKey = 'radio_favorites';

/// Persistent list of starred radio stations. Backed by
/// SharedPreferences under `radio_favorites` as a JSON array; the list
/// reorders most-recent-first so newly starred stations float to top.
class RadioFavoritesNotifier extends StateNotifier<List<FavoriteStation>> {
  RadioFavoritesNotifier(this._ref) : super(_initial(_ref));
  final Ref _ref;

  static List<FavoriteStation> _initial(Ref ref) {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      return FavoriteStation.decode(prefs.getString(_radioFavoritesPrefKey));
    } catch (_) {
      return const [];
    }
  }

  bool isFavorite(String channelId) =>
      state.any((f) => f.channelId == channelId);

  Future<void> add(FavoriteStation station) async {
    if (isFavorite(station.channelId)) return;
    state = [station, ...state];
    await _persist();
  }

  Future<void> remove(String channelId) async {
    state = state.where((f) => f.channelId != channelId).toList();
    await _persist();
  }

  Future<void> toggle(FavoriteStation station) async {
    if (isFavorite(station.channelId)) {
      await remove(station.channelId);
    } else {
      await add(station);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = _ref.read(sharedPrefsProvider);
      await prefs.setString(
          _radioFavoritesPrefKey, FavoriteStation.encode(state));
    } catch (_) {}
  }
}

final radioFavoritesProvider =
    StateNotifierProvider<RadioFavoritesNotifier, List<FavoriteStation>>(
  (ref) => RadioFavoritesNotifier(ref),
);
