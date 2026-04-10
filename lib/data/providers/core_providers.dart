/// Core Riverpod providers — wires all services together
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/gateway/gateway_client.dart';
import '../../core/gateway/gateway_rest.dart';
import '../../core/gateway/offline_queue.dart';
import '../../core/local_agent/llm_engine.dart';
import '../../core/local_agent/local_agent.dart';
import '../../core/local_agent/model_selector.dart';
import '../../core/local_agent/tool_executor.dart';
import '../../core/memory/local_memory.dart';
import '../../core/memory/memory_manager.dart';
import '../../core/memory/memory_sync.dart';
import '../../core/memory/server_memory.dart';
import '../../core/router/smart_router.dart';
import '../../core/session/session_manager.dart';
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

final gatewayUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('gateway_url') ?? '';
});

final gatewayTokenProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('gateway_token') ?? '';
});

final selectedModelIdProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('selected_model') ?? 'gemma-4-e2b';
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

// ── Smart Router ──

final smartRouterProvider = Provider<SmartRouter>((ref) {
  return SmartRouter(
    connectivity: ref.watch(connectivityProvider),
    skills: ref.watch(skillRegistryProvider),
  );
});
