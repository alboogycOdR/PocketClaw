/// Schedules the daily 07:00 morning briefing notification + handles
/// deep-link routing when the user taps it. Power User Feature Pack §6.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../app/router.dart' as app_router;

const int _briefingNotificationId = 42;
const String _channelId = 'hermes_briefing';
const String _channelName = 'Daily Briefing';

Future<void> scheduleDailyBriefing() async {
  try {
    tz_data.initializeTimeZones();

    final plugin = FlutterLocalNotificationsPlugin();

    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final ctx = app_router.rootNavigatorKey.currentContext;
        if (ctx != null) ctx.push('/briefing');
      },
    );

    tz.Location location;
    try {
      location = tz.getLocation('Africa/Johannesburg');
    } catch (_) {
      location = tz.local;
    }

    final scheduled = _nextInstanceOf(hour: 7, minute: 0, location: location);

    await plugin.zonedSchedule(
      _briefingNotificationId,
      'Morning Briefing Ready',
      'Your daily AI-curated Hacker News briefing is ready.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Daily HN + AI briefing at 07:00',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (e) {
    // Scheduling is best-effort: lack of POST_NOTIFICATIONS permission
    // or alarm-clock denial shouldn't crash startup. The briefing
    // screen is still reachable manually via Settings.
    debugPrint('scheduleDailyBriefing failed: $e');
  }
}

tz.TZDateTime _nextInstanceOf({
  required int hour,
  required int minute,
  required tz.Location location,
}) {
  final now = tz.TZDateTime.now(location);
  var scheduled = tz.TZDateTime(
    location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}
