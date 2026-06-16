/// Requests battery optimisation exemption on Android so the OS
/// doesn't kill long-running agent, audio, radio, or TV sessions.
library;

import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryOptimizationService {
  static const _kAskedPrefsKey = 'battery_optimization_asked';
  static const _packageName = 'com.nuburo.hermescommander';
  static const _channel = MethodChannel('com.nuburo.hermescommander/device');

  /// Returns true when Android has already exempted this app from Doze /
  /// battery optimisation. Returns null if the native check is unavailable.
  static Future<bool?> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
    } catch (e) {
      debugPrint('BatteryOptimizationService: status check failed: $e');
      return null;
    }
  }

  /// Opens the Android system settings page for battery optimisation
  /// exemption, pre-filtered to this app. User must manually approve.
  static Future<void> requestExemption() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$_packageName',
      );
      await intent.launch();
    } catch (e) {
      debugPrint('BatteryOptimizationService: direct request failed: $e');
      // Fallback: open the general battery optimisation settings list
      try {
        const fallback = AndroidIntent(
          action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        );
        await fallback.launch();
      } catch (e2) {
        debugPrint('BatteryOptimizationService: fallback failed: $e2');
      }
    }
  }

  /// Whether we've already shown the prompt once. Prefs-backed.
  static Future<bool> hasBeenAsked() async {
    if (!Platform.isAndroid) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kAskedPrefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markAsked() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAskedPrefsKey, true);
    } catch (_) {}
  }
}
