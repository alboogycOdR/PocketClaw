/// Splits long text into synthesis-friendly chunks for Supertonic.
/// Target ~200 chars per chunk — long enough for natural prosody, short
/// enough to stay well within the encoder context.
library;

class SupertonicChunker {
  static const _maxChunkLen = 200;

  List<String> chunk(String text) {
    if (text.length <= _maxChunkLen) return [text];

    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    var current = '';

    for (final sentence in sentences) {
      if (sentence.isEmpty) continue;
      final candidate = current.isEmpty ? sentence : '$current $sentence';
      if (candidate.length <= _maxChunkLen) {
        current = candidate;
      } else {
        if (current.isNotEmpty) chunks.add(current.trim());
        if (sentence.length > _maxChunkLen) {
          chunks.addAll(_splitLong(sentence));
          current = '';
        } else {
          current = sentence;
        }
      }
    }
    if (current.isNotEmpty) chunks.add(current.trim());
    return chunks.where((c) => c.isNotEmpty).toList();
  }

  List<String> _splitLong(String text) {
    final parts = text.split(RegExp(r'(?<=,)\s+'));
    final result = <String>[];
    var buf = '';
    for (final p in parts) {
      final c = buf.isEmpty ? p : '$buf $p';
      if (c.length <= _maxChunkLen) {
        buf = c;
      } else {
        if (buf.isNotEmpty) result.add(buf);
        buf = p.length > _maxChunkLen ? p.substring(0, _maxChunkLen) : p;
      }
    }
    if (buf.isNotEmpty) result.add(buf);
    return result;
  }
}
