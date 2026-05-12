/// LlamaCppEngine — wraps fllama for .gguf model inference
library;

import 'dart:async';
import 'dart:io';

import 'package:fllama/fllama.dart';
import 'package:fllama/fllama_type.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_model_config.dart';
import '../models/model_version_status.dart';
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
    // builds. Format the prompt in Dart instead, picking the per-model
    // template from `_config.chatTemplate`. Picking the wrong template
    // produces garbled output — Gemma echoes its own role headers if
    // given ChatML, etc. Fall back to fllama only when its native path
    // works (best-effort).
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
      // fall through to template router
    }
    formattedPrompt ??= _formatPrompt(
      template: _config.chatTemplate,
      systemPrompt: systemPrompt,
      user: prompt,
    );

    // Set up token stream listener. fllama only emits per-token events when
    // `emitRealtimeCompletion: true` is passed to completion() — otherwise
    // the listener fires zero times and the bubble stays empty.
    final controller = StreamController<String>();
    StreamSubscription<Map<Object?, dynamic>>? subscription;
    final streamedSoFar = StringBuffer();

    subscription = _fllama!.onTokenStream?.listen((data) {
      if (data['function'] == 'completion') {
        final result = data['result'] as Map<Object?, dynamic>?;
        if (result != null) {
          final token = result['token'] as String?;
          if (token != null && token.isNotEmpty) {
            streamedSoFar.write(token);
            controller.add(token);
          }
        }
      }
    });

    // Start completion. The Future also resolves with the full text — used
    // as a safety net if the streaming channel emits nothing (some plugin
    // builds drop events on certain ABIs).
    _fllama!.completion(
      _contextId!,
      prompt: formattedPrompt,
      nPredict: maxTokens,
      temperature: temperature,
      topP: 0.95,
      stop: _stopTokensFor(_config.chatTemplate),
      emitRealtimeCompletion: true,
    ).then((result) {
      // Fallback: emit whatever the future returned, minus what we already
      // streamed, so the user gets text even if the stream was empty.
      if (streamedSoFar.isEmpty && result is Map) {
        final text = (result['text'] ?? result['content'] ?? result['response'])
            as String?;
        if (text != null && text.isNotEmpty) {
          controller.add(text);
        }
      }
      controller.close();
    }).catchError((Object e) {
      controller.addError(e);
      controller.close();
    });

    yield* controller.stream;

    await subscription?.cancel();
  }

  /// Route to the per-template formatter. Each template uses the role
  /// markers and turn structure that the model was trained with — using
  /// the wrong one makes the model emit its own header text in replies.
  static String _formatPrompt({
    required ChatTemplate template,
    String? systemPrompt,
    required String user,
  }) =>
      switch (template) {
        ChatTemplate.gemma =>
          _formatGemma(systemPrompt: systemPrompt, user: user),
        ChatTemplate.llama3 =>
          _formatLlama3(systemPrompt: systemPrompt, user: user),
        ChatTemplate.phi3 =>
          _formatPhi3(systemPrompt: systemPrompt, user: user),
        ChatTemplate.mistral =>
          _formatMistral(systemPrompt: systemPrompt, user: user),
        ChatTemplate.chatml =>
          _formatChatML(systemPrompt: systemPrompt, user: user),
      };

  /// Per-template stop tokens. fllama feeds these to llama.cpp so the
  /// stream halts at the model's own turn boundary instead of continuing
  /// into a hallucinated "user:" reply.
  static List<String> _stopTokensFor(ChatTemplate template) =>
      switch (template) {
        ChatTemplate.gemma => const ['<end_of_turn>', '<eos>'],
        ChatTemplate.llama3 => const ['<|eot_id|>', '<|end_of_text|>'],
        ChatTemplate.chatml => const ['<|im_end|>', '<|endoftext|>'],
        ChatTemplate.phi3 => const ['<|end|>', '<|endoftext|>'],
        ChatTemplate.mistral => const ['</s>'],
      };

  /// ChatML — `<|im_start|>role\ncontent<|im_end|>` with a trailing
  /// `assistant` open turn so the model continues from there. Used by
  /// Qwen 2.x, DeepSeek, Yi, and other recent open models.
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

  /// Gemma — `<start_of_turn>role\n…<end_of_turn>`. Verified against
  /// Gemma 2/3/4 instruct chat templates.
  static String _formatGemma({String? systemPrompt, required String user}) {
    final b = StringBuffer();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      b.write('<start_of_turn>system\n');
      b.write(systemPrompt);
      b.write('<end_of_turn>\n');
    }
    b.write('<start_of_turn>user\n');
    b.write(user);
    b.write('<end_of_turn>\n');
    b.write('<start_of_turn>model\n');
    return b.toString();
  }

  /// Llama 3 — header-id markers wrapping each turn. Used for Llama 3.1,
  /// 3.2 and 3.3 instruct variants.
  static String _formatLlama3({String? systemPrompt, required String user}) {
    final b = StringBuffer()..write('<|begin_of_text|>');
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      b.write('<|start_header_id|>system<|end_header_id|>\n\n');
      b.write(systemPrompt);
      b.write('<|eot_id|>');
    }
    b.write('<|start_header_id|>user<|end_header_id|>\n\n');
    b.write(user);
    b.write('<|eot_id|>');
    b.write('<|start_header_id|>assistant<|end_header_id|>\n\n');
    return b.toString();
  }

  /// Phi-3 — `<|role|>…<|end|>`. Covers Phi-3 / Phi-3.5 instruct.
  static String _formatPhi3({String? systemPrompt, required String user}) {
    final b = StringBuffer();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      b.write('<|system|>\n');
      b.write(systemPrompt);
      b.write('<|end|>\n');
    }
    b.write('<|user|>\n');
    b.write(user);
    b.write('<|end|>\n<|assistant|>\n');
    return b.toString();
  }

  /// Mistral — `[INST] … [/INST]`. The system prompt is folded into the
  /// instruction since Mistral has no dedicated system role marker.
  static String _formatMistral({String? systemPrompt, required String user}) {
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      return '[INST] $systemPrompt\n\n$user [/INST]';
    }
    return '[INST] $user [/INST]';
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

    // Versioned destination: {docs}/models/gguf/{id}/{commitHash}/{file}.
    // Pinning by commit hash means a re-download always yields the exact
    // same bytes even if HF later replaces the "main" pointer with a new
    // quantisation, and lets us run the old + new versions side by side
    // during an upgrade.
    final destDir = await _versionedDirFor(model);
    if (!destDir.existsSync()) await destDir.create(recursive: true);
    final destPath = '${destDir.path}/${model.hfFilename}';

    // `model.downloadUrl` builds the HF resolve URL from the same
    // `hfCommitHash` so the URL and the on-disk path stay in sync.
    final url = model.downloadUrl;

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
    // Wipe both the versioned tree and the legacy flat file so an upgrade
    // → delete cycle doesn't leave stale bytes on disk. Tolerate missing
    // entries — half-migrated state is normal.
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

  /// Resolve a model file on disk. Prefers the versioned layout written by
  /// the current download path; falls back to the legacy flat
  /// `{id}.gguf` location for downloads created before version pinning.
  /// On a legacy hit we lazily migrate to the versioned location so the
  /// next call hits the fast path.
  @override
  Future<String?> getModelPath(String modelId) async {
    if (modelId != _config.id) {
      // This engine instance is bound to one model — refuse cross-lookups.
      // The download manager builds an engine per model, so this check
      // mainly catches mistakes during refactors.
      return null;
    }
    final dir = await getApplicationDocumentsDirectory();
    final filename = _config.hfFilename ?? '$modelId.gguf';
    final versionedPath = '${dir.path}/models/gguf'
        '/$modelId/${_config.hfCommitHash}/$filename';
    if (File(versionedPath).existsSync()) return versionedPath;

    // Legacy: opportunistic migration. If `rename()` fails (cross-volume,
    // permissions), keep returning the legacy path so chat keeps working.
    final legacyPath = '${dir.path}/models/gguf/$modelId.gguf';
    if (File(legacyPath).existsSync()) {
      try {
        await Directory(File(versionedPath).parent.path).create(recursive: true);
        await File(legacyPath).rename(versionedPath);
        return versionedPath;
      } catch (e) {
        debugPrint('LlamaCppEngine: legacy migration failed, using flat path: $e');
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

    // Any other versioned subdir? -> upgrade available.
    final modelRoot = Directory('${dir.path}/models/gguf/${model.id}');
    if (modelRoot.existsSync()) {
      final entries = modelRoot.listSync();
      if (entries.any((e) => e is Directory)) {
        return ModelVersionStatus.updateAvailable;
      }
    }

    // Legacy flat layout counts as a pre-versioning download — treat it as
    // an update opportunity so the user can re-download against the pin.
    final legacyPath = '${dir.path}/models/gguf/${model.id}.gguf';
    if (File(legacyPath).existsSync()) {
      return ModelVersionStatus.updateAvailable;
    }
    return ModelVersionStatus.notDownloaded;
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

  /// Effective context window for the loaded model. fllama 0.0.1 does
  /// not expose the actual n_ctx the context was initialised with;
  /// return a sensible default that matches what most current GGUF
  /// quants ship with so the context-compaction service has a useful
  /// budget to plan against. When fllama exposes a real context-size
  /// getter, replace this with the live value.
  int? get currentContextSize => _isReady ? 4096 : null;

  /// One-shot summary generation. Wraps [generate] so the
  /// context-compaction service can keep a clean dependency on the
  /// engine surface instead of reaching into the raw fllama API.
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

/// Thrown when a download failure is definitively NOT retryable
/// (e.g. HTTP 401, 404). Retry loop re-throws these immediately.
class _FatalDownloadException implements Exception {
  final String message;
  _FatalDownloadException(this.message);
  @override
  String toString() => message;
}
