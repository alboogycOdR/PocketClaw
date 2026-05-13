/// Manages Supertonic ONNX model + voice style downloads.
///
/// Models live at `{app docs}/supertonic/` — keeps them separate from
/// the GGUF chat models (`{app docs}/models/gguf/`) and the Whisper
/// models (`{app support}/ggml-*.bin`). Voice style JSONs sit alongside
/// the encoder/decoder so the user can browse + delete one bundle.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _hfBase = 'https://huggingface.co/Supertone/supertonic-2/resolve/main';

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
  SupertonicVoice(id: 'F1', displayName: 'Female 1 — Natural', gender: 'female'),
  SupertonicVoice(id: 'F2', displayName: 'Female 2 — Warm', gender: 'female'),
  SupertonicVoice(id: 'F3', displayName: 'Female 3 — Clear', gender: 'female'),
];

class SupertonicModelManager {
  static const _encoderFile = 'supertonic_encoder.onnx';
  static const _decoderFile = 'supertonic_decoder.onnx';

  Future<Directory> get _modelDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/supertonic');
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> get encoderPath async =>
      '${(await _modelDir).path}/$_encoderFile';

  Future<String> get decoderPath async =>
      '${(await _modelDir).path}/$_decoderFile';

  Future<String> voicePath(String voiceId) async =>
      '${(await _modelDir).path}/voice_$voiceId.json';

  Future<bool> areModelsDownloaded() async {
    final encoder = File(await encoderPath);
    final decoder = File(await decoderPath);
    return encoder.existsSync() && decoder.existsSync();
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

  Future<void> downloadModels({
    void Function(String label, double progress)? onProgress,
    VoidCallback? onComplete,
  }) async {
    await _downloadFile(
      url: '$_hfBase/encoder.onnx',
      dest: File(await encoderPath),
      onProgress: (p) => onProgress?.call('Downloading encoder…', p * 0.5),
    );
    await _downloadFile(
      url: '$_hfBase/decoder.onnx',
      dest: File(await decoderPath),
      onProgress: (p) =>
          onProgress?.call('Downloading decoder…', 0.5 + p * 0.5),
    );
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

  /// Loads voice style vectors from the downloaded JSON file.
  Future<Map<String, List<double>>> loadVoiceStyle(String voiceId) async {
    final file = File(await voicePath(voiceId));
    if (!file.existsSync()) {
      throw Exception(
          'Voice $voiceId not downloaded. Call downloadVoice() first.');
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return {
      'style_ttl': (json['style_ttl'] as List).cast<num>().map((n) => n.toDouble()).toList(),
      'style_dp': (json['style_dp'] as List).cast<num>().map((n) => n.toDouble()).toList(),
    };
  }

  Future<void> deleteAll() async {
    final dir = await _modelDir;
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}

final supertonicModelManager = SupertonicModelManager();
