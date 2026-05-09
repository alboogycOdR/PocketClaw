/// ACP (Agent Client Protocol) client over SSH exec.
///
/// Drives a `hermes acp` subprocess on the VPS via newline-delimited
/// JSON-RPC 2.0. SPEC-ACPWireProtocol-v1.0.md.
library;

import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../ssh/hermes_ssh_client.dart';
import 'acp_event_parser.dart';
import 'acp_models.dart';

class HermesAcpClient {
  final HermesSshClient _ssh;
  static const _uuid = Uuid();

  // SSH-exec'd `hermes acp` subprocess.
  SshProcess? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  // JSON-RPC id counter — monotonically increasing per spec.
  int _nextId = 1;

  // Pending request completers keyed by JSON-RPC id.
  final _pending = <int, Completer<Map<String, dynamic>?>>{};

  // Public event stream consumed by the chat provider.
  final _eventController = StreamController<AcpEvent>.broadcast();
  Stream<AcpEvent> get events => _eventController.stream;

  bool _started = false;
  String? _currentSessionId;
  Timer? _keepaliveTimer;

  bool get isStarted => _started;
  String? get currentSessionId => _currentSessionId;

  HermesAcpClient({required HermesSshClient ssh}) : _ssh = ssh;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Start the subprocess, run `initialize`, and arm the 30-second
  /// keepalive ping. Throws if `initialize` fails.
  Future<void> start() async {
    if (_started) return;
    _process = await _ssh.executeInteractive('hermes acp');
    _stdoutSub = _process!.stdout.listen(
      _handleLine,
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );
    // Drain stderr so the SSH window doesn't block; we don't surface it.
    _stderrSub = _process!.stderr.listen((_) {});

    _started = true;

    await _request('initialize', {
      'protocolVersion': 1,
      'clientCapabilities': <String, dynamic>{},
      'clientInfo': {'name': 'ClawCommander', 'version': '1.0'},
    });

    _keepaliveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _writeLine(r'{"jsonrpc":"2.0","method":"$/ping"}'),
    );
  }

  /// Stop the keepalive, cancel the stdout subscription, fail any
  /// pending requests, close the SSH session, and close the event stream.
  Future<void> stop() async {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    await _stderrSub?.cancel();
    _stderrSub = null;

    final pending = List.of(_pending.values);
    _pending.clear();
    for (final c in pending) {
      if (!c.isCompleted) c.completeError(const _AcpStopped());
    }

    try {
      await _process?.closeStdin();
    } catch (_) {}
    _process?.close();
    _process = null;

    _started = false;
    _currentSessionId = null;
    if (!_eventController.isClosed) await _eventController.close();
  }

  // ── Session management ────────────────────────────────────────────────

  Future<String> newSession({String cwd = '/home/clawusr'}) async {
    final result = await _request('session/new', {
      'cwd': cwd,
      'mcpServers': <dynamic>[],
    });
    final sessionId = result?['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw AcpException('session/new: missing sessionId in response');
    }
    _currentSessionId = sessionId;
    return sessionId;
  }

  Future<String> loadSession({
    required String sessionId,
    String cwd = '/home/clawusr',
  }) async {
    await _request('session/load', {
      'cwd': cwd,
      'sessionId': sessionId,
      'mcpServers': <dynamic>[],
    });
    _currentSessionId = sessionId;
    return sessionId;
  }

  Future<String> resumeSession({
    required String sessionId,
    String cwd = '/home/clawusr',
  }) async {
    final result = await _request('session/resume', {
      'cwd': cwd,
      'sessionId': sessionId,
      'mcpServers': <dynamic>[],
    });
    final resumedId = result?['sessionId'] as String? ?? sessionId;
    _currentSessionId = resumedId;
    return resumedId;
  }

  // ── Messaging ─────────────────────────────────────────────────────────

  /// Send a user message. Tool-call and message-chunk events stream
  /// out on [events] while the agent runs; the future resolves with
  /// final usage once the turn ends.
  Future<AcpPromptCompleteEvent> sendPrompt({
    required String sessionId,
    required String text,
    List<AcpImageAttachment>? images,
  }) async {
    final messageId = _uuid.v4();
    final prompt = <Map<String, dynamic>>[
      {'type': 'text', 'text': text},
      ...?images?.map((img) => {
            'type': 'image',
            'data': img.base64Data,
            'mimeType': img.mimeType,
          }),
    ];

    // No timeout — agent runs can legitimately take minutes.
    final result = await _request(
      'session/prompt',
      {
        'sessionId': sessionId,
        'messageId': messageId,
        'prompt': prompt,
      },
      timeout: null,
    );

    final usage = result?['usage'] as Map<String, dynamic>? ?? const {};
    return AcpPromptCompleteEvent(
      sessionId: sessionId,
      stopReason: result?['stopReason'] as String? ?? 'end_turn',
      inputTokens: (usage['inputTokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage['outputTokens'] as num?)?.toInt() ?? 0,
      thoughtTokens: (usage['thoughtTokens'] as num?)?.toInt() ?? 0,
      cachedReadTokens: (usage['cachedReadTokens'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> cancel(String sessionId) =>
      _request('session/cancel', {'sessionId': sessionId});

  /// Reply to a server-initiated [AcpPermissionRequestEvent]. Hermes
  /// blocks until it receives the response, so this must be called for
  /// every permission ask.
  void respondToPermission({
    required int requestId,
    required String optionId,
  }) {
    final outcome = optionId == 'deny' ? 'rejected' : 'allowed';
    _writeLine(jsonEncode({
      'jsonrpc': '2.0',
      'id': requestId,
      'result': {
        'outcome': {
          'kind': outcome,
          'optionId': optionId,
        },
      },
    }));
  }

  // ── Transport ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _request(
    String method,
    Map<String, dynamic> params, {
    Duration? timeout = const Duration(seconds: 60),
  }) async {
    if (!_started) {
      throw AcpException('ACP client not started; call start() first');
    }
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>?>();
    _pending[id] = completer;

    _writeLine(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }));

    if (timeout != null) {
      Future.delayed(timeout).then((_) {
        if (!completer.isCompleted) {
          _pending.remove(id);
          completer.completeError(
            TimeoutException('ACP request "$method" timed out', timeout),
          );
        }
      });
    }
    return completer.future;
  }

  void _writeLine(String line) {
    _process?.writeLine(line);
  }

  void _handleLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return;
      json = decoded;
    } catch (_) {
      // Subprocess wrote non-JSON to stdout — ignore. Hermes occasionally
      // emits diagnostic banner lines before the first JSON-RPC frame.
      return;
    }

    final msg = AcpRawMessage.fromJson(json);

    switch (msg.kind) {
      case AcpMessageKind.response:
        final c = _pending.remove(msg.id);
        if (c == null) break;
        if (msg.error != null) {
          c.completeError(AcpException(
            '${msg.error!.message} (code ${msg.error!.code})',
          ));
        } else {
          c.complete(msg.result);
        }
      case AcpMessageKind.notification:
        final ev = AcpEventParser.parseNotification(msg);
        if (ev != null && !_eventController.isClosed) {
          _eventController.add(ev);
        }
      case AcpMessageKind.serverRequest:
        final ev = AcpEventParser.parsePermissionRequest(msg);
        if (ev != null && !_eventController.isClosed) {
          _eventController.add(ev);
        }
      case AcpMessageKind.unknown:
        break;
    }
  }

  void _handleDisconnect() {
    if (!_started) return;
    _started = false;
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    final pending = List.of(_pending.values);
    _pending.clear();
    for (final c in pending) {
      if (!c.isCompleted) c.completeError(const _AcpDisconnected());
    }
    if (!_eventController.isClosed) {
      _eventController.add(
        AcpDisconnectedEvent(sessionId: _currentSessionId ?? ''),
      );
    }
  }
}

class AcpImageAttachment {
  final String base64Data;
  final String mimeType;
  const AcpImageAttachment({
    required this.base64Data,
    required this.mimeType,
  });
}

class AcpException implements Exception {
  final String message;
  const AcpException(this.message);
  @override
  String toString() => 'AcpException: $message';
}

class _AcpStopped extends AcpException {
  const _AcpStopped() : super('ACP client stopped');
}

class _AcpDisconnected extends AcpException {
  const _AcpDisconnected() : super('ACP subprocess terminated');
}
