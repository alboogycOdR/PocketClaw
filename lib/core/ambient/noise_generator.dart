/// On-device noise generators for the procedural Focus Sounds scene.
/// Each kind produces a short PCM-16 mono WAV file that loops cleanly
/// (noise is statistically uniform — head and tail are indistinguishable).
///
/// Why generate vs ship audio assets:
///   - Zero licensing surface, no attribution required
///   - 0 bytes added to APK
///   - Plays immediately even if assets are wiped
///
/// The engine calls `wavPathFor(kind)` once per kind; the file is
/// cached in the app temp dir between calls so we don't regenerate on
/// every play.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

const int _sampleRate = 22050;
const Duration _defaultDuration = Duration(seconds: 8);

/// Kinds of procedural noise the engine knows how to synthesise.
const supportedNoiseKinds = <String>{
  'white',
  'pink',
  'brown',
  'low',
  'mid',
  'high',
};

class NoiseGenerator {
  static final _random = math.Random();

  /// Returns a cached file path containing the requested noise WAV.
  /// Generates the file on first call per [kind] and reuses it on
  /// subsequent calls within the same app launch.
  static Future<String> wavPathFor(
    String kind, {
    Duration duration = _defaultDuration,
  }) async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/ambient_noise_$kind.wav');
    if (!file.existsSync()) {
      final samples = _synthesise(kind, duration);
      await file.writeAsBytes(_buildWav(samples, sampleRate: _sampleRate));
    }
    return file.path;
  }

  static Int16List _synthesise(String kind, Duration duration) {
    final n = (duration.inMicroseconds * _sampleRate) ~/ 1000000;
    switch (kind) {
      case 'white':
        return _white(n);
      case 'pink':
        return _pink(n);
      case 'brown':
        return _brown(n);
      case 'low':
        return _bandpass(_white(n), cutoffHz: 200, kind: 'low');
      case 'mid':
        return _bandpass(_white(n), cutoffHz: 1000, kind: 'mid');
      case 'high':
        return _bandpass(_white(n), cutoffHz: 4000, kind: 'high');
      default:
        return _white(n);
    }
  }

  /// Uniform random samples in roughly [-0.5, 0.5] — full-bandwidth.
  static Int16List _white(int n) {
    final out = Int16List(n);
    for (var i = 0; i < n; i++) {
      out[i] = ((_random.nextDouble() - 0.5) * 32767 * 0.5).round();
    }
    return out;
  }

  /// Pink noise via Voss-McCartney algorithm. Spectrum falls 3 dB / octave.
  static Int16List _pink(int n) {
    const numRows = 16;
    final rows = List<double>.filled(numRows, 0.0);
    var runningSum = 0.0;
    final out = Int16List(n);
    var index = 0;
    for (var i = 0; i < n; i++) {
      // Find the lowest-set bit of the counter — that's which row to
      // update.
      var indexMask = index ^ (index + 1);
      var row = 0;
      while (indexMask != 0) {
        indexMask >>= 1;
        if (row < numRows - 1) row++;
      }
      runningSum -= rows[row];
      final next = _random.nextDouble() * 2 - 1;
      rows[row] = next;
      runningSum += next;
      // Add an extra white component so DC drift stays low.
      final whiteJitter = _random.nextDouble() * 2 - 1;
      final v = (runningSum + whiteJitter) / (numRows + 1);
      out[i] = (v.clamp(-1.0, 1.0) * 32767 * 0.6).round();
      index++;
    }
    return out;
  }

  /// Brown (red) noise — integrated white noise. Spectrum falls
  /// 6 dB / octave. Heavy on the low end.
  static Int16List _brown(int n) {
    final out = Int16List(n);
    var prev = 0.0;
    for (var i = 0; i < n; i++) {
      prev += (_random.nextDouble() - 0.5) * 0.1;
      prev = prev.clamp(-1.0, 1.0);
      out[i] = (prev * 32767 * 0.7).round();
    }
    return out;
  }

  /// Cheap single-pole filter for the 'low' / 'mid' / 'high' bands.
  /// Not a true bandpass — fine for ambient noise where we just need
  /// "weighted toward this frequency range".
  static Int16List _bandpass(
    Int16List input, {
    required double cutoffHz,
    required String kind,
  }) {
    final out = Int16List(input.length);
    final alpha = 2 * math.pi * cutoffHz / _sampleRate;
    final coef = 1 / (1 + alpha);
    var prevLow = 0.0;
    for (var i = 0; i < input.length; i++) {
      final sample = input[i] / 32767.0;
      prevLow = (prevLow + alpha * (sample - prevLow)) * coef;
      double v;
      switch (kind) {
        case 'low':
          v = prevLow * 3.5;
          break;
        case 'high':
          v = (sample - prevLow) * 1.5;
          break;
        case 'mid':
        default:
          // Mid = sample - low - high  (band-shaped)
          final high = sample - prevLow;
          v = (sample - high * 0.6 - prevLow * 0.6);
          break;
      }
      out[i] = (v.clamp(-1.0, 1.0) * 32767).round();
    }
    return out;
  }

  // ── WAV file builder (16-bit mono PCM) ─────────────────────────────

  static Uint8List _buildWav(
    Int16List pcm, {
    required int sampleRate,
  }) {
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
    buf.setUint32(o, sampleRate * 2, Endian.little); o += 4;
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
