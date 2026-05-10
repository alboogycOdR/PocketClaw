# Pocket Claw — Local Model Improvements
## Developer Specification v1.0

**Date:** 2026-05-08  
**Author:** CARMEN PTY LTD  
**Reference:** Google AI Edge Gallery (`mobile-server-main`) — Apache 2.0  
**Status:** Implementation-ready  

---

## 1. Executive Summary

Pocket Claw already has a working local LLM engine (fllama + GGUF), a model registry, and a download manager. The engine is solid. What it lacks is:

1. **Gemma 4** — the newest and most capable Google model — is missing from the registry
2. **The model catalogue is hardcoded** in Dart — adding a new model requires an app release
3. **No RAM gate** — users can download a 5GB model on a 4GB RAM phone
4. **Download notifications** are basic — no foreground service, no system tray progress bar
5. **No model versioning** — no way to detect that a downloaded model has a newer version available
6. **No HuggingFace token prompt** for gated models — the user must know to enter it in settings

All six of these are solved in Google AI Edge Gallery. This spec describes how to borrow each solution and adapt it to Pocket Claw's Flutter/GGUF stack.

---

## 2. Important Capability Boundary

Before anything else, understand this clearly:

**Google AI Edge Gallery uses LiteRT-LM format (`.litertlm`).  
Pocket Claw uses GGUF format (`.gguf`) via fllama (llama.cpp).**

These are different runtimes with different capabilities:

| Feature | LiteRT-LM (Google) | GGUF/fllama (Pocket Claw) |
|---|---|---|
| Text inference | ✅ | ✅ |
| Image input (Gemma 4 vision) | ✅ | ❌ Not supported by fllama |
| Audio input (Gemma 4 audio) | ✅ | ❌ Not supported by fllama |
| Extended thinking | ✅ | ⚠️ Model-dependent |
| Android optimisation | Deep (GPU/NPU/TPU) | CPU + GPU via llama.cpp |
| Model source | HuggingFace `.litertlm` | HuggingFace `.gguf` |

**What this means for Gemma 4:**  
Gemma 4 GGUF files exist on HuggingFace and work with fllama for **text-only** inference. The image and audio capabilities require LiteRT, which Pocket Claw does not currently use. Gemma 4 text chat is achievable today. Gemma 4 vision requires a separate LiteRT integration sprint (see §9).

---

## 3. What to Borrow from Google AI Edge Gallery

### Borrow now (this sprint)

| Concept | Source file | Pocket Claw equivalent |
|---|---|---|
| JSON-driven model allowlist | `model_allowlist.json` + `ModelAllowlist.kt` | Replace hardcoded `kAvailableModels` |
| RAM gate before download | `minDeviceMemoryInGb` check | Add device memory check |
| Version-pinned download URL | `commitHash` → URL path | Add `hfCommitHash` to `LocalModelConfig` |
| Model update detection | `updatableModelFiles` | Add `updatableFrom` list |
| Foreground download service | `DownloadWorker.kt` (WorkManager) | Upgrade existing HttpClient download |
| HuggingFace token auto-prompt | Gated model detection + dialog | Wire to existing HF token setting |
| Model variants (e.g. Q4 vs Q8) | `parentModelName` / `variantLabel` | Add variant grouping to model card |

### Borrow in a future sprint

| Concept | Notes |
|---|---|
| LiteRT-LM runtime | Required for Gemma 4 vision/audio — separate integration |
| Per-SoC model selection | Android-specific hardware variants |
| Benchmark mode | Token/second benchmark UI |

---

## 4. New Gemma 4 GGUF Models

These are the Gemma 4 GGUF files available on HuggingFace today that work with the existing fllama engine. All are **text-only** at this runtime.

| Model ID | HF Repo | File | Size | Min RAM |
|---|---|---|---|---|
| `gemma-4-2b` | `bartowski/gemma-4-2b-it-GGUF` | `gemma-4-2b-it-Q4_K_M.gguf` | ~2.0 GB | 6 GB |
| `gemma-4-4b` | `bartowski/gemma-4-4b-it-GGUF` | `gemma-4-4b-it-Q4_K_M.gguf` | ~3.5 GB | 8 GB |
| `gemma-4-4b-q8` | `bartowski/gemma-4-4b-it-GGUF` | `gemma-4-4b-it-Q8_0.gguf` | ~6.0 GB | 12 GB |

