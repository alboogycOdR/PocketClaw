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

  /// Latest `event:"health"` payload from the gateway. Drives the Mission
  /// Control health panel without another REST call.
  final _health = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get healthStream => _health.stream;

  bool _disposed = false;
  bool _connectCompleted = false;
  bool _reconnecting = false;
  int _reqCounter = 0;
  int _connAttempt = 0;
  StreamSubscription<dynamic>? _streamSub;
  final Map<String, Completer<dynamic>> _pending = {};

  /// Run IDs the client has open chat.send calls for. Any incoming event
  /// whose runId isn't here is treated as a PROACTIVE agent push and
  /// surfaced as a fresh bubble rather than appended to a streaming reply.
  final Set<String> _inFlightRunIds = {};

  /// Per-run last-seen assistant accumulated text. Used to synthesise a
  /// delta when the server frame only carries `data.text` (full) without
  /// `data.delta`. Cleared on the run's final frame.
  final Map<String, String> _lastAssistantTextByRun = {};

  /// Last loaded device identity — exposed so the UI can show the deviceId
  /// on the pairing-waiting screen. Populated on the first connect attempt.
  DeviceIdentity? _deviceIdentity;
  DeviceIdentity? get deviceIdentity => _deviceIdentity;

  /// True if the most recent close reason indicated pairing approval is
  /// outstanding. The reconnect loop respects this and stops looping; the
  /// UI prompts the user (or a VPS admin) to approve the device.
  bool _pairingRequired = false;
  bool get pairingRequired => _pairingRequired;

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

    // Clear the pairing-required flag — a fresh manual reconnect means the
    // caller (UI "Check approval" button, etc) wants to retry from scratch.
    _pairingRequired = false;
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
          final reason = _channel?.closeReason ?? '';
          FileLogger.instance.log(
              _tag,
              'stream DONE  closeCode=${_channel?.closeCode} '
              'closeReason=$reason');
          // Surface the "pairing required" terminal state to the UI and
          // stop the retry loop — approval is a one-time external action,
          // not something a tighter backoff will fix.
          if (reason.toLowerCase().contains('pairing required') ||
              reason.toLowerCase().contains('not-paired')) {
            _pairingRequired = true;
            _connectionState.value = GatewayState.pairingRequired;
            return;
          }
          _handleDisconnect();
        },
      );
    } catch (e, st) {
      FileLogger.instance.log(_tag, 'connect FAILED: $e\n$st');
      _connectionState.value = GatewayState.error;
    }
  }

  /// Send a user message. Returns the server-assigned runId (also equal to
  /// our idempotencyKey) — callers use it to abort mid-stream and to
  /// correlate incoming streaming events to this specific turn.
  ///
  /// [attachments] follows the gateway's chat.send schema: each entry is
  /// `{type, mimeType, fileName, content}` with `content` as a base64
  /// string. 5 MB per attachment; images only (jpeg/png/webp/gif/heic/heif
  /// round-trip, bmp/tiff inline only).
  Future<String?> sendMessage(
    String message, {
    String? sessionKey,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final id = _nextId();
    final idempotencyKey = _uuid.v4();
    _inFlightRunIds.add(idempotencyKey);

    final completer = Completer<dynamic>();
    _pending[id] = completer;

    final params = <String, dynamic>{
      'sessionKey': sessionKey ?? 'pocket-claw-main',
      'message': message,
      'idempotencyKey': idempotencyKey,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments,
    };
    final frame = jsonEncode({
      'type': 'req',
      'id': id,
      'method': 'chat.send',
      'params': params,
    });
    // Log WITHOUT the base64 body — attachments can be huge and
    // unintelligible in a text log.
    final logPayload = {
      ...params,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': '<${attachments.length}>',
    };
    FileLogger.instance
        .log(_tag, 'SEND -> chat.send id=$id params=${jsonEncode(logPayload)}');
    _channel?.sink.add(frame);

    try {
      final ack = await completer.future.timeout(const Duration(seconds: 10));
      // Server echoes our idempotencyKey as runId; prefer the server's value.
      if (ack is Map && ack['runId'] is String) {
        return ack['runId'] as String;
      }
      return idempotencyKey;
    } catch (e) {
      _inFlightRunIds.remove(idempotencyKey);
      FileLogger.instance.log(_tag, 'chat.send ack failed: $e');
      rethrow;
    }
  }

  /// Send a JSON-RPC-style request to the gateway and await the response
  /// payload. Use this for one-shot queries (agents.files.list,
  /// doctor.memory.status, channels.status, etc.). Throws the server's
  /// error map if ok=false, a TimeoutException on timeout, or "disconnected"
  /// on an abrupt close.
  Future<dynamic> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final id = _nextId();
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _channel?.sink.add(jsonEncode({
      'type': 'req',
      'id': id,
      'method': method,
      'params': params,
    }));
    FileLogger.instance.log(_tag, 'SEND -> req $method id=$id');
    try {
      return await completer.future.timeout(timeout);
    } catch (e) {
      _pending.remove(id);
      rethrow;
    }
  }

  /// Ask the server to stop an in-flight chat run. Best-effort.
  Future<void> abortChat({
    required String sessionKey,
    required String runId,
  }) async {
    _inFlightRunIds.remove(runId);
    final id = _nextId();
    _channel?.sink.add(jsonEncode({
      'type': 'req',
      'id': id,
      'method': 'chat.abort',
      'params': {
        'sessionKey': sessionKey,
        'runId': runId,
      },
    }));
    FileLogger.instance
        .log(_tag, 'SEND -> chat.abort sessionKey=$sessionKey runId=$runId');
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

        final runId = payload['runId'] as String?;
        final sessionKey =
            (payload['sessionKey'] as String?) ?? 'pocket-claw-main';
        final proactive = runId != null && !_inFlightRunIds.contains(runId);

        // Chat deltas: event="agent", stream="assistant".
        //
        // The frame's `data` payload carries `text` (full accumulated text
        // so far) and sometimes `delta` (just the new tokens). Not every
        // model emits `delta`; some only give us the growing `text`, in
        // which case we synthesise the delta by diffing against the last
        // accumulated text we saw for this runId.
        if (event == 'agent' && payload['stream'] == 'assistant') {
          final dataField = payload['data'];
          String delta = '';
          if (dataField is Map) {
            final rawDelta = dataField['delta'] as String?;
            final fullText = dataField['text'] as String?;
            if (rawDelta != null && rawDelta.isNotEmpty) {
              delta = rawDelta;
              if (runId != null && fullText != null) {
                _lastAssistantTextByRun[runId] = fullText;
              }
            } else if (fullText != null && runId != null) {
              final prior = _lastAssistantTextByRun[runId] ?? '';
              if (fullText.length > prior.length &&
                  fullText.startsWith(prior)) {
                delta = fullText.substring(prior.length);
              } else if (fullText != prior) {
                // Model rewrote earlier tokens — safest fallback is to
                // resync by skipping; the `chat final` frame delivers the
                // full message anyway, so the UI will end up consistent.
                delta = '';
              }
              _lastAssistantTextByRun[runId] = fullText;
            }
          }
          if (delta.isNotEmpty) {
            _responses.add(ServerResponse(
              sessionKey: sessionKey,
              runId: runId,
              chunk: delta,
              done: false,
              proactive: proactive,
            ));
          }
          break;
        }

        // Tool events: event="agent", stream="tool" surfaces the agent
        // running a function call (web search, memory, etc). Render as
        // inline status so the user knows what's happening.
        if (event == 'agent' && payload['stream'] == 'tool') {
          final d = payload['data'];
          final status = _describeToolEvent(d);
          if (status != null) {
            _responses.add(ServerResponse(
              sessionKey: sessionKey,
              runId: runId,
              chunk: '',
              statusText: status,
              done: false,
              proactive: proactive,
            ));
          }
          break;
        }

        // Lifecycle: start/phase transitions. Keep the user informed on
        // long runs without bloating the bubble with noise.
        if (event == 'agent' && payload['stream'] == 'lifecycle') {
          final d = payload['data'];
          if (d is Map) {
            final phase = d['phase'] as String?;
            String? status;
            if (phase == 'start') status = 'Thinking…';
            if (phase == 'tool_call') status = 'Running tool…';
            if (phase == 'completed') status = null; // clear
            if (status != null) {
              _responses.add(ServerResponse(
                sessionKey: sessionKey,
                runId: runId,
                chunk: '',
                statusText: status,
                done: false,
                proactive: proactive,
              ));
            }
          }
          break;
        }

        // Chat completion: event="chat", state="final" ends the stream.
        if (event == 'chat' && payload['state'] == 'final') {
          // Emit any remaining unseen text from the final message, in case
          // the agent stream's last delta didn't cover everything.
          String trailingDelta = '';
          if (runId != null) {
            final msg = payload['message'];
            if (msg is Map) {
              final parts = msg['content'];
              if (parts is List && parts.isNotEmpty) {
                final first = parts.first;
                if (first is Map) {
                  final finalText = first['text'] as String?;
                  if (finalText != null) {
                    final prior = _lastAssistantTextByRun[runId] ?? '';
                    if (finalText.length > prior.length &&
                        finalText.startsWith(prior)) {
                      trailingDelta = finalText.substring(prior.length);
                    } else if (prior.isEmpty) {
                      trailingDelta = finalText;
                    }
                  }
                }
              }
            }
            _lastAssistantTextByRun.remove(runId);
            _inFlightRunIds.remove(runId);
          }
          if (trailingDelta.isNotEmpty) {
            _responses.add(ServerResponse(
              sessionKey: sessionKey,
              runId: runId,
              chunk: trailingDelta,
              done: false,
              proactive: proactive,
            ));
          }
          _responses.add(ServerResponse(
            sessionKey: sessionKey,
            runId: runId,
            chunk: '',
            done: true,
            proactive: proactive,
          ));
          break;
        }

        // Live health snapshots.
        if (event == 'health') {
          _health.add(payload);
        }

        // Other events (chat delta — redundant with agent.assistant,
        // tick, etc) just flow through to the observer stream.
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
      _deviceIdentity = identity;
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

  /// Best-effort mapping of a `stream:"tool"` payload into a short
  /// human-readable status line. Tool frames have varied shapes; we try a
  /// few well-known fields and fall back to the tool name.
  String? _describeToolEvent(dynamic data) {
    if (data is! Map) return null;
    final name = (data['tool'] ?? data['name']) as String?;
    final phase = (data['phase'] ?? data['state']) as String?;
    final query = (data['query'] ?? data['arg'] ?? data['input']) as String?;
    if (name == null && query == null) return null;
    final verb = switch (name) {
      'web_search' || 'web.search' => 'Searching the web',
      'web_fetch' || 'web.fetch' => 'Fetching page',
      'memory.read' || 'memory_read' => 'Reading memory',
      'memory.write' || 'memory_write' => 'Writing to memory',
      _ => name != null ? 'Running $name' : 'Running tool',
    };
    final suffix = query != null && query.isNotEmpty ? ': $query' : '';
    final phaseSuffix = phase == 'end' || phase == 'completed' ? ' ✓' : '…';
    return '$verb$suffix$phaseSuffix';
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
    _health.close();
    _connectionState.dispose();
  }
}
