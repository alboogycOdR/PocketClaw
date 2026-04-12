/// CloudLLMEngine — connects to Anthropic, OpenAI, or Google AI cloud APIs
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/local_model_config.dart';
import '../models/model_provider.dart';
import '../services/api_key_service.dart';
import 'abstract_llm_engine.dart';

class CloudLLMEngine implements AbstractLLMEngine {
  final LocalModelConfig _config;
  String? _apiKey;
  bool _isReady = false;
  String? _loadedModelId;

  CloudLLMEngine({required LocalModelConfig config}) : _config = config;

  @override
  Future<void> initialize({String? huggingFaceToken}) async {
    final cloudProvider = ApiKeyService.providerFor(_config.provider);
    if (cloudProvider == null) {
      debugPrint('CloudLLMEngine: unknown provider ${_config.provider}');
      return;
    }

    final keyService = ApiKeyService();
    _apiKey = await keyService.getKey(cloudProvider);

    if (_apiKey != null && _apiKey!.isNotEmpty) {
      _isReady = true;
      _loadedModelId = _config.id;
      debugPrint('CloudLLMEngine: ready with ${_config.displayName}');
    } else {
      debugPrint('CloudLLMEngine: no API key for ${_config.provider}');
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
    if (!_isReady || _apiKey == null) {
      throw StateError(
        'CloudLLMEngine: not ready. Configure API key in Settings.',
      );
    }

    yield* switch (_config.provider) {
      ModelProvider.anthropic => _streamAnthropic(
          prompt,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
        ),
      // OpenAI + xAI (Grok) + Moonshot (Kimi) all speak the OpenAI
      // Chat Completions protocol. They differ only in endpoint +
      // model ID, both of which come from LocalModelConfig.
      ModelProvider.openAI ||
      ModelProvider.xai ||
      ModelProvider.moonshot =>
        _streamOpenAI(
          prompt,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
        ),
      ModelProvider.googleAI => _streamGoogleAI(
          prompt,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
        ),
      _ => throw StateError('Unsupported cloud provider: ${_config.provider}'),
    };
  }

  // -- Anthropic Messages API (SSE streaming) ---------------------------------

  Stream<String> _streamAnthropic(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    final body = jsonEncode({
      'model': _config.cloudModelId ?? 'claude-sonnet-4-20250514',
      'max_tokens': maxTokens,
      'stream': true,
      if (systemPrompt != null) 'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });

    final request = http.Request(
      'POST',
      Uri.parse(
        _config.cloudApiEndpoint ?? 'https://api.anthropic.com/v1/messages',
      ),
    );
    request.headers.addAll({
      'x-api-key': _apiKey!,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    });
    request.body = body;

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Anthropic API error ${response.statusCode}: $errorBody');
    }

    await for (final chunk in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!chunk.startsWith('data: ')) continue;
      final data = chunk.substring(6);
      if (data == '[DONE]') break;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final type = json['type'] as String?;
        if (type == 'content_block_delta') {
          final delta = json['delta'] as Map<String, dynamic>?;
          final text = delta?['text'] as String?;
          if (text != null && text.isNotEmpty) yield text;
        }
      } catch (_) {
        // Skip unparseable SSE lines
      }
    }
  }

  // -- OpenAI Chat Completions API (SSE streaming) ----------------------------

  Stream<String> _streamOpenAI(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    final messages = <Map<String, String>>[
      if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': prompt},
    ];

    final body = jsonEncode({
      'model': _config.cloudModelId ?? 'gpt-4o-mini',
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': true,
      'messages': messages,
    });

    final request = http.Request(
      'POST',
      Uri.parse(
        _config.cloudApiEndpoint ??
            'https://api.openai.com/v1/chat/completions',
      ),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    });
    request.body = body;

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('OpenAI API error ${response.statusCode}: $errorBody');
    }

    await for (final chunk in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!chunk.startsWith('data: ')) continue;
      final data = chunk.substring(6);
      if (data == '[DONE]') break;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) yield content;
        }
      } catch (_) {
        // Skip unparseable SSE lines
      }
    }
  }

  // -- Google AI (Gemini) Streaming -------------------------------------------

  Stream<String> _streamGoogleAI(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    final modelId = _config.cloudModelId ?? 'gemini-2.0-flash';
    final url =
        'https://generativelanguage.googleapis.com/v1/models/$modelId:streamGenerateContent?alt=sse&key=$_apiKey';

    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [
          {'text': prompt},
        ],
      },
    ];

    final body = jsonEncode({
      if (systemPrompt != null)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'temperature': temperature,
      },
    });

    final request = http.Request('POST', Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
    request.body = body;

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception(
        'Google AI API error ${response.statusCode}: $errorBody',
      );
    }

    await for (final chunk in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!chunk.startsWith('data: ')) continue;
      final data = chunk.substring(6);

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.isNotEmpty) yield text;
          }
        }
      } catch (_) {
        // Skip unparseable SSE lines
      }
    }
  }

  // -- No-op methods for local-only operations --------------------------------

  @override
  Future<bool> isModelDownloaded(String modelId) async => true;

  @override
  Future<void> downloadModel(
    LocalModelConfig model, {
    void Function(double progress)? onProgress,
    String? huggingFaceToken,
  }) async {
    // Cloud models don't need downloading
  }

  @override
  Future<void> deleteModel(String modelId) async {
    // Nothing to delete for cloud models
  }

  @override
  Future<String?> getModelPath(String modelId) async => null;

  @override
  Future<void> unloadModel() async {
    _isReady = false;
    _loadedModelId = null;
    _apiKey = null;
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
