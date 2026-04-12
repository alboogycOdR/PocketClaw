/// LlamaCppEngine — DISABLED in v2.1.
///
/// GGUF model support via fllama is temporarily removed because the native
/// library causes crash-on-launch on some Android devices (notably HONOR
/// MagicOS builds). This class remains as a no-op so the factory/registry
/// stay compile-compatible; selecting a GGUF model will surface a clear
/// "GGUF disabled" error rather than crashing the app.
///
/// To re-enable: add `fllama` to pubspec.yaml and restore the previous
/// implementation. Tracked issue: native library load failure on arm64.
library;

import 'dart:async';

import '../models/local_model_config.dart';
import 'abstract_llm_engine.dart';

class LlamaCppEngine implements AbstractLLMEngine {
  final LocalModelConfig _config;

  LlamaCppEngine({required LocalModelConfig config}) : _config = config;

  static const _disabledMessage =
      'GGUF models are temporarily disabled in this build. '
      'Please use a Gemma (.task) model or a cloud API model instead.';

  @override
  Future<void> initialize({String? huggingFaceToken}) async {
    // No-op: engine never becomes ready.
  }

  @override
  Future<String> generate(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
  }) async {
    throw StateError(_disabledMessage);
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    throw StateError(_disabledMessage);
  }

  @override
  Future<bool> isModelDownloaded(String modelId) async => false;

  @override
  Future<void> downloadModel(
    LocalModelConfig model, {
    void Function(double progress)? onProgress,
    String? huggingFaceToken,
  }) async {
    throw StateError(_disabledMessage);
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
