/// Persists auto-generated session titles keyed by session id.
/// OpenClaw's gateway doesn't return titles for sessions, so we
/// generate them client-side from the first user message and stash
/// them in SharedPreferences. Hermes already populates `sessions.title`
/// server-side, so this store is OpenClaw-only in practice.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionTitleStore {
  static const _prefKey = 'session_titles_v1';
  static const _maxEntries = 200;

  final SharedPreferences _prefs;
  SessionTitleStore(this._prefs);

  String? getTitle(String sessionId) {
    final raw = _prefs.getString(_prefKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map[sessionId] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setTitle(String sessionId, String title) async {
    final raw = _prefs.getString(_prefKey);
    final map = <String, dynamic>{};
    if (raw != null) {
      try {
        map.addAll(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    map[sessionId] = title;

    if (map.length > _maxEntries) {
      // Drop the earliest insertion-order entries (rough LRU — we don't
      // track access time, so this is best-effort capping not eviction).
      final keys = map.keys.toList();
      for (final k in keys.take(map.length - _maxEntries)) {
        map.remove(k);
      }
    }

    await _prefs.setString(_prefKey, jsonEncode(map));
  }
}
