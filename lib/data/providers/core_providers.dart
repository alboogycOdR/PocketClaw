/// Core Riverpod providers — wires all services together
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/gateway/device_identity.dart';
import 'ssh_providers.dart';
import '../../core/gateway/gateway_client.dart';
import '../../core/gateway/gateway_rest.dart';
import '../../core/gateway/offline_queue.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../core/llm/engines/abstract_llm_engine.dart';
import '../../core/llm/engines/llama_cpp_engine.dart';
import '../../core/llm/engines/llm_engine_factory.dart';
import '../../core/llm/models/local_model_config.dart' as llm;
import '../../core/llm/models/model_download_state.dart';
import '../../core/llm/models/model_version_status.dart';
import '../../core/llm/services/hf_token_service.dart';
import '../../core/llm/services/license_service.dart';
import '../../core/llm/services/model_download_manager.dart';
import '../models/openclaw_device.dart';
import '../models/openclaw_models.dart';
import '../../core/local_agent/llm_engine.dart';
import '../../core/local_agent/local_agent.dart';
import '../../core/local_agent/model_selector.dart';
import '../../core/local_agent/tool_executor.dart';
import '../../core/memory/local_memory.dart';
import '../../core/memory/memory_manager.dart';
import '../../core/memory/memory_router.dart';
import '../../core/memory/memory_service.dart';
import '../../core/memory/memory_sync.dart';
import '../../core/memory/server_memory.dart';
import '../database/app_database.dart';
import '../repositories/project_memory_repository.dart';
import '../../core/router/smart_router.dart';
import '../../core/session/session_manager.dart';
import '../../core/skills/bridge_skill_runner.dart';
import '../../core/skills/skill_registry.dart';
import '../../core/device/calendar_service.dart';
import '../../core/device/camera_service.dart';
import '../../core/device/file_service.dart';
import '../../core/device/notification_service.dart';
import '../../core/device/share_service.dart';
import '../../core/device/tts_service.dart';
import '../../data/models/gateway_event.dart';

// ── Preferences ──

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main with SharedPreferences instance');
});

// ── Settings (reactive) ──

// Gateway URL + token come from SharedPreferences (written by
// GatewayConfig settings screen). Empty string means "not configured" —
// the dashboard renders the configure-me empty state in that case.
final gatewayUrlProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('gateway_url') ?? '';
});

final gatewayTokenProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('gateway_token') ?? '';
});

/// Active project for Memory Router context (spec §5.4). Persisted via [setActiveProjectId].
final activeProjectIdProvider = StateProvider<String?>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('active_project_id');
});

/// When true, Chat runs the GROW coaching loop instead of normal routing (spec Sprint 12).
final growChatModeProvider = StateProvider<bool>((_) => false);

/// Token estimate threshold above which routing prefers SERVER (spec §5.1).
final tokenBudgetThresholdProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getInt('token_budget_threshold') ?? 4000;
});

/// Paperclip REST base URL, e.g. `http://100.x.x.x:3100`.
final paperclipRestUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('paperclip_rest_url') ?? '';
});

/// Paperclip WebSocket URL for real-time events.
final paperclipWsUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('paperclip_ws_url') ?? '';
});

final paperclipTokenProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('paperclip_token') ?? '';
});

final selectedModelIdProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('selected_model') ?? 'gemma-4-2b';
});

// ── Connectivity ──

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return ref.watch(connectivityProvider).onConnectivityChanged;
});

// ── Gateway ──

final gatewayClientProvider = Provider<GatewayClient?>((ref) {
  final url = ref.watch(gatewayUrlProvider);
  final token = ref.watch(gatewayTokenProvider);
  if (url.isEmpty || token.isEmpty) return null;

  final client = GatewayClient(gatewayUrl: url, authToken: token);

  // Kick off the WebSocket connection eagerly. Without this, sendMessage()
  // silently no-ops because _channel is still null and nothing ever leaves
  // the phone. The client handles its own reconnect/backoff loop.
  // ignore: unawaited_futures
  client.connect();

  // Mirror the client's connection state into the gateway state provider so
  // widgets can react (e.g. show the pairing banner when state flips to
  // pairingRequired). Without this the provider stayed on "disconnected"
  // forever.
  void mirrorState() {
    // Using a microtask keeps us out of a setState-during-build trap.
    Future.microtask(() {
      // ignore: invalid_use_of_protected_member
      ref.read(gatewayStateProvider.notifier).state = client.connectionState.value;
    });
  }
  client.connectionState.addListener(mirrorState);
  mirrorState();

  // Replay offline queue when connected
  final queue = ref.read(offlineQueueProvider);
  if (queue.hasPending) {
    client.connectionState.addListener(() async {
      if (client.connectionState.value == GatewayState.connected) {
        final sent = await queue.replay(client);
        if (sent > 0) {
          debugPrint('Replayed $sent queued message(s)');
        }
      }
    });
  }

  ref.onDispose(() => client.dispose());
  return client;
});

