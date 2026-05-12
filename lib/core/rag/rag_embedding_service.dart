/// Embedding service stub.
///
/// The spec wants `FllamaContext.create(...embedding: true)` +
/// `getEmbedding(text)` — those APIs don't exist in the installed
/// fllama 0.0.1 binding. This service holds the shape (load / embed /
/// embedBatch / unload) so RagService and RagRetrievalService can be
/// fully wired today; once fllama exposes embeddings, swap the
/// `_throwUnsupported` body for the real call.
///
/// Why a stub instead of removing the surface? The RAG DB + chunker +
/// retrieval logic + KB UI all work end-to-end on indexed data — only
/// the *embed* step is blocked, and we want to surface that as a
/// clear "not yet wired" rather than a silent NaN-similarity bug.
library;

class RagEmbeddingService {
  static const int embeddingDim = 384;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Marks the service as "loaded" — does not actually warm up a
  /// model since the underlying fllama version can't produce
  /// embeddings. Real implementation will start a CPU-only fllama
  /// context against the bundled `all-MiniLM-L6-v2-Q4_K_M.gguf`.
  Future<void> load() async {
    _loaded = true;
  }

  Future<void> unload() async {
    _loaded = false;
  }

  Future<List<double>> embed(String text) async {
    _throwUnsupported();
  }

  Future<List<List<double>>> embedBatch(List<String> texts) async {
    _throwUnsupported();
  }

  Never _throwUnsupported() {
    throw UnsupportedError(
      'Embedding requires fllama with embedding support (>= bundle-assets '
      'tagged "embedding"). The installed fllama 0.0.1 doesn\'t expose '
      'getEmbedding. Upgrade fllama and swap _throwUnsupported() for '
      'the real call. Until then, indexed docs are stored without '
      'vectors and search returns no hits.',
    );
  }
}

final ragEmbeddingService = RagEmbeddingService();
