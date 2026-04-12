/// Legacy LlmEngine stub — the real inference path now goes through
/// AbstractLLMEngine (GGUF via fllama, or Cloud APIs).
///
/// flutter_gemma was removed in the .task cleanup. This stub stays so
/// that LocalAgent / CameraService continue to compile; they route
/// through AbstractLLMEngine at call sites or short-circuit.
library;

import 'dart:async';

enum ModelCap { text, vision, audio, functionCalling, thinking }

class LocalModelConfig {
  final String id;
  final String displayName;
  final Set<ModelCap> capabilities;
  final int maxTokens;
  final double temperature;
  final int ramRequiredMb;

  const LocalModelConfig({
    required this.id,
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

  /// Deprecated no-op. Previously initialised flutter_gemma.
  static Future<void> initPlatform({String? huggingFaceToken}) async {}

  /// Deprecated. Real loading happens inside LlamaCppEngine now.
  Future<void> loadModel(LocalModelConfig config) async {
    _config = config;
    _isLoaded = false; // stub never ready
  }

  Stream<LlmChunk> generateStream(String prompt) async* {
    yield LlmChunk.text(
        'Legacy engine path. Use AbstractLLMEngine instead.');
  }

  Stream<LlmChunk> continueWithResult(String toolResult) async* {
    yield LlmChunk.text(toolResult);
  }

  /// Collects streamed output into one string. Legacy API kept for
  /// MemoryService compatibility — returns empty in this stub.
  Future<String> generateCompleteText(String prompt) async => '';

  Future<List<double>> generateEmbedding(String text) async =>
      List.filled(384, 0.0);

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
