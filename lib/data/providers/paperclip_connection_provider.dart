/// Paperclip WebSocket connection settings providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// WebSocket URL for the Paperclip service.
/// Defaults to the gateway URL with /paperclip path appended.
final paperclipWsUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final stored = prefs.getString('paperclip_ws_url') ?? '';
  if (stored.isNotEmpty) return stored;

  // Derive from gateway URL if available
  final gatewayUrl = ref.watch(gatewayUrlProvider);
  if (gatewayUrl.isNotEmpty) {
    final base = gatewayUrl.endsWith('/')
        ? gatewayUrl.substring(0, gatewayUrl.length - 1)
        : gatewayUrl;
    return '$base/paperclip';
  }
  return '';
});

/// Auth token for Paperclip — reuses gateway token by default.
final paperclipTokenProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final stored = prefs.getString('paperclip_token') ?? '';
  if (stored.isNotEmpty) return stored;
  return ref.watch(gatewayTokenProvider);
});
