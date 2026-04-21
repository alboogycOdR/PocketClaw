/// Fires local notifications for proactive agent pushes.
///
/// A "proactive" frame is one the server initiates on its own (a runId the
/// client didn't start) — e.g. a cron job's agent output, or a scheduled
/// check-in. We only notify when the app is backgrounded; when foregrounded
/// the chat surface already shows the bubble.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/gateway_event.dart';
import '../../data/providers/core_providers.dart';
import 'gateway_client.dart';

class _ProactiveBuffer {
  final StringBuffer text = StringBuffer();
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
      // silence so the notification still fires.
      buf.idleTimer = Timer(const Duration(seconds: 3), () => _flush(runId));
    }
    if (r.done) {
      _flush(runId);
    }
  }

  Future<void> _flush(String runId) async {
    final buf = _buffers.remove(runId);
    if (buf == null) return;
    buf.idleTimer?.cancel();
    final body = buf.text.toString().trim();
    if (body.isEmpty) return;

    // Suppress when the app is actively foregrounded — the chat surface
    // (or eventually Activity feed) already reflects the message.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.resumed) return;

    final service = _ref.read(notificationServiceProvider);
    await service.showNotification(
      title: 'Pocket Claw',
      body: body.length > 160 ? '${body.substring(0, 157)}…' : body,
    );
  }
}

final proactiveNotifierProvider = Provider<ProactiveNotifier>((ref) {
  final client = ref.watch(gatewayClientProvider);
  final notifier = ProactiveNotifier(ref);
  if (client != null) notifier.attach(client);
  ref.onDispose(notifier.detach);
  return notifier;
});
