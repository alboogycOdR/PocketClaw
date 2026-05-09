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
import '../../core/coaching/grow_session_history.dart';
import '../../core/coaching/grow_state_machine.dart';
import '../../core/coaching/safety_classifier.dart';
import '../../core/gateway/offline_queue.dart';
import '../../core/hermes/acp/acp_models.dart';
import '../../core/hermes/acp/hermes_acp_client.dart';
import '../../core/hermes/hermes_client.dart';
import '../../core/ssh/hermes_ssh_client.dart';
import '../../core/llm/engines/abstract_llm_engine.dart';
import '../../core/llm/models/model_format.dart';
import '../../core/session/session_history.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/gateway_event.dart';
import '../../shared/widgets/execution_path_chip.dart';
import 'academy_providers.dart';
import 'chat_mode_providers.dart';
import 'core_providers.dart';
import 'hermes_providers.dart';
import 'life_architect_providers.dart';
import 'ssh_providers.dart';

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

  /// Look up a message by id, or null if it has been removed/replaced.
  /// Used by the ACP send path to read the in-flight message before
  /// appending more thought-chunk text to it.
  ChatMessage? byId(String id) {
    try {
      return state.firstWhere((m) => m.id == id);
    } on StateError {
      return null;
    }
  }

  /// Append (or replace, if [toolCallId] already exists) a tool call on
  /// the message with [messageId]. Used by the Hermes ACP send path to
  /// surface live tool-call cards inline below the streaming text.
  void addToolCall(String messageId, ChatAcpToolCall call) {
    updateById(messageId, (m) {
      final next = [
        for (final c in m.acpToolCalls)
          if (c.toolCallId != call.toolCallId) c,
        call,
      ];
      return m.copyWith(acpToolCalls: next);
    });
  }

  /// Update an existing tool call's status and/or content in place.
  void updateToolCall(
    String messageId,
    String toolCallId, {
    String? status,
    String? content,
  }) {
    updateById(messageId, (m) {
      final next = [
        for (final c in m.acpToolCalls)
          if (c.toolCallId == toolCallId)
            c.copyWith(status: status, content: content)
          else
            c,
      ];
      return m.copyWith(acpToolCalls: next);
    });
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

// ── ACP permission gate ──
//
// When the agent asks for permission to run a tool, the ACP client
// emits an AcpPermissionRequestEvent. The chat provider can't show a
// dialog itself (no BuildContext), so it parks the event here; the
// chat screen watches this provider, presents a dialog, and routes the
// user's choice back into ACP via [acpPermissionResponderProvider].

final pendingAcpPermissionProvider =
    StateProvider<AcpPermissionRequestEvent?>((_) => null);

/// The active ACP client for the current chat turn — exposed so the chat
/// screen can deliver the user's permission decision. Null when no ACP
/// turn is in flight.
final activeAcpClientProvider = StateProvider<HermesAcpClient?>((_) => null);

/// Resolve a pending permission request with the chosen optionId.
final acpPermissionResponderProvider =
    Provider<void Function(String optionId)>((ref) {
  return (String optionId) {
    final pending = ref.read(pendingAcpPermissionProvider);
    final client = ref.read(activeAcpClientProvider);
    if (pending == null || client == null) return;
    client.respondToPermission(
      requestId: pending.requestId,
      optionId: optionId,
    );
    ref.read(pendingAcpPermissionProvider.notifier).state = null;
  };
});

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

    // ── Safety gate (Life Architect) ─────────────────────────────────
    // Always-on, regardless of Life Architect being switched on.
    // Crisis / high-risk / therapy-drift content is intercepted here
    // and replaced with a safe response — the AI is not called at all.
    // SPEC-LifeArchitect-v1.0 §6 + §14.
    final classifier = ref.read(safetyClassifierProvider);
    final safety = classifier.classifyLocally(text);
    if (safety != SafetyClassification.normal) {
      messages.add(ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: classifier.responseFor(safety),
        source: MessageSource.local,
        timestamp: DateTime.now(),
      ));
      processing.state = false;
      try {
        await ref.read(sessionManagerProvider).addMessage(userMsg);
      } catch (_) {/* persistence is best-effort */}
      return;
    }

    // Dispatch by explicit user-chosen chat mode (not Smart Router).
    final mode = ref.read(chatModeProvider);
    final cleanText = router.stripPrefix(text);

    // Update execution path indicator for the chat chip
    final executionPath = switch (mode) {
      ChatMode.local    => ExecutionPath.local,
      ChatMode.openclaw => ExecutionPath.server,
      ChatMode.hermes   => ExecutionPath.hermes,
    };
    ref.read(executionPathProvider.notifier).state = executionPath;

    try {
      switch (mode) {
        case ChatMode.local:
          await _processLocal(ref, cleanText, imageUrl: imageUrl);
          break;
        case ChatMode.openclaw:
          // Server mode handles images natively via chat.send.attachments —
          // no local preprocessing required. _processBridge (if retained)
          // is for a future "use local VLM to describe first" feature.
          await _processServer(ref, cleanText, imagePath: imageUrl);
          break;
        case ChatMode.hermes:
          await _processHermes(ref, cleanText);
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

    // Persist both the user message and the completed assistant reply
    // to the per-mode session DB. Without persisting the assistant side
    // here, switching chat modes (or any session reload) would replay
    // only the user's half from disk and the AI's response would
    // visually disappear.
    try {
      final session = ref.read(sessionManagerProvider);
      await session.addMessage(userMsg);

      // Find the most recent assistant message that landed during this
      // turn. The streaming pipelines (_processLocal/_processCloud/
      // _processServer/_processHermes) all end with the assistant reply
      // as the tail of messagesProvider, with isStreaming flipped off.
      final all = ref.read(messagesProvider);
      for (var i = all.length - 1; i >= 0; i--) {
        final m = all[i];
        if (m.role == MessageRole.assistant && !m.isStreaming) {
          if (m.content.trim().isNotEmpty) {
            await session.addMessage(m);
          }
          break;
        }
      }
    } catch (_) {
      // Session persistence may fail on web
    }
  };
});

