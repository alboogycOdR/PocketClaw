/// Pocket Claw root application widget.
/// Absolutely minimal at launch — no providers watched that touch native
/// libraries, database, or network. All heavy work is deferred.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // Only read the biometric setting — no heavy provider watches here.
    // Model init, Paperclip realtime, and DB init are all lazy now.
    bool biometricEnabled = false;
    try {
      final prefs = ref.watch(sharedPrefsProvider);
      biometricEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
    } catch (e) {
      debugPrint('SharedPreferences unavailable: $e');
    }
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
