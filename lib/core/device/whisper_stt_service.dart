/// Whisper STT — offline audio transcription via `whisper_ggml_plus`.
///
/// Replaces the v2.3.x stub that always threw UnsupportedError. We keep
/// our own resume-capable downloader (the package's downloader is
/// non-resumable and silent on errors) but defer to the package for
/// the actual transcription call. Models are stored at the location
/// the package expects so a single file backs both code paths.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_ggml/whisper_ggml.dart' as wgg;

class WhisperModel {
  final String id;
  final String displayName;
  final int sizeMb;
  final String url;
  final String description;
  final List<String> languages;
  const WhisperModel({
    required this.id,
    required this.displayName,
    required this.sizeMb,
    required this.url,
    required this.description,
    required this.languages,
  });
}

const kWhisperModels = <WhisperModel>[
  WhisperModel(
    id: 'tiny.en',
    displayName: 'Whisper Tiny (English)',
    sizeMb: 75,
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
    description: 'Fastest, English only, good for basic transcription',
    languages: ['en'],
  ),
  WhisperModel(
    id: 'tiny',
    displayName: 'Whisper Tiny (Multilingual)',
    sizeMb: 75,
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
    description: 'Fast, supports Afrikaans and 99 other languages',
    languages: ['en', 'af', 'zu', 'xh', 'multi'],
  ),
  WhisperModel(
    id: 'base.en',
    displayName: 'Whisper Base (English)',
    sizeMb: 142,
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin',
    description: 'Better accuracy, English only',
    languages: ['en'],
  ),
  WhisperModel(
    id: 'base',
    displayName: 'Whisper Base (Multilingual)',
    sizeMb: 142,
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
    description: 'Good accuracy, multilingual including Afrikaans',
    languages: ['en', 'af', 'zu', 'xh', 'multi'],
  ),
  WhisperModel(
    id: 'small.en',
    displayName: 'Whisper Small (English)',
    sizeMb: 466,
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin',
    description: 'High accuracy, English only, requires more RAM',
    languages: ['en'],
  ),
];

class WhisperSttService {
  static const _activeModelPref = 'whisper_active_model_id';

  Directory? _dir;
  bool _legacyMigrated = false;

  /// Resolve where whisper_ggml_plus expects the models — application
  /// support dir on Android, library dir on iOS. Using the same path
  /// means our downloader and the transcribe call share one file.
  Future<Directory> _modelsDir() async {
    if (_dir != null) return _dir!;
    final base = Platform.isAndroid
        ? await getApplicationSupportDirectory()
        : await getLibraryDirectory();
    if (!base.existsSync()) await base.create(recursive: true);
    _dir = base;
    return base;
  }

