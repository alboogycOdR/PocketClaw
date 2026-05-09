/// One §-delimited entry inside `MEMORY.md`. Hermes appends entries
/// over time; the timestamp is conventionally on the first line as a
/// markdown heading like `## 2026-05-09 22:14 UTC`. We're tolerant —
/// if no timestamp is parseable, [timestamp] stays null and the body
/// is returned verbatim.
library;

class HermesMemoryEntry {
  final DateTime? timestamp;
  final String body;

  const HermesMemoryEntry({this.timestamp, required this.body});

  HermesMemoryEntry copyWith({DateTime? timestamp, String? body}) =>
      HermesMemoryEntry(
        timestamp: timestamp ?? this.timestamp,
        body: body ?? this.body,
      );

  /// Parse an entry from its serialized form. Looks at the first
  /// non-blank line for an ISO-8601 / `YYYY-MM-DD HH:mm` timestamp; if
  /// found, strips that line off the body and uses it as the entry
  /// timestamp. Otherwise the whole block is the body.
  factory HermesMemoryEntry.fromBlock(String block) {
    final lines = block.split('\n');
    int firstNonEmpty = 0;
    while (firstNonEmpty < lines.length &&
        lines[firstNonEmpty].trim().isEmpty) {
      firstNonEmpty++;
    }
    if (firstNonEmpty == lines.length) {
      return HermesMemoryEntry(body: block);
    }

    final header = lines[firstNonEmpty];
    final ts = _tryParseHeaderTimestamp(header);
    if (ts == null) {
      return HermesMemoryEntry(body: block.trim());
    }

    final remaining = lines.sublist(firstNonEmpty + 1).join('\n').trim();
    return HermesMemoryEntry(timestamp: ts, body: remaining);
  }

  /// Re-serialize for writing back to MEMORY.md. If we have a
  /// timestamp we render it as a `## ` heading; otherwise just the
  /// body as-is.
  String toBlock() {
    if (timestamp == null) return body.trim();
    final ts = timestamp!.toUtc();
    final stamp = '${ts.year.toString().padLeft(4, '0')}-'
        '${ts.month.toString().padLeft(2, '0')}-'
        '${ts.day.toString().padLeft(2, '0')} '
        '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')} UTC';
    return '## $stamp\n\n$body';
  }

  static DateTime? _tryParseHeaderTimestamp(String line) {
    var text = line.trim();
    while (text.startsWith('#')) {
      text = text.substring(1).trimLeft();
    }
    text = text.replaceAll(RegExp(r'\s*UTC\s*$', caseSensitive: false), '')
        .trim();
    if (text.isEmpty) return null;

    // Try ISO-8601 directly.
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    // Try `YYYY-MM-DD HH:mm` style.
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(text);
    if (m == null) return null;
    return DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      m.group(6) == null ? 0 : int.parse(m.group(6)!),
    );
  }
}
