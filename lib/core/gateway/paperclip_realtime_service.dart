/// Paperclip WebSocket realtime service — connects to the Paperclip
/// backend and feeds live company data into PaperclipNotifier.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/providers/paperclip_connection_provider.dart';
import '../../data/providers/paperclip_provider.dart';

class PaperclipRealtimeService {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  static const int _maxBackoffSeconds = 60;

  PaperclipRealtimeService(this._ref);

  /// Connect to the Paperclip WebSocket endpoint.
  Future<void> connect() async {
    if (_disposed) return;

    final wsUrl = _ref.read(paperclipWsUrlProvider);
    final token = _ref.read(paperclipTokenProvider);

    if (wsUrl.isEmpty || token.isEmpty) {
      debugPrint('Paperclip: no URL or token configured, skipping connect');
      return;
    }

    _cancelReconnect();

    try {
      debugPrint('Paperclip: connecting to $wsUrl');

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['paperclip-v1'],
      );

      // Authenticate
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'token': token,
      }));

      _ref.read(paperclipProvider.notifier).updateConnection(true);
      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
    } catch (e) {
      debugPrint('Paperclip: connection failed — $e');
      _ref.read(paperclipProvider.notifier).updateConnection(false);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      _ref.read(paperclipProvider.notifier).handleWebSocketEvent(data);
    } catch (e) {
      debugPrint('Paperclip: failed to parse message — $e');
    }
  }

  void _onError(Object error) {
    debugPrint('Paperclip: WebSocket error — $error');
    _ref.read(paperclipProvider.notifier).updateConnection(false);
    _scheduleReconnect();
  }

  void _onDone() {
    if (_disposed) return;
    debugPrint('Paperclip: WebSocket closed');
    _ref.read(paperclipProvider.notifier).updateConnection(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _cancelReconnect();

    final delaySec = min(
      pow(2, _reconnectAttempts).toInt(),
      _maxBackoffSeconds,
    );
    _reconnectAttempts++;

    debugPrint('Paperclip: reconnecting in ${delaySec}s '
        '(attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_disposed) connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void disconnect() {
    _cancelReconnect();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _ref.read(paperclipProvider.notifier).updateConnection(false);
  }

  void dispose() {
    _disposed = true;
    disconnect();
  }
}

/// Provider that creates and auto-starts the Paperclip realtime service.
/// Watch this provider from the app root to keep the connection alive.
final paperclipRealtimeProvider = Provider<PaperclipRealtimeService>((ref) {
  final service = PaperclipRealtimeService(ref);

  // Auto-connect when the URL and token become available
  final wsUrl = ref.watch(paperclipWsUrlProvider);
  final token = ref.watch(paperclipTokenProvider);

  if (wsUrl.isNotEmpty && token.isNotEmpty) {
    // Schedule connect after the provider is fully initialised
    Future.microtask(() => service.connect());
  }

  ref.onDispose(() => service.dispose());
  return service;
});
