/// Chat-specific providers — message state, sending, streaming
library;

import 'dart:async';


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/gateway/offline_queue.dart';
import '../../core/router/smart_router.dart';
import '../../core/session/session_history.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/gateway_event.dart';
import '../../shared/widgets/execution_path_chip.dart';
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

    // Check for user execution path override
    final override = ref.read(executionPathOverrideProvider);
    RoutingDecision decision;
    if (override != null) {
      final overrideTarget = switch (override) {
        ExecutionPath.local => RouteTarget.local,
        ExecutionPath.server => RouteTarget.server,
        ExecutionPath.bridge => RouteTarget.bridge,
      };
      decision = RoutingDecision(
        target: overrideTarget,
        reason: 'User override: ${override.name}',
      );
    } else {
      decision = await router.routeWithContext(
        text,
        hasImage: imageUrl != null,
      );
    }
    final target = decision.target;
    final cleanText = router.stripPrefix(text);

    // Update execution path indicator
    final executionPath = switch (target) {
      RouteTarget.local => ExecutionPath.local,
      RouteTarget.server => ExecutionPath.server,
      RouteTarget.bridge => ExecutionPath.bridge,
      RouteTarget.device => ExecutionPath.local,
      RouteTarget.missionControl => ExecutionPath.local,
    };
    ref.read(executionPathProvider.notifier).state = executionPath;

    try {
      switch (target) {
        case RouteTarget.local:
          await _processLocal(ref, cleanText, imageUrl: imageUrl);
          break;
        case RouteTarget.server:
          await _processServer(ref, cleanText);
          break;
        case RouteTarget.bridge:
          await _processBridge(ref, cleanText, imageUrl: imageUrl);
          break;
        case RouteTarget.device:
          _processDevice(ref, cleanText);
          break;
        case RouteTarget.missionControl:
          _processMissionControl(ref, cleanText);
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
  final agent = ref.read(localAgentProvider);
  final messages = ref.read(messagesProvider.notifier);

  // Add streaming placeholder
  final msgId = _uuid.v4();
  messages.add(ChatMessage(
    id: msgId,
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.local,
    timestamp: DateTime.now(),
    isStreaming: true,
  ));

  bool receivedAnyToken = false;
  final timeout = Future<void>.delayed(const Duration(seconds: 30));
  bool timedOut = false;

  timeout.then((_) {
    if (!receivedAnyToken) timedOut = true;
  });

  await for (final response in agent.process(text, imageUrl: imageUrl)) {
    if (timedOut) {
      messages.updateLast((m) => m.copyWith(
            content: '${m.content}\n\n[Inference timed out after 30s. '
                'Try a shorter question or test on a real device — '
                'emulators are very slow for on-device AI.]',
            isStreaming: false,
          ));
      break;
    }

    if (response.isDone) {
      messages.updateLast((m) => m.copyWith(isStreaming: false));
      break;
    }

    if (response.functionCall != null) {
      messages.updateLast((m) => m.copyWith(
            functionCall: FunctionCallInfo(
              name: response.functionCall!.name,
              args: response.functionCall!.args,
              isExecuting: true,
            ),
          ));
    } else if (response.text.isNotEmpty) {
      receivedAnyToken = true;
      messages.appendToLast(response.text);
    }
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

/// Lists all saved sessions, most recent first.
final sessionListProvider = FutureProvider<List<SessionInfo>>((ref) async {
  final session = ref.watch(sessionManagerProvider);
  return session.listSessions();
});

/// Invalidation trigger — bump this to refresh the session list.
final sessionListRefreshProvider = StateProvider<int>((_) => 0);

/// Session list that auto-refreshes when the trigger changes.
final sessionListAutoProvider = FutureProvider<List<SessionInfo>>((ref) async {
  ref.watch(sessionListRefreshProvider);
  final history = SessionHistory();
  return history.listSessions();
});
