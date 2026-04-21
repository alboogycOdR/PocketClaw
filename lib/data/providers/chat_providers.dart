/// Chat-specific providers — message state, sending, streaming
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
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

  /// Replace the in-memory thread wholesale — used when loading server-side
  /// history to reconcile against the source of truth.
  void replaceAll(List<ChatMessage> messages) {
    state = List<ChatMessage>.unmodifiable(messages);
  }
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

// ── OpenClaw session key (one "conversation") ──
//
// Persisted in SharedPreferences so chat history survives relaunches — the
// gateway keys session state (and chat.history output) by this. Generated
// on first run and whenever the user taps "New chat".
const String _kSessionKeyPref = 'openclaw_session_key';
final sessionKeyProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final existing = prefs.getString(_kSessionKeyPref);
  if (existing != null && existing.isNotEmpty) return existing;
  final fresh = 'pocket-claw-${_uuid.v4()}';
  // ignore: unawaited_futures
  prefs.setString(_kSessionKeyPref, fresh);
  return fresh;
});

/// The runId of the currently-streaming server reply, or null if idle.
/// Used by the Stop button to call chat.abort against the right run.
final currentRunIdProvider = StateProvider<String?>((_) => null);

/// Start a new conversation: fresh sessionKey + empty thread. Persists the
/// new key so relaunches continue in the new session.
final resetChatProvider = Provider<void Function()>((ref) {
  return () {
    final prefs = ref.read(sharedPrefsProvider);
    final fresh = 'pocket-claw-${_uuid.v4()}';
    // ignore: unawaited_futures
    prefs.setString(_kSessionKeyPref, fresh);
    ref.read(sessionKeyProvider.notifier).state = fresh;
    ref.read(messagesProvider.notifier).clear();
    ref.read(currentRunIdProvider.notifier).state = null;
    ref.read(isProcessingProvider.notifier).state = false;
  };
});

/// Load past turns for the current session from the gateway. Safe to call
/// multiple times — the caller is expected to gate on sessionKey changes.
/// Clears the current in-memory thread and replaces it with server truth.
final loadChatHistoryProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final client = ref.read(gatewayClientProvider);
    if (client == null) return;
    final state = ref.read(gatewayStateProvider);
    if (state != GatewayState.connected) return;
    final sessionKey = ref.read(sessionKeyProvider);
    try {
      final result = await client.request(
        'chat.history',
        {'sessionKey': sessionKey, 'limit': 200},
      );
      if (result is! Map) return;
      final raw = result['messages'];
      if (raw is! List) return;
      final parsed = <ChatMessage>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final msg = _parseHistoryTurn(item);
        if (msg != null) parsed.add(msg);
      }
      // Only replace if there IS history — otherwise keep any unsent
      // draft-state the local thread already has.
      if (parsed.isNotEmpty) {
        ref.read(messagesProvider.notifier).replaceAll(parsed);
      }
    } catch (_) {
      // Silent — history is a "nice to have", not a blocker.
    }
  };
});

/// Convert a chat.history `messages[i]` entry to a ChatMessage, or null if
/// we intentionally skip it (tool / system rows, empty entries). See the
/// gateway spec in memory/gateway_protocol_reference.md for the full shape.
ChatMessage? _parseHistoryTurn(Map<String, dynamic> raw) {
  final roleStr = raw['role'] as String?;
  MessageRole role;
  switch (roleStr) {
    case 'user':
      role = MessageRole.user;
      break;
    case 'assistant':
      role = MessageRole.assistant;
      break;
    default:
      // Skip tool / toolResult / system rows in v1 — UI isn't wired for them.
      return null;
  }

  final content = _extractHistoryText(raw['content']);
  if (content.isEmpty) return null;

  // Timestamp: ms-int is the common case; string is legacy/tolerance.
  DateTime ts = DateTime.now();
  final tsRaw = raw['timestamp'];
  if (tsRaw is int) {
    ts = DateTime.fromMillisecondsSinceEpoch(tsRaw);
  } else if (tsRaw is String) {
    ts = DateTime.tryParse(tsRaw) ?? DateTime.now();
  }

  return ChatMessage(
    id: _uuid.v4(),
    role: role,
    content: content,
    source: role == MessageRole.assistant
        ? MessageSource.server
        : MessageSource.device,
    timestamp: ts,
  );
}

String _extractHistoryText(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) return raw;
  if (raw is! List) return '';
  final buf = StringBuffer();
  for (final block in raw) {
    if (block is! Map) continue;
    switch (block['type']) {
      case 'text':
        final t = block['text'];
        if (t is String) buf.write(t);
        break;
      case 'image':
        if (buf.isNotEmpty) buf.write('\n');
        buf.write('_[image]_');
        break;
      case 'tool_use':
        final name = block['name'] as String? ?? 'tool';
        if (buf.isNotEmpty) buf.write('\n');
        buf.write('_[called $name]_');
        break;
      // tool_result, canvas: skip
    }
  }
  return buf.toString();
}

