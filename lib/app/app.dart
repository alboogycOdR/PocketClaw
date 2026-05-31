/// Pocket Claw root application widget.
/// Absolutely minimal at launch — no providers watched that touch native
/// libraries, database, or network. All heavy work is deferred.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/device/battery_optimization_service.dart';
import '../core/gateway/proactive_notifier.dart';
import '../data/providers/core_providers.dart';
import 'biometric_lock_screen.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_provider.dart';

class PocketClawApp extends ConsumerStatefulWidget {
  const PocketClawApp({super.key});

  @override
  ConsumerState<PocketClawApp> createState() => _PocketClawAppState();
}

class _PocketClawAppState extends ConsumerState<PocketClawApp> {
  bool _unlocked = false;
  bool _batteryPromptShown = false;

  @override
  void initState() {
    super.initState();
    // Show the battery optimisation prompt once on first launch,
    // after the UI has rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskForBattery());
  }

  Future<void> _maybeAskForBattery() async {
    if (_batteryPromptShown) return;
    _batteryPromptShown = true;
    try {
      final asked = await BatteryOptimizationService.hasBeenAsked();
      if (asked) return;
      if (!mounted) return;

      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;

      final proceed = await showDialog<bool>(
        context: ctx,
        builder: (d) => AlertDialog(
          title: const Text('Keep Pocket Claw running'),
          content: const Text(
            'On-device AI inference and agent sessions work best when '
            'Android does not throttle the app.\n\n'
            'Next screen: please tap "Allow" to exempt Pocket Claw from '
            'battery optimisation.\n\n'
            'You can change this later in your phone Settings > Apps > '
            'Pocket Claw > Battery.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Skip for now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (proceed == true) {
        await BatteryOptimizationService.requestExemption();
      }
      await BatteryOptimizationService.markAsked();
    } catch (e) {
      debugPrint('Battery prompt failed: $e');
    }
  }

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

    // Keep the proactive-notification listener alive for the whole app
    // lifetime. It no-ops when the app is foregrounded.
    ref.watch(proactiveNotifierProvider);
    final showLock = biometricEnabled && !_unlocked;

    // Resolve the active theme and swap the palette BEFORE building
    // MaterialApp. Hand-painted widgets that read PocketClawTheme.bronze
    // / .deepCharcoal / etc. directly will see the new colours in the
    // same frame as the new ThemeData.
    final themeId = ref.watch(themeIdProvider);
    PocketClawTheme.setActive(themeId);

    return MaterialApp.router(
      title: 'ClawCommander',
      debugShowCheckedModeBanner: false,
      theme: PocketClawTheme.themeData,
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
