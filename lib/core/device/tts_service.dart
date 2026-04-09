/// Wraps flutter_tts for text-to-speech output
library;

import 'package:flutter_tts/flutter_tts.dart';

import '../local_agent/tool_executor.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialised = false;

  Future<void> _ensureInit() async {
    if (_initialised) return;

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);

    _initialised = true;
  }

  /// Speaks [text] aloud using the device TTS engine.
  ///
  /// [language] is a BCP-47 language tag (e.g. "en-US", "af-ZA", "zu-ZA").
  Future<ToolResult> speak(String text, {String language = 'en'}) async {
    try {
      await _ensureInit();

      // Attempt to set the requested language; fall back silently.
      final langResult = await _tts.setLanguage(language);
      if (langResult != 1) {
        // Language not available — try a broader match.
        final base = language.split('-').first;
        await _tts.setLanguage(base);
      }

      final speakResult = await _tts.speak(text);
      if (speakResult != 1) {
        return ToolResult.error('TTS engine refused to speak.');
      }

      final wordCount = text.split(RegExp(r'\s+')).length;
      return ToolResult.ok(
        'Speaking $wordCount words in $language.',
        data: {'wordCount': wordCount, 'language': language},
      );
    } catch (e) {
      return ToolResult.error('Text-to-speech failed: $e');
    }
  }

  /// Stops any ongoing speech.
  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
