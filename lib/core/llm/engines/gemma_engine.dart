/// GemmaEngine — wraps flutter_gemma for .task model inference
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_model_config.dart';
import 'abstract_llm_engine.dart';

class GemmaEngine implements AbstractLLMEngine {
  final LocalModelConfig _config;
  bool _isReady = false;
  String? _loadedModelId;
  InferenceModel? _model;

  /// Whether FlutterGemma.initialize() has been called at least once.
  /// We initialise lazily on first use (download or load) rather than at
  /// app startup, so the app launches even if no Gemma model is ever used.
  static bool _platformInitialised = false;

  GemmaEngine({required LocalModelConfig config}) : _config = config;

  /// Idempotent: initialises the flutter_gemma platform once. Safe to call
  /// on every Gemma operation.
  static Future<void> _ensurePlatformInitialised(String? hfToken) async {
    if (_platformInitialised) return;
    try {
      await FlutterGemma.initialize(huggingFaceToken: hfToken);
      _platformInitialised = true;
    } catch (e) {
      debugPrint('GemmaEngine: FlutterGemma.initialize failed: $e');
      // Leave _platformInitialised=false so the next call can retry
      rethrow;
    }
  }

  @override
  Future<void> initialize({String? huggingFaceToken}) async {
    // Ensure platform is ready before any flutter_gemma call
    try {
      await _ensurePlatformInitialised(huggingFaceToken);
    } catch (_) {
      _isReady = false;
      return;
    }

    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        supportImage: _config.capabilities.contains('vision'),
        supportAudio: _config.capabilities.contains('audio'),
      );
      _isReady = true;
      _loadedModelId = _config.id;
      debugPrint('GemmaEngine: loaded ${_config.displayName}');
    } catch (e) {
      debugPrint('GemmaEngine: failed to load model: $e');
      _isReady = false;
    }
  }

  @override
  Future<String> generate(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
  }) async {
    final buffer = StringBuffer();
    await for (final token in generateStream(
      prompt,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    )) {
      buffer.write(token);
    }
    return buffer.toString();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    if (!_isReady || _model == null) {
      throw StateError('GemmaEngine: model not loaded');
    }

    final formattedPrompt = systemPrompt != null
        ? '<start_of_turn>system\n$systemPrompt<end_of_turn>\n'
          '<start_of_turn>user\n$prompt<end_of_turn>\n'
          '<start_of_turn>model\n'
        : '<start_of_turn>user\n$prompt<end_of_turn>\n'
          '<start_of_turn>model\n';

    final chat = await _model!.createChat();
    await chat.addQuery(Message(text: formattedPrompt, isUser: true));

    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        final token = response.token;
        if (token.isNotEmpty) yield token;
      }
    }
  }

  @override
  Future<bool> isModelDownloaded(String modelId) async {
    // flutter_gemma manages its own model storage — check via the active model
    try {
      await _ensurePlatformInitialised(null);
      await FlutterGemma.getActiveModel(maxTokens: 256);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> downloadModel(
    LocalModelConfig model, {
    void Function(double progress)? onProgress,
    String? huggingFaceToken,
  }) async {
    // Lazy platform init — critical. flutter_gemma's plugin throws
    // "FlutterGemma not initialized!" if installModel is called before
    // FlutterGemma.initialize() has run.
    await _ensurePlatformInitialised(huggingFaceToken);

    // flutter_gemma handles .task download internally via installModel
    final modelType = ModelType.gemmaIt;
    final fileType = ModelFileType.task;

    final url = model.downloadUrl ?? 'https://huggingface.co/${model.hfRepo}';

    await FlutterGemma.installModel(
      modelType: modelType,
      fileType: fileType,
    )
        .fromNetwork(url, token: huggingFaceToken)
        .withProgress((progress) {
          onProgress?.call(progress / 100.0);
        })
        .install();
  }

  @override
  Future<void> deleteModel(String modelId) async {
    final path = await getModelPath(modelId);
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
  }

  @override
  Future<String?> getModelPath(String modelId) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/models/gemma/$modelId.task';
    return File(path).existsSync() ? path : null;
  }

  @override
  Future<void> unloadModel() async {
    _isReady = false;
    _loadedModelId = null;
    _model = null;
  }

  @override
  bool get isReady => _isReady;

  @override
  String? get loadedModelId => _loadedModelId;

  @override
  Future<void> dispose() async {
    await unloadModel();
  }
}
