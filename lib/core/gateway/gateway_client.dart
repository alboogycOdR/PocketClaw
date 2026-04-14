/// Gateway WebSocket client for OpenClaw server communication
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/models/gateway_event.dart';
import 'file_logger.dart';

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

  static const String _tag = '[gateway]';

  Future<void> connect() async {
    if (_disposed) return;
    _connectionState.value = GatewayState.connecting;
    FileLogger.instance.log(_tag, 'connect() url=$gatewayUrl tokenLen=${authToken.length}');

    try {
      final socket = await WebSocket.connect(
        gatewayUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      FileLogger.instance.log(_tag, 'ws OPEN  readyState=${socket.readyState} '
          'protocol=${socket.protocol}');

      _channel = IOWebSocketChannel(socket);

      // Also send the auth envelope after connect
      final authMsg = jsonEncode({'type': 'auth', 'token': authToken});
      _channel!.sink.add(authMsg);
      FileLogger.instance.log(_tag, 'SEND -> $authMsg');

      _connectionState.value = GatewayState.connected;

      _channel!.stream.listen(
        (data) {
          final preview = data is String
              ? (data.length > 400 ? '${data.substring(0, 400)}...' : data)
              : '<binary>';
          FileLogger.instance.log(_tag, 'RECV <- $preview');
          try {
            _handleMessage(jsonDecode(data as String));
          } catch (e) {
            FileLogger.instance.log(_tag, 'RECV parse error: $e');
          }
        },
        onError: (Object e) {
          FileLogger.instance.log(_tag, 'stream ERROR: $e');
          _handleError(e);
        },
        onDone: () {
          FileLogger.instance.log(_tag, 'stream DONE  closeCode=${_channel?.closeCode} '
              'closeReason=${_channel?.closeReason}');
          _handleDisconnect();
        },
      );
    } catch (e, st) {
      FileLogger.instance.log(_tag, 'connect FAILED: $e\n$st');
      _connectionState.value = GatewayState.error;
    }
  }

  Future<void> sendMessage(String message, {String? sessionKey}) async {
    final frame = jsonEncode({
      'type': 'message',
      'content': message,
      'sessionKey': sessionKey ?? 'pocket-claw-main',
      'source': 'pocket-claw',
    });
    FileLogger.instance.log(_tag, 'SEND -> $frame');
    _channel?.sink.add(frame);
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
      default:
        FileLogger.instance.log(_tag, 'UNHANDLED message type="${data['type']}" '
            'keys=${data.keys.toList()}');
    }
  }

  void _handleError(Object error) {
    _connectionState.value = GatewayState.error;
    FileLogger.instance.log(_tag, 'error: $error');
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
