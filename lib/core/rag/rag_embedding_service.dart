/// Embedding service backed by the currently-loaded `llamadart`
/// `LlamaEngine`. We don't bundle a dedicated all-MiniLM-L6-v2 model
/// — embeddings are produced by the chat model itself. Quality is
/// lower than a purpose-trained embedding model but the feature
/// works today against any GGUF, and the user gets:
///
///   - Knowledge Base retrieval (cosine over chat-model vectors)
///   - Conversation similarity / semantic memory (future)
///
/// When a dedicated embedding model is wanted, drop a separate
/// LlamaEngine instance into [_dedicated] via [bindDedicated] before
/// any embed() call — RAG will prefer it over the chat engine.
library;

import 'package:llamadart/llamadart.dart';

class RagEmbeddingService {
  /// Optional dedicated embedding engine. When set, takes precedence
  /// over the shared chat engine. Lets future builds bundle
  /// `all-MiniLM-L6-v2-Q4_K_M.gguf` without touching the call sites.
  LlamaEngine? _dedicated;

  /// Shared chat engine, registered by `LlamaCppEngine.initialize()`
  /// after a successful load. Lazily resolved by callers via
  /// [bindShared].
  LlamaEngine? _shared;

  bool get isLoaded => (_dedicated ?? _shared) != null;

  /// Used by [LlamaCppEngine] (or test code) to register the engine
  /// to route embeddings through.
  void bindShared(LlamaEngine? engine) => _shared = engine;

  /// Used by a future "bundled embedding model" path. Same shape as
  /// [bindShared] but takes precedence — set this when you want
  /// chat + embed to use different models.
  void bindDedicated(LlamaEngine? engine) => _dedicated = engine;

  /// No-op load — there's nothing to warm up that isn't already
  /// loaded as part of the chat engine. Kept for API parity with the
  /// stub the rest of the app expects.
  Future<void> load() async {}

  Future<void> unload() async {
    _dedicated = null;
    // Don't dispose the shared engine here — the chat path owns it.
    _shared = null;
  }

  /// Produce an embedding vector for [text]. Throws when no engine
  /// is bound (e.g. user has no local model loaded yet).
  Future<List<double>> embed(String text) async {
    final eng = _dedicated ?? _shared;
    if (eng == null) {
      throw StateError(
        'No engine bound for embeddings. Load a local model in '
        'Settings → Models, then retry.',
      );
    }
    return eng.embed(text);
  }

  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final eng = _dedicated ?? _shared;
    if (eng == null) {
      throw StateError(
        'No engine bound for embeddings. Load a local model in '
        'Settings → Models, then retry.',
      );
    }
    return eng.embedBatch(texts);
  }
}

final ragEmbeddingService = RagEmbeddingService();
