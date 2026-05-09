/// Active-server scoping — the top-level provider that drives which
/// agent's surfaces (Mission Control, Memory, Skills, chat default)
/// the user is currently looking at.
///
/// Replaces `chatModeProvider` as the *primary* concept; chatMode is
/// now derived from this so the two stay in sync. Per ADR-001.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';
import 'hermes_providers.dart';

/// The three server types ClawCommander can connect to.
enum ActiveServer { openclaw, hermes, local }

extension ActiveServerLabel on ActiveServer {
  String get displayName => switch (this) {
        ActiveServer.openclaw => 'OpenClaw',
        ActiveServer.hermes => 'Hermes',
        ActiveServer.local => 'Local',
      };
}

/// The currently active server. Persisted in SharedPreferences. If the
/// user has not made an explicit choice, auto-detect from configured
/// servers — OpenClaw beats Hermes beats Local.
final activeServerProvider = StateProvider<ActiveServer>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);

  final stored = prefs.getString('active_server');
  if (stored != null) {
    try {
      return ActiveServer.values.byName(stored);
    } catch (_) {
      // Stored value from a future / removed enum entry — fall through.
    }
  }

  return _detectActiveServer(ref);
});

ActiveServer _detectActiveServer(Ref ref) {
  try {
    final url = ref.read(gatewayUrlProvider);
    if (url.isNotEmpty) return ActiveServer.openclaw;
  } catch (_) {}

  try {
    final url = ref.read(hermesBaseUrlProvider);
    final key = ref.read(hermesApiKeyProvider);
    if (url.isNotEmpty && key.isNotEmpty) return ActiveServer.hermes;
  } catch (_) {}

  return ActiveServer.local;
}

/// Persist the user's active-server choice and update the in-memory
/// state. Use this from anywhere that needs to switch — picker sheet,
/// chat-mode selector, etc.
Future<void> setActiveServer(WidgetRef ref, ActiveServer server) async {
  await ref.read(sharedPrefsProvider).setString('active_server', server.name);
  ref.read(activeServerProvider.notifier).state = server;
}