/// Combined Academy / Life Architect / GROW overlay applied to every
/// chat send. Returns null when no overlay is active. Life Architect
/// takes precedence over Academy when both are on; GROW context (if
/// the GROW-in-Chat toggle is on) is appended to the Life Architect
/// system prompt so the model gets the phase nudge alongside the base
/// architect persona.
String? _activeSystemPromptOverlay(Ref ref) {
  final lifePrompt = ref.read(lifeArchitectSystemPromptProvider);
  final growCtx = ref.read(growContextProvider);
  final academyPrompt = ref.read(academySystemPromptProvider);

  if (lifePrompt != null) {
    return growCtx != null ? '$lifePrompt\n\n$growCtx' : lifePrompt;
  }
  return academyPrompt;
}

/// After a turn completes, advance the GROW phase if the user is in
/// "GROW in Chat" mode. Records the user's message against the current
/// phase, and if the session reaches the review state, persists the
/// completed session to disk and surfaces a system message in chat.
/// SPEC-LifeArchitect-v1.0 §7-§8.
Future<void> _maybeAdvanceGrowPhase(Ref ref, String userText) async {
  if (!ref.read(growInChatActiveProvider)) return;
  final notifier = ref.read(growSessionProvider.notifier);
  notifier.respondToPhase(userText);

  final session = ref.read(growSessionProvider);
  if (!session.isComplete) return;

  // Persist the completed session and tell the user.
  try {
    await GrowSessionHistory().save(session);
  } catch (_) {/* fail soft — the user already saw the conversation */}
  ref.read(messagesProvider.notifier).add(ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content:
            '✅ GROW session complete. Your commitments have been saved. '
            'Say "life review" any time for a weekly synthesis.',
        source: MessageSource.local,
        timestamp: DateTime.now(),
      ));
}

Future<void> _processLocal(Ref ref, String text, {String? imageUrl}) async {
  final messages = ref.read(messagesProvider.notifier);
  final model = ref.read(selectedModelConfigProvider);

  if (model == null) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content:
          'No local model configured. Pick one in Settings \u2192 Models '
          'to use Local mode.',
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

  final overlay = _activeSystemPromptOverlay(ref);

  try {
    await for (final token in engine.generateStream(
      text,
      systemPrompt: overlay,
      maxTokens: 1024,
    )) {
      messages.appendToLast(token);
    }
    messages.updateLast((m) => m.copyWith(isStreaming: false));
    await _maybeAdvanceGrowPhase(ref, text);
  } catch (e) {
    messages.updateLast((m) => m.copyWith(
          content: m.content.isEmpty
              ? 'Local inference error: $e'
              : '${m.content}\n\n[Error: $e]',
          isStreaming: false,
        ));
  }
}

// _processCloud and the cloud chat path were removed 2026-05-09.
// PocketClaw routes only to local / OpenClaw / Hermes now.