final gatewayStateProvider = StateProvider<GatewayState>(
  (_) => GatewayState.disconnected,
);

final gatewayRestClientProvider = Provider<GatewayRestClient?>((ref) {
  final url = ref.watch(gatewayUrlProvider);
  final token = ref.watch(gatewayTokenProvider);
  if (url.isEmpty || token.isEmpty) return null;

  // Convert wss:// to https:// for REST
  final restUrl = url
      .replaceFirst('wss://', 'https://')
      .replaceFirst('ws://', 'http://');

  final client = GatewayRestClient(baseUrl: restUrl, authToken: token);
  ref.onDispose(() => client.dispose());
  return client;
});

// ── OpenClaw devices (paired + pending) ──
// SPEC-OpenClaw-Improvements §4. Drives the Devices settings screen and
// the pending-approval count badge on the Settings tile.

final openClawDevicesProvider =
    FutureProvider<List<OpenClawDevice>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  final sshSvc = await ref.watch(openClawSshServiceProvider.future);

  // SSH is authoritative on the user's gateway version (the WS
  // `devices.*` namespace doesn't exist — requests silently drop).
  // When SSH is configured, prefer it. Fall back to WS only when SSH
  // isn't available.
  List<OpenClawDevice>? devices;

  if (sshSvc != null) {
    // Surface SSH errors — they're the diagnostic path and the user
    // needs to see them when the parser or CLI fails. Catching here
    // would hide the truth and reproduce the original "empty state
    // for both real-empty and CLI-broken" bug.
    devices = await sshSvc.listDevices();
  } else if (client != null) {
    devices = await client.listDevices();
  }

  devices ??= const [];

  final me = await DeviceIdentity.current();
  if (me == null) return devices;
  return [
    for (final d in devices)
      d.copyWith(isCurrentDevice: d.id == me.deviceId),
  ];
});

// ── OpenClaw models status ──
// SPEC-OpenClaw-Improvements §5. Default model, alias, fallbacks,
// per-model health.

final openClawModelsProvider =
    FutureProvider<OpenClawModelsStatus>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return const OpenClawModelsStatus();
  try {
    return await client.getModelsStatus();
  } catch (_) {
    return const OpenClawModelsStatus();
  }
});

// ── Paperclip REST client (standalone service, not OpenClaw) ──
//
// Paperclip is a separate Node+PostgreSQL service the user runs on the same
// VPS at a different port (default 3100). Auth is an agent API key issued
// from the Paperclip dashboard, not the OpenClaw gateway token. See
// docs/PocketClaw-Paperclip-Architecture-v2.0.md for full contract.

/// Expected format: `http://<host>:3100/api` (base URL includes the `/api`
/// prefix). Empty string ⇒ Paperclip not configured.
final paperclipBaseUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('paperclip_base_url') ?? '';
});

/// Paperclip agent API key (long-lived). Distinct from the OpenClaw bearer
/// token, and cannot be derived from it.
final paperclipApiKeyProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('paperclip_api_key') ?? '';
});

final paperclipRestClientProvider = Provider<PaperclipRestClient?>((ref) {
  final baseUrl = ref.watch(paperclipBaseUrlProvider);
  final apiKey = ref.watch(paperclipApiKeyProvider);
  if (baseUrl.isEmpty || apiKey.isEmpty) return null;
  final client = PaperclipRestClient(baseUrl: baseUrl, apiKey: apiKey);
  ref.onDispose(client.dispose);
  return client;
});

// ── Offline Queue ──

final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return OfflineQueue(prefs: prefs);
});

// ── Device Services ──

final calendarServiceProvider = Provider<CalendarService>(
  (_) => CalendarService(),
);

