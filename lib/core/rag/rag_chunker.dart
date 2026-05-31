/// Splits a document into overlapping chunks for embedding.
/// Verified chunk sizes / overlap from off-grid-mobile-ai source.
library;

class RagChunk {
  final String content;
  final int position;
  const RagChunk({required this.content, required this.position});
}

class RagChunker {
  static const int defaultChunkSize = 500;
  static const int defaultOverlap = 100;
  static const int defaultMinLength = 20;

  List<RagChunk> chunk(
    String text, {
    int chunkSize = defaultChunkSize,
    int overlap = defaultOverlap,
    int minLength = defaultMinLength,
  }) {
    if (text.trim().length < minLength) return const [];

    final paragraphs = text.split(RegExp(r'\n\n+'));
    final chunks = <RagChunk>[];
    var currentChunk = '';
    var position = 0;

    for (final paragraph in paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length > chunkSize) {
        if (currentChunk.trim().length >= minLength) {
          chunks.add(RagChunk(
              content: currentChunk.trim(), position: position++));
          currentChunk = '';
        }
        var start = 0;
        while (start < trimmed.length) {
          final end = (start + chunkSize).clamp(0, trimmed.length);
          final slice = trimmed.substring(start, end);
          if (slice.trim().length >= minLength) {
            chunks.add(RagChunk(content: slice.trim(), position: position++));
          }
          start += chunkSize - overlap;
        }
        continue;
      }

      final candidate =
          currentChunk.isEmpty ? trimmed : '$currentChunk\n\n$trimmed';
      if (candidate.length > chunkSize) {
        if (currentChunk.trim().length >= minLength) {
          chunks.add(RagChunk(
              content: currentChunk.trim(), position: position++));
        }
        currentChunk = trimmed;
      } else {
        currentChunk = candidate;
      }
    }

    if (currentChunk.trim().length >= minLength) {
      chunks.add(RagChunk(content: currentChunk.trim(), position: position));
    }
    return chunks;
  }
}
