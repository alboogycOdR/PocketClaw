/// Local LLM engine wrapper
///
/// Wraps flutter_gemma for on-device inference with streaming support.
/// Model files are managed by flutter_gemma's internal model manager.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

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
  InferenceModel? _model;

  bool get isLoaded => _isLoaded;
  LocalModelConfig? get config => _config;

  /// One-time initialisation — call early in app startup.
  static Future<void> initPlatform({String? huggingFaceToken}) async {
    await FlutterGemma.initialize(
      huggingFaceToken: huggingFaceToken,
    );
  }

  /// Load the active model that was previously installed via
  /// FlutterGemma.installModel().
  Future<void> loadModel(LocalModelConfig config) async {
    _config = config;

    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: config.maxTokens,
        supportImage: config.capabilities.contains(ModelCap.vision),
        supportAudio: config.capabilities.contains(ModelCap.audio),
      );

      _isLoaded = true;
      debugPrint('LlmEngine: loaded ${config.displayName}');
    } catch (e) {
      debugPrint('LlmEngine: failed to load model: $e');
      _isLoaded = false;
      rethrow;
    }
  }

  Stream<LlmChunk> generateStream(String prompt) async* {
    if (!_isLoaded || _model == null) {
      yield LlmChunk.text(
          'Local model not loaded. Please download a model in Settings.');
      return;
    }

    try {
      final chat = await _model!.createChat();
      await chat.addQuery(Message(text: prompt, isUser: true));

      final buffer = StringBuffer();

      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          final token = response.token;
          if (token.isEmpty) continue;
          buffer.write(token);

          // Check if the accumulated text contains a function call
          final accumulated = buffer.toString();
          final callMatch = _parseFunctionCall(accumulated);

          if (callMatch != null) {
            yield LlmChunk.functionCall(callMatch);
            buffer.clear();
          } else {
            yield LlmChunk.text(token);
          }
        } else if (response is FunctionCallResponse) {
          yield LlmChunk.functionCall(FunctionCallData(
            name: response.name,
            args: response.args,
          ));
        }
      }
    } catch (e) {
      yield LlmChunk.text('Inference error: $e');
    }
  }

  /// Collects streamed text into a single string (summarisation, brief updates).
  Future<String> generateCompleteText(String prompt) async {
    if (!_isLoaded || _model == null) {
      return '';
    }
    final buffer = StringBuffer();
    await for (final chunk in generateStream(prompt)) {
      if (chunk.isText && chunk.text != null) {
        buffer.write(chunk.text);
      }
    }
    return buffer.toString().trim();
  }

  Stream<LlmChunk> continueWithResult(String toolResult) async* {
    if (!_isLoaded || _model == null) {
      yield LlmChunk.text(toolResult);
      return;
    }

    try {
      final prompt =
          '<tool_result>$toolResult</tool_result>\n'
          'Based on the tool result above, provide a natural language response to the user.';

      await for (final chunk in generateStream(prompt)) {
        yield chunk;
      }
    } catch (e) {
      yield LlmChunk.text(toolResult);
    }
  }

  Future<List<double>> generateEmbedding(String text) async {
    try {
      final embeddingModel =
          await FlutterGemmaPlugin.instance.createEmbeddingModel();
      final embedding = await embeddingModel.generateEmbedding(text);
      return embedding;
    } catch (e) {
      debugPrint('LlmEngine: embedding failed: $e');
      return List.filled(384, 0.0);
    }
  }

  void unload() {
    _isLoaded = false;
    _config = null;
    _model = null;
  }

  void dispose() {
    unload();
  }

  /// Attempts to parse a function call from accumulated LLM output.
  /// Format: <tool_call>{"name":"tool_name","args":{...}}</tool_call>
  FunctionCallData? _parseFunctionCall(String text) {
    final regex = RegExp(r'<tool_call>(.*?)</tool_call>', dotAll: true);
    final match = regex.firstMatch(text);
    if (match == null) return null;

    try {
      final json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      return FunctionCallData(
        name: json['name'] as String,
        args: (json['args'] as Map<String, dynamic>?) ?? {},
      );
    } catch (_) {
      return null;
    }
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