/// Abort the in-flight streaming reply (best-effort).
final abortChatProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final client = ref.read(gatewayClientProvider);
    final runId = ref.read(currentRunIdProvider);
    final sessionKey = ref.read(sessionKeyProvider);
    if (client == null || runId == null) return;
    await client.abortChat(sessionKey: sessionKey, runId: runId);
    ref.read(messagesProvider.notifier).updateLast((m) => m.copyWith(
          isStreaming: false,
          content: m.content.isEmpty ? '[Cancelled]' : '${m.content}\n\n[Cancelled]',
          clearStatusText: true,
        ));
    ref.read(currentRunIdProvider.notifier).state = null;
    ref.read(isProcessingProvider.notifier).state = false;
  };
});

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
          // Server mode handles images natively via chat.send.attachments —
          // no local preprocessing required. _processBridge (if retained)
          // is for a future "use local VLM to describe first" feature.
          await _processServer(ref, cleanText, imagePath: imageUrl);
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

Future<void> _processServer(
  Ref ref,
  String text, {
  String? imagePath,
}) async {
  final client = ref.read(gatewayClientProvider);
  final messages = ref.read(messagesProvider.notifier);
  final sessionKey = ref.read(sessionKeyProvider);
  final gatewayState = ref.read(gatewayStateProvider);

  // Fast-fail: if we already know the WS isn't connected, surface that
  // immediately instead of waiting 10 seconds for chat.send to time out
  // against a dead socket. Pairing-required has its own dedicated banner
  // and we let that flow own the UX, so we don't duplicate the message.
  if (client != null &&
      gatewayState != GatewayState.connected &&
      gatewayState != GatewayState.pairingRequired) {
    final hint = switch (gatewayState) {
      GatewayState.reconnecting =>
        'Still reconnecting to the gateway — hold on a moment and try again.',
      GatewayState.error =>
        'Gateway error — check Tailscale / VPN and the gateway service.',
      _ =>
        'Gateway offline — check that Tailscale is on and the gateway is running.',
    };
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: hint,
      source: MessageSource.local,
      timestamp: DateTime.now(),
    ));
    return;
  }

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

  // Build attachments from an optional image path (chat.send expects
  // base64 per element; 5 MB per attachment max, images only).
  List<Map<String, dynamic>>? attachments;
  if (imagePath != null) {
    try {
      attachments = [await _encodeImageAttachment(imagePath)];
    } catch (e) {
      messages.add(ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: 'Attachment error: $e',
        source: MessageSource.local,
        timestamp: DateTime.now(),
      ));
      return;
    }
  }

  // Add streaming placeholder (we'll attach the runId to it once the server
  // acks the send, so the Stop button knows which run to abort).
  final placeholderId = _uuid.v4();
  messages.add(ChatMessage(
    id: placeholderId,
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.server,
    timestamp: DateTime.now(),
    isStreaming: true,
    statusText: 'Sending…',
  ));

  // Send and await the ack so we know the runId.
  String? runId;
  try {
    runId = await client.sendMessage(
      text,
      sessionKey: sessionKey,
      attachments: attachments,
    );
  } catch (e) {
    messages.updateById(placeholderId, (m) => m.copyWith(
          content: 'Send failed: $e',
          isStreaming: false,
          clearStatusText: true,
        ));
    return;
  }
  ref.read(currentRunIdProvider.notifier).state = runId;
  messages.updateById(placeholderId, (m) => m.copyWith(
        runId: runId,
        statusText: 'Thinking…',
      ));

  final completer = Completer<void>();
  late StreamSubscription<ServerResponse> sub;

  sub = client.responses.listen((response) {
    // Proactive frames (server-initiated runIds) are handled by the
    // always-on ProactiveNotifier at the app root — it owns chat-bubble
    // insertion + notification firing. Skip them here so we don't
    // double-insert or overwrite the user's in-flight placeholder.
    if (response.proactive) return;

    // Only react to our own run.
    if (response.runId != null && response.runId != runId) return;

    if (response.statusText != null) {
      messages.updateById(placeholderId,
          (m) => m.copyWith(statusText: response.statusText));
    }
    if (response.chunk.isNotEmpty) {
      messages.updateById(placeholderId, (m) => m.copyWith(
            content: m.content + response.chunk,
            clearStatusText: true,
          ));
    }
    if (response.done) {
      messages.updateById(placeholderId, (m) => m.copyWith(
            isStreaming: false,
            clearStatusText: true,
          ));
      sub.cancel();
      if (!completer.isCompleted) completer.complete();
    }
  });

  // No hard timeout — a long tool run can legitimately take minutes. The
  // user has a Stop button (abortChatProvider) if they want out.
  try {
    await completer.future;
  } finally {
    sub.cancel();
    ref.read(currentRunIdProvider.notifier).state = null;
  }
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

/// Encode a local image file as a `chat.send` attachment element.
/// Enforces the 5 MB per-attachment cap and rejects non-image MIMEs —
/// matches the server-side guardrails in
/// `parseMessageWithAttachments` (attachment-normalize-fsjzmyqL.js).
Future<Map<String, dynamic>> _encodeImageAttachment(String path) async {
  final file = io.File(path);
  final bytes = await file.readAsBytes();
  const maxBytes = 5 * 1024 * 1024;
  if (bytes.length > maxBytes) {
    final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
    throw "Image is ${mb} MB, over the 5 MB attachment limit.";
  }
  final fileName = p.basename(path);
  final mime = lookupMimeType(path, headerBytes: bytes.take(16).toList()) ??
      "application/octet-stream";
  if (!mime.startsWith("image/")) {
    throw "Only image attachments are supported (got $mime).";
  }
  return {
    "type": "image",
    "mimeType": mime,
    "fileName": fileName,
    "content": base64Encode(bytes),
  };
}