**Chat template:** Gemma 4 uses the `<start_of_turn>` / `<end_of_turn>` format, not ChatML. The `_formatChatML` fallback in `LlamaCppEngine` needs a Gemma-specific template:

```dart
static String _formatGemma({String? systemPrompt, required String user}) {
  final b = StringBuffer();
  if (systemPrompt != null && systemPrompt.isNotEmpty) {
    b.write('<start_of_turn>system\n');
    b.write(systemPrompt);
    b.write('<end_of_turn>\n');
  }
  b.write('<start_of_turn>user\n');
  b.write(user);
  b.write('<end_of_turn>\n');
  b.write('<start_of_turn>model\n');
  return b.toString();
}
```

---

## 5. JSON-Driven Model Allowlist

### 5.1 The File

Replace the hardcoded `kAvailableModels` list in `model_registry.dart` with a JSON file that ships with the app and can be replaced by a remote version.

**Location:** `assets/model_allowlist.json`

```json
{
  "version": "1.0.0",
  "updatedAt": "2026-05-08",
  "models": [
    {
      "id": "gemma-4-2b",
      "displayName": "Gemma 4 2B",
      "description": "Google's newest Gemma — fast, capable text model. 2B parameters, Q4 quantisation.",
      "provider": "google",
      "hfRepo": "bartowski/gemma-4-2b-it-GGUF",
      "hfFilename": "gemma-4-2b-it-Q4_K_M.gguf",
      "hfCommitHash": "main",
      "sizeBytes": 2147483648,
      "minRamBytes": 6442450944,
      "format": "gguf",
      "chatTemplate": "gemma",
      "capabilities": ["text", "reasoning"],
      "requiresLicense": true,
      "licenseUrl": "https://ai.google.dev/gemma/terms",
      "tags": ["recommended", "new"],
      "variants": [
        {
          "id": "gemma-4-4b",
          "variantLabel": "4B Q4 — better quality",
          "hfFilename": "gemma-4-4b-it-Q4_K_M.gguf",
          "sizeBytes": 3758096384,
          "minRamBytes": 8589934592
        },
        {
          "id": "gemma-4-4b-q8",
          "variantLabel": "4B Q8 — highest quality",
          "hfFilename": "gemma-4-4b-it-Q8_0.gguf",
          "sizeBytes": 6442450944,
          "minRamBytes": 12884901888
        }
      ]
    },
    {
      "id": "gemma-3-1b",
      "displayName": "Gemma 3 1B",
      "description": "Tiny and fast — good for quick responses on any phone.",
      "provider": "google",
      "hfRepo": "bartowski/google_gemma-3-1b-it-GGUF",
      "hfFilename": "google_gemma-3-1b-it-Q4_K_M.gguf",
      "hfCommitHash": "main",
      "sizeBytes": 752000000,
      "minRamBytes": 2147483648,
      "format": "gguf",
      "chatTemplate": "gemma",
      "capabilities": ["text"],
      "requiresLicense": true,
      "licenseUrl": "https://ai.google.dev/gemma/terms",
      "tags": []
    },
    {
      "id": "gemma-3-4b",
      "displayName": "Gemma 3 4B",
      "description": "Balanced Gemma 3 — stronger reasoning than 1B.",
      "provider": "google",
      "hfRepo": "bartowski/google_gemma-3-4b-it-GGUF",
      "hfFilename": "google_gemma-3-4b-it-Q4_K_M.gguf",
      "hfCommitHash": "main",
      "sizeBytes": 2684354560,
      "minRamBytes": 6442450944,
      "format": "gguf",
      "chatTemplate": "gemma",
      "capabilities": ["text", "reasoning"],
      "requiresLicense": true,
      "licenseUrl": "https://ai.google.dev/gemma/terms",
      "tags": []
    },
    {
      "id": "llama-3.2-3b",
      "displayName": "Llama 3.2 3B",
      "description": "Strong general-purpose model by Meta.",
      "provider": "meta",
      "hfRepo": "bartowski/Llama-3.2-3B-Instruct-GGUF",
      "hfFilename": "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
      "hfCommitHash": "main",
      "sizeBytes": 1932735283,
      "minRamBytes": 4294967296,
      "format": "gguf",
      "chatTemplate": "chatml",
      "capabilities": ["text", "reasoning"],
      "requiresLicense": true,
      "licenseUrl": "https://www.llama.com/llama3_2/license/",
      "tags": []
    },
    {
      "id": "llama-3.2-1b",
      "displayName": "Llama 3.2 1B",
      "description": "Fast and lightweight Meta model.",
      "provider": "meta",
      "hfRepo": "bartowski/Llama-3.2-1B-Instruct-GGUF",
      "hfFilename": "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
      "hfCommitHash": "main",
      "sizeBytes": 752000000,
      "minRamBytes": 2147483648,
      "format": "gguf",
      "chatTemplate": "chatml",
      "capabilities": ["text"],
      "requiresLicense": true,
      "licenseUrl": "https://www.llama.com/llama3_2/license/",
      "tags": []
    },
    {
      "id": "qwen-2.5-1.5b",
      "displayName": "Qwen 2.5 1.5B",
      "description": "Fast multilingual model by Alibaba.",
      "provider": "alibaba",
      "hfRepo": "bartowski/Qwen2.5-1.5B-Instruct-GGUF",
      "hfFilename": "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf",
      "hfCommitHash": "main",
      "sizeBytes": 987842560,
      "minRamBytes": 3221225472,
      "format": "gguf",
      "chatTemplate": "chatml",
      "capabilities": ["text"],
      "requiresLicense": false,
      "tags": []
    },
    {
      "id": "deepseek-r1-1.5b",
      "displayName": "DeepSeek R1 1.5B",
      "description": "Reasoning-focused model by DeepSeek — strong chain-of-thought.",
      "provider": "deepseek",
      "hfRepo": "bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF",
      "hfFilename": "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf",
      "hfCommitHash": "main",
      "sizeBytes": 987842560,
      "minRamBytes": 3221225472,
      "format": "gguf",
      "chatTemplate": "chatml",
      "capabilities": ["text", "reasoning"],
      "requiresLicense": false,
      "tags": []
    }
  ]
}
```

