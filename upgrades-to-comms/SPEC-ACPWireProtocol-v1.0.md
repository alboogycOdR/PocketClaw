# Pocket Claw — Hermes ACP Wire Protocol
## Complete Developer Reference (Sprint 5)

**Date:** 2026-05-08  
**Author:** CARMEN PTY LTD  
**Source:** Verified from `scarf-main/Packages/ScarfCore/Sources/ScarfCore/ACP/ACPClient.swift` and `ACPMessages.swift` — production iOS code running against live Hermes v0.12  
**Status:** Implementation-ready — no guessing required  

---

## What ACP Is

ACP (Agent Client Protocol) is a **JSON-RPC 2.0 session** that runs over the stdio of a `hermes acp` subprocess. On iOS/Android, the subprocess runs remotely on the VPS via SSH exec. The client writes JSON-RPC request lines to stdin; the server writes JSON-RPC response and notification lines to stdout.

**Transport (for Pocket Claw):**
```
SSHClient.execute("hermes acp")
  ├── stdin  → write JSON-RPC request lines (newline-terminated)
  └── stdout ← read JSON-RPC response + notification lines (one JSON object per line)
```

**Why ACP instead of REST for chat:**
- REST `/v1/chat/completions` returns only the final text — agent runs invisibly
- ACP streams every tool call, thought chunk, and progress event in real time
- Gives the UI live visibility into what the agent is doing (terminal commands, web searches, file reads)

---

## Transport Rules

1. **One JSON object per line** — newline `\n` terminates each message
2. **No pretty-printing** — compact JSON only, no embedded newlines
3. **Keepalive every 30 seconds** — send `{"jsonrpc":"2.0","method":"$/ping"}` — plain newlines cause `json.loads("")` errors in Hermes, always send a valid JSON notification
4. **Request timeout: 60 seconds** — except `session/prompt` which has no timeout (agent can run for minutes)
5. **Connect timeout: 10 seconds** — SSH exec timeout before the subprocess starts

---

## Message Type Discrimination

Every message has this shape. Discriminate by presence of `id` and `method`:

```
id present  + method absent  → Response     (server reply to a client request)
id absent   + method present → Notification (server-initiated event, no reply expected)
id present  + method present → Request      (server asking client for something — permission)
```

---

## Client → Server: Requests

All client requests follow this envelope:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "<method-name>",
  "params": { ... }
}
```

`id` is a monotonically incrementing integer starting at 1. Each request gets a unique id; responses carry the same id.

---

### Method: `initialize`

**Send immediately after the subprocess starts.** Required before any other method.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": 1,
    "clientCapabilities": {},
    "clientInfo": {
      "name": "PocketClaw",
      "version": "1.0"
    }
  }
}
```

**Response (success):**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {}
}
```

**On error:** `result` is absent, `error` object present (see Error Responses below).

---

### Method: `session/new`

Create a brand new session. Returns a `sessionId` to use in all subsequent `session/prompt` calls.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "session/new",
  "params": {
    "cwd": "/home/clawusr",
    "mcpServers": []
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
}
```

---

### Method: `session/load`

Load an existing session by its ID (from `state.db`). Used to resume a specific past conversation.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "session/load",
  "params": {
    "cwd": "/home/clawusr",
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "mcpServers": []
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {}
}
```

> Note: Response is `{}` on success — the sessionId is NOT echoed back. Use the sessionId you sent.

---

### Method: `session/resume`

Resume the most recently active session. Different from `session/load` — Hermes picks the session; you don't specify one.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "session/resume",
  "params": {
    "cwd": "/home/clawusr",
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "mcpServers": []
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
}
```

---

### Method: `session/prompt`

Send a user message. **This is the main chat method.** The response arrives AFTER all streaming notifications have been emitted for this turn. No timeout — agent can run for minutes.

