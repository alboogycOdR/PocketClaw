/// Supertonic ONNX inference + WAV playback.
///
/// Pipeline (per spec §7 + Supertonic architecture paper):
///   1. Tokenise text → int64 token IDs
///   2. Encoder ONNX: tokens + style_ttl → z0 latent + noise
///   3. Decoder ONNX, N flow-matching steps: z_t + style_dp → z_prev
///   4. Vocoder pass (final decoder run): latent → waveform float32
///   5. Convert float32 [-1,1] → int16 PCM → minimal WAV → just_audio
///
/// Tensor names below (z0, noise, z_prev, waveform, style_ttl, style_dp)
/// are taken from the Supertonic reference implementations and the
/// architecture paper. The spec author flagged in §15 that these MUST
/// be verified against the actual `encoder.onnx` / `decoder.onnx` with
/// Netron after first download — if the names differ, adjust the keys
/// in the three session.run() calls below. The code will throw a clear
/// "missing output X" error rather than silently produce garbage.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'supertonic_chunker.dart';
import 'supertonic_model_manager.dart';
import 'supertonic_text_preprocessor.dart';

/// 2 = fastest (RTF ~0.015). Higher = marginally better quality.
const _kDefaultSteps = 2;

/// 1.05 = slightly faster than neutral. Range 0.8–1.3 sensible.
const _kDefaultSpeed = 1.05;

class SupertonicTtsService {
  final _preprocessor = SupertonicTextPreprocessor();
  final _chunker = SupertonicChunker();
  final _player = AudioPlayer();

  OrtSession? _encoderSession;
  OrtSession? _decoderSession;
  Map<String, List<double>>? _voiceStyle;
  String _loadedVoiceId = '';

  bool _speaking = false;
  bool get isSpeaking => _speaking;
  String get loadedVoiceId => _loadedVoiceId;

  bool get isLoaded =>
      _encoderSession != null &&
      _decoderSession != null &&
      _voiceStyle != null;

  Future<void> loadModel({String voiceId = 'M1'}) async {
    final mgr = supertonicModelManager;

    if (!await mgr.areModelsDownloaded()) {
      throw StateError(
          'Supertonic models not downloaded. Call SupertonicModelManager.downloadModels() first.');
    }
    if (!await mgr.isVoiceDownloaded(voiceId)) {
      throw StateError(
          'Voice $voiceId not downloaded. Call SupertonicModelManager.downloadVoice() first.');
    }

    await _encoderSession?.close();
    await _decoderSession?.close();

    final ort = OnnxRuntime();
    final opts = OrtSessionOptions(intraOpNumThreads: 2);

    _encoderSession = await ort.createSession(await mgr.encoderPath, options: opts);
    _decoderSession = await ort.createSession(await mgr.decoderPath, options: opts);
    _voiceStyle = await mgr.loadVoiceStyle(voiceId);
    _loadedVoiceId = voiceId;
  }

  /// Speak [text] aloud end-to-end (preprocess → chunk → synth → play).
  /// Throws [StateError] if no model loaded. Returns early when
  /// [stop] is called mid-stream.
  Future<void> speak(
    String text, {
    int steps = _kDefaultSteps,
    double speed = _kDefaultSpeed,
  }) async {
    if (!isLoaded) throw StateError('Call loadModel() first');
    if (text.trim().isEmpty) return;

    _speaking = true;
    try {
      await _player.stop();

      final processed = _preprocessor.process(text);
      final chunks = _chunker.chunk(processed);

      final pcmBuffers = <Int16List>[];
      for (final chunk in chunks) {
        if (!_speaking) break;
        final pcm = await _synthesiseChunk(chunk, steps: steps, speed: speed);
        if (pcm != null) pcmBuffers.add(pcm);
      }

      if (pcmBuffers.isEmpty || !_speaking) return;

      final combined = _concatenate(pcmBuffers);
      await _play(combined);
    } finally {
      _speaking = false;
    }
  }

  Future<void> stop() async {
    _speaking = false;
    await _player.stop();
  }

  void dispose() {
    _speaking = false;
    _player.dispose();
    _encoderSession?.close();
    _decoderSession?.close();
  }

