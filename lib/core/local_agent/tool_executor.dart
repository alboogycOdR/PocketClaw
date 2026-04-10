/// Executes function calls from the LLM by mapping to device APIs
library;

import 'package:math_expressions/math_expressions.dart';

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

        case 'ocr':
        case 'analyse_image':
          return _camera.processImageWithVision(
            imagePath: call.args['image_path'] as String,
            prompt: call.args['prompt'] as String? ??
                'Extract all text from this image.',
          );

        default:
          return ToolResult.error('Unknown tool: ${call.name}');
      }
    } catch (e) {
      return ToolResult.error('${call.name} failed: $e');
    }
  }

  ToolResult _calculateExpression(String expression) {
    try {
      // Sanitise: only allow digits, operators, parens, decimal points, spaces
      final sanitized = expression.replaceAll(RegExp(r'[^0-9+\-*/().%^ ]'), '');
      if (sanitized.isEmpty) {
        return ToolResult.error('Invalid expression');
      }

      // Handle percentage: convert e.g. "50%" to "(50/100)"
      final withPercent = sanitized.replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)%'),
        (m) => '(${m.group(1)}/100)',
      );

      final parser = Parser();
      final exp = parser.parse(withPercent);
      final contextModel = ContextModel();
      final result = exp.evaluate(EvaluationType.REAL, contextModel) as double;

      // Format: strip trailing .0 for whole numbers
      final formatted = result == result.roundToDouble()
          ? result.toInt().toString()
          : result.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

      return ToolResult.ok(
        '$expression = $formatted',
        data: {'expression': expression, 'result': result},
      );
    } catch (e) {
      return ToolResult.error('Calculation failed: $e');
    }
  }
}