**Request (text only):**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "session/prompt",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "messageId": "550e8400-e29b-41d4-a716-446655440000",
    "prompt": [
      {
        "type": "text",
        "text": "What is the current price of XAUUSD?"
      }
    ]
  }
}
```

**Request (text + image):**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "session/prompt",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "messageId": "550e8400-e29b-41d4-a716-446655440000",
    "prompt": [
      {
        "type": "text",
        "text": "Analyse this chart"
      },
      {
        "type": "image",
        "data": "<base64-encoded-image-data>",
        "mimeType": "image/jpeg"
      }
    ]
  }
}
```

> `messageId` is a UUID you generate. Use `uuid.v4()` — it deduplicate retries server-side.

**Response (arrives AFTER all notifications for this turn):**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "stopReason": "end_turn",
    "usage": {
      "inputTokens": 17273,
      "outputTokens": 142,
      "thoughtTokens": 0,
      "cachedReadTokens": 0
    }
  }
}
```

**`stopReason` values:** `"end_turn"` (normal), `"max_tokens"`, `"cancelled"`, `"tool_use"`

---

### Method: `session/cancel`

Cancel an in-progress prompt. Safe to call at any time during a `session/prompt` — Hermes will stop the agent and emit a `promptComplete` notification.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "session/cancel",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {}
}
```

---

### Keepalive (Notification — No Response Expected)

Send every 30 seconds to keep the subprocess alive. **Must be valid JSON** — a bare newline causes Hermes to log a JSON parse error.

```json
{"jsonrpc":"2.0","method":"$/ping"}
```

No `id` field — this is a notification, not a request. Hermes silently ignores it.

---

## Server → Client: Notifications (Events)

All events arrive as JSON-RPC **notifications** (no `id`) with method `"session/update"`.

**Notification envelope:**
```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "update": {
      "sessionUpdate": "<event-type>",
      ... event-specific fields ...
    }
  }
}
```

Discriminate on `params.update.sessionUpdate`:

---

### Event: `agent_message_chunk`

A chunk of the agent's text response. Accumulate these to build the complete response. Emitted zero or more times before the `session/prompt` response arrives.

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "update": {
      "sessionUpdate": "agent_message_chunk",
      "content": {
        "text": "The current XAUUSD price is approximately "
      }
    }
  }
}
```

**Extract:** `params.update.content.text` → append to response buffer.

---

### Event: `agent_thought_chunk`

The agent's internal reasoning (only emitted when `display.show_reasoning: true` in Hermes config). Not shown to the user by default — use for a collapsible "thinking" indicator.

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "update": {
      "sessionUpdate": "agent_thought_chunk",
      "content": {
        "text": "I need to search for the current gold price..."
      }
    }
  }
}
```

**Extract:** `params.update.content.text` — same field as message chunk.

---

### Event: `tool_call`

The agent is starting a tool call. Show a tool call card in the UI.

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "update": {
      "sessionUpdate": "tool_call",
      "toolCallId": "call_abc123",
      "title": "web_search: XAUUSD current price",
      "kind": "fetch",
      "status": "pending",
      "content": [],
      "rawInput": {
        "query": "XAUUSD current price today"
      }
    }
  }
}
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `toolCallId` | string | Unique ID — correlates with `tool_call_update` events |
| `title` | string | Format: `"functionName: summary"` or just `"functionName"` |
| `kind` | string | Tool category — see Kind Values below |
| `status` | string | Always `"pending"` on start |
| `rawInput` | object | The arguments passed to the tool |

**Kind Values (for UI colour coding):**

| kind | Colour | Meaning |
|---|---|---|
| `"read"` | Blue `#60A5FA` | File read, directory list, search |
| `"edit"` | Amber `#FBBF24` | File write, edit, delete |
| `"execute"` | Emerald `#34D399` | Terminal command, code execution |
| `"fetch"` | Violet `#A78BFA` | Web search, browser, URL fetch |
| `"search"` | Sky `#38BDF8` | Session search, memory search |
| `"think"` | Pink `#F472B6` | Internal reasoning step |
| `"other"` | Gray `#9CA3AF` | Everything else |

**Title parsing:**
```dart
// title is "functionName: human summary" or just "functionName"
final parts = title.split(':');
final functionName = parts.first.trim();      // "web_search"
final summary = parts.length > 1
    ? parts.sublist(1).join(':').trim()        // "XAUUSD current price"
    : '';
```

