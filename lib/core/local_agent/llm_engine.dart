/// Local LLM engine wrapper
///
/// Wraps flutter_gemma (or equivalent) for on-device inference.
/// Currently stubbed — will integrate with flutter_gemma when model
/// files are available on device.
library;

import 'dart:async';

enum ModelCap { text, vision, audio, functionCalling, thinking }

class LocalModelConfig {
  final String id;
  final String path;
  final String displayName;
  final Set<ModelCap> capabilities;
  final int maxTokens;
  final double temperature;
  final int ramRequiredMb;

  const LocalModelConfig({
    required this.id,
    required this.path,
    required this.displayName,
    required this.capabilities,
    this.maxTokens = 1024,
    this.temperature = 0.3,
    this.ramRequiredMb = 1500,
  });
}

class LlmEngine {
  LocalModelConfig? _config;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  LocalModelConfig? get config => _config;

  Future<void> loadModel(LocalModelConfig config) async {
    _config = config;
    // TODO: Initialize flutter_gemma with model file
    // await FlutterGemma.instance.init(modelPath: config.path);
    _isLoaded = true;
  }

  Stream<LlmChunk> generateStream(String prompt) async* {
    if (!_isLoaded) {
      yield LlmChunk.text(
          'Local model not loaded. Please download a model in Settings.');
      return;
    }

    // TODO: Replace with actual flutter_gemma streaming inference
    // Stub: echo a placeholder response
    yield LlmChunk.text(
        'I\'m running locally on your device. Model: ${_config?.displayName ?? "none"}');
  }

  Stream<LlmChunk> continueWithResult(String toolResult) async* {
    // Feed tool result back into LLM for natural language response
    yield LlmChunk.text(toolResult);
  }

  Future<List<double>> generateEmbedding(String text) async {
    // TODO: Use flutter_gemma embeddings
    // Stub: return empty embedding
    return List.filled(384, 0.0);
  }

  void unload() {
    _isLoaded = false;
    _config = null;
  }

  void dispose() {
    unload();
  }
}

class LlmChunk {
  final String? text;
  final FunctionCallData? functionCall;

  bool get isFunctionCall => functionCall != null;
  bool get isText => text != null;

  const LlmChunk._({this.text, this.functionCall});

  factory LlmChunk.text(String text) => LlmChunk._(text: text);
  factory LlmChunk.functionCall(FunctionCallData call) =>
      LlmChunk._(functionCall: call);
}

class FunctionCallData {
  final String name;
  final Map<String, dynamic> args;

  const FunctionCallData({required this.name, required this.args});
}
