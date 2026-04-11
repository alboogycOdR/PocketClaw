/// Pocket Claw root application widget
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gateway/paperclip_realtime_service.dart';
import '../data/providers/core_providers.dart';
import 'biometric_lock_screen.dart';
import 'router.dart';
import 'theme.dart';

class PocketClawApp extends ConsumerStatefulWidget {
  const PocketClawApp({super.key});

  @override
  ConsumerState<PocketClawApp> createState() => _PocketClawAppState();
}

class _PocketClawAppState extends ConsumerState<PocketClawApp> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    // Trigger model loading on startup (fire-and-forget)
    ref.watch(modelInitProvider);

    // Keep Paperclip WebSocket alive while the app is running
    ref.watch(paperclipRealtimeProvider);

    final prefs = ref.watch(sharedPrefsProvider);
    final biometricEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
    final showLock = biometricEnabled && !_unlocked;

    return MaterialApp.router(
      title: 'Pocket Claw',
      debugShowCheckedModeBanner: false,
      theme: PocketClawTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        if (showLock) {
          return BiometricLockScreen(
            onUnlocked: () {
              if (mounted) setState(() => _unlocked = true);
            },
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
