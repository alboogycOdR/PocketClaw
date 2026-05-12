/// Whisper STT scaffolding.
///
/// Status:
///   - Model catalogue + download (URL → `{docs}/whisper-models/`) → ✅
///   - Voice settings screen reads / writes the active model id → ✅
///   - Audio transcription itself → ❌ requires a Flutter Whisper
///     binding. Two paths: (a) fllama gains audio transcription
///     (preferred), (b) add `whisper_dart` to pubspec. Until then,
///     [transcribeFile] throws a clear UnsupportedError so the
///     existing Android-online STT path stays the runtime default.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<Directory> _modelsDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/whisper-models');
    if (!d.existsSync()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  Future<String> modelPath(String modelId) async {
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

  /// Returns transcribed text for a wav/m4a file. NOT YET WIRED — the
  /// installed fllama doesn't expose audio transcription. Add
  /// `whisper_dart` (or upgrade fllama) and replace this body with
  /// the real native call.
  Future<String> transcribeFile(String audioPath, {String? modelId}) async {
    throw UnsupportedError(
      'Whisper transcription requires a Flutter Whisper binding. '
      'Either upgrade fllama to a build that supports audio, or add '
      '`whisper_dart` to pubspec.yaml and call its transcribe API '
      'here. Currently the on-device STT path falls back to the '
      'Android system speech recogniser (online).',
    );
  }
}

final whisperSttService = WhisperSttService();