final cameraServiceProvider = Provider<CameraService>((ref) {
  final camera = CameraService();
  final engine = ref.watch(llmEngineProvider);
  camera.setLlmEngine(engine);
  return camera;
});

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);

final ttsServiceProvider = Provider<TtsService>((_) {
  final svc = TtsService();
  return svc;
});

final shareServiceProvider = Provider<ShareService>(
  (_) => ShareService(),
);

final fileServiceProvider = Provider<FileService>(
  (_) => FileService(),
);

// ── Skills ──

final skillRegistryProvider = Provider<SkillRegistry>((ref) {
  return SkillRegistry();
});

final skillsLoadedProvider = FutureProvider<void>((ref) async {
  final registry = ref.watch(skillRegistryProvider);
  await registry.loadAll();
});

// ── Local Memory ──

final localMemoryProvider = Provider<LocalMemory>((ref) {
  final llm = ref.watch(llmEngineProvider);
  return LocalMemory(llmEngine: llm);
});

// ── Server Memory ──

final serverMemoryProvider = Provider<ServerMemory?>((ref) {
  final rest = ref.watch(gatewayRestClientProvider);
  if (rest == null) return null;
  return ServerMemory(client: rest);
});

// ── Memory Manager ──

final memorySyncProvider = Provider<MemorySync?>((ref) {
  final local = ref.watch(localMemoryProvider);
  final server = ref.watch(serverMemoryProvider);
  if (server == null) return null;
  return MemorySync(local: local, server: server);
});

final memoryManagerProvider = Provider<MemoryManager>((ref) {
  final local = ref.watch(localMemoryProvider);
  final server = ref.watch(serverMemoryProvider);
  final sync = ref.watch(memorySyncProvider);
  final connectivity = ref.watch(connectivityProvider);
  return MemoryManager(
    local: local,
    server: server,
    sync: sync,
    connectivity: connectivity,
  );
});

// ── LLM Engine ──

final llmEngineProvider = Provider<LlmEngine>((ref) {
  final engine = LlmEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

final modelSelectorProvider = Provider<ModelSelector>(
  (_) => ModelSelector(),
);

/// Loads the selected model into the LLM engine on startup.
/// Returns true if a model was successfully loaded.
final modelInitProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb) return false;

  final engine = ref.watch(llmEngineProvider);
  final selector = ref.watch(modelSelectorProvider);
  final prefs = ref.watch(sharedPrefsProvider);

  final selectedId = prefs.getString('selected_model');
  if (selectedId == null || selectedId.isEmpty) return false;

  try {
    // Look up the config for the selected model ID
    final config = selector.getConfigById(selectedId) ??
        await selector.selectModel();

    await engine.loadModel(config);
    return true;
  } catch (e) {
    debugPrint('Model init failed: $e');
    return false;
  }
});

// ── Session ──

final sessionManagerProvider = Provider<SessionManager>((ref) {
  // On web, DAOs won't work — use in-memory only
  if (kIsWeb) {
    return SessionManager();
  }
  return SessionManager();
});

// ── Bridge skill runner ──

final bridgeSkillRunnerProvider = Provider<BridgeSkillRunner>((ref) {
  return BridgeSkillRunner(
    camera: ref.watch(cameraServiceProvider),
    calendar: ref.watch(calendarServiceProvider),
    gateway: ref.watch(gatewayClientProvider),
  );
});

// ── Tool Executor ──

final toolExecutorProvider = Provider<ToolExecutor>((ref) {
  return ToolExecutor(
    calendar: ref.watch(calendarServiceProvider),
    notes: ref.watch(localMemoryProvider),
    camera: ref.watch(cameraServiceProvider),
    notifications: ref.watch(notificationServiceProvider),
    tts: ref.watch(ttsServiceProvider),
    share: ref.watch(shareServiceProvider),
    files: ref.watch(fileServiceProvider),
  );
});

// ── Local Agent ──

final localAgentProvider = Provider<LocalAgent>((ref) {
  return LocalAgent(
    llm: ref.watch(llmEngineProvider),
    tools: ref.watch(toolExecutorProvider),
    memory: ref.watch(localMemoryProvider),
    skills: ref.watch(skillRegistryProvider),
    sessionManager: ref.watch(sessionManagerProvider),
  );
});

// ── Project Memory ──

