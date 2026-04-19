/// Gateway WebSocket client for OpenClaw server communication
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:uuid/uuid.dart';

import '../../data/models/gateway_event.dart';
import 'device_identity.dart';
import 'file_logger.dart';

const _uuid = Uuid();

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
  bool _connectCompleted = false;
  bool _reconnecting = false;
  int _reqCounter = 0;
  int _connAttempt = 0;
  StreamSubscription<dynamic>? _streamSub;
  final Map<String, Completer<dynamic>> _pending = {};

  GatewayClient({
    required this.gatewayUrl,
    required this.authToken,
  });

  static const String _tag = '[gateway]';

  String _nextId() =>
      'pc-${DateTime.now().millisecondsSinceEpoch}-${_reqCounter++}';

  Future<void> connect() async {
    if (_disposed) return;

    // Tear down any prior connection BEFORE opening a new one, otherwise a
    // stale stream.listen from the previous socket will still fire onDone
    // later and kick off a parallel reconnect loop (observed as a 503 storm).
    try {
      await _streamSub?.cancel();
    } catch (_) {}
    _streamSub = null;
    try {
      _channel?.sink.close(1000);
    } catch (_) {}
    _channel = null;

    _connectionState.value = GatewayState.connecting;
    _connectCompleted = false;
    final attempt = ++_connAttempt;
    FileLogger.instance
        .log(_tag, 'connect() url=$gatewayUrl tokenLen=${authToken.length}');

    try {
      final socket = await WebSocket.connect(
        gatewayUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
        },
        compression: CompressionOptions.compressionOff,
      );

      FileLogger.instance.log(
          _tag,
          'ws OPEN  readyState=${socket.readyState} '
          'protocol=${socket.protocol}');

      _channel = IOWebSocketChannel(socket);

      // We do NOT mark the connection "connected" here. The OpenClaw gateway
      // protocol requires a handshake: the server sends a `connect.challenge`
      // event with a nonce, and the client must reply with a `connect` request
      // frame (JSON-RPC style: {id, method, params}). Only when the server
      // returns a helloOk response do we consider the connection usable.

      _streamSub = _channel!.stream.listen(
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
          // Ignore events from stale subscriptions.
          if (attempt != _connAttempt) return;
          FileLogger.instance.log(_tag, 'stream ERROR: $e');
          _handleError(e);
        },
        onDone: () {
          // Ignore zombie onDone from a subscription we've already replaced.
          if (attempt != _connAttempt) return;
          FileLogger.instance.log(
              _tag,
              'stream DONE  closeCode=${_channel?.closeCode} '
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
    // Gateway method is `chat.send`. Required params: sessionKey, message,
    // idempotencyKey (UUID, also used as runId). Server replies with
    // {runId, status:"started"}; assistant tokens stream later as separate
    // server-pushed `session.message` frames correlated by runId.
    final id = _nextId();
    final idempotencyKey = _uuid.v4();
    final frame = jsonEncode({
      'type': 'req',
      'id': id,
      'method': 'chat.send',
      'params': {
        'sessionKey': sessionKey ?? 'pocket-claw-main',
        'message': message,
        'idempotencyKey': idempotencyKey,
      },
    });
    FileLogger.instance.log(_tag, 'SEND -> $frame');
    _channel?.sink.add(frame);
  }

  Future<void> sendTask(String action, Map<String, dynamic> data) async {
    final id = _nextId();
    _channel?.sink.add(jsonEncode({
      'type': 'req',
      'id': id,
      'method': 'task',
      'params': {
        'action': action,
        'data': data,
      },
    }));
  }

  Future<void> query(String resource) async {
    final id = _nextId();
    _channel?.sink.add(jsonEncode({
      'type': 'req',
      'id': id,
      'method': 'query',
      'params': {'resource': resource},
    }));
  }

  void _handleMessage(Map<String, dynamic> data) {
    // Response frame: {type:"res", id, ok, payload?, error?}
    // (Server uses `payload` for success results, not `result`.)
    final idVal = data['id'];
    if (data['type'] == 'res' && idVal is String) {
      final completer = _pending.remove(idVal);
      final err = data['error'];
      final isError = data['ok'] == false || err != null;
      final successBody = data['payload'] ?? data['result'];

      if (completer != null && !completer.isCompleted) {
        if (isError) {
          completer.completeError(err ?? 'request failed');
        } else {
          completer.complete(successBody);
        }
        return;
      }

      // Fire-and-forget response — only surface ERRORS in the chat stream.
      // A `chat.send` success returns {runId, status:"started"} which is
      // NOT the assistant's reply; the reply arrives as separate
      // server-pushed `session.message` frames. Emitting the ack would
      // clobber the streaming placeholder with "{\"runId\":...}".
      if (isError) {
        final chunk = ((err is Map ? err['message'] : null) as String?) ??
            'Server error: ${jsonEncode(err)}';
        _responses.add(ServerResponse(
          sessionKey: 'pocket-claw-main',
          chunk: chunk,
          done: true,
        ));
      } else {
        FileLogger.instance.log(_tag, 'res ok (ack) payload=$successBody');
      }
      return;
    }

    // Server-pushed request frame: {type:"req", id, method, params}.
    // The gateway uses this to stream assistant tokens via `session.message`
    // and tool events via `session.tool`, correlated by runId.
    if (data['type'] == 'req' && data['method'] is String) {
      final method = data['method'] as String;
      final params = (data['params'] as Map<String, dynamic>?) ?? const {};
      if (method == 'session.message') {
        // Heuristic extraction — log the raw once so we can lock down the
        // exact field name on first round-trip.
        final chunk = (params['content'] ??
                params['text'] ??
                params['delta'] ??
                params['message'] ??
                '')
            .toString();
        final done = params['done'] == true ||
            params['status'] == 'completed' ||
            params['final'] == true;
        _responses.add(ServerResponse(
          sessionKey: (params['sessionKey'] as String?) ?? 'pocket-claw-main',
          chunk: chunk,
          done: done,
        ));
      } else if (method == 'session.tool') {
        FileLogger.instance.log(_tag, 'session.tool: ${jsonEncode(params)}');
      }
      // ACK so the server doesn't time out the push frame.
      if (idVal is String) {
        _channel?.sink.add(jsonEncode({
          'type': 'res',
          'id': idVal,
          'ok': true,
          'payload': {},
        }));
      }
      return;
    }

    switch (data['type']) {
      case 'response':
        _responses.add(ServerResponse.fromJson(data));
        break;
      case 'event':
        final event = data['event'];
        final payload = (data['payload'] as Map<String, dynamic>?) ?? const {};

        if (event == 'connect.challenge') {
          final nonce = payload['nonce'] as String?;
          if (nonce != null && nonce.isNotEmpty && !_connectCompleted) {
            _sendConnectRequest(nonce);
          } else {
            FileLogger.instance.log(
                _tag, 'challenge received but nonce missing or already sent');
          }
          break;
        }

        // Chat deltas: event="agent", stream="assistant" carries {text, delta}.
        // We stream data.delta (incremental) so the UI appends tokens.
        if (event == 'agent' && payload['stream'] == 'assistant') {
          final dataField = payload['data'];
          final delta = (dataField is Map)
              ? (dataField['delta'] as String?) ?? ''
              : '';
          if (delta.isNotEmpty) {
            _responses.add(ServerResponse(
              sessionKey:
                  (payload['sessionKey'] as String?) ?? 'pocket-claw-main',
              chunk: delta,
              done: false,
            ));
          }
          break;
        }

        // Chat completion: event="chat", state="final" ends the stream.
        // Emit an empty done=true chunk so the chat UI stops the spinner.
        if (event == 'chat' && payload['state'] == 'final') {
          _responses.add(ServerResponse(
            sessionKey:
                (payload['sessionKey'] as String?) ?? 'pocket-claw-main',
            chunk: '',
            done: true,
          ));
          break;
        }

        // Other events (chat deltas — redundant with agent, lifecycle,
        // health, tick) just flow through to the observer stream.
        _agentEvents.add(AgentEvent.fromJson(data));
        break;
      case 'heartbeat':
        _agentEvents.add(AgentEvent.heartbeat(data));
        break;
      default:
        FileLogger.instance.log(
            _tag,
            'UNHANDLED message type="${data['type']}" '
            'keys=${data.keys.toList()}');
    }
  }

  Future<void> _sendConnectRequest(String nonce) async {
    _connectCompleted = true;

    // --- Build device-auth v3 signature ---
    //
    // The OpenClaw gateway clears any requested scopes for clients without a
    // signed device identity. We persist an Ed25519 keypair in secure storage
    // and sign each `connect.challenge` nonce. First-time connects will still
    // be pending admin approval (`openclaw devices approve <deviceId>` on the
    // VPS); subsequent connects reuse the same keypair.
    final DeviceIdentity identity;
    try {
      identity = await DeviceIdentity.loadOrCreate();
    } catch (e) {
      FileLogger.instance.log(_tag, 'device identity load failed: $e');
      return;
    }

    const clientIdStr = 'openclaw-android';
    const clientModeStr = 'ui';
    const roleStr = 'operator';
    const platformStr = 'android';
    final scopesList = <String>['operator.admin'];
    final signedAtMs = DateTime.now().millisecondsSinceEpoch;

    final signingPayload = buildSignaturePayloadV3(
      deviceId: identity.deviceId,
      clientId: clientIdStr,
      clientMode: clientModeStr,
      role: roleStr,
      scopes: scopesList,
      signedAtMs: signedAtMs,
      token: authToken,
      nonce: nonce,
      platform: platformStr,
      deviceFamily: null,
    );
    final signature = await signPayloadEd25519(signingPayload, identity);

    final id = _nextId();
    final completer = Completer<dynamic>();
    _pending[id] = completer;

    final frame = jsonEncode({
      'type': 'req',
      'id': id,
      'method': 'connect',
      'params': {
        'minProtocol': 3,
        'maxProtocol': 3,
        'client': {
          'id': clientIdStr,
          'displayName': 'Pocket Claw',
          'version': '1.0.0',
          'platform': platformStr,
          'mode': clientModeStr,
          'instanceId': id,
        },
        'caps': <String>[],
        'auth': {'token': authToken},
        'role': roleStr,
        'scopes': scopesList,
        'device': {
          'id': identity.deviceId,
          'publicKey': identity.publicKeyBase64Url,
          'signature': signature,
          'signedAt': signedAtMs,
          'nonce': nonce,
        },
      },
    });
    FileLogger.instance.log(
        _tag,
        'SEND -> connect req id=$id '
        'deviceId=${identity.deviceId.substring(0, 8)}... nonce=$nonce');
    _channel?.sink.add(frame);

    try {
      final result =
          await completer.future.timeout(const Duration(seconds: 10));
      FileLogger.instance.log(_tag, 'helloOk received');
      _connectionState.value = GatewayState.connected;
    } catch (e) {
      FileLogger.instance.log(_tag, 'connect request failed: $e');
      _pending.remove(id);
    }
  }

  void _handleError(Object error) {
    _connectionState.value = GatewayState.error;
    FileLogger.instance.log(_tag, 'error: $error');
  }

  Future<void> _handleDisconnect() async {
    if (_disposed) return;
    // Prevent multiple reconnect loops from running in parallel when
    // several close events arrive close together.
    if (_reconnecting) return;
    _reconnecting = true;
    try {
      // Fail any in-flight requests so callers unblock.
      for (final c in _pending.values) {
        if (!c.isCompleted) c.completeError('disconnected');
      }
      _pending.clear();
      _connectionState.value = GatewayState.reconnecting;

      // Start with a longer first delay so a 503 burst from the gateway
      // has a chance to cool off.
      for (final delay in [5, 5, 10, 15, 30, 60]) {
        if (_disposed) return;
        await Future<void>.delayed(Duration(seconds: delay));
        try {
          await connect();
          // Allow the handshake a moment to complete.
          await Future<void>.delayed(const Duration(seconds: 3));
          if (_connectionState.value == GatewayState.connected) return;
        } catch (_) {
          // Continue retry loop
        }
      }

      _connectionState.value = GatewayState.disconnected;
    } finally {
      _reconnecting = false;
    }
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
