/// Riverpod providers for the Hermes Agent integration.
///
/// Settings live in SharedPreferences (non-sensitive — the API key is a
/// self-hosted gateway token, not a user-specific credential). See spec §7.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hermes/hermes_client.dart';
import 'core_providers.dart';

// ── Settings ─────────────────────────────────────────────────────────────

final hermesBaseUrlProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('hermes_base_url') ?? '';
});

final hermesApiKeyProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('hermes_api_key') ?? '';
});

// ── Client (null when not configured) ────────────────────────────────────

final hermesClientProvider = Provider<HermesClient?>((ref) {
  final url = ref.watch(hermesBaseUrlProvider);
  final key = ref.watch(hermesApiKeyProvider);
  if (url.isEmpty || key.isEmpty) return null;
  final client = HermesClient(baseUrl: url, apiKey: key);
  ref.onDispose(client.dispose);
  return client;
});

// ── Connection state ─────────────────────────────────────────────────────

final hermesReachableProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(hermesClientProvider);
  if (client == null) return false;
  return client.isReachable();
});

final hermesModelIdProvider = FutureProvider<String?>((ref) async {
  final client = ref.watch(hermesClientProvider);
  if (client == null) return null;
  return client.getModelId();
});