**Add to `pubspec.yaml`:**
```yaml
flutter:
  assets:
    - assets/model_allowlist.json  # ← add this line
```

---

### 5.2 Updated LocalModelConfig

Add the new fields needed to support the allowlist:

```dart
// lib/core/llm/models/local_model_config.dart

enum ChatTemplate { chatml, gemma, llama3, phi3, mistral }

class LocalModelConfig {
  final String id;
  final String displayName;
  final String description;
  final String provider;
  final String hfRepo;
  final String hfFilename;
  final String hfCommitHash;       // NEW — pins the exact file version
  final int sizeBytes;             // NEW — in bytes (was sizeGB: double)
  final int minRamBytes;           // NEW — in bytes (was ramMB: int)
  final ModelFormat format;
  final ChatTemplate chatTemplate; // NEW — determines prompt formatting
  final List<String> capabilities;
  final bool requiresLicense;
  final String? licenseUrl;
  final List<String> tags;         // NEW — "recommended", "new", etc.
  final List<ModelVariant>? variants; // NEW — Q4/Q8/etc variants

  const LocalModelConfig({ ... });

  /// Constructs the HuggingFace download URL.
  /// Uses commitHash for version-pinned downloads — same file every time.
  String get downloadUrl =>
      'https://huggingface.co/$hfRepo'
      '/resolve/$hfCommitHash'
      '/$hfFilename'
      '?download=true';

  /// File size in GB for display purposes.
  double get sizeGB => sizeBytes / (1024 * 1024 * 1024);

  /// RAM requirement in GB for display purposes.
  double get minRamGB => minRamBytes / (1024 * 1024 * 1024);
}

class ModelVariant {
  final String id;
  final String variantLabel;
  final String hfFilename;
  final int sizeBytes;
  final int minRamBytes;

  const ModelVariant({
    required this.id,
    required this.variantLabel,
    required this.hfFilename,
    required this.sizeBytes,
    required this.minRamBytes,
  });
}
```

---

### 5.3 Allowlist Service

Replaces the hardcoded `kAvailableModels` constant:

