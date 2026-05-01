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
          // Fllama returns contextId as `num` over the platform channel —
          // sometimes int when the handle is a small whole number, sometimes
          // double. Coerce via `num` to avoid `int → double?` cast failure.
          _contextId = (result['contextId'] as num?)?.toDouble();
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

    // fllama's `getFormattedChat` does a `(HashMap[]) ArrayList` cast on
    // its Java side that crashes with `ClassCastException` on current
    // builds. Format the prompt in Dart instead — ChatML is the chat
    // template for Qwen 2.x / DeepSeek / Yi / many recent open models.
    // Fall back to fllama if it's available and works (best-effort).
    String? formattedPrompt;
    try {
      final messages = <RoleContent>[
        if (systemPrompt != null)
          RoleContent(role: 'system', content: systemPrompt),
        RoleContent(role: 'user', content: prompt),
      ];
      formattedPrompt = await _fllama!.getFormattedChat(
        _contextId!,
        messages: messages,
      );
    } catch (_) {
      // fall through to manual ChatML
    }
    formattedPrompt ??= _formatChatML(systemPrompt: systemPrompt, user: prompt);

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
      prompt: formattedPrompt,
      nPredict: maxTokens,
      temperature: temperature,
      topP: 0.95,
      stop: ['<|im_end|>', '<|endoftext|>', '<|end|>', '</s>'],
    ).then((_) {
      controller.close();
    }).catchError((Object e) {
      controller.addError(e);
      controller.close();
    });

    yield* controller.stream;

    await subscription?.cancel();
  }

  /// ChatML template — `<|im_start|>role\ncontent<|im_end|>` with a trailing
  /// `assistant` open turn so the model continues from there. Used by Qwen
  /// 2.x, DeepSeek, Yi, and several other recent open models.
  static String _formatChatML({String? systemPrompt, required String user}) {
    final b = StringBuffer();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      b.write('<|im_start|>system\n');
      b.write(systemPrompt);
      b.write('<|im_end|>\n');
    }
    b.write('<|im_start|>user\n');
    b.write(user);
    b.write('<|im_end|>\n');
    b.write('<|im_start|>assistant\n');
    return b.toString();
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

    // Up to 3 attempts. Each attempt resumes from the byte count already
    // written to disk (HTTP Range request). HF CDN pre-signed URLs often
    // drop connections on large mobile transfers — resuming is the fix.
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _downloadAttempt(
          url: url,
          destPath: destPath,
          huggingFaceToken: huggingFaceToken,
          onProgress: onProgress,
        );
        return; // success
      } on _FatalDownloadException {
        rethrow; // 401 / 404 — no point retrying
      } catch (e) {
        if (attempt == maxAttempts) {
          throw Exception(
            'Download failed after $maxAttempts attempts: ${_cleanError(e)}',
          );
        }
        // Transient error — wait briefly and retry from byte offset
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// One download attempt. Supports resume via HTTP Range header.
  /// Throws _FatalDownloadException on 401/404 (don't retry), or any
  /// other Exception on transient failures (will be retried).
  Future<void> _downloadAttempt({
    required String url,
    required String destPath,
    required String? huggingFaceToken,
    required void Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      // Check for partial file — resume from here if present
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

      // 206 Partial Content = resume succeeded. 200 = full download
      // (server ignored our Range header or we were starting fresh).
      if (response.statusCode == 206) {
        await _streamToFile(
          response: response,
          destPath: destPath,
          alreadyReceived: resumeFrom,
          onProgress: onProgress,
          append: true,
        );
      } else if (response.statusCode == 200) {
        // Server didn't honour Range — start over
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
    // Content-Length is the remaining bytes (for 206); add what's on disk
    // to get the real total for progress calculation.
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

  /// Strip noisy URL dumps from network exception messages.
  String _cleanError(Object e) {
    final msg = e.toString();
    if (msg.contains('Connection closed while receiving data')) {
      return 'Network interrupted \u2014 connection closed mid-download. '
          'Tap Retry to resume from where it left off.';
    }
    if (msg.contains('SocketException') || msg.contains('HttpException')) {
      // Truncate at the first ", uri =" so we don't dump the huge URL
      final i = msg.indexOf(', uri =');
      if (i > 0) return msg.substring(0, i);
    }
    return msg;
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

/// Thrown when a download failure is definitively NOT retryable
/// (e.g. HTTP 401, 404). Retry loop re-throws these immediately.
class _FatalDownloadException implements Exception {
  final String message;
  _FatalDownloadException(this.message);
  @override
  String toString() => message;
}