  Future<Int16List?> _synthesiseChunk(
    String text, {
    required int steps,
    required double speed,
  }) async {
    final encoder = _encoderSession!;
    final decoder = _decoderSession!;
    final style = _voiceStyle!;

    final tokenIds = _tokenise(text);
    if (tokenIds.isEmpty) return null;

    // tokens are int64 per Supertonic encoder spec
    final tokenTensor = await OrtValue.fromList(
      Int64List.fromList(tokenIds),
      [1, tokenIds.length],
    );
    final styleTtlTensor = await OrtValue.fromList(
      Float32List.fromList(
          style['style_ttl']!.map((d) => d.toDouble()).toList()),
      [1, style['style_ttl']!.length],
    );

    final encOutputs = await encoder.run({
      'tokens': tokenTensor,
      'style_ttl': styleTtlTensor,
    });
    final z0 = encOutputs['z0'];
    final noise = encOutputs['noise'];
    if (z0 == null || noise == null) {
      throw StateError(
          'Encoder produced unexpected outputs ${encOutputs.keys}. '
          'Expected "z0" and "noise" — inspect encoder.onnx with Netron '
          'and adjust tensor names in supertonic_tts_service.dart.');
    }

    final styleDpTensor = await OrtValue.fromList(
      Float32List.fromList(
          style['style_dp']!.map((d) => d.toDouble()).toList()),
      [1, style['style_dp']!.length],
    );
    final speedTensor = await OrtValue.fromList(
      Float32List.fromList([speed]),
      [1],
    );

    var zCurrent = z0;
    final dt = 1.0 / steps;

    for (var i = 0; i < steps; i++) {
      if (!_speaking) return null;
      final t = dt * (i + 1);
      final tTensor = await OrtValue.fromList(Float32List.fromList([t]), [1]);

      final decOutputs = await decoder.run({
        'z': zCurrent,
        'noise': noise,
        't': tTensor,
        'style_dp': styleDpTensor,
        'speed': speedTensor,
      });
      final zPrev = decOutputs['z_prev'];
      if (zPrev == null) {
        throw StateError(
            'Decoder step output missing "z_prev" — got ${decOutputs.keys}. '
            'Inspect decoder.onnx with Netron and adjust names.');
      }
      zCurrent = zPrev;
    }

    // Final vocoder pass — `decode: true` triggers waveform output.
    final vocoderOutputs = await decoder.run({
      'z': zCurrent,
      'noise': noise,
      't': await OrtValue.fromList(Float32List.fromList([1.0]), [1]),
      'style_dp': styleDpTensor,
      'speed': speedTensor,
      'decode': await OrtValue.fromList([true], [1]),
    });

    final waveformTensor = vocoderOutputs['waveform'];
    if (waveformTensor == null) {
      throw StateError(
          'Vocoder pass missing "waveform" output — got ${vocoderOutputs.keys}.');
    }
    final raw = await waveformTensor.asFlattenedList();
    final rawFloats = raw.map((e) => (e as num).toDouble()).toList();

    final pcm = Int16List(rawFloats.length);
    for (var i = 0; i < rawFloats.length; i++) {
      pcm[i] = (rawFloats[i].clamp(-1.0, 1.0) * 32767).round();
    }
    return pcm;
  }

  // Character-level tokeniser. Vocab matches Supertonic py/helper.py.
  // Characters not in the vocab are skipped.
  // ignore: unused_field
  static const _pad = 0;
  static const _vocab = ' !"#\$%&\'()*+,-./0123456789:;<=>?@'
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`'
      'abcdefghijklmnopqrstuvwxyz{|}~';

  List<int> _tokenise(String text) {
    final result = <int>[];
    for (final code in text.codeUnits) {
      final char = String.fromCharCode(code);
      final idx = _vocab.indexOf(char);
      if (idx >= 0) result.add(idx + 1); // +1 because 0 is PAD
    }
    return result;
  }

  Int16List _concatenate(List<Int16List> buffers) {
    final total = buffers.fold<int>(0, (sum, b) => sum + b.length);
    final out = Int16List(total);
    var offset = 0;
    for (final buf in buffers) {
      out.setRange(offset, offset + buf.length, buf);
      offset += buf.length;
    }
    return out;
  }

  Future<void> _play(Int16List pcm) async {
    final tmpDir = await getTemporaryDirectory();
    final wavFile = File('${tmpDir.path}/supertonic_output.wav');
    await wavFile.writeAsBytes(_buildWav(pcm, sampleRate: 22050));

    try {
      await _player.setFilePath(wavFile.path);
      await _player.play();
      await _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed);
    } catch (e) {
      debugPrint('SupertonicTtsService: playback failed: $e');
      rethrow;
    }
  }

  /// Minimal 16-bit mono PCM-WAV. Supertonic outputs 22050 Hz mono.
  Uint8List _buildWav(Int16List pcm, {int sampleRate = 22050}) {
    final dataBytes = pcm.length * 2;
    final buf = ByteData(44 + dataBytes);
    var o = 0;

    buf.setUint8(o++, 0x52); buf.setUint8(o++, 0x49); // R I
    buf.setUint8(o++, 0x46); buf.setUint8(o++, 0x46); // F F
    buf.setUint32(o, 36 + dataBytes, Endian.little); o += 4;
    buf.setUint8(o++, 0x57); buf.setUint8(o++, 0x41); // W A
    buf.setUint8(o++, 0x56); buf.setUint8(o++, 0x45); // V E

    buf.setUint8(o++, 0x66); buf.setUint8(o++, 0x6D); // f m
    buf.setUint8(o++, 0x74); buf.setUint8(o++, 0x20); // t (space)
    buf.setUint32(o, 16, Endian.little); o += 4;
    buf.setUint16(o, 1, Endian.little); o += 2;          // PCM
    buf.setUint16(o, 1, Endian.little); o += 2;          // mono
    buf.setUint32(o, sampleRate, Endian.little); o += 4;
    buf.setUint32(o, sampleRate * 2, Endian.little); o += 4; // byte rate
    buf.setUint16(o, 2, Endian.little); o += 2;          // block align
    buf.setUint16(o, 16, Endian.little); o += 2;         // bits per sample

    buf.setUint8(o++, 0x64); buf.setUint8(o++, 0x61); // d a
    buf.setUint8(o++, 0x74); buf.setUint8(o++, 0x61); // t a
    buf.setUint32(o, dataBytes, Endian.little); o += 4;
    for (final sample in pcm) {
      buf.setInt16(o, sample, Endian.little); o += 2;
    }
    return buf.buffer.asUint8List();
  }
}

final supertonicTtsService = SupertonicTtsService();
