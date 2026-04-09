/// Gateway WebSocket client for OpenClaw server communication
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/models/gateway_event.dart';

class GatewayClient {
  WebSocketChannel? _channel;
  final String gatewayUrl;
  final String authToken;

  final _connectionState =
      ValueNotifier<GatewayState>(GatewayState.disconnected);
  ValueListenable<GatewayState> get connectionState => _connectionState;

  final _agentEvents = StreamController<AgentEvent>.broadcast();
  Stream<AgentEvent> get agentEvents => _agentEvents.stream;

  final _responses = StreamController<ServerResponse>.broadcast();
  Stream<ServerResponse> get responses => _responses.stream;

  bool _disposed = false;

  GatewayClient({
    required this.gatewayUrl,
    required this.authToken,
  });

  Future<void> connect() async {
    if (_disposed) return;
    _connectionState.value = GatewayState.connecting;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(gatewayUrl),
        protocols: ['openclaw-v1'],
      );

      // Send auth on connect
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'token': authToken,
      }));

      _connectionState.value = GatewayState.connected;

      _channel!.stream.listen(
        (data) => _handleMessage(jsonDecode(data as String)),
        onError: (Object e) => _handleError(e),
        onDone: () => _handleDisconnect(),
      );
    } catch (e) {
      _connectionState.value = GatewayState.error;
    }
  }

  Future<void> sendMessage(String message, {String? sessionKey}) async {
    _channel?.sink.add(jsonEncode({
      'type': 'message',
      'content': message,
      'sessionKey': sessionKey ?? 'pocket-claw-main',
      'source': 'pocket-claw',
    }));
  }

  Future<void> sendTask(String action, Map<String, dynamic> data) async {
    _channel?.sink.add(jsonEncode({
      'type': 'task',
      'action': action,
      'data': data,
    }));
  }

  Future<void> query(String resource) async {
    _channel?.sink.add(jsonEncode({
      'type': 'query',
      'resource': resource,
    }));
  }

  void _handleMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'response':
        _responses.add(ServerResponse.fromJson(data));
        break;
      case 'event':
        _agentEvents.add(AgentEvent.fromJson(data));
        break;
      case 'heartbeat':
        _agentEvents.add(AgentEvent.heartbeat(data));
        break;
    }
  }

  void _handleError(Object error) {
    _connectionState.value = GatewayState.error;
    debugPrint('Gateway error: $error');
  }

  Future<void> _handleDisconnect() async {
    if (_disposed) return;
    _connectionState.value = GatewayState.reconnecting;

    for (final delay in [1, 2, 4, 8, 16, 30]) {
      if (_disposed) return;
      await Future<void>.delayed(Duration(seconds: delay));
      try {
        await connect();
        if (_connectionState.value == GatewayState.connected) return;
      } catch (_) {
        // Continue retry loop
      }
    }

    _connectionState.value = GatewayState.disconnected;
  }

  void disconnect() {
    _channel?.sink.close();
    _connectionState.value = GatewayState.disconnected;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _agentEvents.close();
    _responses.close();
    _connectionState.dispose();
  }
}
