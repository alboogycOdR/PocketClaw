/// Handles proactive agent pushes — frames the server emits on its own
/// (a runId we didn't start, e.g. a cron output or a Paperclip callback).
///
/// Two things happen on flush:
///   1. The accumulated text is appended to the chat as a new assistant
///      bubble, regardless of whether the app is foregrounded — this is
///      what the user sees when they open the app.
///   2. If the app is NOT resumed, a local notification also fires so the
///      user is alerted while backgrounded.
///
/// This listener is always-on (attached by a Provider watched at the root
/// of the widget tree) so it captures proactive frames that arrive outside
/// any in-flight `chat.send` call.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/chat_message.dart';
import '../../data/models/gateway_event.dart';
import '../../data/providers/chat_providers.dart';
import '../../data/providers/core_providers.dart';
import 'gateway_client.dart';

const _uuid = Uuid();

class _ProactiveBuffer {
  final StringBuffer text = StringBuffer();
  final DateTime startedAt = DateTime.now();
  Timer? idleTimer;
}

class ProactiveNotifier {
  final Ref _ref;
  final Map<String, _ProactiveBuffer> _buffers = {};
  StreamSubscription<ServerResponse>? _sub;

  ProactiveNotifier(this._ref);

  void attach(GatewayClient client) {
    _sub?.cancel();
    _sub = client.responses.listen(_onResponse);
  }

  void detach() {
    _sub?.cancel();
    _sub = null;
    for (final b in _buffers.values) {
      b.idleTimer?.cancel();
    }
    _buffers.clear();
  }

  void _onResponse(ServerResponse r) {
    if (!r.proactive) return;
    final runId = r.runId ?? '_unknown';
    final buf = _buffers.putIfAbsent(runId, () => _ProactiveBuffer());
    if (r.chunk.isNotEmpty) {
      buf.text.write(r.chunk);
      buf.idleTimer?.cancel();
      // Server sometimes omits a terminal `done:true` — flush after 3s of
      // silence so the bubble + notification still go out.
      buf.idleTimer =
          Timer(const Duration(seconds: 3), () => _flush(runId, r));
    }
    if (r.done) {
      _flush(runId, r);
    }
  }

  Future<void> _flush(String runId, ServerResponse last) async {
    final buf = _buffers.remove(runId);
    if (buf == null) return;
    buf.idleTimer?.cancel();
    final body = buf.text.toString().trim();
    if (body.isEmpty) return;

    // 1. Always append to the chat thread so the bubble is visible when
    //    the user opens the app. Dedup against runId in case a chat.send
    //    flow somehow ingested the same frames (current implementation
    //    does not — in-flight replies use the placeholder bubble).
    try {
      final existing = _ref.read(messagesProvider);
      final alreadyAdded = runId != '_unknown' &&
          existing.any((m) => m.runId == runId);
      if (!alreadyAdded) {
        _ref.read(messagesProvider.notifier).add(ChatMessage(
              id: _uuid.v4(),
              role: MessageRole.assistant,
              content: body,
              source: MessageSource.server,
              timestamp: buf.startedAt,
              runId: runId == '_unknown' ? null : runId,
            ));
      }
    } catch (_) {
      // Adding to chat should never throw; swallow to keep notifications
      // firing even if the provider scope is gone.
    }

    // 2. Notify if the app isn't actively foregrounded.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != AppLifecycleState.resumed) {
      final service = _ref.read(notificationServiceProvider);
      await service.showNotification(
        title: 'ClawCommander',
        body: body.length > 160 ? '${body.substring(0, 157)}…' : body,
      );
    }
  }
}

final proactiveNotifierProvider = Provider<ProactiveNotifier>((ref) {
  final client = ref.watch(gatewayClientProvider);
  final notifier = ProactiveNotifier(ref);
  if (client != null) notifier.attach(client);
  ref.onDispose(notifier.detach);
  return notifier;
});
