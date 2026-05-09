/// Speech-to-text service wrapping the device's built-in recognition engine.
///
/// Per SPEC-VoiceInput-v1.0 §6 — Option A (on-device STT via speech_to_text).
/// No API key, no network round-trip; uses Android's built-in recognition
/// (the same engine Google Assistant uses).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text service wrapping the device's built-in recognition engine.
///
/// Usage:
///   final stt = ref.read(sttServiceProvider);
///   if (!await stt.initialize()) { /* show error */ }
///   stt.startListening(onPartialResult: ..., onFinalResult: ..., onDone: ...);
///   stt.stopListening();
class SttService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool _initialized = false;
  bool get isListening => _stt.isListening;
  bool get isAvailable => _available;

  /// Requests microphone permission and initialises the STT engine.
  /// Must be called before [startListening]. Safe to call multiple times.
  /// Returns true if STT is available on this device.
  Future<bool> initialize() async {
    if (_initialized) return _available;
    _available = await _stt.initialize(
      onError: (error) {
        // SpeechToText surfaces errors here but they don't need to crash —
        // the onDone callback will fire and the UI resets cleanly.
      },
      onStatus: (status) {
        // 'listening' | 'notListening' | 'done'
      },
    );
    _initialized = true;
    return _available;
  }

  /// Starts listening. [onPartialResult] fires on each word as it's
  /// recognised in real time. [onFinalResult] fires with the complete
  /// transcription when the user stops speaking. [onDone] fires when
  /// the session ends (whether by silence, stop() call, or timeout).
  Future<void> startListening({
    required void Function(String text) onPartialResult,
    required void Function(String text) onFinalResult,
    required void Function() onDone,
    String localeId = 'en_ZA', // South African English as default
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_available) return;

    // Bridge SpeechToText status events to our onDone callback. Set this
    // BEFORE listen() so we don't miss the first 'done' transition.
    _stt.statusListener = (status) {
      if (status == 'done' || status == 'notListening') {
        onDone();
      }
    };

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          onFinalResult(result.recognizedWords);
        } else {
          onPartialResult(result.recognizedWords);
        }
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  /// Stops listening and triggers final result processing.
  Future<void> stopListening() async {
    await _stt.stop();
  }

  /// Cancels listening without triggering a final result.
  Future<void> cancelListening() async {
    await _stt.cancel();
  }

  /// Returns the list of locales (BCP-47 IDs) the engine has installed.
  /// Useful for the Settings dropdown in spec §10.
  Future<List<LocaleName>> locales() async {
    if (!_initialized) await initialize();
    if (!_available) return const [];
    return _stt.locales();
  }

  void dispose() {
    _stt.cancel();
  }
}

/// Singleton STT service — created once per app, shared across widgets.
final sttServiceProvider = Provider<SttService>((_) => SttService());
