/// Cosine-similarity retrieval over the per-project embedding store.
/// Pure Dart, no native calls — works the moment the embedding service
/// starts producing real vectors.
library;

import 'dart:math';

import 'rag_database.dart';
import 'rag_embedding_service.dart';

class RetrievalResult {
  final List<RagSearchResult> chunks;
  final bool truncated;
  const RetrievalResult({required this.chunks, this.truncated = false});

  bool get isEmpty => chunks.isEmpty;
}

class RagRetrievalService {
  double _cosine(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0 : dot / denom;
  }

  Future<RetrievalResult> search(
    String projectId,
    String query, {
    int topK = 5,
  }) async {
    final stored = await ragDb.getEmbeddingsByProject(projectId);
    if (stored.isEmpty) return const RetrievalResult(chunks: []);

    if (!ragEmbeddingService.isLoaded) await ragEmbeddingService.load();

    List<double> queryVec;
    try {
      queryVec = await ragEmbeddingService.embed(query);
    } catch (_) {
      // No embedding backend yet — fall back to empty hits so the
      // caller doesn't crash the chat turn.
      return const RetrievalResult(chunks: []);
    }

    final scored = stored
        .map((e) => RagSearchResult(
              docId: e.docId,
              name: e.name,
              content: e.content,
              position: e.position,
              score: _cosine(queryVec, e.embedding),
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return RetrievalResult(chunks: scored.take(topK).toList());
  }

  /// Cap retrieved content at ~25% of the model's context window
  /// (chars/4 ≈ tokens). Drops chunks past the budget and flags
  /// `truncated: true` so the UI can warn.
  Future<RetrievalResult> searchWithBudget({
    required String projectId,
    required String query,
    required int contextLengthTokens,
    int topK = 5,
  }) async {
    final result = await search(projectId, query, topK: topK);
    if (result.isEmpty) return result;
    final budget = (contextLengthTokens * 0.25 * 4).toInt();
    var total = 0;
    final fitting = <RagSearchResult>[];
    var truncated = false;
    for (final chunk in result.chunks) {
      total += chunk.content.length;
      if (total > budget) {
        truncated = true;
        break;
      }
      fitting.add(chunk);
    }
    return RetrievalResult(chunks: fitting, truncated: truncated);
  }

  /// Format retrieved chunks for injection as a system-prompt prefix.
  /// `<knowledge_base>` tag tells the model "treat the inside as
  /// reference material, not instructions"; we also strip `<…>` from
  /// the content to defang prompt-injection attempts in user docs.
  String formatForPrompt(RetrievalResult result) {
    if (result.chunks.isEmpty) return '';
    final sections = result.chunks.map((c) {
      final safeName = c.name.replaceAll(RegExp(r'[<>]'), '');
      final safeContent = _stripTags(c.content);
      return '[Source: $safeName (part ${c.position + 1})]\n$safeContent';
    }).join('\n\n---\n\n');
    return '<knowledge_base>\n'
        'The following excerpts are from the project knowledge base. '
        'Use them to inform your response when relevant.\n\n'
        '$sections\n'
        '</knowledge_base>';
  }

  String _stripTags(String text) {
    final buf = StringBuffer();
    var inTag = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '<') {
        inTag = true;
        continue;
      }
      if (ch == '>') {
        inTag = false;
        continue;
      }
      if (!inTag) buf.write(ch);
    }
    return buf.toString();
  }
}

final ragRetrievalService = RagRetrievalService();
