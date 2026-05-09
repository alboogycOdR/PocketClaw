/// Pocket Claw - Mobile AI Agent with OpenClaw Integration
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/router.dart' as app_router;
import 'app/theme.dart';
import 'core/llm/model_registry.dart';
import 'core/llm/models/local_model_config.dart';
import 'core/llm/services/model_allowlist_service.dart';
import 'data/providers/core_providers.dart';

/// Minimal, bulletproof startup.
/// ONLY essential work happens here:
///  1. Initialise Flutter binding
///  2. Set status bar
///  3. Load SharedPreferences (pure Dart, no native calls)
///  4. runApp()
///
/// Everything else — database, HuggingFace token, flutter_gemma, Paperclip —
/// is deferred to when the user actually needs it. This guarantees first
/// launch reaches a usable UI even on a completely fresh device.
void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Route all Flutter framework errors through our logger instead of
    // the red error screen.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exception}');
    };

    // Custom error widget for any build-time widget exceptions.
    ErrorWidget.builder = _buildErrorWidget;

    // Non-critical: dark status bar cosmetics.
    if (!kIsWeb) {
      try {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: PocketClawTheme.deepCharcoal,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );
      } catch (_) {}
    }

    // SharedPreferences is pure Dart and safe — the only thing we need
    // before runApp.
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SharedPreferences failed, degraded mode: $e');
    }

    // Seed the router's first-run flag before it builds any routes.
    app_router.hasOnboarded = prefs?.getBool('onboarded') ?? false;

    // Pre-load the model catalogue so the synchronous
    // `modelCatalogueProvider` / `selectedModelConfigProvider` callsites
    // see the full local + cloud list immediately. If the bundled JSON
    // can't be parsed (broken asset, malformed cache override), fall back
    // to cloud-only — cloud chat keeps working, local section just
    // appears empty. Background remote refresh updates the cache for
    // the next launch.
    final allowlistService = ModelAllowlistService();
    List<LocalModelConfig> catalogue;
    try {
      final localModels = await allowlistService.loadModels();
      catalogue = [...localModels, ...kCloudModels];
    } catch (e) {
      debugPrint('Catalogue pre-load failed, falling back to cloud-only: $e');
      catalogue = kCloudModels;
    }
    // Fire-and-forget: refresh remote allowlist for next launch.
    // ignore: unawaited_futures
    allowlistService.refreshFromRemote();

    final overrides = <Override>[
      if (prefs != null) sharedPrefsProvider.overrideWithValue(prefs),
      modelCatalogueProvider.overrideWithValue(catalogue),
    ];

    runApp(
      ProviderScope(
        overrides: overrides,
        child: const PocketClawApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Zone-level uncaught error: $error\n$stack');
  });
}

Widget _buildErrorWidget(FlutterErrorDetails details) {
  return Container(
    color: PocketClawTheme.deepCharcoal,
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: PocketClawTheme.lobsterRed),
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