---

### Event: `tool_call_update`

The tool call has completed (or failed). Update the existing tool call card.

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "update": {
      "sessionUpdate": "tool_call_update",
      "toolCallId": "call_abc123",
      "kind": "fetch",
      "status": "completed",
      "content": [
        {
          "content": {
            "text": "Found 5 results. XAUUSD is trading at $3,234.50..."
          }
        }
      ],
      "rawOutput": "Found 5 results. XAUUSD is trading at $3,234.50..."
    }
  }
}
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `toolCallId` | string | Matches the `tool_call` event with same ID |
| `kind` | string | Same kind as the start event |
| `status` | string | `"completed"` or `"failed"` |
| `content` | array | Nested: `[{"content": {"text": "..."}}]` — see extraction below |
| `rawOutput` | string | Plain text output from the tool |

**Content extraction:**
```dart
// content is an array of objects with nested content.text
final text = (update['content'] as List? ?? [])
    .cast<Map<String, dynamic>>()
    .map((item) => (item['content'] as Map?)?['text'] as String? ?? '')
    .where((s) => s.isNotEmpty)
    .join('\n');
```

**Status values:** `"completed"`, `"failed"`

---

### Event: `available_commands_update`

The agent is advertising what slash commands it supports in this context. Store and surface in the command palette if needed.

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "update": {
      "sessionUpdate": "available_commands_update",
      "availableCommands": [
        {"name": "/help", "description": "Show available commands"},
        {"name": "/reset", "description": "Reset conversation"}
      ]
    }
  }
}
```

---

## Server → Client: Requests (Permission)

Hermes can also send **requests** (with `id`) when it needs the user to approve a tool action. These arrive as `method: "session/request_permission"`.

**Incoming permission request:**
```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "method": "session/request_permission",
  "params": {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "toolCall": {
      "title": "terminal: rm -rf /tmp/build",
      "kind": "execute"
    },
    "options": [
      {"optionId": "allow", "name": "Allow"},
      {"optionId": "allow_always", "name": "Always Allow"},
      {"optionId": "deny", "name": "Deny"}
    ]
  }
}
```

**Required client response** (must send — Hermes blocks until it receives this):
```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "result": {
    "outcome": {
      "kind": "allowed",
      "optionId": "allow"
    }
  }
}
```

For deny:
```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "result": {
    "outcome": {
      "kind": "rejected",
      "optionId": "deny"
    }
  }
}
```

**`kind` values:** `"allowed"` (any allow option), `"rejected"` (deny)  
**`optionId` values:** Whatever was in `options[].optionId` — pass it back unchanged.

---

## Error Responses

Any request can receive an error response instead of a result:

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "error": {
    "code": -32603,
    "message": "Internal error: model not found"
  }
}
```

**Common error codes:**

| Code | Meaning |
|---|---|
| `-32700` | Parse error — malformed JSON sent |
| `-32600` | Invalid Request — missing required field |
| `-32601` | Method not found |
| `-32602` | Invalid params |
| `-32603` | Internal error — most Hermes runtime errors |

---

## Complete Session Flow (Annotated)

```
CLIENT                                          SERVER (hermes acp)
  │                                                │
  │── initialize ──────────────────────────────►  │
  │◄── result: {} ─────────────────────────────  │
  │                                                │
  │── session/new ─────────────────────────────►  │
  │◄── result: {sessionId} ────────────────────  │
  │                                                │
  │── session/prompt (text) ───────────────────►  │
  │◄── notification: tool_call (web_search) ────  │  ← agent starts searching
  │◄── notification: tool_call_update ──────────  │  ← search complete
  │◄── notification: agent_message_chunk ───────  │  ← "The price is"
  │◄── notification: agent_message_chunk ───────  │  ← " $3,234.50"
  │◄── result: {stopReason, usage} ─────────────  │  ← turn complete
  │                                                │
  │  [30s timer fires]                             │
  │── $/ping ──────────────────────────────────►  │  ← keepalive (no response)
  │                                                │
  │── session/prompt (next message) ───────────►  │
  │  [agent might request permission]              │
  │◄── request: session/request_permission ─────  │
  │── result: {outcome: allowed} ──────────────►  │  ← user approved
  │◄── notification: tool_call ─────────────────  │
  │◄── notification: tool_call_update ──────────  │
  │◄── notification: agent_message_chunk ───────  │
  │◄── result: {stopReason, usage} ─────────────  │
  │                                                │
  │  [user taps cancel]                            │
  │── session/cancel ──────────────────────────►  │
  │◄── result: {} ─────────────────────────────  │
  │                                                │
  │  [user closes chat / app backgrounds]          │
  │── [close SSH exec channel] ────────────────►  │  ← process exits
```

