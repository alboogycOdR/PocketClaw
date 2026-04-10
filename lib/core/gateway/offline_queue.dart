/// Queues messages for the server when offline, replays on reconnect.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gateway_client.dart';

class OfflineQueue {
  static const _queueKey = 'offline_message_queue';
  final SharedPreferences _prefs;

  OfflineQueue({required SharedPreferences prefs}) : _prefs = prefs;

  /// Add a message to the offline queue.
  Future<void> enqueue(QueuedMessage message) async {
    final queue = _loadQueue();
    queue.add(message);
    await _saveQueue(queue);
    debugPrint('OfflineQueue: enqueued "${message.text}" (${queue.length} pending)');
  }

  /// Number of messages waiting in the queue.
  int get pendingCount => _loadQueue().length;

  /// Whether there are messages waiting.
  bool get hasPending => pendingCount > 0;

  /// Replay all queued messages through the gateway client, then clear.
  Future<int> replay(GatewayClient client) async {
    final queue = _loadQueue();
    if (queue.isEmpty) return 0;

    int sent = 0;
    final failed = <QueuedMessage>[];

    for (final message in queue) {
      try {
        await client.sendMessage(message.text, sessionKey: message.sessionKey);
        sent++;
      } catch (e) {
        debugPrint('OfflineQueue: failed to replay: $e');
        failed.add(message);
      }
    }

    // Keep only failed messages
    await _saveQueue(failed);
    debugPrint('OfflineQueue: replayed $sent, ${failed.length} still pending');
    return sent;
  }

  /// Clear the entire queue.
  Future<void> clear() async {
    await _prefs.remove(_queueKey);
  }

  List<QueuedMessage> _loadQueue() {
    final raw = _prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => QueuedMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<QueuedMessage> queue) async {
    final json = jsonEncode(queue.map((m) => m.toJson()).toList());
    await _prefs.setString(_queueKey, json);
  }
}

class QueuedMessage {
  final String text;
  final String? sessionKey;
  final DateTime queuedAt;

  const QueuedMessage({
    required this.text,
    this.sessionKey,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'sessionKey': sessionKey,
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) => QueuedMessage(
        text: json['text'] as String,
        sessionKey: json['sessionKey'] as String?,
        queuedAt: DateTime.parse(json['queuedAt'] as String),
      );
}