final projectMemoryRepositoryProvider =
    Provider<ProjectMemoryRepository>((ref) {
  return ProjectMemoryRepositoryImpl(db: AppDatabase());
});

final memoryRouterProvider = Provider<MemoryRouter>((ref) {
  return MemoryRouter(
    repository: ref.watch(projectMemoryRepositoryProvider),
  );
});

final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService(
    repository: ref.watch(projectMemoryRepositoryProvider),
    llm: ref.watch(llmEngineProvider),
  );
});

// ── Smart Router ──

final smartRouterProvider = Provider<SmartRouter>((ref) {
  return SmartRouter(
    connectivity: ref.watch(connectivityProvider),
    skills: ref.watch(skillRegistryProvider),
  );
});

// ── Multi-Model LLM Services ──

final hfTokenServiceProvider = Provider<HFTokenService>((_) {
  return HFTokenService();
});

final licenseServiceProvider = Provider<LicenseService>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return LicenseService(prefs: prefs);
});

final modelDownloadManagerProvider = Provider<ModelDownloadManager>((ref) {
  final manager = ModelDownloadManager(
    tokenService: ref.watch(hfTokenServiceProvider),
    licenseService: ref.watch(licenseServiceProvider),
  );
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Full model catalogue: local GGUF / .task entries loaded from
/// `assets/model_allowlist.json` at startup. main() pre-loads and
/// overrides this; the default empty list is the safe fallback when
/// the bundled asset can't be parsed at all.
final modelCatalogueProvider =
    Provider<List<llm.LocalModelConfig>>((_) => const []);

final selectedModelConfigProvider = Provider<llm.LocalModelConfig?>((ref) {
  final selectedId = ref.watch(selectedModelIdProvider);
  final catalogue = ref.watch(modelCatalogueProvider);
  if (catalogue.isEmpty) return null;
  return catalogue.firstWhere(
    (m) => m.id == selectedId,
    orElse: () => catalogue.first,
  );
});

/// Pref key for per-model custom ID override.
String _customModelIdKey(String modelId) => 'custom_model_id_$modelId';

/// Get/set custom model ID override. Used by the Models screen.
String? getCustomModelId(SharedPreferences prefs, String modelId) {
  return prefs.getString(_customModelIdKey(modelId));
}

Future<void> setCustomModelId(
  SharedPreferences prefs,
  String modelId,
  String? customId,
) async {
  if (customId == null || customId.trim().isEmpty) {
    await prefs.remove(_customModelIdKey(modelId));
  } else {
    await prefs.setString(_customModelIdKey(modelId), customId.trim());
  }
}

final abstractLlmEngineProvider = FutureProvider<AbstractLLMEngine>((ref) async {
  final model = ref.watch(selectedModelConfigProvider);
  if (model == null) {
    throw StateError(
      'No local model selected. Pick one in Settings → Models.',
    );
  }
  final token = await ref.watch(hfTokenServiceProvider).getToken();
  final engine = LLMEngineFactory.forModel(model);
  await engine.initialize(huggingFaceToken: token);
  ref.onDispose(() => engine.dispose());
  return engine;
});

final modelDownloadStateProvider =
    StreamProvider.family<ModelDownloadState, String>((ref, modelId) {
  final manager = ref.watch(modelDownloadManagerProvider);
  return manager.watchDownload(modelId);
});

final hasHFTokenProvider = FutureProvider<bool>((ref) async {
  return ref.watch(hfTokenServiceProvider).hasToken();
});

/// Per-model "Update available" / "Current version" / "Not downloaded"
/// status. Drives the badge + Update button on the model card.
///
/// Family key is the model `id` so Riverpod equality is cheap; the lookup
/// resolves the full config from the catalogue inside the provider so
/// re-watches don't depend on object identity of the LocalModelConfig.
final modelVersionStatusProvider =
    FutureProvider.family<ModelVersionStatus, String>((ref, modelId) async {
  final catalogue = ref.watch(modelCatalogueProvider);
  final model = catalogue.firstWhere(
    (m) => m.id == modelId,
    orElse: () => throw StateError('Model $modelId not in catalogue'),
  );
  return LlamaCppEngine.getVersionStatus(model);
});

// apiKeyServiceProvider + hasCloudKeyProvider removed 2026-05-09 along
// with the rest of the cloud chat path.