---

## Dart Implementation

### Data Models

```dart
// lib/core/hermes/acp/acp_models.dart

import 'dart:convert';

// ── Outbound ────────────────────────────────────────────────────────────────

class ACPRequest {
  final int id;
  final String method;
  final Map<String, dynamic> params;

  const ACPRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  String toLine() {
    return jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }) + '\n';
  }
}

// Keepalive notification — no id, no response expected
const String kACPKeepaliveLine = '{"jsonrpc":"2.0","method":"\$/ping"}\n';

// ── Inbound ─────────────────────────────────────────────────────────────────

enum ACPMessageKind { response, notification, serverRequest, unknown }

class ACPRawMessage {
  final String? jsonrpc;
  final int? id;
  final String? method;
  final Map<String, dynamic>? result;
  final ACPErrorPayload? error;
  final Map<String, dynamic>? params;

  const ACPRawMessage({
    this.jsonrpc,
    this.id,
    this.method,
    this.result,
    this.error,
    this.params,
  });

  ACPMessageKind get kind {
    if (id != null && method == null) return ACPMessageKind.response;
    if (id == null && method != null) return ACPMessageKind.notification;
    if (id != null && method != null) return ACPMessageKind.serverRequest;
    return ACPMessageKind.unknown;
  }

  factory ACPRawMessage.fromJson(Map<String, dynamic> json) => ACPRawMessage(
    jsonrpc: json['jsonrpc'] as String?,
    id:      json['id'] as int?,
    method:  json['method'] as String?,
    result:  json['result'] as Map<String, dynamic>?,
    error:   json['error'] != null
        ? ACPErrorPayload.fromJson(json['error'] as Map<String, dynamic>)
        : null,
    params:  json['params'] as Map<String, dynamic>?,
  );
}

class ACPErrorPayload {
  final int code;
  final String message;

  const ACPErrorPayload({required this.code, required this.message});

  factory ACPErrorPayload.fromJson(Map<String, dynamic> json) =>
      ACPErrorPayload(
        code:    json['code'] as int? ?? -32603,
        message: json['message'] as String? ?? 'Unknown error',
      );
}

// ── Events ───────────────────────────────────────────────────────────────────

sealed class ACPEvent {}

class ACPMessageChunkEvent extends ACPEvent {
  final String sessionId;
  final String text;
  ACPMessageChunkEvent({required this.sessionId, required this.text});
}

class ACPThoughtChunkEvent extends ACPEvent {
  final String sessionId;
  final String text;
  ACPThoughtChunkEvent({required this.sessionId, required this.text});
}

class ACPToolCallStartEvent extends ACPEvent {
  final String sessionId;
  final String toolCallId;
  final String title;
  final String functionName;
  final String summary;
  final String kind;
  final String status;
  final Map<String, dynamic>? rawInput;

  ACPToolCallStartEvent({
    required this.sessionId,
    required this.toolCallId,
    required this.title,
    required this.kind,
    required this.status,
    this.rawInput,
  })  : functionName = title.contains(':')
            ? title.split(':').first.trim()
            : title,
        summary = title.contains(':')
            ? title.substring(title.indexOf(':') + 1).trim()
            : '';
}

class ACPToolCallUpdateEvent extends ACPEvent {
  final String sessionId;
  final String toolCallId;
  final String kind;
  final String status;  // 'completed' | 'failed'
  final String content;
  final String? rawOutput;

  ACPToolCallUpdateEvent({
    required this.sessionId,
    required this.toolCallId,
    required this.kind,
    required this.status,
    required this.content,
    this.rawOutput,
  });
}

class ACPPermissionRequestEvent extends ACPEvent {
  final String sessionId;
  final int requestId;          // Must be echoed in response
  final String toolCallTitle;
  final String toolCallKind;
  final List<ACPPermissionOption> options;

  ACPPermissionRequestEvent({
    required this.sessionId,
    required this.requestId,
    required this.toolCallTitle,
    required this.toolCallKind,
    required this.options,
  });
}

class ACPPermissionOption {
  final String optionId;
  final String name;
  const ACPPermissionOption({required this.optionId, required this.name});
}

class ACPPromptCompleteEvent extends ACPEvent {
  final String sessionId;
  final String stopReason;
  final int inputTokens;
  final int outputTokens;
  final int thoughtTokens;
  final int cachedReadTokens;

  ACPPromptCompleteEvent({
    required this.sessionId,
    required this.stopReason,
    required this.inputTokens,
    required this.outputTokens,
    required this.thoughtTokens,
    required this.cachedReadTokens,
  });
}

class ACPUnknownEvent extends ACPEvent {
  final String sessionId;
  final String type;
  ACPUnknownEvent({required this.sessionId, required this.type});
}
```

