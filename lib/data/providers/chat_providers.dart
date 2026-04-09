/// Chat-specific providers — message state, sending, streaming
library;

import 'dart:async';


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/router/smart_router.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/gateway_event.dart';
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

    // Route the message
    final target = await router.route(
      text,
      hasImage: imageUrl != null,
    );
    final cleanText = router.stripPrefix(text);

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

  await for (final response in agent.process(text, imageUrl: imageUrl)) {
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
      messages.appendToLast(response.text);
    }
  }
}

Future<void> _processServer(Ref ref, String text) async {
  final client = ref.read(gatewayClientProvider);
  final messages = ref.read(messagesProvider.notifier);

  if (client == null) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content:
          'Server not configured. Go to Settings to connect your OpenClaw gateway, or prefix with /local to use the on-device model.',
      source: MessageSource.local,
      timestamp: DateTime.now(),
    ));
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
  final messages = ref.read(messagesProvider.notifier);

  // Phase 1: Local processing (OCR etc.)
  messages.add(ChatMessage(
    id: _uuid.v4(),
    role: MessageRole.assistant,
    content: 'Processing on device...',
    source: MessageSource.local,
    timestamp: DateTime.now(),
    isStreaming: true,
  ));

  // TODO: Implement bridge flow — local capture → server process → local display
  // For now, fall back to server
  messages.updateLast((m) => m.copyWith(
        content: 'Bridge processing — routing to server for analysis...',
        isStreaming: false,
      ));

  await _processServer(ref, text);
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