```dart
// lib/core/llm/services/model_allowlist_service.dart
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_model_config.dart';

/// Priority order for model catalogue:
/// 1. Remotely downloaded allowlist (overrides bundled, enables OTA updates)
/// 2. Bundled assets/model_allowlist.json (ships with app)
///
/// The remote allowlist is fetched at startup and cached locally.
/// If fetch fails, the bundled version is used silently.
class ModelAllowlistService {
  static const _remoteUrl =
      'https://raw.githubusercontent.com/alboogycOdR/PocketClaw/main/assets/model_allowlist.json';

  static const _cacheFileName = 'model_allowlist_cache.json';

  /// Load the model catalogue. Returns cached/bundled list immediately,
  /// then fetches remote update in the background.
  Future<List<LocalModelConfig>> loadModels() async {
    final cached = await _loadCached();
    if (cached != null) return cached;
    return _loadBundled();
  }

  /// Fetch remote allowlist and update local cache.
  /// Call this at startup — failures are silent.
  Future<void> refreshFromRemote() async {
    try {
      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 10));
      final response = await request.close();
      if (response.statusCode == 200) {
        final raw = await response.transform(utf8.decoder).join();
        // Validate it parses before caching
        _parseAllowlist(raw);
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_cacheFileName');
        await file.writeAsString(raw);
      }
    } catch (_) {
      // Silent failure — bundled version remains active
    }
  }

  Future<List<LocalModelConfig>?> _loadCached() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      return _parseAllowlist(raw);
    } catch (_) {
      return null;
    }
  }

  Future<List<LocalModelConfig>> _loadBundled() async {
    final raw = await rootBundle.loadString('assets/model_allowlist.json');
    return _parseAllowlist(raw);
  }

  List<LocalModelConfig> _parseAllowlist(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final models = data['models'] as List;
    return models
        .cast<Map<String, dynamic>>()
        .map(_modelFromJson)
        .toList();
  }

  LocalModelConfig _modelFromJson(Map<String, dynamic> json) {
    final variantsRaw = json['variants'] as List?;
    return LocalModelConfig(
      id:              json['id'] as String,
      displayName:     json['displayName'] as String,
      description:     json['description'] as String,
      provider:        json['provider'] as String,
      hfRepo:          json['hfRepo'] as String,
      hfFilename:      json['hfFilename'] as String,
      hfCommitHash:    json['hfCommitHash'] as String? ?? 'main',
      sizeBytes:       (json['sizeBytes'] as num).toInt(),
      minRamBytes:     (json['minRamBytes'] as num).toInt(),
      format:          ModelFormat.gguf,
      chatTemplate:    _parseChatTemplate(json['chatTemplate'] as String?),
      capabilities:    (json['capabilities'] as List?)?.cast<String>() ?? [],
      requiresLicense: json['requiresLicense'] as bool? ?? false,
      licenseUrl:      json['licenseUrl'] as String?,
      tags:            (json['tags'] as List?)?.cast<String>() ?? [],
      variants:        variantsRaw?.cast<Map<String, dynamic>>()
          .map((v) => ModelVariant(
                id:           v['id'] as String,
                variantLabel: v['variantLabel'] as String,
                hfFilename:   v['hfFilename'] as String,
                sizeBytes:    (v['sizeBytes'] as num).toInt(),
                minRamBytes:  (v['minRamBytes'] as num).toInt(),
              ))
          .toList(),
    );
  }

  ChatTemplate _parseChatTemplate(String? raw) => switch (raw) {
    'gemma'   => ChatTemplate.gemma,
    'llama3'  => ChatTemplate.llama3,
    'phi3'    => ChatTemplate.phi3,
    'mistral' => ChatTemplate.mistral,
    _         => ChatTemplate.chatml,
  };
}

final modelAllowlistServiceProvider = Provider<ModelAllowlistService>(
  (_) => ModelAllowlistService(),
);

final modelCatalogueProvider = FutureProvider<List<LocalModelConfig>>((ref) async {
  final service = ref.watch(modelAllowlistServiceProvider);
  // Background refresh — don't block on it
  service.refreshFromRemote();
  return service.loadModels();
});
```

---

## 6. RAM Gate

**Verified from `ModelAllowlist.kt` in Google AI Edge Gallery.**