### Event Parser

```dart
// lib/core/hermes/acp/acp_event_parser.dart

import 'acp_models.dart';

class ACPEventParser {
  /// Parse a notification (method == "session/update") into a typed event.
  static ACPEvent? parseNotification(ACPRawMessage message) {
    if (message.method != 'session/update') return null;

    final params = message.params;
    final sessionId = params?['sessionId'] as String?;
    final update = params?['update'] as Map<String, dynamic>?;
    final updateType = update?['sessionUpdate'] as String?;

    if (sessionId == null || update == null || updateType == null) return null;

    return switch (updateType) {
      'agent_message_chunk' => ACPMessageChunkEvent(
          sessionId: sessionId,
          text: (update['content'] as Map?)?['text'] as String? ?? '',
        ),

      'agent_thought_chunk' => ACPThoughtChunkEvent(
          sessionId: sessionId,
          text: (update['content'] as Map?)?['text'] as String? ?? '',
        ),

      'tool_call' => ACPToolCallStartEvent(
          sessionId:  sessionId,
          toolCallId: update['toolCallId'] as String? ?? '',
          title:      update['title'] as String? ?? '',
          kind:       update['kind'] as String? ?? 'other',
          status:     update['status'] as String? ?? 'pending',
          rawInput:   update['rawInput'] as Map<String, dynamic>?,
        ),

      'tool_call_update' => ACPToolCallUpdateEvent(
          sessionId:  sessionId,
          toolCallId: update['toolCallId'] as String? ?? '',
          kind:       update['kind'] as String? ?? 'other',
          status:     update['status'] as String? ?? 'completed',
          content:    _extractContentArrayText(update),
          rawOutput:  update['rawOutput'] as String?,
        ),

      'available_commands_update' => null,  // ignore for now

      _ => ACPUnknownEvent(sessionId: sessionId, type: updateType),
    };
  }

  /// Parse a server-initiated permission request.
  static ACPPermissionRequestEvent? parsePermissionRequest(ACPRawMessage message) {
    if (message.method != 'session/request_permission') return null;
    final params  = message.params;
    final id      = message.id;
    final sessionId = params?['sessionId'] as String?;
    if (id == null || sessionId == null) return null;

    final toolCall = params?['toolCall'] as Map<String, dynamic>? ?? {};
    final rawOptions = params?['options'] as List? ?? [];

    return ACPPermissionRequestEvent(
      sessionId:     sessionId,
      requestId:     id,
      toolCallTitle: toolCall['title'] as String? ?? '',
      toolCallKind:  toolCall['kind'] as String? ?? 'other',
      options: rawOptions
          .cast<Map<String, dynamic>>()
          .map((o) => ACPPermissionOption(
                optionId: o['optionId'] as String? ?? '',
                name:     o['name'] as String? ?? '',
              ))
          .toList(),
    );
  }

  // content is [{content: {text: "..."}}] — nested two levels
  static String _extractContentArrayText(Map<String, dynamic> update) {
    final arr = update['content'] as List?;
    if (arr == null) return '';
    return arr
        .cast<Map<String, dynamic>>()
        .map((item) => (item['content'] as Map?)?['text'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .join('\n');
  }
}
```

