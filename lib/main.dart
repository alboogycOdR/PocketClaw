/// Pocket Claw - Mobile AI Agent with OpenClaw Integration
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/theme.dart';
import 'core/llm/services/hf_token_service.dart';
import 'core/local_agent/llm_engine.dart';
import 'data/database/app_database.dart';
import 'data/providers/core_providers.dart';

/// Runs the app with comprehensive error handling — any native crash or
/// uncaught Dart error during init should NOT prevent the app from showing
/// a usable UI.
void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Global Flutter framework error handler — prevents red error screen
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter framework error: ${details.exception}');
    };

    // Custom error widget instead of the red error screen (release builds)
    ErrorWidget.builder = (details) => _buildErrorWidget(details);

    // Force dark status bar (mobile only)
    if (!kIsWeb) {
      try {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF121222),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );
      } catch (e) {
        debugPrint('System UI overlay setup failed: $e');
      }
    }

    // Initialize database — non-blocking for app launch
    if (!kIsWeb) {
      try {
        await AppDatabase().initialize();
      } catch (e, st) {
        debugPrint('Database init failed (non-fatal): $e\n$st');
      }
    }

    // Initialize shared preferences — required, but don't crash on failure
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SharedPreferences init failed: $e');
    }

    // Migrate HuggingFace token from SharedPreferences to secure storage
    if (!kIsWeb && prefs != null) {
      try {
        final oldToken = prefs.getString('huggingface_token');
        if (oldToken != null && oldToken.isNotEmpty) {
          final tokenService = HFTokenService();
          final hasSecure = await tokenService.hasToken();
          if (!hasSecure) {
            try {
              await tokenService.saveToken(oldToken);
              debugPrint('Migrated HF token to secure storage');
            } catch (_) {
              // Token format invalid — skip migration
            }
          }
        }
      } catch (e) {
        debugPrint('HF token migration failed (non-fatal): $e');
      }
    }

    // Initialize flutter_gemma platform — WRAPPED so a native crash here
    // doesn't prevent the app from starting. User can still use cloud models.
    if (!kIsWeb) {
      try {
        String? hfToken;
        try {
          hfToken = await HFTokenService().getToken();
        } catch (_) {
          hfToken = prefs?.getString('huggingface_token');
        }
        await LlmEngine.initPlatform(huggingFaceToken: hfToken);
      } catch (e, st) {
        debugPrint('FlutterGemma init failed (non-fatal): $e\n$st');
        // App continues without local LLM. User will see "No model" in UI.
      }
    }

    // Use SharedPreferences override if available; otherwise app will
    // gracefully degrade (settings persistence disabled for this session).
    final overrides = <Override>[
      if (prefs != null) sharedPrefsProvider.overrideWithValue(prefs),
    ];

    runApp(
      ProviderScope(
        overrides: overrides,
        child: const PocketClawApp(),
      ),
    );
  }, (error, stackTrace) {
    // Top-level uncaught error handler — log but keep running
    debugPrint('Uncaught error in runZonedGuarded: $error\n$stackTrace');
  });
}

/// Custom error widget — shown in place of crashed widgets. Dark-themed,
/// non-scary, with a retry hint.
Widget _buildErrorWidget(FlutterErrorDetails details) {
  return Container(
    color: PocketClawTheme.deepCharcoal,
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: PocketClawTheme.lobsterRed,
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please restart the app.',
            style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 13),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Text(
              details.exception.toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    ),
  );
}
