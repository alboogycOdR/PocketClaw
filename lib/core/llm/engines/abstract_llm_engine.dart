/// Abstract LLM engine interface for multi-runtime model support
library;

import '../models/local_model_config.dart';

abstract class AbstractLLMEngine {
  /// Initialize the engine with any required config.
  Future<void> initialize({String? huggingFaceToken});

  /// Generate a streaming response token by token.
  Stream<String> generateStream(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  });

  /// Non-streaming convenience wrapper.
  Future<String> generate(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
  });

  /// Check if model file exists on device.
  Future<bool> isModelDownloaded(String modelId);

  /// Download model from HuggingFace with progress callback.
  Future<void> downloadModel(
    LocalModelConfig model, {
    void Function(double progress)? onProgress,
    String? huggingFaceToken,
  });

  /// Delete model file from device storage.
  Future<void> deleteModel(String modelId);

  /// Get local file path for a downloaded model.
  Future<String?> getModelPath(String modelId);

  /// Unload model from memory (release RAM).
  Future<void> unloadModel();

  /// Whether engine is initialized and model loaded.
  bool get isReady;

  /// Currently loaded model ID.
  String? get loadedModelId;

  /// Dispose engine resources.
  Future<void> dispose();
}