### ACP Client (Full Implementation)

```dart
// lib/core/hermes/acp/hermes_acp_client.dart

import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../ssh/hermes_ssh_client.dart';
import 'acp_models.dart';
import 'acp_event_parser.dart';

/// Manages an ACP session over SSH exec.
///
/// Usage:
///   final client = HermesACPClient(ssh: sshClient);
///   await client.start();
///   final sessionId = await client.newSession();
///   await for (final event in client.events) { ... }
///   await client.sendPrompt(sessionId: sessionId, text: "Hello");
///   // events stream emits message chunks + tool call events
class HermesACPClient {
  final HermesSSHClient _ssh;
  static const _uuid = Uuid();

  // SSH exec channel to `hermes acp` subprocess
  StreamSubscription<String>? _stdoutSub;
  StreamSink<String>? _stdin;

  // JSON-RPC id counter
  int _nextId = 1;

  // Pending request completers: id → Completer<Map?>
  final _pending = <int, Completer<Map<String, dynamic>?>>{};

  // Event stream for UI consumption
  final _eventController = StreamController<ACPEvent>.broadcast();
  Stream<ACPEvent> get events => _eventController.stream;

  // State
  bool _connected = false;
  String? _currentSessionId;
  Timer? _keepaliveTimer;

  bool get isConnected => _connected;
  String? get currentSessionId => _currentSessionId;

  HermesACPClient({required HermesSSHClient ssh}) : _ssh = ssh;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_connected) return;

    // Open SSH exec channel running `hermes acp`
    // dartssh2: use client.execute() which gives stdin/stdout streams
    final process = await _ssh.executeInteractive('hermes acp');
    _stdin = process.stdin;

    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onDone: _handleDisconnect);

    _connected = true;

    // Initialize immediately
    await _request('initialize', {
      'protocolVersion': 1,
      'clientCapabilities': <String, dynamic>{},
      'clientInfo': {'name': 'PocketClaw', 'version': '1.0'},
    });

    // Start 30s keepalive
    _keepaliveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendLine(kACPKeepaliveLine.trimRight()),
    );
  }

  Future<void> stop() async {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    _connected = false;
    _currentSessionId = null;

    // Fail all pending requests
    for (final c in _pending.values) {
      c.completeError(Exception('ACP client stopped'));
    }
    _pending.clear();
    await _eventController.close();
  }

  // ── Session Management ────────────────────────────────────────────────────

  Future<String> newSession({String cwd = '/home/clawusr'}) async {
    final result = await _request('session/new', {
      'cwd': cwd,
      'mcpServers': <dynamic>[],
    });
    final sessionId = result?['sessionId'] as String?;
    if (sessionId == null) throw Exception('session/new: missing sessionId');
    _currentSessionId = sessionId;
    return sessionId;
  }

  Future<String> loadSession({
    required String sessionId,
    String cwd = '/home/clawusr',
  }) async {
    await _request('session/load', {
      'cwd': cwd,
      'sessionId': sessionId,
      'mcpServers': <dynamic>[],
    });
    _currentSessionId = sessionId;
    return sessionId;
  }

  Future<String> resumeSession({
    required String sessionId,
    String cwd = '/home/clawusr',
  }) async {
    final result = await _request('session/resume', {
      'cwd': cwd,
      'sessionId': sessionId,
      'mcpServers': <dynamic>[],
    });
    final resumedId = result?['sessionId'] as String? ?? sessionId;
    _currentSessionId = resumedId;
    return resumedId;
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  /// Send a text message. Returns token usage when complete.
  /// Events are emitted on [events] stream during the agent run.
  Future<ACPPromptCompleteEvent> sendPrompt({
    required String sessionId,
    required String text,
    List<Map<String, dynamic>>? imageAttachments,
  }) async {
    final messageId = _uuid.v4();

    final promptBlocks = <Map<String, dynamic>>[
      {'type': 'text', 'text': text},
      ...?imageAttachments?.map((img) => {
        'type': 'image',
        'data': img['base64Data'],
        'mimeType': img['mimeType'],
      }),
    ];

    final result = await _request('session/prompt', {
      'sessionId': sessionId,
      'messageId': messageId,
      'prompt': promptBlocks,
    }, timeout: null); // no timeout for prompts

    final usage = result?['usage'] as Map<String, dynamic>? ?? {};
    return ACPPromptCompleteEvent(
      sessionId:       sessionId,
      stopReason:      result?['stopReason'] as String? ?? 'end_turn',
      inputTokens:     (usage['inputTokens'] as num?)?.toInt() ?? 0,
      outputTokens:    (usage['outputTokens'] as num?)?.toInt() ?? 0,
      thoughtTokens:   (usage['thoughtTokens'] as num?)?.toInt() ?? 0,
      cachedReadTokens: (usage['cachedReadTokens'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> cancel(String sessionId) async {
    await _request('session/cancel', {'sessionId': sessionId});
  }

  /// Respond to a server-initiated permission request.
  void approvePermission(int requestId, String optionId) {
    final outcomeKind = optionId == 'deny' ? 'rejected' : 'allowed';
    _sendLine(jsonEncode({
      'jsonrpc': '2.0',
      'id': requestId,
      'result': {
        'outcome': {
          'kind': outcomeKind,
          'optionId': optionId,
        },
      },
    }));
  }

  // ── Transport ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _request(
    String method,
    Map<String, dynamic> params, {
    Duration? timeout = const Duration(seconds: 60),
  }) async {
    final id = _nextId++;
    final line = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

    final completer = Completer<Map<String, dynamic>?>();
    _pending[id] = completer;
    _sendLine(line);

    if (timeout != null) {
      Future.delayed(timeout).then((_) {
        if (!completer.isCompleted) {
          _pending.remove(id);
          completer.completeError(
            TimeoutException('ACP request "$method" timed out', timeout),
          );
        }
      });
    }

    return completer.future;
  }

  void _sendLine(String json) {
    _stdin?.add('$json\n');
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final msg  = ACPRawMessage.fromJson(json);

      switch (msg.kind) {
        case ACPMessageKind.response:
          final c = _pending.remove(msg.id!);
          if (msg.error != null) {
            c?.completeError(
              Exception('ACP error ${msg.error!.code}: ${msg.error!.message}'),
            );
          } else {
            c?.complete(msg.result);
          }

        case ACPMessageKind.notification:
          final event = ACPEventParser.parseNotification(msg);
          if (event != null) _eventController.add(event);

        case ACPMessageKind.serverRequest:
          final event = ACPEventParser.parsePermissionRequest(msg);
          if (event != null) _eventController.add(event);

        case ACPMessageKind.unknown:
          break;
      }
    } catch (_) {
      // Malformed line — ignore silently
    }
  }

  void _handleDisconnect() {
    _connected = false;
    for (final c in _pending.values) {
      c.completeError(Exception('ACP subprocess terminated'));
    }
    _pending.clear();
    _eventController.add(
      ACPUnknownEvent(sessionId: _currentSessionId ?? '', type: 'disconnected'),
    );
  }
}
```

