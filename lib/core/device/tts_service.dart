/// Text-to-speech service — hybrid Supertonic + flutter_tts.
///
/// Uses Supertonic (on-device ONNX) when models are downloaded and the
/// engine is loaded. Falls back to flutter_tts (Android system TTS)
/// otherwise. Call sites (`speak`, `stop`, `dispose`) are unchanged —
/// they work identically regardless of which engine is active.
library;

import 'package:flutter_tts/flutter_tts.dart';

import '../local_agent/tool_executor.dart';
import '../tts/supertonic_tts_service.dart';

class TtsService {
  final FlutterTts _systemTts = FlutterTts();
  bool _systemInitialised = false;

  bool get _useSupertonic => supertonicTtsService.isLoaded;

  Future<ToolResult> speak(String text, {String language = 'en'}) async {
    if (text.trim().isEmpty) return ToolResult.ok('Nothing to speak.');

    try {
      if (_useSupertonic) {
        await supertonicTtsService.speak(text);
        final wordCount = text.split(RegExp(r'\s+')).length;
        return ToolResult.ok(
          'Speaking $wordCount words via Supertonic.',
          data: {'wordCount': wordCount, 'engine': 'supertonic'},
        );
      }
      return await _speakSystem(text, language: language);
    } catch (e) {
      // If Supertonic fails mid-speak, fall back to the system engine
      // for THIS call so the user still hears something. Don't
      // permanently disable Supertonic — the next call retries it.
      if (_useSupertonic) {
        try {
          return await _speakSystem(text, language: language);
        } catch (_) {}
      }
      return ToolResult.error('Text-to-speech failed: $e');
    }
  }

  Future<void> stop() async {
    if (_useSupertonic) {
      await supertonicTtsService.stop();
    } else {
      await _systemTts.stop();
    }
  }

  void dispose() {
    supertonicTtsService.dispose();
    _systemTts.stop();
  }

  Future<ToolResult> _speakSystem(String text, {String language = 'en'}) async {
    if (!_systemInitialised) {
      await _systemTts.setVolume(1.0);
      await _systemTts.setSpeechRate(0.5);
      await _systemTts.setPitch(1.0);
      _systemInitialised = true;
    }
    final langResult = await _systemTts.setLanguage(language);
    if (langResult != 1) {
      await _systemTts.setLanguage(language.split('-').first);
    }
    final result = await _systemTts.speak(text);
    if (result != 1) return ToolResult.error('System TTS refused to speak.');
    final wordCount = text.split(RegExp(r'\s+')).length;
    return ToolResult.ok(
      'Speaking $wordCount words via system TTS.',
      data: {'wordCount': wordCount, 'engine': 'system'},
    );
  }
}
