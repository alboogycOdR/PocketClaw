/// Wraps flutter_local_notifications for reminders and notifications
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/app_flavor.dart';
import '../local_agent/tool_executor.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  int _nextId = 1;

  /// Initialise the notification plugin. Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialised = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Can be wired up to navigation in the future.
  }

  /// Schedules a reminder notification at [dateTime].
  Future<ToolResult> scheduleReminder({
    required String title,
    required DateTime dateTime,
  }) async {
    try {
      await init();

      final now = DateTime.now();
      if (dateTime.isBefore(now)) {
        return ToolResult.error(
          'Cannot schedule a reminder in the past. '
          'Requested: ${dateTime.toIso8601String()}, now: ${now.toIso8601String()}.',
        );
      }

      final id = _nextId++;
      final delay = dateTime.difference(now);

      // Use zonedSchedule for exact scheduling where supported;
      // fall back to Future.delayed + show for simplicity.
      // Full production code would use AndroidNotificationDetails with
      // exact alarm permission and TZDateTime.
      Future.delayed(delay, () async {
        await _showRaw(id: id, title: 'Reminder', body: title);
      });

      final minutes = delay.inMinutes;
      final label = minutes < 60
          ? '$minutes minute${minutes == 1 ? '' : 's'}'
          : '${delay.inHours}h ${minutes % 60}m';

      return ToolResult.ok(
        'Reminder "$title" scheduled for $label from now '
        '(${dateTime.toIso8601String()}).',
        data: {
          'notificationId': id,
          'scheduledFor': dateTime.toIso8601String(),
        },
      );
    } catch (e) {
      return ToolResult.error('Failed to schedule reminder: $e');
    }
  }

  /// Shows an immediate notification.
  Future<ToolResult> showNotification({
    required String title,
    required String body,
  }) async {
    try {
      await init();
      final id = _nextId++;
      await _showRaw(id: id, title: title, body: body);
      return ToolResult.ok(
        'Notification shown: "$title".',
        data: {'notificationId': id},
      );
    } catch (e) {
      return ToolResult.error('Failed to show notification: $e');
    }
  }

  Future<void> _showRaw({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      // Channel ID kept as 'pocket_claw_default' — changing it would
      // create a new channel and abandon any user-tuned notification
      // preferences (sound/vibration/importance) on the old channel.
      'pocket_claw_default',
      kAppFlavor.appName,
      channelDescription: 'General notifications from ${kAppFlavor.appName}',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }
}