---

## Chat Provider Integration (How to Wire into the Existing Chat Screen)

```dart
// In chat_providers.dart — add Hermes ACP path alongside the existing REST path

case ExecutionPath.hermes:
  // Prefer ACP (SSH) for rich tool call visibility
  // Fall back to REST if SSH not configured
  final sshClient = ref.read(sshClientProvider);
  if (sshClient != null && await sshClient.isReachable()) {
    await _sendViaACP(text, ref, placeholderId);
  } else {
    await _sendViaHermesREST(text, ref, placeholderId);
  }

// ACP send:
Future<void> _sendViaACP(
  String text, WidgetRef ref, String placeholderId) async {

  final ssh = ref.read(sshClientProvider)!;
  final acpClient = HermesACPClient(ssh: ssh);
  await acpClient.start();

  final sessionId = await acpClient.newSession();

  // Collect tool call events and bubble updates
  final toolCalls = <String, ACPToolCallStartEvent>{};

  acpClient.events.listen((event) {
    switch (event) {
      case ACPMessageChunkEvent(:final text):
        // Append text chunk to the chat bubble
        messages.appendToMessage(placeholderId, text);

      case ACPToolCallStartEvent(:final toolCallId) && final e:
        // Add a tool call card below the streaming bubble
        toolCalls[toolCallId] = e;
        messages.addToolCall(placeholderId, e);

      case ACPToolCallUpdateEvent(:final toolCallId, :final status, :final content):
        // Update the tool call card
        messages.updateToolCall(placeholderId, toolCallId, status, content);

      case ACPPermissionRequestEvent(:final requestId, :final toolCallTitle):
        // Show permission dialog, then:
        // acpClient.approvePermission(requestId, 'allow');
        _showPermissionDialog(ref, acpClient, requestId, toolCallTitle);

      default:
        break;
    }
  });

  await acpClient.sendPrompt(sessionId: sessionId, text: text);
  messages.finaliseMessage(placeholderId);
  await acpClient.stop();
}
```

