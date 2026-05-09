/// Generates a concise session title from the first user message.
///
/// Strategy is deliberately simple — no AI call, just text trimming:
///   1. Strip leading slash commands (e.g. `/btw `)
///   2. Take the first line only
///   3. Truncate to 40 chars on a word boundary, append "…"
///
/// The user's own words make the best title; a future sprint can swap
/// this for an LLM-generated headline if it becomes worthwhile.
library;

class SessionTitleGenerator {
  static const _maxLength = 40;

  static String generate(String firstUserMessage) {
    var text = firstUserMessage.trim();

    if (text.startsWith('/')) {
      final spaceIdx = text.indexOf(' ');
      if (spaceIdx > 0) text = text.substring(spaceIdx + 1).trim();
    }

    final firstLine = text.split('\n').first.trim();
    if (firstLine.isEmpty) return 'Chat session';

    if (firstLine.length <= _maxLength) return firstLine;

    final truncated = firstLine.substring(0, _maxLength);
    final lastSpace = truncated.lastIndexOf(' ');
    return lastSpace > 20
        ? '${truncated.substring(0, lastSpace)}…'
        : '$truncated…';
  }
}
