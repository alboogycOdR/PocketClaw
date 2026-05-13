/// LlamaCppEngine — wraps the actively-maintained `llamadart` package
/// for .gguf model inference. Replaces the dead `fllama 0.0.1` binding
/// we shipped from v1.0 through v2.3.x.
///
/// Why the swap: fllama was frozen at 0.0.1 (18 months stale, no
/// embedding, no audio). llamadart 0.6+ tracks upstream llama.cpp and
/// exposes `generate()` (Stream<String>), `embed()` (List<double>),
/// and a real `getContextSize()`. The chat-template router we had to
/// maintain by hand for fllama is now done by llamadart automatically
/// from the GGUF metadata.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import '../../rag/rag_embedding_service.dart';
import '../models/local_model_config.dart';
import '../models/model_version_status.dart';
import 'abstract_llm_engine.dart';

class LlamaCppEngine implements AbstractLLMEngine {
  final LocalModelConfig _config;
  LlamaEngine? _engine;
  bool _isReady = false;
  String? _loadedModelId;
  int? _contextSize;

  LlamaCppEngine({required LocalModelConfig config}) : _config = config;

  /// The currently loaded engine, exposed so RagEmbeddingService can
  /// route `embed()` through it without holding its own model copy.
  LlamaEngine? get engine => _engine;