Before showing the Download button, check that the device has enough free RAM. If not, disable the button and show a warning.

```dart
// lib/core/llm/services/device_memory_service.dart
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceMemoryService {
  static const _channel = MethodChannel('com.carmenlabs.pocketclaw/device');

  /// Returns total device RAM in bytes.
  /// Falls back to 4GB if detection fails.
  Future<int> getTotalRamBytes() async {
    try {
      if (Platform.isAndroid) {
        final bytes = await _channel.invokeMethod<int>('getTotalRam');
        return bytes ?? 4294967296; // 4GB fallback
      }
      return 4294967296; // iOS: assume 4GB (cannot query easily)
    } catch (_) {
      return 4294967296;
    }
  }

  /// Returns true if the device has enough RAM to run this model.
  Future<bool> canRunModel(LocalModelConfig model) async {
    final available = await getTotalRamBytes();
    return available >= model.minRamBytes;
  }
}

final deviceMemoryServiceProvider = Provider<DeviceMemoryService>(
  (_) => DeviceMemoryService(),
);

final deviceRamProvider = FutureProvider<int>((ref) async {
  return ref.watch(deviceMemoryServiceProvider).getTotalRamBytes();
});
```

**Android native method** (add to `MainActivity.kt`):

```kotlin
// In MainActivity.kt — add to configureFlutterEngine
MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "com.carmenlabs.pocketclaw/device"
).setMethodCallHandler { call, result ->
    when (call.method) {
        "getTotalRam" -> {
            val activityManager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
            val memInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memInfo)
            result.success(memInfo.totalMem)
        }
        else -> result.notImplemented()
    }
}
```

**In the model card UI:**

```dart
// Model download button logic
Consumer(builder: (context, ref, _) {
  final deviceRam = ref.watch(deviceRamProvider);
  final canRun = deviceRam.when(
    data: (ram) => ram >= model.minRamBytes,
    loading: () => true,  // optimistic while loading
    error: (_, __) => true,
  );

  if (!canRun) {
    return Column(children: [
      ElevatedButton.icon(
        onPressed: null, // disabled
        icon: const Icon(Icons.memory),
        label: const Text('Download'),
      ),
      Text(
        'Requires ${model.minRamGB.toStringAsFixed(0)} GB RAM — '
        'your device may not support this model',
        style: const TextStyle(color: Colors.orange, fontSize: 12),
      ),
    ]);
  }
  // Show normal download button
});
```

---

## 7. Chat Template Routing

The existing `_formatChatML` in `LlamaCppEngine` is Qwen/DeepSeek format. Add a router:

```dart
// In LlamaCppEngine — replace the single _formatChatML call with:

String _formatPrompt({
  required ChatTemplate template,
  String? systemPrompt,
  required String user,
}) => switch (template) {
  ChatTemplate.gemma   => _formatGemma(systemPrompt: systemPrompt, user: user),
  ChatTemplate.llama3  => _formatLlama3(systemPrompt: systemPrompt, user: user),
  ChatTemplate.chatml  => _formatChatML(systemPrompt: systemPrompt, user: user),
  ChatTemplate.phi3    => _formatPhi3(systemPrompt: systemPrompt, user: user),
  ChatTemplate.mistral => _formatMistral(systemPrompt: systemPrompt, user: user),
};

// Gemma — verified template for Gemma 2, 3, 4
static String _formatGemma({String? systemPrompt, required String user}) {
  final b = StringBuffer();
  if (systemPrompt != null && systemPrompt.isNotEmpty) {
    b.write('<start_of_turn>system\n$systemPrompt<end_of_turn>\n');
  }
  b.write('<start_of_turn>user\n$user<end_of_turn>\n');
  b.write('<start_of_turn>model\n');
  return b.toString();
}

// Llama 3 — for Llama 3.1, 3.2, 3.3
static String _formatLlama3({String? systemPrompt, required String user}) {
  final b = StringBuffer();
  b.write('<|begin_of_text|>');
  if (systemPrompt != null && systemPrompt.isNotEmpty) {
    b.write('<|start_header_id|>system<|end_header_id|>\n\n$systemPrompt<|eot_id|>');
  }
  b.write('<|start_header_id|>user<|end_header_id|>\n\n$user<|eot_id|>');
  b.write('<|start_header_id|>assistant<|end_header_id|>\n\n');
  return b.toString();
}

// Phi-3 — for Microsoft Phi-3 / Phi-3.5
static String _formatPhi3({String? systemPrompt, required String user}) {
  final b = StringBuffer();
  if (systemPrompt != null && systemPrompt.isNotEmpty) {
    b.write('<|system|>\n$systemPrompt<|end|>\n');
  }
  b.write('<|user|>\n$user<|end|>\n<|assistant|>\n');
  return b.toString();
}

// Mistral — for Mistral 7B, Mixtral
static String _formatMistral({String? systemPrompt, required String user}) {
  final b = StringBuffer();
  if (systemPrompt != null && systemPrompt.isNotEmpty) {
    b.write('[INST] $systemPrompt\n\n$user [/INST]');
  } else {
    b.write('[INST] $user [/INST]');
  }
  return b.toString();
}
```

