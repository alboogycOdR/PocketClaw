/// On-device embedding via feature hashing over character n-grams.
///
/// Produces a fixed-length L2-normalised vector without any ML model — good
/// enough for cosine-similarity ranking of short Markdown notes, and works
/// offline on every device regardless of whether a local LLM is loaded.
///
/// The space is deliberately small (256-d) because embeddings are cached
/// on disk and compared in-memory during search.
library;

import 'dart:math' as math;

class LocalEmbedder {
  /// Dimensionality of the output vector. 256 is a compromise between
  /// collision rate (lower ⇒ more collisions) and memory per note.
  static const int dims = 256;

  /// Character n-gram sizes used as features.
  static const List<int> _ngramSizes = [3, 4, 5];

  /// Generate an L2-normalised vector for [text].
  List<double> embed(String text) {
    final vec = List<double>.filled(dims, 0.0);
    final normalised = _normalise(text);
    if (normalised.isEmpty) return vec;

    for (final n in _ngramSizes) {
      if (normalised.length < n) continue;
      for (var i = 0; i <= normalised.length - n; i++) {
        final gram = normalised.substring(i, i + n);
        final bucket = _hash(gram) % dims;
        // Sign hashing spreads collisions in both directions → keeps the
        // vector zero-centred instead of biased.
        final sign = (_hash('s:$gram') & 1) == 0 ? 1.0 : -1.0;
        vec[bucket] += sign;
      }
    }

    return _l2Normalise(vec);
  }

  /// Whether [text] produces a meaningful embedding.
  bool isMeaningful(String text) => _normalise(text).length >= 3;

  String _normalise(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// FNV-1a 32-bit hash. Deterministic, fast, and stdlib-free.
  int _hash(String s) {
    var hash = 0x811c9dc5;
    for (final code in s.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  List<double> _l2Normalise(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm == 0.0) return v;
    for (var i = 0; i < v.length; i++) {
      v[i] = v[i] / norm;
    }
    return v;
  }
}
