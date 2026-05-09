/// SSE parser for the Hermes Agent stream. Originally returned plain
/// token strings; now yields a typed event stream so the chat path can
/// react to non-token events (tool progress, completion sentinels) the
/// way the ACP path does.
///
/// Wire format (verified against live VPS):
///
///   event: hermes.tool.progress    ← optional named events
///   data: {"id":"call_42","status":"running","title":"read foo.txt"}
///
///   data: {"choices":[{"delta":{"content":"Hey"}}]}
///   data: [DONE]
///
/// SSE spec rules respected: blank line ends an event, `event:` line
/// names it, multiple `data:` lines per event are joined with `\n`.
library;

import 'dart:convert';

sealed class SseParsedEvent {
  const SseParsedEvent();
}

/// A streamed text delta from `delta.content`.
class SseTextToken extends SseParsedEvent {
  final String text;
  const SseTextToken(this.text);
}

/// Tool-progress notification from a `hermes.tool.progress` SSE event.
/// Fields mirror the AcpToolCall shape so the UI can map both paths to
/// the same TUI activity card.
class SseToolProgress extends SseParsedEvent {
  final String toolCallId;
  final String title;
  final String kind; // read|edit|execute|fetch|search|think|other
  final String status; // pending|completed|failed
  final String content;

  const SseToolProgress({
    required this.toolCallId,
    required this.title,
    required this.kind,
    required this.status,
    this.content = '',
  });
}

/// Final `[DONE]` sentinel. Yielded once and the stream then completes.
class SseDone extends SseParsedEvent {
  const SseDone();
}

class HermesSseParser {
  final _buffer = StringBuffer();
  String? _pendingEvent; // 'message' (default) | 'hermes.tool.progress'
  final List<String> _pendingData = [];

  /// Process a raw text chunk; yields zero or more typed events.
  Iterable<SseParsedEvent> process(String chunk) sync* {
    _buffer.write(chunk);
    final raw = _buffer.toString();
    final lines = raw.split('\n');

    // Keep last partial line in the buffer.
    _buffer.clear();
    if (!raw.endsWith('\n')) {
      _buffer.write(lines.removeLast());
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();

      // Blank line — dispatch the accumulated event.
      if (line.isEmpty) {
        yield* _flush();
        continue;
      }

      if (line.startsWith(':')) continue; // SSE comment

      if (line.startsWith('event:')) {
        _pendingEvent = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        var payload = line.substring(5);
        if (payload.startsWith(' ')) payload = payload.substring(1);
        _pendingData.add(payload);
        continue;
      }

      // id: / retry: — ignored.
    }
  }

  Iterable<SseParsedEvent> _flush() sync* {
    if (_pendingData.isEmpty) {
      _pendingEvent = null;
      return;
    }
    final data = _pendingData.join('\n');
    final event = _pendingEvent ?? 'message';
    _pendingData.clear();
    _pendingEvent = null;

    if (data == '[DONE]') {
      yield const SseDone();
      return;
    }

    if (event == 'hermes.tool.progress') {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        yield SseToolProgress(
          toolCallId: json['id'] as String? ?? json['toolCallId'] as String? ?? '',
          title: json['title'] as String? ?? '',
          kind: json['kind'] as String? ?? 'other',
          status: json['status'] as String? ?? 'pending',
          content: json['content'] as String? ?? '',
        );
      } catch (_) {
        // Malformed tool-progress payload — drop silently.
      }
      return;
    }

    // Default `message` event — OpenAI-compatible delta.content tokens.
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return;
      final delta = choices.first['delta'] as Map<String, dynamic>?;
      if (delta == null) return;
      final content = delta['content'] as String?;
      if (content != null && content.isNotEmpty) {
        yield SseTextToken(content);
      }
    } catch (_) {
      // Malformed delta — skip.
    }
  }

  /// Convenience: filter events to plain text tokens. Lets older call
  /// sites keep `Iterable<String>` semantics if they don't care about
  /// tool progress yet.
  static Iterable<String> textTokensOnly(Iterable<SseParsedEvent> events) sync* {
    for (final e in events) {
      if (e is SseTextToken) yield e.text;
    }
  }
}
