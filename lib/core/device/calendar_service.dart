/// Wraps the device_calendar plugin for calendar read/write operations
library;

import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';

import '../local_agent/tool_executor.dart';

class CalendarService {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  String? _defaultCalendarId;

  /// Initialises the service by requesting permissions and caching the default
  /// calendar id.
  Future<void> init() async {
    final permResult = await _plugin.requestPermissions();
    if (!permResult.isSuccess || permResult.data != true) {
      return; // permissions denied — operations will return errors
    }
    final calendarsResult = await _plugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data != null) {
      final calendars = calendarsResult.data!;
      if (calendars.isNotEmpty) {
        _defaultCalendarId = calendars.first.id;
      }
    }
  }

  /// Returns events between [start] and [end].
  Future<ToolResult> getEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      if (_defaultCalendarId == null) {
        await init();
      }
      if (_defaultCalendarId == null) {
        return ToolResult.error(
          'No calendar available. Check calendar permissions.',
        );
      }

      final result = await _plugin.retrieveEvents(
        _defaultCalendarId!,
        RetrieveEventsParams(startDate: start, endDate: end),
      );

      if (!result.isSuccess || result.data == null) {
        return ToolResult.error('Failed to retrieve calendar events.');
      }

      final events = result.data!;
      if (events.isEmpty) {
        final fmt = DateFormat('MMM d');
        return ToolResult.ok(
          'No events found between ${fmt.format(start)} and ${fmt.format(end)}.',
        );
      }

      final buffer = StringBuffer('Found ${events.length} event(s):\n');
      final timeFmt = DateFormat('MMM d HH:mm');
      for (final event in events) {
        final startStr =
            event.start != null ? timeFmt.format(event.start!) : '?';
        final endStr = event.end != null ? timeFmt.format(event.end!) : '?';
        buffer.writeln('- ${event.title ?? "(no title)"}: $startStr - $endStr');
      }

      return ToolResult.ok(
        buffer.toString().trim(),
        data: {
          'count': events.length,
          'events': events
              .map((e) => <String, dynamic>{
                    'title': e.title,
                    'start': e.start?.toIso8601String(),
                    'end': e.end?.toIso8601String(),
                    'location': e.location,
                  })
              .toList(),
        },
      );
    } catch (e) {
      return ToolResult.error('Calendar query failed: $e');
    }
  }

  /// Creates a new calendar event.
  Future<ToolResult> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      if (_defaultCalendarId == null) {
        await init();
      }
      if (_defaultCalendarId == null) {
        return ToolResult.error(
          'No calendar available. Check calendar permissions.',
        );
      }

      final event = Event(_defaultCalendarId!)
        ..title = title
        ..start = TZDateTime.from(start, local)
        ..end = TZDateTime.from(end, local);

      final result = await _plugin.createOrUpdateEvent(event);
      if (result == null || !result.isSuccess) {
        return ToolResult.error('Failed to create calendar event.');
      }

      final fmt = DateFormat('MMM d HH:mm');
      return ToolResult.ok(
        'Event "$title" created for ${fmt.format(start)} - ${fmt.format(end)}.',
        data: {'eventId': result.data},
      );
    } catch (e) {
      return ToolResult.error('Failed to create event: $e');
    }
  }
}
