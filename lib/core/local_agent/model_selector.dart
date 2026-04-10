/// Auto-selects best local model based on device capabilities
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'llm_engine.dart';

class ModelSelector {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<LocalModelConfig> selectModel() async {
    final ram = await _getAvailableRamMb();
    final hasGpu = await _hasGpuDelegate();

    debugPrint('ModelSelector: RAM=${ram}MB, GPU=$hasGpu');

    if (ram >= 6000 && hasGpu) {
      return const LocalModelConfig(
        id: 'gemma-4-e2b',
        displayName: 'Gemma 4 E2B',
        capabilities: {
          ModelCap.text,
          ModelCap.vision,
          ModelCap.audio,
          ModelCap.functionCalling,
          ModelCap.thinking,
        },
        maxTokens: 1024,
        temperature: 0.3,
        ramRequiredMb: 1500,
      );
    } else if (ram >= 4000) {
      return const LocalModelConfig(
        id: 'gemma-3-1b',
        displayName: 'Gemma 3 1B',
        capabilities: {
          ModelCap.text,
          ModelCap.functionCalling,
        },
        maxTokens: 768,
        temperature: 0.3,
        ramRequiredMb: 500,
      );
    } else {
      return const LocalModelConfig(
        id: 'gemma-3-270m',
        displayName: 'Gemma 3 270M',
        capabilities: {ModelCap.text},
        maxTokens: 256,
        temperature: 0.3,
        ramRequiredMb: 200,
      );
    }
  }

  /// Look up a specific model config by ID.
  LocalModelConfig? getConfigById(String id) {
    const configs = <String, LocalModelConfig>{
      'gemma-4-e2b': LocalModelConfig(
        id: 'gemma-4-e2b',
        displayName: 'Gemma 4 E2B',
        capabilities: {
          ModelCap.text,
          ModelCap.vision,
          ModelCap.audio,
          ModelCap.functionCalling,
          ModelCap.thinking,
        },
        maxTokens: 1024,
        ramRequiredMb: 1500,
      ),
      'gemma-3-1b': LocalModelConfig(
        id: 'gemma-3-1b',
        displayName: 'Gemma 3 1B',
        capabilities: {ModelCap.text, ModelCap.functionCalling},
        maxTokens: 768,
        ramRequiredMb: 500,
      ),
      'gemma-3-270m': LocalModelConfig(
        id: 'gemma-3-270m',
        displayName: 'Gemma 3 270M',
        capabilities: {ModelCap.text},
        maxTokens: 256,
        ramRequiredMb: 200,
      ),
    };
    return configs[id];
  }

  Future<int> _getAvailableRamMb() async {
    try {
      if (kIsWeb) return 4000;

      if (Platform.isAndroid) {
        return await _readAndroidRamMb();
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return _estimateIosRamMb(info.utsname.machine);
      }
    } catch (e) {
      debugPrint('ModelSelector: RAM detection failed: $e');
    }
    return 4000;
  }

  Future<int> _readAndroidRamMb() async {
    try {
      final meminfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(meminfo);
      if (match != null) {
        final totalKb = int.parse(match.group(1)!);
        return (totalKb / 1024).round();
      }
    } catch (e) {
      debugPrint('ModelSelector: /proc/meminfo read failed: $e');
    }
    return 4000;
  }

  int _estimateIosRamMb(String machine) {
    if (machine.contains('iPhone16') || machine.contains('iPhone17')) {
      return 8000;
    } else if (machine.contains('iPhone15') || machine.contains('iPhone14')) {
      return 6000;
    } else if (machine.contains('iPhone13') || machine.contains('iPhone12')) {
      return 4000;
    } else if (machine.contains('iPad')) {
      return 6000;
    }
    return 4000;
  }

  Future<bool> _hasGpuDelegate() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final features = info.systemFeatures;
        return features.contains('android.hardware.vulkan.compute') ||
            features.contains('android.hardware.opengles.aep') ||
            info.version.sdkInt >= 29;
      } else if (Platform.isIOS) {
        return true;
      }
    } catch (e) {
      debugPrint('ModelSelector: GPU detection failed: $e');
    }
    return false;
  }
}