Also update the stop tokens per template:

```dart
Map<ChatTemplate, List<String>> _stopTokens = {
  ChatTemplate.gemma:   ['<end_of_turn>', '<eos>'],
  ChatTemplate.llama3:  ['<|eot_id|>', '<|end_of_text|>'],
  ChatTemplate.chatml:  ['<|im_end|>', '<|endoftext|>'],
  ChatTemplate.phi3:    ['<|end|>', '<|endoftext|>'],
  ChatTemplate.mistral: ['</s>'],
};
```

---

## 8. Download Improvements

### 8.1 Version-Pinned Downloads

The existing `downloadModel` uses `/resolve/main/` which always gets the latest file. If the HuggingFace repo updates the file, users re-downloading get a different model.

Update the download URL to use `commitHash`:

```dart
// In LocalModelConfig
String get downloadUrl =>
    'https://huggingface.co/$hfRepo'
    '/resolve/$hfCommitHash'  // pins to exact version
    '/$hfFilename'
    '?download=true';
```

Also store the version in the download path — same as Google AI Edge Gallery:

```
Before: {docs}/models/gguf/{id}.gguf
After:  {docs}/models/gguf/{id}/{hfCommitHash}/{hfFilename}
```

This enables:
- Multiple versions coexisting without conflicts
- Clean upgrade path when a new version is released
- Easy detection of whether the current download matches the allowlist version

```dart
// Updated getModelPath in LlamaCppEngine
Future<String> getModelPath(LocalModelConfig model) async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/models/gguf'
      '/${model.id}'
      '/${model.hfCommitHash}'
      '/${model.hfFilename}';
}

// Check if downloaded version matches allowlist version
Future<bool> isCurrentVersion(LocalModelConfig model) async {
  final path = await getModelPath(model);
  return File(path).existsSync();
}

// Check if any version is downloaded (old or new)
Future<bool> isAnyVersionDownloaded(LocalModelConfig model) async {
  final dir = await getApplicationDocumentsDirectory();
  final modelDir = Directory('${dir.path}/models/gguf/${model.id}');
  if (!modelDir.existsSync()) return false;
  return modelDir.listSync().isNotEmpty;
}
```

### 8.2 Model Update Detection

When the allowlist is refreshed and a model's `hfCommitHash` changes:

```dart
// In model card provider
enum ModelVersionStatus { notDownloaded, currentVersion, updateAvailable }

Future<ModelVersionStatus> getVersionStatus(LocalModelConfig model) async {
  final engine = ref.read(llamaCppEngineProvider);
  final isCurrentVersion = await engine.isCurrentVersion(model);
  if (isCurrentVersion) return ModelVersionStatus.currentVersion;
  final anyDownloaded = await engine.isAnyVersionDownloaded(model);
  if (anyDownloaded) return ModelVersionStatus.updateAvailable;
  return ModelVersionStatus.notDownloaded;
}
```

**UI:** Show an "Update available" badge on the model card when `updateAvailable`, and an Update button alongside the existing delete button.

### 8.3 Download Notification via flutter_local_notifications

The existing download runs silently in the background. When the app is backgrounded on Android, the download continues but there's no system tray indicator. Add a foreground notification:

```dart
// In LlamaCppEngine._downloadAttempt — add notification updates

// On download start:
await _showDownloadNotification(
  id: model.id.hashCode,
  modelName: model.displayName,
  progress: 0,
);

// During download (throttled to 1s):
if (curTs - lastNotificationTs > 1000) {
  await _updateDownloadNotification(
    id: model.id.hashCode,
    modelName: model.displayName,
    progress: (receivedBytes / totalBytes * 100).toInt(),
    bytesPerSec: bytesPerSec,
  );
  lastNotificationTs = curTs;
}

// On complete:
await _completeDownloadNotification(
  id: model.id.hashCode,
  modelName: model.displayName,
);
```

Uses the existing `flutter_local_notifications` package already in `pubspec.yaml`.

---

## 9. Updated Model Config Screen

The existing `ModelConfig` screen needs these changes to support the allowlist:

### 9.1 Load from allowlist instead of hardcoded list

```dart
// Replace: final models = kAvailableModels;
// With:
final catalogueAsync = ref.watch(modelCatalogueProvider);
final models = catalogueAsync.when(
  data: (list) => list,
  loading: () => <LocalModelConfig>[],
  error: (_, __) => <LocalModelConfig>[],
);
```

### 9.2 Model card additions

Each model card should show:
- **"NEW"** badge for models with `tags.contains('new')`
- **"RECOMMENDED"** badge for `tags.contains('recommended')`
- **RAM warning** when device RAM < `model.minRamBytes`
- **Variant selector** when `model.variants != null` — show a dropdown to pick Q4/Q8/etc before downloading
- **Update available** badge when `status == ModelVersionStatus.updateAvailable`
- **Version info** in expanded state: "v{hfCommitHash.take(7)}" + "Updated: {date from allowlist}"

### 9.3 HuggingFace token auto-prompt

The existing `ApiKeyService` stores the HF token. Wire it to auto-prompt when downloading a gated model:

```dart
Future<void> _startDownload(LocalModelConfig model) async {
  // 1. License gate (existing)
  if (model.requiresLicense) {
    final accepted = await _checkLicense(model);
    if (!accepted) return;
  }

  // 2. HuggingFace token gate (NEW)
  if (model.requiresLicense) {
    // Google/Meta/etc models are gated — require HF token
    final apiKeyService = ref.read(apiKeyServiceProvider);
    final hasToken = apiKeyService.getHuggingFaceToken() != null;
    if (!hasToken) {
      final entered = await _showHuggingFaceTokenDialog(context);
      if (entered == null) return; // user cancelled
      await apiKeyService.saveHuggingFaceToken(entered);
    }
  }

  // 3. RAM gate (NEW)
  final canRun = await ref.read(deviceMemoryServiceProvider)
      .canRunModel(model);
  if (!canRun && mounted) {
    final proceed = await _showLowRamWarningDialog(context, model);
    if (proceed != true) return;
  }

  // 4. Start download (existing)
  await _downloadModel(model);
}
```

---

## 10. New File Inventory

```
lib/core/llm/
├── models/
│   ├── local_model_config.dart     ← Update: add ChatTemplate, sizeBytes, variants
│   ├── model_variant.dart          ← New: ModelVariant class
│   └── model_version_status.dart   ← New: enum ModelVersionStatus
├── services/
│   ├── model_allowlist_service.dart ← New: JSON loading, remote refresh
│   └── device_memory_service.dart  ← New: RAM detection + MethodChannel
└── engines/
    └── llama_cpp_engine.dart       ← Update: chat template router, versioned paths, download notifications

assets/
└── model_allowlist.json            ← New: curated model catalogue

android/app/src/main/kotlin/.../MainActivity.kt
                                    ← Update: getTotalRam MethodChannel handler
```

---

## 11. Changes to Existing Files

| File | Change |
|---|---|
| `lib/core/llm/model_registry.dart` | Remove `kAvailableModels` constant — replaced by `modelCatalogueProvider` |
| `lib/core/llm/models/local_model_config.dart` | Add `hfCommitHash`, `sizeBytes`, `minRamBytes`, `chatTemplate`, `tags`, `variants` |
| `lib/core/llm/engines/llama_cpp_engine.dart` | Add chat template router, versioned file paths, download notifications |
| `lib/features/settings/model_config.dart` | Use `modelCatalogueProvider`, add RAM gate, HF token prompt, variant picker, update badge |
| `pubspec.yaml` | Add `assets/model_allowlist.json` to flutter assets |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Add `getTotalRam` MethodChannel |

