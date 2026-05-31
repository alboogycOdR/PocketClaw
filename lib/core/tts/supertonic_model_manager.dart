/// Manages Supertonic-3 ONNX model + voice style downloads.
///
/// Supertonic-3 is a 4-stage TTS pipeline (duration_predictor →
/// text_encoder → vector_estimator (N diffusion steps) → vocoder).
/// Models live under `huggingface.co/Supertone/supertonic-3` and are
/// downloaded into `{app docs}/supertonic/` alongside the two config
/// files (`tts.json`, `unicode_indexer.json`) and per-voice style
/// JSONs.
///
/// Total bundle is ~400 MB — heavier than the v1 spec advertised
/// because the published model is a 31-language diffusion model rather
/// than the lightweight 2-stage one the original spec was written
/// against. APK stays unaffected; this is all on-device download.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _hfBase = 'https://huggingface.co/Supertone/supertonic-3/resolve/main';

class SupertonicVoice {
  final String id;
  final String displayName;
  final String gender;

  const SupertonicVoice({
    required this.id,
    required this.displayName,
    required this.gender,
  });
}

const kSupertonicVoices = [
  SupertonicVoice(id: 'M1', displayName: 'Male 1 — Natural', gender: 'male'),
  SupertonicVoice(id: 'M2', displayName: 'Male 2 — Warm', gender: 'male'),
  SupertonicVoice(id: 'M3', displayName: 'Male 3 — Crisp', gender: 'male'),
  SupertonicVoice(id: 'M4', displayName: 'Male 4 — Deep', gender: 'male'),
  SupertonicVoice(id: 'M5', displayName: 'Male 5 — Bright', gender: 'male'),
  SupertonicVoice(id: 'F1', displayName: 'Female 1 — Natural', gender: 'female'),
  SupertonicVoice(id: 'F2', displayName: 'Female 2 — Warm', gender: 'female'),
  SupertonicVoice(id: 'F3', displayName: 'Female 3 — Clear', gender: 'female'),
  SupertonicVoice(id: 'F4', displayName: 'Female 4 — Soft', gender: 'female'),
  SupertonicVoice(id: 'F5', displayName: 'Female 5 — Bright', gender: 'female'),
];

/// Loaded voice style — both vectors come as flat Float32 arrays plus
/// the original tensor shape from the JSON `dims` field.
class SupertonicVoiceStyle {
  final Float32List ttl;
  final List<int> ttlDims;
  final Float32List dp;
  final List<int> dpDims;

  SupertonicVoiceStyle({
    required this.ttl,
    required this.ttlDims,
    required this.dp,
    required this.dpDims,
  });
}

class SupertonicModelManager {
  static const _durationFile = 'duration_predictor.onnx';
  static const _textEncoderFile = 'text_encoder.onnx';
  static const _vectorEstFile = 'vector_estimator.onnx';
  static const _vocoderFile = 'vocoder.onnx';
  static const _ttsConfigFile = 'tts.json';
  static const _unicodeIndexerFile = 'unicode_indexer.json';

  Future<Directory> get _modelDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/supertonic');
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> _pathFor(String name) async =>
      '${(await _modelDir).path}/$name';

  Future<String> get durationPath => _pathFor(_durationFile);
  Future<String> get textEncoderPath => _pathFor(_textEncoderFile);
  Future<String> get vectorEstPath => _pathFor(_vectorEstFile);
  Future<String> get vocoderPath => _pathFor(_vocoderFile);
  Future<String> get ttsConfigPath => _pathFor(_ttsConfigFile);
  Future<String> get unicodeIndexerPath => _pathFor(_unicodeIndexerFile);
  Future<String> voicePath(String voiceId) => _pathFor('voice_$voiceId.json');

  Future<bool> areModelsDownloaded() async {
    for (final p in [
      await durationPath,
      await textEncoderPath,
      await vectorEstPath,
      await vocoderPath,
      await ttsConfigPath,
      await unicodeIndexerPath,
    ]) {
      if (!File(p).existsSync()) return false;
    }
    return true;
  }

  Future<bool> isVoiceDownloaded(String voiceId) async {
    return File(await voicePath(voiceId)).existsSync();
  }

  Future<int> totalSizeBytes() async {
    var total = 0;
    final dir = await _modelDir;
    if (!dir.existsSync()) return 0;
    for (final f in dir.listSync().whereType<File>()) {
      total += f.lengthSync();
    }
    return total;
  }