/// Run a Hermes turn over ACP (SSH-exec'd `hermes acp` JSON-RPC).
///
/// Returns true if the turn ran (whether it ended in success or an
/// error that was surfaced to the user). Returns false only when the
/// ACP client failed to start before any output appeared, so the
/// caller can fall through to REST.
Future<bool> _processHermesAcp(
  Ref ref,
  String text,
  HermesSshClient ssh,
) async {
  final messages = ref.read(messagesProvider.notifier);
  final placeholderId = _uuid.v4();
  messages.add(ChatMessage(
    id: placeholderId,
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.server,
    timestamp: DateTime.now(),
    isStreaming: true,
    statusText: 'Hermes is starting…',
  ));

  final acp = HermesAcpClient(ssh: ssh);
  ref.read(activeAcpClientProvider.notifier).state = acp;

  try {
    await acp.start();
  } catch (e) {
    // Couldn't even start the subprocess. Drop the placeholder and let
    // the REST path try.
    messages.removeById(placeholderId);
    ref.read(activeAcpClientProvider.notifier).state = null;
    await acp.stop();
    return false;
  }

  // Subscribe to event stream. The subscription is cancelled in the
  // finally block once the prompt completes.
  final buffer = StringBuffer();
  final sub = acp.events.listen((event) {
    switch (event) {
      case AcpMessageChunkEvent(:final text):
        buffer.write(text);
        messages.updateById(placeholderId, (m) => m.copyWith(
              content: buffer.toString(),
              clearStatusText: true,
            ));
      case AcpThoughtChunkEvent(:final text):
        // Accumulate the agent's reasoning into thinkingText so the
        // ThinkingIndicator can show the full transcript on demand;
        // statusText becomes a brief "thinking…" indicator only.
        final current = messages.byId(placeholderId)?.thinkingText ?? '';
        messages.updateById(placeholderId, (m) => m.copyWith(
              thinkingText: current + text,
              statusText: '\u{1F4A1} Thinking…',
            ));
      case AcpToolCallStartEvent():
        messages.addToolCall(
          placeholderId,
          ChatAcpToolCall(
            toolCallId: event.toolCallId,
            title: event.title,
            kind: event.kind,
            status: event.status,
            rawInput: event.rawInput,
          ),
        );
      case AcpToolCallUpdateEvent():
        messages.updateToolCall(
          placeholderId,
          event.toolCallId,
          status: event.status,
          content: event.content,
        );
      case AcpPermissionRequestEvent():
        // Park the request so the chat screen can show a dialog.
        ref.read(pendingAcpPermissionProvider.notifier).state = event;
      case AcpPromptCompleteEvent():
        // Final completion is handled by sendPrompt's await; we don't
        // need to do anything here. (Notifications can also arrive
        // out-of-band so the case is kept exhaustive.)
        break;
      case AcpDisconnectedEvent():
        // Stream surfaces in the prompt's error path below; nothing
        // extra to update from here.
        break;
      case AcpUnknownEvent():
        break;
    }
  });

  String? sessionId;
  try {
    sessionId = await acp.newSession();
    final result = await acp.sendPrompt(sessionId: sessionId, text: text);
    final usageNote = result.totalTokens > 0
        ? '${result.inputTokens}→${result.outputTokens} tok'
        : null;
    messages.updateById(placeholderId, (m) => m.copyWith(
          isStreaming: false,
          clearStatusText: true,
          // If the agent ended without ever streaming content (rare),
          // surface the stop reason so the bubble isn't empty.
          content: buffer.isEmpty
              ? '_(no response — stopReason: ${result.stopReason}'
                  '${usageNote != null ? ', $usageNote' : ''})_'
              : m.content,
        ));
  } on AcpException catch (e) {
    messages.updateById(placeholderId, (m) => m.copyWith(
          content: buffer.isEmpty
              ? 'Hermes ACP error: $e'
              : '$buffer\n\n[ACP error: $e]',
          isStreaming: false,
          clearStatusText: true,
        ));
  } on TimeoutException catch (e) {
    messages.updateById(placeholderId, (m) => m.copyWith(
          content: buffer.isEmpty
              ? 'Hermes ACP timed out: $e'
              : '$buffer\n\n[Timed out: $e]',
          isStreaming: false,
          clearStatusText: true,
        ));
  } catch (e) {
    messages.updateById(placeholderId, (m) => m.copyWith(
          content: buffer.isEmpty
              ? 'Hermes ACP failed: $e'
              : '$buffer\n\n[Error: $e]',
          isStreaming: false,
          clearStatusText: true,
        ));
  } finally {
    await sub.cancel();
    ref.read(activeAcpClientProvider.notifier).state = null;
    ref.read(pendingAcpPermissionProvider.notifier).state = null;
    await acp.stop();
  }

  return true;
}

