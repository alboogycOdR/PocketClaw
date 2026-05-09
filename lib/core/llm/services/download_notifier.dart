/// Foreground notification for in-progress model downloads.
///
/// Posts an ongoing notification with a progress bar so users can leave the
/// app during a multi-GB download and still see the percent in the system
/// tray. On completion the notification flips to a non-ongoing toast; on
/// failure it's dismissed (the in-app error UI tells the user what to do).
///
/// Updates are throttled to once a second so we don't hammer the
/// notification manager — Android coalesces rapid updates anyway, but
/// throttling on our side keeps the system log clean.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ModelDownloadNotifier {
  static const _channelId = 'pocket_claw_model_downloads';
  static const _channelName = 'Model Downloads';
  static const _channelDescription =
      'Progress for on-device model downloads';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  final Map<int, int> _lastUpdateMs = {};

  Future<void> _ensureInit() async {
    if (_initialised) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialised = true;
  }

  /// Show the initial 0%/preparing notification.
  Future<void> start({
    required String modelId,
    required String displayName,
  }) async {
    try {
      await _ensureInit();
      await _showProgress(
        id: _idFor(modelId),
        title: 'Downloading $displayName',
        body: 'Starting…',
        progress: 0,
        ongoing: true,
      );
    } catch (e) {
      debugPrint('ModelDownloadNotifier.start failed: $e');
    }
  }

  /// Update progress. Call as often as you like — internal throttle keeps
  /// system updates to ~1/s per model.
  Future<void> update({
    required String modelId,
    required String displayName,
    required double progress,
  }) async {
    final id = _idFor(modelId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastUpdateMs[id] ?? 0;
    if (now - last < 1000) return;
    _lastUpdateMs[id] = now;

    final pct = (progress * 100).clamp(0, 100).toInt();
    try {
      await _showProgress(
        id: id,
        title: 'Downloading $displayName',
        body: '$pct%',
        progress: pct,
        ongoing: true,
      );
    } catch (e) {
      debugPrint('ModelDownloadNotifier.update failed: $e');
    }
  }

  /// Final success notification. Stays in the tray, non-ongoing.
  Future<void> complete({
    required String modelId,
    required String displayName,
  }) async {
    final id = _idFor(modelId);
    _lastUpdateMs.remove(id);
    try {
      await _ensureInit();
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false,
        autoCancel: true,
      );
      await _plugin.show(
        id,
        'Download complete',
        '$displayName is ready to use.',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('ModelDownloadNotifier.complete failed: $e');
    }
  }

  /// Clear the ongoing notification on failure. The error UI inside the
  /// app surfaces the actual problem — a system-tray error is just noise.
  Future<void> fail({required String modelId}) async {
    final id = _idFor(modelId);
    _lastUpdateMs.remove(id);
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> _showProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
    required bool ongoing,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: ongoing,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      onlyAlertOnce: true,
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  /// Stable, deterministic notification id per model. Using `hashCode`
  /// keeps it within int range and identical across calls so updates
  /// replace rather than stack.
  int _idFor(String modelId) => modelId.hashCode & 0x7fffffff;
}
