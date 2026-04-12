/// Chat-specific providers — message state, sending, streaming
library;

import 'dart:async';


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/chat/chat_mode.dart';
import '../../core/gateway/offline_queue.dart';
import '../../core/llm/engines/abstract_llm_engine.dart';
import '../../core/llm/models/model_format.dart';
import '../../core/router/smart_router.dart';
import '../../core/session/session_history.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/gateway_event.dart';
import '../../shared/widgets/execution_path_chip.dart';
import 'chat_mode_providers.dart';
import 'core_providers.dart';

const _uuid = Uuid();

// ── Messages State ──

class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  MessagesNotifier() : super([]);

  void add(ChatMessage message) {
    state = [...state, message];
  }

  void updateLast(ChatMessage Function(ChatMessage) updater) {
    if (state.isEmpty) return;
    final updated = [...state];
    updated[updated.length - 1] = updater(updated.last);
    state = updated;
  }

  void appendToLast(String text) {
    if (state.isEmpty) return;
    final updated = [...state];
    final last = updated.last;
    updated[updated.length - 1] = last.copyWith(
      content: last.content + text,
    );
    state = updated;
  }

  void removeById(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void updateById(String id, ChatMessage Function(ChatMessage) updater) {
    state = [
      for (final m in state)
        if (m.id == id) updater(m) else m,
    ];
  }

  void clear() => state = [];
}

final messagesProvider =
    StateNotifierProvider<MessagesNotifier, List<ChatMessage>>((ref) {
  return MessagesNotifier();
});

// ── Gateway Connection State ──

final connectionStateProvider = StateProvider<GatewayState>((ref) {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return GatewayState.disconnected;
  // Listen to the client's connection state
  return GatewayState.disconnected;
});

// ── Is Processing ──

final isProcessingProvider = StateProvider<bool>((_) => false);

// ── Send Message Action ──

final sendMessageProvider = Provider<Future<void> Function(String, {String? imageUrl})>((ref) {
  return (String text, {String? imageUrl}) async {
    if (text.trim().isEmpty) return;

    final router = ref.read(smartRouterProvider);
    final messages = ref.read(messagesProvider.notifier);
    final processing = ref.read(isProcessingProvider.notifier);

    processing.state = true;

    // Add user message
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: text,
      source: MessageSource.device,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
    );
    messages.add(userMsg);

    // Dispatch by explicit user-chosen chat mode (not Smart Router).
    final mode = ref.read(chatModeProvider);
    final cleanText = router.stripPrefix(text);

    // Update execution path indicator for the chat chip
    final executionPath = switch (mode) {
      ChatMode.local    => ExecutionPath.local,
      ChatMode.cloud    => ExecutionPath.server,
      ChatMode.openclaw => ExecutionPath.server,
    };
    ref.read(executionPathProvider.notifier).state = executionPath;

    try {
      switch (mode) {
        case ChatMode.local:
          await _processLocal(ref, cleanText, imageUrl: imageUrl);
          break;
        case ChatMode.cloud:
          await _processCloud(ref, cleanText);
          break;
        case ChatMode.openclaw:
          if (imageUrl != null) {
            await _processBridge(ref, cleanText, imageUrl: imageUrl);
          } else {
            await _processServer(ref, cleanText);
          }
          break;
      }
    } catch (e) {
      messages.add(ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: 'Something went wrong: $e',
        source: MessageSource.local,
        timestamp: DateTime.now(),
      ));
    } finally {
      processing.state = false;
    }

    // Persist to session
    try {
      final session = ref.read(sessionManagerProvider);
      await session.addMessage(userMsg);
    } catch (_) {
      // Session persistence may fail on web
    }
  };
});