---

## Test Script — Verify ACP on VPS Before Building

Run this on the VPS to confirm `hermes acp` starts and responds correctly:

```bash
# Install pexpect if not available
pip install pexpect --break-system-packages

# Quick ACP smoke test
python3 << 'EOF'
import subprocess, json, time

proc = subprocess.Popen(
    ['hermes', 'acp'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1
)

def send(obj):
    line = json.dumps(obj)
    print(f">>> {line}")
    proc.stdin.write(line + "\n")
    proc.stdin.flush()

def recv():
    line = proc.stdout.readline()
    print(f"<<< {line.strip()}")
    return json.loads(line)

# 1. Initialize
send({"jsonrpc":"2.0","id":1,"method":"initialize",
      "params":{"protocolVersion":1,"clientCapabilities":{},
                "clientInfo":{"name":"test","version":"1.0"}}})
resp = recv()
assert resp.get("result") is not None, f"initialize failed: {resp}"
print("✅ initialize OK")

# 2. New session
send({"jsonrpc":"2.0","id":2,"method":"session/new",
      "params":{"cwd":"/home/clawusr","mcpServers":[]}})
resp = recv()
session_id = resp["result"]["sessionId"]
print(f"✅ session/new OK — sessionId: {session_id}")

# 3. Send a prompt
send({"jsonrpc":"2.0","id":3,"method":"session/prompt",
      "params":{"sessionId":session_id,
                "messageId":"test-001",
                "prompt":[{"type":"text","text":"say the word hello only"}]}})

# Collect events until we get the response
chunks = []
while True:
    line = proc.stdout.readline()
    msg = json.loads(line)
    if "method" in msg:
        update = msg.get("params",{}).get("update",{})
        etype = update.get("sessionUpdate","")
        print(f"  EVENT: {etype}")
        if etype == "agent_message_chunk":
            chunks.append(update.get("content",{}).get("text",""))
    elif "result" in msg and msg.get("id") == 3:
        print(f"✅ prompt complete — stopReason: {msg['result'].get('stopReason')}")
        print(f"   assembled text: {''.join(chunks)}")
        break

proc.terminate()
print("✅ ACP smoke test passed")
EOF
```

Run this before Sprint 5 development begins. The output will confirm exact event shapes from your specific Hermes version.

---

*CARMEN PTY LTD — Pocket Claw ACP Wire Protocol Reference v1.0*  
*Verified from Scarf v2.7.1 production source — ACPClient.swift + ACPMessages.swift*  
*2026-05-08*
