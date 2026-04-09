/// Auto-selects best local model based on device capabilities
library;

import 'llm_engine.dart';

class ModelSelector {
  Future<LocalModelConfig> selectModel() async {
    final ram = await _getAvailableRamMb();
    final hasGpu = await _hasGpuDelegate();

    if (ram >= 6000 && hasGpu) {
      return const LocalModelConfig(
        id: 'gemma-4-e2b',
        path: 'gemma-4-e2b-it.task',
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
        id: 'qwen3-06b',
        path: 'qwen3-0.6b.task',
        displayName: 'Qwen3 0.6B',
        capabilities: {
          ModelCap.text,
          ModelCap.functionCalling,
          ModelCap.thinking,
        },
        maxTokens: 768,
        temperature: 0.3,
        ramRequiredMb: 500,
      );
    } else {
      return const LocalModelConfig(
        id: 'smollm-135m',
        path: 'smollm-135m.task',
        displayName: 'SmolLM 135M',
        capabilities: {ModelCap.text},
        maxTokens: 256,
        temperature: 0.3,
        ramRequiredMb: 200,
      );
    }
  }

  Future<int> _getAvailableRamMb() async {
    // TODO: Use platform channels to query actual device RAM
    // Default conservative estimate
    return 4000;
  }

  Future<bool> _hasGpuDelegate() async {
    // TODO: Check for GPU/NPU acceleration support
    return false;
  }
}