Future<void> _processLocal(Ref ref, String text, {String? imageUrl}) async {
  final messages = ref.read(messagesProvider.notifier);
  final model = ref.read(selectedModelConfigProvider);

  if (model.format == ModelFormat.cloud) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content:
          'Local mode needs a local model. Switch to Cloud mode, or pick '
          'a local model in Settings \u2192 Models.',
      source: MessageSource.local,
      timestamp: DateTime.now(),
    ));
    return;
  }

  // Resolve the engine via abstractLlmEngineProvider — awaiting the
  // future so engine.initialize() has completed before we stream.
  AbstractLLMEngine engine;
  try {
    engine = await ref.read(abstractLlmEngineProvider.future);
  } catch (e) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: 'Failed to initialise local engine: $e',
      source: MessageSource.local,
      timestamp: DateTime.now(),
    ));
    return;
  }

  if (!engine.isReady) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: 'Model \u201c${model.displayName}\u201d is not downloaded yet. '
          'Download it in Settings \u2192 Models.',
      source: MessageSource.local,
      timestamp: DateTime.now(),
    ));
    return;
  }

  // Streaming placeholder
  final msgId = _uuid.v4();
  messages.add(ChatMessage(
    id: msgId,
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.local,
    timestamp: DateTime.now(),
    isStreaming: true,
  ));

  try {
    await for (final token in engine.generateStream(text, maxTokens: 1024)) {
      messages.appendToLast(token);
    }
    messages.updateLast((m) => m.copyWith(isStreaming: false));
  } catch (e) {
    messages.updateLast((m) => m.copyWith(
          content: m.content.isEmpty
              ? 'Local inference error: $e'
              : '${m.content}\n\n[Error: $e]',
          isStreaming: false,
        ));
  }
}

Future<void> _processCloud(Ref ref, String text) async {
  final messages = ref.read(messagesProvider.notifier);
  final model = ref.read(selectedModelConfigProvider);

  if (model.format != ModelFormat.cloud) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content:
          'Cloud mode requires a cloud model (Claude, GPT, or Gemini). '
          'Pick one in Settings \u2192 Models.',
      source: MessageSource.server,
      timestamp: DateTime.now(),
    ));
    return;
  }

  // Resolve the cloud engine — initialises and uses the stored API key.
  // Await the future in case the engine is still initialising (e.g. after
  // the user just saved a key, the provider was invalidated and is
  // rebuilding).
  AbstractLLMEngine engine;
  try {
    engine = await ref.read(abstractLlmEngineProvider.future);
  } catch (e) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: 'Failed to initialise cloud engine: $e',
      source: MessageSource.server,
      timestamp: DateTime.now(),
    ));
    return;
  }

  if (!engine.isReady) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content:
          'Cloud engine not ready. Check your API key for '
          '${model.displayName} in Settings \u2192 Models.',
      source: MessageSource.server,
      timestamp: DateTime.now(),
    ));
    return;
  }

  // Streaming placeholder
  final msgId = _uuid.v4();
  messages.add(ChatMessage(
    id: msgId,
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.server,
    timestamp: DateTime.now(),
    isStreaming: true,
  ));

  try {
    // 8192 is generous for modern cloud APIs and covers reasoning
    // models (Gemini 2.5 Pro, GPT-o1, Claude extended thinking) that
    // consume tokens internally before producing user-visible output.
    await for (final token in engine.generateStream(text, maxTokens: 8192)) {
      messages.appendToLast(token);
    }
    messages.updateLast((m) => m.copyWith(isStreaming: false));
  } catch (e) {
    messages.updateLast((m) => m.copyWith(
          content: m.content.isEmpty
              ? 'Cloud API error: $e'
              : '${m.content}\n\n[Error: $e]',
          isStreaming: false,
        ));
  }
}

Future<void> _processServer(Ref ref, String text) async {
  final client = ref.read(gatewayClientProvider);
  final messages = ref.read(messagesProvider.notifier);

  if (client == null) {
    // Queue the message for later if gateway is configured but offline
    final offlineQueue = ref.read(offlineQueueProvider);
    final gatewayUrl = ref.read(gatewayUrlProvider);

    if (gatewayUrl.isNotEmpty) {
      await offlineQueue.enqueue(QueuedMessage(
        text: text,
        queuedAt: DateTime.now(),
      ));
      messages.add(ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content:
            'Server is offline. Message queued — it will be sent automatically when the connection is restored. '
            '(${offlineQueue.pendingCount} message(s) pending)',
        source: MessageSource.local,
        timestamp: DateTime.now(),
      ));
    } else {
      messages.add(ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content:
            'Server not configured. Go to Settings to connect your OpenClaw gateway, or prefix with /local to use the on-device model.',
        source: MessageSource.local,
        timestamp: DateTime.now(),
      ));
    }
    return;
  }

  // Add streaming placeholder
  messages.add(ChatMessage(
    id: _uuid.v4(),
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.server,
    timestamp: DateTime.now(),
    isStreaming: true,
  ));

  // Send to gateway
  await client.sendMessage(text);

  // Listen for response chunks
  final completer = Completer<void>();
  late StreamSubscription<ServerResponse> sub;

  sub = client.responses.listen((response) {
    messages.appendToLast(response.chunk);
    if (response.done) {
      messages.updateLast((m) => m.copyWith(isStreaming: false));
      sub.cancel();
      if (!completer.isCompleted) completer.complete();
    }
  });

  // Timeout after 60s
  await completer.future.timeout(
    const Duration(seconds: 60),
    onTimeout: () {
      sub.cancel();
      messages.updateLast(
        (m) => m.copyWith(
          content: '${m.content}\n\n[Response timed out]',
          isStreaming: false,
        ),
      );
    },
  );
}