---

## 12. Implementation Order

### Phase 1 — Model Catalogue (2 days, no native code)

1. Create `assets/model_allowlist.json` with all models from §5.1
2. Update `LocalModelConfig` with new fields
3. Create `ModelAllowlistService`
4. Add `modelCatalogueProvider`
5. Update `model_config.dart` to read from provider instead of `kAvailableModels`
6. Delete `kAvailableModels` from `model_registry.dart`
7. Test: all existing models still appear, Gemma 4 appears as new

### Phase 2 — Chat Templates (1 day)

8. Add `ChatTemplate` enum
9. Implement all five template formatters in `LlamaCppEngine`
10. Update stop tokens per template
11. Test with Gemma 3 (existing download) — should work better than before

### Phase 3 — RAM Gate (1 day)

12. Add `DeviceMemoryService`
13. Add `getTotalRam` MethodChannel in `MainActivity.kt`
14. Wire RAM gate to download button in model card
15. Test: model with `minRamBytes > device RAM` shows warning + disabled button

### Phase 4 — Version Pinning + Updates (1 day)

16. Update `downloadUrl` to use `hfCommitHash`
17. Update `getModelPath` to use versioned directory
18. Add `isCurrentVersion` + `isAnyVersionDownloaded` checks
19. Add `ModelVersionStatus` enum + provider
20. Add "Update available" badge to model card
21. Migrate existing downloads: move from flat `{id}.gguf` to `{id}/main/{filename}`

### Phase 5 — Download Notifications (1 day)

22. Add progress notification on download start
23. Throttle notification updates to 1s
24. Show "Download complete" notification on finish
25. Test on physical Android device (notifications only work on device)

---

## 13. Future Sprint — LiteRT Integration (True Gemma 4 Multimodal)

This is the path to Gemma 4 with image and audio input — the full capability set from Google AI Edge Gallery. It is a separate sprint because it requires:

1. Adding `google_ai_edge_litert` (or `google_mlkit`) Flutter package
2. Building a `LiteRtEngine` implementing `AbstractLLMEngine`
3. Downloading `.litertlm` files instead of `.gguf`
4. Adding image attachment support to the LiteRT chat path
5. Adding audio attachment support

The allowlist already has the architecture for this — add `"format": "litertlm"` entries alongside the `"gguf"` entries, and the `LlamaCppEngine` vs `LiteRtEngine` selection is driven by `model.format`.

**Benefit:** True Gemma 4 multimodal — send a screenshot of a chart and ask "what does this mean?" or record your voice and ask a question — all processed on-device, no internet required.

---

## 14. Developer Notes

**Why not use the `.litertlm` files directly?**  
The LiteRT-LM format is proprietary to Google's Android runtime. It cannot be loaded by fllama (llama.cpp). The GGUF equivalents from Bartowski's HuggingFace repos are the same underlying model weights, just in a format that fllama can load. The trade-off is that text performance is very similar, but vision/audio requires LiteRT.

**Why Bartowski's repos?**  
Bartowski is the most reputable GGUF conversion maintainer on HuggingFace. Their Q4_K_M quantisations are the standard recommendation — good quality-to-size ratio, widely tested. All Gemma/Llama models in the allowlist reference Bartowski repos.

**What does Q4_K_M mean?**  
Q4 = 4-bit quantisation (smaller, slightly less accurate). K_M = "K-quant Medium" — a specific quantisation scheme that preserves quality better than basic Q4. It is the standard recommendation for mobile deployment. Q8_0 = 8-bit (better quality, double the size).

**Gemma license requirement**  
All Gemma models require accepting Google's Gemma Terms of Use on HuggingFace and generating an access token. The app already has HuggingFace token support in `ApiKeyService`. The license gate in `_startDownload` handles this flow — it shows the terms URL, asks the user to accept, then prompts for the token.

---

*CARMEN PTY LTD — Pocket Claw Local Model Improvements Spec v1.0*  
*Reference: Google AI Edge Gallery (Apache 2.0) — mobile-server-main*  
*2026-05-08*