Future<void> _processHermes(Ref ref, String text) async {
  final messages = ref.read(messagesProvider.notifier);

  // Prefer ACP over SSH when SSH is configured — it streams tool calls
  // and thoughts in real time, which the REST path can't do. Fall back to
  // REST when SSH isn't configured or the client errors out before the
  // first response.
  final ssh = await ref.read(sshClientProvider.future);
  if (ssh != null) {
    final used = await _processHermesAcp(ref, text, ssh);
    if (used) return;
    // ACP failed before any output — fall through to REST so the user
    // still gets a reply.
  }

  final client = ref.read(hermesClientProvider);

  if (client == null) {
    messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content:
          'Hermes is not configured. Open Settings → Hermes Agent and set '
          'the base URL + API key, then try again.',
      source: MessageSource.local,
      timestamp: DateTime.now(),
    ));
    return;
  }

  // Build history from non-streaming, non-system turns. Hermes wants the
  // OpenAI-compatible {role, content} shape.
  final history = ref
      .read(messagesProvider)
      .where((m) => m.role != MessageRole.system && !m.isStreaming)
      // Drop the just-added user message; we re-add it as the prompt below.
      .where((m) => m.content.trim().isNotEmpty)
      .map((m) => {
            'role': switch (m.role) {
              MessageRole.user => 'user',
              MessageRole.assistant => 'assistant',
              MessageRole.system => 'system',
            },
            'content': m.content,
          })
      .toList();
  // Drop the last user turn (current prompt) — chatStream re-appends it.
  if (history.isNotEmpty && history.last['role'] == 'user') {
    history.removeLast();
  }

  // Prepend Academy / Life Architect overlay as a system message if
  // either is active. Hermes is OpenAI-compatible, so a leading
  // {role: 'system', content: ...} entry steers the model exactly the
  // way the spec intends.
  final overlay = _activeSystemPromptOverlay(ref);
  if (overlay != null && overlay.trim().isNotEmpty) {
    history.insert(0, {'role': 'system', 'content': overlay});
  }

  final placeholderId = _uuid.v4();
  messages.add(ChatMessage(
    id: placeholderId,
    role: MessageRole.assistant,
    content: '',
    source: MessageSource.server,
    timestamp: DateTime.now(),
    isStreaming: true,
    statusText: 'Hermes is thinking…',
  ));

  final buffer = StringBuffer();
  try {
    await for (final token in client.chatStream(text, history: history)) {
      buffer.write(token);
      messages.updateById(placeholderId, (m) => m.copyWith(
            content: buffer.toString(),
            clearStatusText: true,
          ));
    }
    messages.updateById(placeholderId, (m) => m.copyWith(
          isStreaming: false,
          clearStatusText: true,
        ));
    await _maybeAdvanceGrowPhase(ref, text);
  } on HermesApiException catch (e) {
    messages.updateById(placeholderId, (m) => m.copyWith(
          content: e.isAuthError
              ? 'Hermes auth failed (${e.statusCode}). Check the API key.'
              : 'Hermes error (${e.statusCode}): ${e.message}',
          isStreaming: false,
          clearStatusText: true,
        ));
  } catch (e) {
    messages.updateById(placeholderId, (m) => m.copyWith(
          content: buffer.isEmpty
              ? 'Hermes request failed: $e'
              : '$buffer\n\n[Stream interrupted: $e]',
          isStreaming: false,
          clearStatusText: true,
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

  // OpenClaw `chat.send` has no system-prompt slot, so when an Academy
  // / Life Architect overlay is active we prepend it to the user's
  // text as a fenced "Coaching context" block. The agent treats it as
  // an instruction prefix; the rendered chat bubble still shows just
  // the user's original question.
  final overlay = _activeSystemPromptOverlay(ref);
  final sendText = (overlay != null && overlay.trim().isNotEmpty)
      ? '[Coaching context — follow these instructions for this turn]\n'
          '${overlay.trim()}\n'
          '---\n\n'
          '$text'
      : text;

  // Send and await the ack so we know the runId.
  String? runId;
  try {
    runId = await client.sendMessage(
      sendText,
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
  await _maybeAdvanceGrowPhase(ref, text);
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
