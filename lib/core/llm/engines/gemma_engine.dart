/// GemmaEngine — DEPRECATED.
///
/// The .task format (MediaPipe LiteRT) was removed along with the
/// flutter_gemma dependency. Gemma models are now served as GGUF
/// quantizations via LlamaCppEngine.
///
/// This stub exists only so the engine factory and model registry
/// stay compile-compatible; .task models have been removed from the
/// registry so this class should never be constructed in practice.
library;

import '../models/local_model_config.dart';
import 'abstract_llm_engine.dart';

class GemmaEngine implements AbstractLLMEngine {
  // ignore: unused_field
  final LocalModelConfig _config;

  GemmaEngine({required LocalModelConfig config}) : _config = config;

  static const _removedMessage =
      'MediaPipe .task support has been removed. Use a GGUF model '
      '(Gemma, Llama, Phi, Qwen, SmolLM) or a cloud API model instead.';

  @override
  Future<void> initialize({String? huggingFaceToken}) async {
    // No-op; engine is never ready
  }

  @override
  Future<String> generate(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
  }) async {
    throw StateError(_removedMessage);
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    throw StateError(_removedMessage);
  }

  @override
  Future<bool> isModelDownloaded(String modelId) async => false;

  @override
  Future<void> downloadModel(
    LocalModelConfig model, {
    void Function(double progress)? onProgress,
    String? huggingFaceToken,
  }) async {
    throw StateError(_removedMessage);
  }

  @override
  Future<void> deleteModel(String modelId) async {
    // No-op
  }

  @override
  Future<String?> getModelPath(String modelId) async => null;

  @override
  Future<void> unloadModel() async {
    // No-op
  }

  @override
  bool get isReady => false;

  @override
  String? get loadedModelId => null;

  @override
  Future<void> dispose() async {
    // No-op
  }
}
