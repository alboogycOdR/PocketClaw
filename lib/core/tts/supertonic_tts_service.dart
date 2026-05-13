/// Supertonic-3 ONNX inference + WAV playback.
///
/// Ported from the reference `py/helper.py` (`TextToSpeech._infer`).
/// Four-stage pipeline:
///
///   1. Tokenise: ord(char) → unicode_indexer.json lookup → int64 ids
///      plus a text_mask tensor of shape (B=1, 1, len).
///   2. Duration predictor (`duration_predictor.onnx`):
///        inputs:  text_ids, style_dp, text_mask
///        output:  per-token duration in seconds → scaled by /speed
///   3. Text encoder (`text_encoder.onnx`):
///        inputs:  text_ids, style_ttl, text_mask
///        output:  text_emb (feeds vector estimator each step)
///   4. Sample noisy latent xt of shape (1, ldim*compress, latent_len)
///      where latent_len = ceil(sum(durations) * sampleRate / 3072).
///      Multiply by latent_mask.
///   5. Vector estimator (`vector_estimator.onnx`), N diffusion steps:
///        inputs:  noisy_latent (xt), text_emb, style_ttl, text_mask,
///                 latent_mask, current_step (float32 scalar),
///                 total_step (float32 scalar)
///        output:  next xt
///   6. Vocoder (`vocoder.onnx`):
///        input:   latent (final xt)
///        output:  wav float32 → int16 PCM → minimal WAV → just_audio
///
/// Sample rate is 44.1 kHz (per tts.json `ae.sample_rate`). Constants
/// base_chunk_size=512, chunk_compress_factor=6, ldim=24 also come
/// from that config.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'supertonic_chunker.dart';
import 'supertonic_model_manager.dart';
import 'supertonic_text_preprocessor.dart';

// Constants pulled from Supertonic-3 tts.json.
const int _sampleRate = 44100;
const int _baseChunkSize = 512;
const int _chunkCompressFactor = 6;
const int _ldim = 24;
const int _latentDim = _ldim * _chunkCompressFactor;        // 144
const int _chunkSize = _baseChunkSize * _chunkCompressFactor; // 3072

/// 8 diffusion steps is a good mobile default — Supertonic recommends
/// 4–16 depending on target RTF. Higher = slightly better quality at
/// linear cost.
const int _kDefaultSteps = 8;

/// 1.05 = slightly faster than neutral. Matches Supertonic helper.py.
const double _kDefaultSpeed = 1.05;

class SupertonicTtsService {
  final _preprocessor = SupertonicTextPreprocessor();
  final _chunker = SupertonicChunker();
  final _player = AudioPlayer();
  final _random = math.Random();

  OrtSession? _durationSession;
  OrtSession? _textEncoderSession;
  OrtSession? _vectorEstSession;
  OrtSession? _vocoderSession;
  SupertonicVoiceStyle? _voiceStyle;
  List<int>? _unicodeIndexer;
  String _loadedVoiceId = '';

  bool _speaking = false;
  bool get isSpeaking => _speaking;
  String get loadedVoiceId => _loadedVoiceId;

  bool get isLoaded =>
      _durationSession != null &&
      _textEncoderSession != null &&
      _vectorEstSession != null &&
      _vocoderSession != null &&
      _voiceStyle != null &&
      _unicodeIndexer != null;

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

    await _closeSessions();

    final ort = OnnxRuntime();
    final opts = OrtSessionOptions(intraOpNumThreads: 2);