Future<void> _processBridge(Ref ref, String text, {String? imageUrl}) async {
  final agent = ref.read(localAgentProvider);
  final client = ref.read(gatewayClientProvider);
  final messages = ref.read(messagesProvider.notifier);

  // Phase 1: Local preprocessing
  messages.add(ChatMessage(
    id: _uuid.v4(),
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.local,
    timestamp: DateTime.now(),
    isStreaming: true,
  ));

  String localSummary = '';

  if (agent.isModelLoaded) {
    // Run local LLM to summarise / extract key info from the query
    await for (final response in agent.process(
      'Briefly summarise this request for a more powerful server model. '
      'Extract key details, entities, and intent:\n\n$text',
      imageUrl: imageUrl,
    )) {
      if (response.isDone) break;
      if (response.text.isNotEmpty) {
        localSummary += response.text;
        messages.appendToLast(response.text);
      }
    }
  } else {
    localSummary = text;
  }

  // Phase 2: Send enriched context to server
  if (client == null) {
    messages.updateLast((m) => m.copyWith(
          content: '${m.content}\n\n[No server connection — showing local result only]',
          isStreaming: false,
        ));
    return;
  }

  messages.updateLast((m) => m.copyWith(isStreaming: false));

  // Add server response placeholder
  messages.add(ChatMessage(
    id: _uuid.v4(),
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.server,
    timestamp: DateTime.now(),
    isStreaming: true,
  ));

  // Send enriched prompt to server
  final enrichedPrompt = localSummary.isNotEmpty
      ? 'User query: $text\n\nLocal analysis: $localSummary'
      : text;
  await client.sendMessage(enrichedPrompt);

  // Stream server response
  final completer = Completer<void>();
  late StreamSubscription<ServerResponse> sub;

  sub = client.responses.listen((response) {
    messages.appendToLast(response.chunk);
    if (response.done) {
      messages.updateLast((m) => m.copyWith(isStreaming: false));
      sub.cancel();
      if (!completer.isCompleted) completer.complete();
    }
  });

  await completer.future.timeout(
    const Duration(seconds: 60),
    onTimeout: () {
      sub.cancel();
      messages.updateLast(
        (m) => m.copyWith(
          content: '${m.content}\n\n[Response timed out]',
          isStreaming: false,
        ),
      );
    },
  );
}

void _processDevice(Ref ref, String text) {
  final messages = ref.read(messagesProvider.notifier);
  messages.add(ChatMessage(
    id: _uuid.v4(),
    role: MessageRole.assistant,
    content: 'Device action triggered: $text',
    source: MessageSource.device,
    timestamp: DateTime.now(),
  ));
}

void _processMissionControl(Ref ref, String text) {
  final messages = ref.read(messagesProvider.notifier);
  messages.add(ChatMessage(
    id: _uuid.v4(),
    role: MessageRole.assistant,
    content:
        'Check the Control tab for live Mission Control data. Tap "Control" in the bottom nav.',
    source: MessageSource.server,
    timestamp: DateTime.now(),
  ));
}

// ── Session Management ──

/// Provider for the active session key.
final currentSessionKeyProvider = StateProvider<String>((ref) {
  final session = ref.watch(sessionManagerProvider);
  return session.currentSessionKey;
});

/// Lists saved sessions, most recent first. Filters by the current chat
/// mode so that Local / Cloud / OpenClaw sessions never cross-contaminate.
final sessionListProvider = FutureProvider<List<SessionInfo>>((ref) async {
  final session = ref.watch(sessionManagerProvider);
  final mode = ref.watch(chatModeProvider);
  return session.listSessions(mode: mode.name);
});

/// Invalidation trigger — bump this to refresh the session list.
final sessionListRefreshProvider = StateProvider<int>((_) => 0);

/// Session list that auto-refreshes when the trigger changes.
/// Filtered by active chat mode.
final sessionListAutoProvider = FutureProvider<List<SessionInfo>>((ref) async {
  ref.watch(sessionListRefreshProvider);
  final mode = ref.watch(chatModeProvider);
  final history = SessionHistory();
  return history.listSessions(mode: mode.name);
});
