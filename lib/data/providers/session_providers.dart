/// Providers for client-side session title generation. OpenClaw's
/// gateway doesn't return titles, so we generate them from the first
/// user message and persist them keyed by sessionKey. Hermes already
/// has server-side titles in `state.db` and doesn't use this store.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_title_store.dart';
import 'core_providers.dart';

final sessionTitleStoreProvider = Provider<SessionTitleStore>((ref) {
  return SessionTitleStore(ref.watch(sharedPrefsProvider));
});

/// Family provider for fetching a stored title for a given session key.
/// Returns null when there's no stored title — caller decides whether
/// to fall back to the raw key or a placeholder.
final sessionTitleProvider = Provider.family<String?, String>(
  (ref, sessionKey) =>
      ref.watch(sessionTitleStoreProvider).getTitle(sessionKey),
);