  @override
  Future<void> initialize({String? huggingFaceToken}) async {
    final path = await getModelPath(_config.id);
    if (path == null) return;

    final eng = LlamaEngine(LlamaBackend());
    try {
      await eng.loadModel(
        path,
        modelParams: const ModelParams(
          contextSize: 4096,
          gpuLayers: 0,
        ),
      );
      _contextSize = await eng.getContextSize();
      _engine = eng;
      _isReady = true;
      _loadedModelId = _config.id;
      // Make the engine available to RAG so KB indexing + semantic
      // search work as soon as a chat model is loaded.
      ragEmbeddingService.bindShared(eng);
      debugPrint(
        'LlamaCppEngine: loaded ${_config.displayName} '
        '(ctx=$_contextSize)',
      );
    } catch (e) {
      debugPrint('LlamaCppEngine: load failed: $e');
      try {
        await eng.dispose();
      } catch (_) {}
      rethrow;
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
    if (!_isReady || _engine == null) {
      throw StateError('LlamaCppEngine: model not loaded');
    }

    // Build a system+user composite prompt. llamadart applies the
    // model's chat template automatically when it detects role markers
    // in the prompt, so we just concatenate with a separating newline.
    // For tighter chat-template adherence we'd use `engine.create()`
    // with LlamaChatMessage list, but generate() preserves the
    // single-prompt API our existing chat path expects.
    final composite = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? '$systemPrompt\n\n$prompt'
        : prompt;

    yield* _engine!.generate(
      composite,
      params: GenerationParams(
        maxTokens: maxTokens,
        temp: temperature,
        topP: 0.95,
      ),
    );
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

    // Versioned destination: {docs}/models/gguf/{id}/{commitHash}/{file}
    final destDir = await _versionedDirFor(model);
    if (!destDir.existsSync()) await destDir.create(recursive: true);
    final destPath = '${destDir.path}/${model.hfFilename}';

    final url = model.downloadUrl;

    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _downloadAttempt(
          url: url,
          destPath: destPath,
          huggingFaceToken: huggingFaceToken,
          onProgress: onProgress,
        );
        return;
      } on _FatalDownloadException {
        rethrow;
      } catch (e) {
        if (attempt == maxAttempts) {
          throw Exception(
            'Download failed after $maxAttempts attempts: ${_cleanError(e)}',
          );
        }
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  Future<void> _downloadAttempt({
    required String url,
    required String destPath,
    required String? huggingFaceToken,
    required void Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final file = File(destPath);
      var resumeFrom = 0;
      if (file.existsSync()) {
        resumeFrom = file.lengthSync();
      }

      final request = await client.getUrl(Uri.parse(url));
      if (huggingFaceToken != null) {
        request.headers.set('Authorization', 'Bearer $huggingFaceToken');
      }
      if (resumeFrom > 0) {
        request.headers.set('Range', 'bytes=$resumeFrom-');
      }
      request.followRedirects = true;
      request.maxRedirects = 5;

      final response = await request.close();

      if (response.statusCode == 401) {
        await response.drain<void>();
        throw _FatalDownloadException(
          'Authentication required. Check your HuggingFace token in Settings.',
        );
      }
      if (response.statusCode == 404) {
        await response.drain<void>();
        throw _FatalDownloadException(
          'Model file not found at $url. The repo or filename may be wrong.',
        );
      }

      if (response.statusCode == 206) {
        await _streamToFile(
          response: response,
          destPath: destPath,
          alreadyReceived: resumeFrom,
          onProgress: onProgress,
          append: true,
        );
      } else if (response.statusCode == 200) {
        await _streamToFile(
          response: response,
          destPath: destPath,
          alreadyReceived: 0,
          onProgress: onProgress,
          append: false,
        );
      } else {
        await response.drain<void>();
        throw Exception('Unexpected HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  Future<void> _streamToFile({
    required HttpClientResponse response,
    required String destPath,
    required int alreadyReceived,
    required void Function(double progress)? onProgress,
    required bool append,
  }) async {
    final remainingBytes = response.contentLength;
    final totalBytes =
        remainingBytes > 0 ? alreadyReceived + remainingBytes : 0;
    var receivedBytes = alreadyReceived;

    final sink = File(destPath).openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );

    try {
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  String _cleanError(Object e) {
    final msg = e.toString();
    if (msg.contains('Connection closed while receiving data')) {
      return 'Network interrupted — connection closed mid-download. '
          'Tap Retry to resume from where it left off.';
    }
    if (msg.contains('SocketException') || msg.contains('HttpException')) {
      final i = msg.indexOf(', uri =');
      if (i > 0) return msg.substring(0, i);
    }
    return msg;
  }

  @override
  Future<void> deleteModel(String modelId) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models/gguf/$modelId');
    if (modelDir.existsSync()) {
      try {
        await modelDir.delete(recursive: true);
      } catch (_) {}
    }
    final legacyFile = File('${dir.path}/models/gguf/$modelId.gguf');
    if (legacyFile.existsSync()) {
      try {
        await legacyFile.delete();
      } catch (_) {}
    }
    if (_loadedModelId == modelId) {
      await unloadModel();
    }
  }

  @override
  Future<String?> getModelPath(String modelId) async {
    if (modelId != _config.id) return null;
    final dir = await getApplicationDocumentsDirectory();
    final filename = _config.hfFilename ?? '$modelId.gguf';
    final versionedPath = '${dir.path}/models/gguf'
        '/$modelId/${_config.hfCommitHash}/$filename';
    if (File(versionedPath).existsSync()) return versionedPath;

    // Legacy flat layout — migrate opportunistically.
    final legacyPath = '${dir.path}/models/gguf/$modelId.gguf';
    if (File(legacyPath).existsSync()) {
      try {
        await Directory(File(versionedPath).parent.path)
            .create(recursive: true);
        await File(legacyPath).rename(versionedPath);
        return versionedPath;
      } catch (e) {
        debugPrint('LlamaCppEngine: legacy migration failed: $e');
        return legacyPath;
      }
    }
    return null;
  }

  Future<Directory> _versionedDirFor(LocalModelConfig model) async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory(
      '${dir.path}/models/gguf/${model.id}/${model.hfCommitHash}',
    );
  }

  /// Whether the on-disk download matches the catalogue's pinned version.
  static Future<ModelVersionStatus> getVersionStatus(
    LocalModelConfig model,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = model.hfFilename ?? '${model.id}.gguf';
    final pinnedPath =
        '${dir.path}/models/gguf/${model.id}/${model.hfCommitHash}/$filename';
    if (File(pinnedPath).existsSync()) {
      return ModelVersionStatus.currentVersion;
    }
    final modelRoot = Directory('${dir.path}/models/gguf/${model.id}');
    if (modelRoot.existsSync()) {
      final entries = modelRoot.listSync();
      if (entries.any((e) => e is Directory)) {
        return ModelVersionStatus.updateAvailable;
      }
    }
    final legacyPath = '${dir.path}/models/gguf/${model.id}.gguf';
    if (File(legacyPath).existsSync()) {
      return ModelVersionStatus.updateAvailable;
    }
    return ModelVersionStatus.notDownloaded;
  }

  @override
  Future<void> unloadModel() async {
    ragEmbeddingService.bindShared(null);
    if (_engine != null) {
      try {
        await _engine!.dispose();
      } catch (_) {}
    }
    _engine = null;
    _isReady = false;
    _loadedModelId = null;
    _contextSize = null;
  }

  @override
  bool get isReady => _isReady;

  @override
  String? get loadedModelId => _loadedModelId;

  /// Live context size from the loaded GGUF, falling back to the
  /// default we passed at load time if the engine isn't ready.
  int? get currentContextSize => _contextSize;

  /// One-shot summary generation. Used by the context-compaction
  /// service so it can keep a clean dependency on the engine surface
  /// instead of reaching into llamadart directly.
  Future<String> generateSummary(
    String transcript, {
    String? systemPrompt,
    int maxTokens = 256,
  }) =>
      generate(
        transcript,
        systemPrompt: systemPrompt,
        maxTokens: maxTokens,
      );

  @override
  Future<void> dispose() async {
    await unloadModel();
  }
}

class _FatalDownloadException implements Exception {
  final String message;
  _FatalDownloadException(this.message);
  @override
  String toString() => message;
}
