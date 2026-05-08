/// SSE parser for the OpenAI-compatible Hermes Agent API stream.
library;

import 'dart:convert';

/// Parses the OpenAI-compatible SSE stream from Hermes.
///
/// Input: raw text chunks from the HTTP response body.
/// Output: individual token strings extracted from delta.content.
///
/// Wire format (verified from live VPS):
///   data: {"choices":[{"delta":{"content":"Hey"},...}],...}
///   data: [DONE]
class HermesSseParser {
  final _buffer = StringBuffer();

  /// Process a raw text chunk. Returns zero or more token strings.
  Iterable<String> process(String chunk) sync* {
    _buffer.write(chunk);
    final raw = _buffer.toString();
    final lines = raw.split('\n');

    // Keep the last incomplete line in the buffer.
    _buffer.clear();
    if (!raw.endsWith('\n')) {
      _buffer.write(lines.removeLast());
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.startsWith('data: ')) continue;

      final payload = trimmed.substring(6); // strip "data: "
      if (payload == '[DONE]') continue;

      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;

        final delta = choices.first['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;

        final content = delta['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
      } catch (_) {
        // Malformed chunk — skip silently.
      }
    }
  }
}