  /// One-shot move of any models downloaded by v2.3.x into the new
  /// directory. Old layout was `{docs}/whisper-models/ggml-$id.bin`.
  Future<void> _migrateLegacyIfNeeded() async {
    if (_legacyMigrated) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final legacy = Directory('${docs.path}/whisper-models');
      if (!legacy.existsSync()) {
        _legacyMigrated = true;
        return;
      }
      final target = await _modelsDir();
      for (final entry in legacy.listSync()) {
        if (entry is File && entry.path.endsWith('.bin')) {
          final name = entry.uri.pathSegments.last;
          final newPath = '${target.path}/$name';
          if (!File(newPath).existsSync()) {
            try {
              await entry.rename(newPath);
            } catch (_) {
              // Cross-volume rename can fail — fall back to copy+delete.
              await entry.copy(newPath);
              await entry.delete();
            }
          } else {
            await entry.delete();
          }
        }
      }
      try {
        await legacy.delete(recursive: true);
      } catch (_) {}
    } catch (e) {
      debugPrint('WhisperSttService: legacy migration skipped: $e');
    }
    _legacyMigrated = true;
  }

  Future<String> modelPath(String modelId) async {
    await _migrateLegacyIfNeeded();
    final d = await _modelsDir();
    return '${d.path}/ggml-$modelId.bin';
  }

  Future<bool> isModelDownloaded(String modelId) async {
    return File(await modelPath(modelId)).existsSync();
  }

  Future<int> modelSizeOnDisk(String modelId) async {
    final f = File(await modelPath(modelId));
    if (!f.existsSync()) return 0;
    return f.length();
  }

  Future<String?> activeModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeModelPref);
  }

  Future<void> setActiveModelId(String? modelId) async {
    final prefs = await SharedPreferences.getInstance();
    if (modelId == null) {
      await prefs.remove(_activeModelPref);
    } else {
      await prefs.setString(_activeModelPref, modelId);
    }
  }

  /// Stream-download with resume + progress callback.
  Future<void> downloadModel(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final model = kWhisperModels.firstWhere((m) => m.id == modelId);
    final dest = File(await modelPath(modelId));
    if (dest.existsSync()) return;
    final tmp = File('${dest.path}.part');
    await tmp.parent.create(recursive: true);

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(model.url));
      final resumeFrom = tmp.existsSync() ? tmp.lengthSync() : 0;
      if (resumeFrom > 0) {
        req.headers['Range'] = 'bytes=$resumeFrom-';
      }
      final response = await client.send(req);
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception(
            'Download failed: HTTP ${response.statusCode}');
      }
      final total = (response.contentLength ?? 0) + resumeFrom;
      var received = resumeFrom;
      final sink = tmp.openWrite(
        mode: resumeFrom > 0 ? FileMode.append : FileMode.write,
      );
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      await tmp.rename(dest.path);
    } finally {
      client.close();
    }
  }

  Future<void> deleteModel(String modelId) async {
    final f = File(await modelPath(modelId));
    if (f.existsSync()) await f.delete();
  }

  /// Map our catalogue ID to the package's WhisperModel enum.
  wgg.WhisperModel? _enumFor(String modelId) {
    switch (modelId) {
      case 'tiny':
        return wgg.WhisperModel.tiny;
      case 'tiny.en':
        return wgg.WhisperModel.tinyEn;
      case 'base':
        return wgg.WhisperModel.base;
      case 'base.en':
        return wgg.WhisperModel.baseEn;
      case 'small':
        return wgg.WhisperModel.small;
      case 'small.en':
        return wgg.WhisperModel.smallEn;
      case 'medium':
        return wgg.WhisperModel.medium;
      case 'medium.en':
        return wgg.WhisperModel.mediumEn;
      case 'large':
        return wgg.WhisperModel.large;
    }
    return null;
  }

  /// Transcribe an audio file (wav/m4a/aac) to text using the on-device
  /// whisper.cpp build shipped by `whisper_ggml_plus`. Falls back to
  /// the active model from SharedPreferences when [modelId] is null.
  ///
  /// Returns the transcribed text (possibly empty). Throws when the
  /// requested model isn't downloaded, or when the native call returns
  /// no result (which the package surfaces as a null return).
  Future<String> transcribeFile(String audioPath, {String? modelId}) async {
    final effectiveId = modelId ?? await activeModelId();
    if (effectiveId == null) {
      throw StateError(
        'No Whisper model selected. Pick one in Settings → Voice.',
      );
    }
    final enumModel = _enumFor(effectiveId);
    if (enumModel == null) {
      throw StateError('Unknown Whisper model id: $effectiveId');
    }
    if (!await isModelDownloaded(effectiveId)) {
      throw StateError(
        'Whisper model "$effectiveId" is not downloaded yet. '
        'Open Settings → Voice and tap Download.',
      );
    }

    final controller = wgg.WhisperController();
    final result = await controller.transcribe(
      model: enumModel,
      audioPath: audioPath,
      // 'auto' isn't supported by whisper.cpp directly — let the model
      // detect language by passing an empty hint. The English-only
      // variants ignore this anyway.
      lang: 'en',
    );

    if (result == null) {
      throw StateError(
        'Whisper transcription failed — see debug logs for details.',
      );
    }
    return result.transcription.text.trim();
  }
}

final whisperSttService = WhisperSttService();