  /// Downloads the six core files (4 ONNX + 2 JSONs). Voice styles are
  /// downloaded separately via [downloadVoice]. Reports progress as a
  /// label string + 0..1 fraction over the whole sequence.
  Future<void> downloadModels({
    void Function(String label, double progress)? onProgress,
    VoidCallback? onComplete,
  }) async {
    // Weighted by approximate size: vector_estimator 257 MB > vocoder
    // 101 MB > text_encoder 36 MB > duration 3.7 MB > configs (~280 KB).
    final steps = <(String label, String url, File dest, double weight)>[
      ('Duration predictor (3.7 MB)…',  '$_hfBase/onnx/$_durationFile',     File(await durationPath),      0.01),
      ('Text encoder (36 MB)…',         '$_hfBase/onnx/$_textEncoderFile',  File(await textEncoderPath),   0.09),
      ('Vector estimator (257 MB)…',    '$_hfBase/onnx/$_vectorEstFile',    File(await vectorEstPath),     0.65),
      ('Vocoder (101 MB)…',             '$_hfBase/onnx/$_vocoderFile',      File(await vocoderPath),       0.24),
      ('TTS config…',                   '$_hfBase/onnx/$_ttsConfigFile',    File(await ttsConfigPath),     0.005),
      ('Unicode indexer…',              '$_hfBase/onnx/$_unicodeIndexerFile', File(await unicodeIndexerPath), 0.005),
    ];

    var doneWeight = 0.0;
    for (final step in steps) {
      final start = doneWeight;
      await _downloadFile(
        url: step.$2,
        dest: step.$3,
        onProgress: (p) =>
            onProgress?.call(step.$1, start + p * step.$4),
      );
      doneWeight += step.$4;
    }
    onComplete?.call();
  }

  Future<void> downloadVoice(
    String voiceId, {
    void Function(double)? onProgress,
  }) async {
    await _downloadFile(
      url: '$_hfBase/voice_styles/$voiceId.json',
      dest: File(await voicePath(voiceId)),
      onProgress: onProgress,
    );
  }

  Future<void> _downloadFile({
    required String url,
    required File dest,
    void Function(double)? onProgress,
  }) async {
    if (dest.existsSync()) return;

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} for $url');
      }
      final total = response.contentLength ?? 0;
      var received = 0;

      final tmp = File('${dest.path}.part');
      final sink = tmp.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();
      await tmp.rename(dest.path);
    } finally {
      client.close();
    }
  }

  /// Reads the voice style JSON — Supertonic-3 wraps each vector with
  /// `{"data": [...], "dims": [...]}` so we preserve both.
  Future<SupertonicVoiceStyle> loadVoiceStyle(String voiceId) async {
    final file = File(await voicePath(voiceId));
    if (!file.existsSync()) {
      throw Exception(
          'Voice $voiceId not downloaded. Call downloadVoice() first.');
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    Float32List flatten(dynamic raw) {
      // Recursively flatten nested lists into a single flat Float32List.
      final out = <double>[];
      void walk(dynamic v) {
        if (v is List) {
          for (final e in v) {
            walk(e);
          }
        } else if (v is num) {
          out.add(v.toDouble());
        }
      }
      walk(raw);
      return Float32List.fromList(out);
    }

    final ttlSection = json['style_ttl'] as Map<String, dynamic>;
    final dpSection = json['style_dp'] as Map<String, dynamic>;

    return SupertonicVoiceStyle(
      ttl: flatten(ttlSection['data']),
      ttlDims: (ttlSection['dims'] as List).cast<int>(),
      dp: flatten(dpSection['data']),
      dpDims: (dpSection['dims'] as List).cast<int>(),
    );
  }

  /// Loads `unicode_indexer.json` — a flat JSON array where the array
  /// position IS the Unicode codepoint and the value is the token ID
  /// (-1 means "no mapping, skip this character"). Matches the layout
  /// `self.indexer = json.load(f)` in py/helper.py where the
  /// subsequent `self.indexer[ord(char)]` is positional indexing.
  Future<List<int>> loadUnicodeIndexer() async {
    final file = File(await unicodeIndexerPath);
    if (!file.existsSync()) {
      throw Exception(
          'unicode_indexer.json not downloaded. Run downloadModels() first.');
    }
    final raw = jsonDecode(await file.readAsString());
    if (raw is List) {
      return [for (final v in raw) (v is num) ? v.toInt() : -1];
    }
    throw Exception(
        'unicode_indexer.json was not a JSON array (got ${raw.runtimeType}). '
        'Expected `[..int_tokens..]` indexed by Unicode codepoint.');
  }

  Future<void> deleteAll() async {
    final dir = await _modelDir;
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}

final supertonicModelManager = SupertonicModelManager();
