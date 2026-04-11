/// LlamaCppEngine — wraps fllama for .gguf model inference
library;

import 'dart:async';
import 'dart:io';

import 'package:fllama/fllama.dart';
import 'package:fllama/fllama_type.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_model_config.dart';
import 'abstract_llm_engine.dart';

class LlamaCppEngine implements AbstractLLMEngine {
  final LocalModelConfig _config;
  bool _isReady = false;
  String? _loadedModelId;
  double? _contextId;
  Fllama? _fllama;

  LlamaCppEngine({required LocalModelConfig config}) : _config = config;

  @override
  Future<void> initialize({String? huggingFaceToken}) async {
    final path = await getModelPath(_config.id);
    if (path != null) {
      _fllama = Fllama.instance();
      if (_fllama != null) {
        final result = await _fllama!.initContext(
          path,
          emitLoadProgress: false,
        );
        if (result != null) {
          _contextId = result['contextId'] as double?;
          if (_contextId != null) {
            _isReady = true;
            _loadedModelId = _config.id;
            debugPrint('LlamaCppEngine: ready with ${_config.displayName}');
          }
        }
      }
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
    if (!_isReady || _fllama == null || _contextId == null) {
      throw StateError('LlamaCppEngine: model not loaded');
    }

    // Format messages using fllama's chat template
    final messages = <RoleContent>[
      if (systemPrompt != null)
        RoleContent(role: 'system', content: systemPrompt),
      RoleContent(role: 'user', content: prompt),
    ];

    final formattedPrompt = await _fllama!.getFormattedChat(
      _contextId!,
      messages: messages,
    );

    // Set up token stream listener
    final controller = StreamController<String>();
    StreamSubscription<Map<Object?, dynamic>>? subscription;

    subscription = _fllama!.onTokenStream?.listen((data) {
      if (data['function'] == 'completion') {
        final result = data['result'] as Map<Object?, dynamic>?;
        if (result != null) {
          final token = result['token'] as String?;
          if (token != null && token.isNotEmpty) {
            controller.add(token);
          }
        }
      }
    });

    // Start completion
    _fllama!.completion(
      _contextId!,
      prompt: formattedPrompt ?? prompt,
      nPredict: maxTokens,
      temperature: temperature,
      topP: 0.95,
      stop: ['<|endoftext|>', '<|end|>', '</s>'],
    ).then((_) {
      controller.close();
    }).catchError((Object e) {
      controller.addError(e);
      controller.close();
    });

    yield* controller.stream;

    await subscription?.cancel();
  }

  @override
  Future<bool> isModelDownloaded(String modelId) async {
    final path = await getModelPath(modelId);
    return path != null && File(path).existsSync();
  }

  @override
  Future<void> downloadModel(
    LocalModelConfig model, {
    void Function(double progress)? onProgress,
    String? huggingFaceToken,
  }) async {
    assert(
      model.hfFilename != null,
      'GGUF models require hfFilename in LocalModelConfig',
    );

    final dir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${dir.path}/models/gguf');
    if (!destDir.existsSync()) await destDir.create(recursive: true);

    final destPath = '${destDir.path}/${model.id}.gguf';
    final url = 'https://huggingface.co/${model.hfRepo}'
        '/resolve/main/${model.hfFilename}';

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));

      if (huggingFaceToken != null) {
        request.headers.set('Authorization', 'Bearer $huggingFaceToken');
      }
      request.followRedirects = true;
      request.maxRedirects = 5;

      final response = await request.close();

      if (response.statusCode == 401) {
        response.drain<void>();
        throw Exception(
          'Authentication required. Provide a HuggingFace token in Settings.',
        );
      }
      if (response.statusCode != 200) {
        response.drain<void>();
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      await _downloadToFile(response, destPath, onProgress);
    } finally {
      client.close();
    }
  }

  Future<void> _downloadToFile(
    HttpClientResponse response,
    String destPath,
    void Function(double progress)? onProgress,
  ) async {
    final totalBytes = response.contentLength;
    var receivedBytes = 0;
    final sink = File(destPath).openWrite();

    await for (final chunk in response) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress?.call(receivedBytes / totalBytes);
      }
    }

    await sink.flush();
    await sink.close();
  }

  @override
  Future<void> deleteModel(String modelId) async {
    final path = await getModelPath(modelId);
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
    if (_loadedModelId == modelId) {
      await unloadModel();
    }
  }

  @override
  Future<String?> getModelPath(String modelId) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/models/gguf/$modelId.gguf';
    return File(path).existsSync() ? path : null;
  }

  @override
  Future<void> unloadModel() async {
    if (_fllama != null && _contextId != null) {
      await _fllama!.releaseContext(_contextId!);
    }
    _isReady = false;
    _loadedModelId = null;
    _contextId = null;
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
