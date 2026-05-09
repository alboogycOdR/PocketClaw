/// Reports device RAM so the model card can disable Download for models that
/// would OOM the device. Uses a `MethodChannel` to ask Android's
/// `ActivityManager.MemoryInfo` for the authoritative number; falls back to
/// `/proc/meminfo` and finally a 4 GB assumption when neither path works.
///
/// iOS has no equivalent public API and we don't want to ship private-API
/// reflection — for now iOS gets a 4 GB fallback and the gate effectively
/// only fires on Android. That's acceptable: iOS App Store review filters
/// hardware where models would fail anyway.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_model_config.dart';

class DeviceMemoryService {
  static const _channel = MethodChannel('com.carmen.clawcommander/device');
  static const _fallbackBytes = 4 * 1024 * 1024 * 1024; // 4 GB

  /// Cache the lookup so repeated `canRunModel` calls during a build
  /// don't re-cross the platform channel for every model card.
  Future<int>? _cached;

  /// Total device RAM in bytes. Falls back to 4 GB on detection failure.
  Future<int> getTotalRamBytes() {
    return _cached ??= _detectTotalRam();
  }

  Future<int> _detectTotalRam() async {
    try {
      if (Platform.isAndroid) {
        final bytes = await _channel.invokeMethod<int>('getTotalRam');
        if (bytes != null && bytes > 0) return bytes;
      }
    } catch (e) {
      debugPrint('DeviceMemoryService: MethodChannel failed: $e');
    }

    // Pure-Dart fallback for Android (and a no-op on iOS).
    if (Platform.isAndroid) {
      try {
        final meminfo = await File('/proc/meminfo').readAsString();
        final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(meminfo);
        if (match != null) {
          return int.parse(match.group(1)!) * 1024;
        }
      } catch (e) {
        debugPrint('DeviceMemoryService: /proc/meminfo read failed: $e');
      }
    }

    return _fallbackBytes;
  }

  /// True if the device meets the model's `minRamBytes` requirement.
  /// Models with `minRamBytes == 0` (e.g. cloud) always pass.
  Future<bool> canRunModel(LocalModelConfig model) async {
    if (model.minRamBytes == 0) return true;
    final available = await getTotalRamBytes();
    return available >= model.minRamBytes;
  }
}

final deviceMemoryServiceProvider = Provider<DeviceMemoryService>(
  (_) => DeviceMemoryService(),
);

/// Cached total-RAM lookup so model card builds can read it synchronously
/// (after the first frame) via `.whenOrNull(data: …)`.
final deviceRamProvider = FutureProvider<int>((ref) {
  return ref.watch(deviceMemoryServiceProvider).getTotalRamBytes();
});