    _durationSession =
        await ort.createSession(await mgr.durationPath, options: opts);
    _textEncoderSession =
        await ort.createSession(await mgr.textEncoderPath, options: opts);
    _vectorEstSession =
        await ort.createSession(await mgr.vectorEstPath, options: opts);
    _vocoderSession =
        await ort.createSession(await mgr.vocoderPath, options: opts);
    _voiceStyle = await mgr.loadVoiceStyle(voiceId);
    _unicodeIndexer = await mgr.loadUnicodeIndexer();
    _loadedVoiceId = voiceId;
  }

  Future<void> _closeSessions() async {
    await _durationSession?.close();
    await _textEncoderSession?.close();
    await _vectorEstSession?.close();
    await _vocoderSession?.close();
    _durationSession = null;
    _textEncoderSession = null;
    _vectorEstSession = null;
    _vocoderSession = null;
  }

  /// Speak [text] aloud end-to-end (preprocess → chunk → synth → play).
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
      await _play(_concatenate(pcmBuffers));
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
    _closeSessions();
  }

  // ── Inference pipeline ─────────────────────────────────────────────

  Future<Int16List?> _synthesiseChunk(
    String text, {
    required int steps,
    required double speed,
  }) async {
    final dpSess = _durationSession!;
    final teSess = _textEncoderSession!;
    final veSess = _vectorEstSession!;
    final vocSess = _vocoderSession!;
    final style = _voiceStyle!;

    final tokenIds = _tokenise(text);
    if (tokenIds.isEmpty) {
      _lastDiagnostic = const SupertonicDiagnostic(
        tokenCount: 0,
        durationSeconds: 0,
        latentLen: 0,
        wavSampleCount: 0,
        peakAmplitude: 0,
      );
      throw StateError(
          'Tokeniser produced no IDs for "${text.length > 40 ? "${text.substring(0, 40)}…" : text}" '
          '— unicode_indexer mismatch. Indexer length=${_unicodeIndexer!.length}.');
    }

    final textLen = tokenIds.length;
    final textIdsTensor = await OrtValue.fromList(
      Int64List.fromList(tokenIds),
      [1, textLen],
    );
    final textMaskTensor = await OrtValue.fromList(
      Float32List.fromList(List<double>.filled(textLen, 1.0)),
      [1, 1, textLen],
    );
    // The voice JSON's `dims` field is the FULL tensor shape, including
    // the batch dimension. helper.py does `ttl_data.reshape(ttl_dims)`
    // — no extra batch dim is prepended. v2.6.1 prepended [1, ...] here
    // which produced wrong-rank tensors → silent audio (the vocoder ran
    // but its conditioning was nonsense).
    final styleDpTensor = await OrtValue.fromList(style.dp, style.dpDims);
    final styleTtlTensor = await OrtValue.fromList(style.ttl, style.ttlDims);

    // ── 1. Duration predictor ─────────────────────────────────────────
    final dpOut = await dpSess.run({
      'text_ids': textIdsTensor,
      'style_dp': styleDpTensor,
      'text_mask': textMaskTensor,
    });
    final durOnnx = dpOut.values.first;
    final durList = (await durOnnx.asFlattenedList())
        .map((e) => (e as num).toDouble() / speed)
        .toList(growable: false);

    // ── 2. Text encoder ───────────────────────────────────────────────
    final teOut = await teSess.run({
      'text_ids': textIdsTensor,
      'style_ttl': styleTtlTensor,
      'text_mask': textMaskTensor,
    });
    final textEmb = teOut.values.first;

    // ── 3. Sample noisy latent ────────────────────────────────────────
    final totalDurSeconds = durList.fold<double>(0, (a, b) => a + b);
    final wavLenMax = (totalDurSeconds * _sampleRate).ceil();
    final wavLenSamples = wavLenMax; // bsz=1 so max == only
    final latentLen =
        ((wavLenMax + _chunkSize - 1) ~/ _chunkSize).clamp(1, 1 << 30);

    // get_latent_mask(wav_lengths, base_chunk_size, chunk_compress_factor)
    final latentLengths =
        (wavLenSamples + _chunkSize - 1) ~/ _chunkSize;
    final latentMaskFlat = Float32List(latentLen);
    for (var i = 0; i < latentLen; i++) {
      latentMaskFlat[i] = i < latentLengths ? 1.0 : 0.0;
    }
    final latentMaskTensor =
        await OrtValue.fromList(latentMaskFlat, [1, 1, latentLen]);

    // Random Gaussian noise (1, latentDim, latentLen), masked.
    var xtFlat = Float32List(_latentDim * latentLen);
    for (var i = 0; i < xtFlat.length; i++) {
      xtFlat[i] = _gaussian();
    }
    for (var d = 0; d < _latentDim; d++) {
      for (var t = 0; t < latentLen; t++) {
        xtFlat[d * latentLen + t] *= latentMaskFlat[t];
      }
    }
    var xtTensor =
        await OrtValue.fromList(xtFlat, [1, _latentDim, latentLen]);

    // ── 4. Diffusion loop ─────────────────────────────────────────────
    final totalStepTensor =
        await OrtValue.fromList(Float32List.fromList([steps.toDouble()]), [1]);

    for (var step = 0; step < steps; step++) {
      if (!_speaking) return null;
      final currentStepTensor = await OrtValue.fromList(
        Float32List.fromList([step.toDouble()]),
        [1],
      );

      final veOut = await veSess.run({
        'noisy_latent': xtTensor,
        'text_emb': textEmb,
        'style_ttl': styleTtlTensor,
        'text_mask': textMaskTensor,
        'latent_mask': latentMaskTensor,
        'current_step': currentStepTensor,
        'total_step': totalStepTensor,
      });
      // The output name varies — take the first (matches helper.py's
      // `xt, *_ = ...`).
      xtTensor = veOut.values.first;
    }

    // ── 5. Vocoder ────────────────────────────────────────────────────
    final vocOut = await vocSess.run({'latent': xtTensor});
    final wav = vocOut.values.first;
    final rawFloats = (await wav.asFlattenedList())
        .map((e) => (e as num).toDouble())
        .toList(growable: false);

    // Peak amplitude is the cheapest "did synthesis actually produce
    // something" sanity check. Surfaced via lastDiagnostic so the UI
    // can show it after Test Voice.
    var peak = 0.0;
    for (final v in rawFloats) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    _lastDiagnostic = SupertonicDiagnostic(
      tokenCount: textLen,
      durationSeconds: totalDurSeconds,
      latentLen: latentLen,
      wavSampleCount: rawFloats.length,
      peakAmplitude: peak,
    );

    final pcm = Int16List(rawFloats.length);
    for (var i = 0; i < rawFloats.length; i++) {
      pcm[i] = (rawFloats[i].clamp(-1.0, 1.0) * 32767).round();
    }
    return pcm;
  }

  /// Snapshot of the last synthesis pass — useful diagnostic when
  /// the audio is silent or distorted. Populated inside _synthesiseChunk.
  SupertonicDiagnostic? _lastDiagnostic;
  SupertonicDiagnostic? get lastDiagnostic => _lastDiagnostic;

  // ── Tokeniser ──────────────────────────────────────────────────────

  /// Per Supertonic helper.py: codepoint → indexer[codepoint] where the
  /// indexer is a flat array with `-1` for "no mapping". We skip those
  /// rather than emit PAD so unmapped characters don't insert silence
  /// or noise tokens into the synthesis.
  List<int> _tokenise(String text) {
    final idx = _unicodeIndexer!;
    final out = <int>[];
    for (final code in text.runes) {
      if (code < 0 || code >= idx.length) continue;
      final tok = idx[code];
      if (tok >= 0) out.add(tok);
    }
    return out;
  }

  // ── Random Gaussian (Box-Muller) ───────────────────────────────────

  double _gaussian() {
    // Marsaglia polar method — avoids the cos/sin of plain Box-Muller.
    double u, v, s;
    do {
      u = _random.nextDouble() * 2 - 1;
      v = _random.nextDouble() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1 || s == 0);
    return u * math.sqrt(-2 * math.log(s) / s);
  }

  // ── PCM utils ──────────────────────────────────────────────────────

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
    await wavFile.writeAsBytes(_buildWav(pcm, sampleRate: _sampleRate));

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

  Uint8List _buildWav(Int16List pcm, {required int sampleRate}) {
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

/// Last-pass synthesis diagnostic. Surfaced via the TTS settings
/// screen's Test Voice action so we can see what the pipeline
/// produced even when playback is silent.
class SupertonicDiagnostic {
  final int tokenCount;
  final double durationSeconds;
  final int latentLen;
  final int wavSampleCount;
  final double peakAmplitude;

  const SupertonicDiagnostic({
    required this.tokenCount,
    required this.durationSeconds,
    required this.latentLen,
    required this.wavSampleCount,
    required this.peakAmplitude,
  });

  String toLine() =>
      'toks=$tokenCount dur=${durationSeconds.toStringAsFixed(2)}s '
      'lat=$latentLen wav=$wavSampleCount peak=${peakAmplitude.toStringAsFixed(3)}';
}
