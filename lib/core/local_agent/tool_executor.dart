/// Executes function calls from the LLM by mapping to device APIs
library;

import '../device/calendar_service.dart';
import '../device/camera_service.dart';
import '../device/file_service.dart';
import '../device/notification_service.dart';
import '../device/share_service.dart';
import '../device/tts_service.dart';
import '../memory/local_memory.dart';
import 'llm_engine.dart';

class ToolResult {
  final bool success;
  final String output;
  final Map<String, dynamic>? data;

  const ToolResult({
    required this.success,
    required this.output,
    this.data,
  });

  factory ToolResult.ok(String output, {Map<String, dynamic>? data}) =>
      ToolResult(success: true, output: output, data: data);

  factory ToolResult.error(String message) =>
      ToolResult(success: false, output: 'Error: $message');
}

class ToolExecutor {
  final CalendarService _calendar;
  final LocalMemory _notes;
  final CameraService _camera;
  final NotificationService _notifications;
  final TtsService _tts;
  final ShareService _share;
  final FileService _files;

  ToolExecutor({
    required CalendarService calendar,
    required LocalMemory notes,
    required CameraService camera,
    required NotificationService notifications,
    required TtsService tts,
    required ShareService share,
    required FileService files,
  })  : _calendar = calendar,
        _notes = notes,
        _camera = camera,
        _notifications = notifications,
        _tts = tts,
        _share = share,
        _files = files;

  Future<ToolResult> execute(FunctionCallData call) async {
    try {
      switch (call.name) {
        case 'create_note':
          return _notes.createNote(
            title: call.args['title'] as String,
            content: call.args['content'] as String,
            folder: call.args['folder'] as String? ?? 'general',
          );

        case 'search_notes':
          return _notes.searchNotes(
            query: call.args['query'] as String,
            limit: call.args['limit'] as int? ?? 5,
          );

        case 'create_reminder':
          return _notifications.scheduleReminder(
            title: call.args['title'] as String,
            dateTime: DateTime.parse(call.args['datetime'] as String),
          );

        case 'query_calendar':
          return _calendar.getEvents(
            start: DateTime.parse(call.args['start_date'] as String),
            end: DateTime.parse(call.args['end_date'] as String),
          );

        case 'calculate':
          return _calculateExpression(call.args['expression'] as String);

        case 'draft_message':
          return _share.draft(
            body: call.args['body'] as String,
            recipient: call.args['recipient'] as String?,
            subject: call.args['subject'] as String?,
            channel: call.args['channel'] as String? ?? 'generic',
          );

        case 'capture_photo':
          return _camera.capture(
            purpose: call.args['purpose'] as String? ?? 'save',
          );

        case 'read_file':
          return _files.readFile(call.args['path'] as String);

        case 'text_to_speech':
          return _tts.speak(
            call.args['text'] as String,
            language: call.args['language'] as String? ?? 'en',
          );

        default:
          return ToolResult.error('Unknown tool: ${call.name}');
      }
    } catch (e) {
      return ToolResult.error('${call.name} failed: $e');
    }
  }

  ToolResult _calculateExpression(String expression) {
    // Simple math evaluation
    // For safety, only allow basic arithmetic
    try {
      final sanitized = expression.replaceAll(RegExp(r'[^0-9+\-*/().% ]'), '');
      if (sanitized.isEmpty) {
        return ToolResult.error('Invalid expression');
      }
      // TODO: Use a proper math expression parser
      return ToolResult.ok('Calculated: $expression (parser pending)');
    } catch (e) {
      return ToolResult.error('Calculation failed: $e');
    }
  }
}
