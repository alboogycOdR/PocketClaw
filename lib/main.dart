/// Pocket Claw - Mobile AI Agent with OpenClaw Integration
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/local_agent/llm_engine.dart';
import 'data/database/app_database.dart';
import 'data/providers/core_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force dark status bar (mobile only)
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF121222),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  // Initialize database (sqflite not available on web)
  if (!kIsWeb) {
    try {
      await AppDatabase().initialize();
    } catch (e) {
      debugPrint('Database init failed: $e');
    }
  }

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize flutter_gemma platform with optional HuggingFace token
  if (!kIsWeb) {
    try {
      final hfToken = prefs.getString('huggingface_token');
      await LlmEngine.initPlatform(huggingFaceToken: hfToken);
    } catch (e) {
      debugPrint('FlutterGemma init failed: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const PocketClawApp(),
    ),
  );
}
