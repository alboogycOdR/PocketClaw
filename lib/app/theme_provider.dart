/// Theme selection provider — reads / writes the chosen `ThemeId` to
/// SharedPreferences and broadcasts changes so `PocketClawApp` rebuilds
/// MaterialApp with the new ThemeData.
///
/// The active palette swap on `PocketClawTheme` is done by
/// `PocketClawApp.build()` at the top of build, *before* MaterialApp is
/// returned — that way the new ThemeData and the new static colour
/// getters consumed by hand-painted widgets paint the same frame.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/core_providers.dart';
import 'theme.dart';

const _themeIdPrefKey = 'app_theme_id';

class ThemeIdNotifier extends StateNotifier<ThemeId> {
  ThemeIdNotifier(this._ref) : super(_initial(_ref));

  final Ref _ref;

  static ThemeId _initial(Ref ref) {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      final raw = prefs.getString(_themeIdPrefKey);
      if (raw != null) {
        for (final id in ThemeId.values) {
          if (id.name == raw) return id;
        }
      }
    } catch (_) {
      // SharedPreferences not yet available — fall through to default.
    }
    return ThemeId.dark;
  }

  Future<void> setTheme(ThemeId id) async {
    if (id == state) return;
    state = id;
    try {
      final prefs = _ref.read(sharedPrefsProvider);
      await prefs.setString(_themeIdPrefKey, id.name);
    } catch (_) {
      // Best-effort persistence; the in-memory swap still applies.
    }
  }
}

final themeIdProvider =
    StateNotifierProvider<ThemeIdNotifier, ThemeId>((ref) {
  return ThemeIdNotifier(ref);
});
