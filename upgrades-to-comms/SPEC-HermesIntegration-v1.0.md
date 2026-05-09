# Pocket Claw — Hermes Agent Integration
## Developer Specification v1.0

**Date:** 2026-05-08  
**Author:** CARMEN PTY LTD  
**Status:** Implementation-ready — all API contracts verified from live VPS  
**Hermes version:** v0.12.0 (2026.4.30)  
**VPS:** `100.78.70.2` · Tailscale-only access  

---

## 1. What This Sprint Delivers

A fourth execution path in Pocket Claw — **Hermes** — sitting alongside Local, Cloud, and OpenClaw. When the user selects or the Smart Router chooses the Hermes path, chat messages go to the Hermes Agent API instead of OpenClaw. Hermes runs its full toolset (terminal, web, memory, skills, delegation) and returns a streamed response in standard OpenAI SSE format.

**Paperclip is on hold.** The Company tab and `PaperclipRestClient` remain untouched this sprint.

---

## 2. Verified API Contract

### Base URL
```
http://100.78.70.2:8642
```

### Authentication
Every request requires:
```
Authorization: Bearer <YOUR_HERMES_API_KEY>
```

### Confirmed Endpoints

| Endpoint | Method | Status | Notes |
|---|---|---|---|
| `/v1/models` | GET | ✅ Verified | Returns model list |
| `/v1/chat/completions` | POST | ✅ Verified | Both streaming + non-streaming |
| `/v1/sessions` | GET | ❌ 404 | Not exposed in v0.12.0 |
| `/v1/skills` | GET | ❌ 404 | Not exposed in v0.12.0 |
| `/v1/cron` | GET | ❌ 404 | Not exposed in v0.12.0 |
| `/v1/api-surface` | GET | ❌ 404 | Not exposed in v0.12.0 |

**Implication:** The API server in v0.12.0 is intentionally an OpenAI-compatible chat-only interface. Sessions, skills, and cron are managed via CLI and Telegram only — not via REST. The Pocket Claw integration is therefore chat-focused.

---

### 2.1 Models Endpoint

**Request:**
```
GET /v1/models
Authorization: Bearer <YOUR_HERMES_API_KEY>
```

**Response (verified):**
```json
{
  "object": "list",
  "data": [
    {
      "id": "hermes-agent",
      "object": "model",
      "created": 1778231444,
      "owned_by": "hermes",
      "permission": [],
      "root": "hermes-agent",
      "parent": null
    }
  ]
}
```

Model ID to use in all requests: `"hermes-agent"`

---

### 2.2 Chat Completions — Non-Streaming

**Request:**
```
POST /v1/chat/completions
Authorization: Bearer <YOUR_HERMES_API_KEY>
Content-Type: application/json

{
  "model": "hermes-agent",
  "messages": [
    {"role": "user", "content": "your message here"}
  ],
  "stream": false,
  "max_tokens": 1024
}
```

**Response (verified):**
```json
{
  "id": "chatcmpl-1c701713e49942fba4fef981d8927",
  "object": "chat.completion",
  "created": 1778231444,
  "model": "hermes-agent",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 17273,
    "completion_tokens": 4,
    "total_tokens": 17277
  }
}
```

---

### 2.3 Chat Completions — Streaming (SSE)

**Request:** Same as above with `"stream": true`

**Response (verified):** Standard Server-Sent Events, one chunk per line:

```
data: {"id":"chatcmpl-...","object":"chat.completion.chunk","created":1778231580,"model":"hermes-agent","choices":[{"index":0,"delta":{"role":"assistant"},"finish_reason":null}]}

data: {"id":"chatcmpl-...","object":"chat.completion.chunk","created":1778231580,"model":"hermes-agent","choices":[{"index":0,"delta":{"content":"Hey"},"finish_reason":null}]}

data: {"id":"chatcmpl-...","object":"chat.completion.chunk","created":1778231580,"model":"hermes-agent","choices":[{"index":0,"delta":{"content":" there!"},"finish_reason":null}]}

data: {"id":"chatcmpl-...","object":"chat.completion.chunk","created":1778231580,"model":"hermes-agent","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":17270,"completion_tokens":14,"total_tokens":17284}}

data: [DONE]
```

**SSE parsing rules:**
- Each line starts with `data: `
- Strip the `data: ` prefix
- If value is `[DONE]` — stream is complete
- Otherwise parse as JSON, read `choices[0].delta.content`
- Final chunk carries `usage` object and `finish_reason: "stop"`

---

## 3. Configuration

### Hermes config.yaml (relevant fields)
```yaml
model:
  default: claude-haiku-4-5-20251001
  provider: anthropic

providers:
  ollama-launch:
    api: http://127.0.0.1:11434/v1
    default_model: kimi-k2.6:cloud
    models:
      - kimi-k2.6:cloud
      - llama3.2:3b
```

Hermes routes to **Claude Haiku 4.5** by default via Anthropic directly. It also has Ollama available as a fallback provider.

### API Server .env (relevant fields — do not log these)
```
API_SERVER_KEY=<YOUR_HERMES_API_KEY>
API_SERVER_HOST=100.78.70.2
API_SERVER_PORT=8642
ANTHROPIC_API_KEY=[set]
NEUROMETRIC_API_KEY=[set]
```

---

## 4. Architecture

### 4.1 How Hermes Fits into the Existing Execution Paths

```
User Message
     │
     ▼
Smart Router
     │
     ├── local   → LlamaCppEngine / CloudLLMEngine
     ├── server  → GatewayClient (OpenClaw WebSocket)
     ├── bridge  → Device capture + OpenClaw
     └── hermes  → HermesClient (NEW) ← this sprint
```

Hermes is a **REST-based** path. It does NOT use WebSockets. It does NOT use the existing `GatewayClient`. It is independent of OpenClaw.

### 4.2 Reuse Decision

The existing `CloudLLMEngine` handles OpenAI-compatible endpoints but is tied to the LLM model registry and model download flow. Hermes chat is different — it's talking to an agent (with tools, memory, skills) not a raw LLM. A dedicated `HermesClient` is cleaner and more maintainable.

---

## 5. New Files

```
lib/core/hermes/
├── hermes_client.dart          ← REST client (chat, health, models)
└── hermes_sse_parser.dart      ← SSE stream → token Stream<String>

lib/data/providers/
└── hermes_providers.dart       ← Riverpod providers

lib/features/settings/
└── hermes_settings.dart        ← Base URL + API key + test connection

lib/features/hermes/
└── hermes_status_screen.dart   ← Connection status, model info, send test
```

---

## 6. Implementation

### 6.1 HermesClient

```dart
// lib/core/hermes/hermes_client.dart
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HermesClient {
  final String baseUrl;   // e.g. http://100.78.70.2:8642
  final String apiKey;
  final http.Client _http;

  static const String _modelId = 'hermes-agent';

  HermesClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  // ── Health / reachability ────────────────────────────────────────────

  /// Calls /v1/models — the only reliably reachable health check in v0.12.
  Future<bool> isReachable() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/v1/models'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns the advertised model ID (always "hermes-agent" in v0.12).
  Future<String?> getModelId() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/v1/models'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as List?;
      if (data == null || data.isEmpty) return null;
      return (data.first as Map<String, dynamic>)['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Chat — non-streaming ─────────────────────────────────────────────

  Future<String> chat(
    String message, {
    List<Map<String, String>>? history,
    int maxTokens = 1024,
  }) async {
    final messages = [
      ...?history,
      {'role': 'user', 'content': message},
    ];

    final res = await _http
        .post(
          Uri.parse('$baseUrl/v1/chat/completions'),
          headers: _headers,
          body: jsonEncode({
            'model': _modelId,
            'messages': messages,
            'stream': false,
            'max_tokens': maxTokens,
          }),
        )
        .timeout(const Duration(seconds: 120));

    _checkStatus(res);

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = json['choices'] as List;
    return (choices.first['message']['content'] as String?) ?? '';
  }

  // ── Chat — streaming SSE ─────────────────────────────────────────────

  /// Returns a stream of token strings. Caller collects them to build the
  /// full response. Stream completes when `data: [DONE]` is received.
  Stream<String> chatStream(
    String message, {
    List<Map<String, String>>? history,
    int maxTokens = 1024,
  }) async* {
    final messages = [
      ...?history,
      {'role': 'user', 'content': message},
    ];

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/v1/chat/completions'),
    );
    request.headers.addAll(_headers);
    request.body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'stream': true,
      'max_tokens': maxTokens,
    });

    final response = await _http.send(request).timeout(
      const Duration(seconds: 120),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HermesApiException(
        statusCode: response.statusCode,
        message: 'Stream request failed',
      );
    }

    final parser = HermesSseParser();

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final token in parser.process(chunk)) {
        yield token;
      }
    }
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HermesApiException(
        statusCode: res.statusCode,
        message: res.body,
      );
    }
  }

  void dispose() => _http.close();
}

class HermesApiException implements Exception {
  final int statusCode;
  final String message;
  const HermesApiException({required this.statusCode, required this.message});
  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isRetryable => statusCode >= 500;
  @override
  String toString() => 'HermesApiException($statusCode): $message';
}
```

---

### 6.2 SSE Parser

```dart
// lib/core/hermes/hermes_sse_parser.dart
library;

import 'dart:convert';

/// Parses the OpenAI-compatible SSE stream from Hermes.
///
/// Input: raw text chunks from the HTTP response body
/// Output: individual token strings extracted from delta.content
///
/// Format (verified from live VPS):
///   data: {"choices":[{"delta":{"content":"Hey"},...}],...}
///   data: [DONE]
class HermesSseParser {
  final _buffer = StringBuffer();

  /// Process a raw text chunk. Returns zero or more token strings.
  Iterable<String> process(String chunk) sync* {
    _buffer.write(chunk);
    final raw = _buffer.toString();
    final lines = raw.split('\n');

    // Keep the last incomplete line in the buffer
    _buffer.clear();
    if (!raw.endsWith('\n')) {
      _buffer.write(lines.removeLast());
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.startsWith('data: ')) continue;

      final payload = trimmed.substring(6); // strip "data: "
      if (payload == '[DONE]') continue;

      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;

        final delta = choices.first['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;

        final content = delta['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
      } catch (_) {
        // Malformed chunk — skip silently
      }
    }
  }
}
```

---

### 6.3 Riverpod Providers

```dart
// lib/data/providers/hermes_providers.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/hermes/hermes_client.dart';
import 'core_providers.dart';

// ── Settings ─────────────────────────────────────────────────────────────

final hermesBaseUrlProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('hermes_base_url') ?? '';
});

final hermesApiKeyProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('hermes_api_key') ?? '';
});

// ── Client (null when not configured) ────────────────────────────────────

final hermesClientProvider = Provider<HermesClient?>((ref) {
  final url = ref.watch(hermesBaseUrlProvider);
  final key = ref.watch(hermesApiKeyProvider);
  if (url.isEmpty || key.isEmpty) return null;
  return HermesClient(baseUrl: url, apiKey: key);
});

// ── Connection state ─────────────────────────────────────────────────────

final hermesReachableProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(hermesClientProvider);
  if (client == null) return false;
  return client.isReachable();
});

final hermesModelIdProvider = FutureProvider<String?>((ref) async {
  final client = ref.watch(hermesClientProvider);
  if (client == null) return null;
  return client.getModelId();
});
```

---

### 6.4 Smart Router — Add Hermes Path

In `lib/core/router/execution_path.dart`, add the new value:

```dart
enum ExecutionPath {
  local,
  server,   // OpenClaw
  bridge,
  hermes,   // ← new
}
```

In `lib/core/router/smart_router.dart`, add Hermes routing logic:

```dart
// Add to the routing decision chain, before the default fallback:

// Prefer Hermes when: server is unreachable but Hermes is up,
// or user has explicitly set hermes as default path.
final hermesClient = ref.read(hermesClientProvider);
final defaultPath = prefs.getString('default_execution_path') ?? 'auto';

if (defaultPath == 'hermes' && hermesClient != null) {
  return ExecutionPath.hermes;
}

// Auto: fall through to existing local/server/bridge logic
```

---

### 6.5 Execution Path Chip — Add Hermes

In `lib/shared/widgets/execution_path_chip.dart`, add the Hermes case:

```dart
// In _getColor():
ExecutionPath.hermes => const Color(0xFF7C3AED), // purple

// In _getIcon():
ExecutionPath.hermes => Icons.psychology_outlined,

// Label: "HERMES"
```

---

### 6.6 Chat Providers — Wire Hermes Path

In `lib/data/providers/chat_providers.dart`, add a Hermes send branch alongside the existing OpenClaw server send:

```dart
// Inside _sendMessage() or equivalent routing:

case ExecutionPath.hermes:
  final hermesClient = ref.read(hermesClientProvider);
  if (hermesClient == null) {
    // Surface error: Hermes not configured
    break;
  }

  // Build history from current session messages
  final history = messages.value
      .where((m) => m.role != 'system' && !m.isStreaming)
      .map((m) => {'role': m.role, 'content': m.content})
      .toList();

  // Add streaming placeholder bubble
  final placeholderId = _uuid.v4();
  messages.add(ChatMessage(
    id: placeholderId,
    role: 'assistant',
    content: '',
    isStreaming: true,
    path: ExecutionPath.hermes,
  ));

  // Stream tokens into the bubble
  final buffer = StringBuffer();
  try {
    await for (final token in hermesClient.chatStream(
      text,
      history: history,
    )) {
      buffer.write(token);
      messages.updateById(placeholderId, (m) => m.copyWith(
        content: buffer.toString(),
      ));
    }
    messages.updateById(placeholderId, (m) => m.copyWith(
      isStreaming: false,
    ));
  } on HermesApiException catch (e) {
    messages.updateById(placeholderId, (m) => m.copyWith(
      content: 'Hermes error: ${e.message}',
      isStreaming: false,
      isError: true,
    ));
  }
  break;
```

---

### 6.7 Settings Screen

```dart
// lib/features/settings/hermes_settings.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/hermes_client.dart';
import '../../data/providers/hermes_providers.dart';
import '../../data/providers/core_providers.dart';

class HermesSettings extends ConsumerStatefulWidget {
  const HermesSettings({super.key});

  @override
  ConsumerState<HermesSettings> createState() => _HermesSettingsState();
}

class _HermesSettingsState extends ConsumerState<HermesSettings> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  bool _testing = false;
  bool? _testOk;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _baseUrl = TextEditingController(
      text: prefs.getString('hermes_base_url') ?? '',
    );
    _apiKey = TextEditingController(
      text: prefs.getString('hermes_api_key') ?? '',
    );
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('hermes_base_url', _baseUrl.text.trim());
    await prefs.setString('hermes_api_key', _apiKey.text.trim());
    ref.read(hermesBaseUrlProvider.notifier).state = _baseUrl.text.trim();
    ref.read(hermesApiKeyProvider.notifier).state = _apiKey.text.trim();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hermes settings saved')),
      );
    }
  }

  Future<void> _test() async {
    setState(() { _testing = true; _testOk = null; _testMessage = null; });
    final client = HermesClient(
      baseUrl: _baseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
    );
    try {
      final ok = await client.isReachable();
      final model = ok ? await client.getModelId() : null;
      setState(() {
        _testing = false;
        _testOk = ok;
        _testMessage = ok
            ? 'Connected · model: ${model ?? "hermes-agent"}'
            : 'Unreachable — check URL and API key';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testOk = false;
        _testMessage = '$e';
      });
    } finally {
      client.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hermes Agent',
            style: GoogleFonts.jetBrainsMono(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.psychology_outlined,
                        color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Text('Hermes Agent v0.12',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Self-improving AI agent by Nous Research. '
                    'Runs with full toolset — terminal, web, memory, '
                    'skills — on your VPS.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Base URL field
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'http://100.78.70.2:8642',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),

          // API Key field
          TextField(
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'hermes-pocket-claw-...',
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 24),

          // Test button
          ElevatedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: Text(_testing ? 'Testing…' : 'Test Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lobsterRed,
            ),
          ),

          if (_testMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testOk == true ? Colors.teal : Colors.red)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testOk == true ? Colors.tealAccent : Colors.redAccent,
                ),
              ),
              child: Text(_testMessage!,
                  style: TextStyle(
                    color: _testOk == true
                        ? Colors.tealAccent
                        : Colors.redAccent,
                    fontSize: 13,
                  )),
            ),
          ],

          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
```

---

### 6.8 Settings Screen Integration

Add to `lib/features/settings/settings_screen.dart` in the appropriate section:

```dart
// Add a "Hermes Agent" tile alongside the Gateway Connection tile
ListTile(
  leading: const Icon(Icons.psychology_outlined, color: Color(0xFF7C3AED)),
  title: const Text('Hermes Agent'),
  subtitle: Consumer(builder: (_, ref, __) {
    final reachable = ref.watch(hermesReachableProvider);
    return reachable.when(
      data: (ok) => Text(ok ? 'Connected' : 'Not configured',
          style: TextStyle(
              color: ok ? Colors.tealAccent : Colors.white54)),
      loading: () => const Text('Checking…'),
      error: (_, __) => const Text('Unreachable'),
    );
  }),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/hermes'),
),
```

Add the route in `lib/app/router.dart`:
```dart
GoRoute(
  path: '/settings/hermes',
  builder: (_, __) => const HermesSettings(),
),
```

---

## 7. Secure Storage Keys

Add to `SharedPreferences` (non-sensitive):

| Key | Value |
|---|---|
| `hermes_base_url` | `http://100.78.70.2:8642` |
| `hermes_api_key` | `<YOUR_HERMES_API_KEY>` |
| `default_execution_path` | `auto` \| `local` \| `server` \| `hermes` |

The API key is not a long-lived credential (it's a gateway token set by you), so `SharedPreferences` is acceptable. If this ever becomes a sensitive user-specific key, move to `flutter_secure_storage`.

---

## 8. VPS — Make Hermes Gateway Persistent

The gateway is currently running as a background process. Set it up as a systemd service so it survives reboots:

```bash
sudo nano /etc/systemd/system/hermes-gateway.service
```

```ini
[Unit]
Description=Hermes Agent Gateway
After=network.target tailscaled.service
Wants=tailscaled.service

[Service]
Type=simple
User=clawusr
WorkingDirectory=/home/clawusr
ExecStart=/home/clawusr/.hermes/hermes-agent/venv/bin/python \
  -m hermes_cli.main gateway run --replace
Restart=on-failure
RestartSec=15
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hermes-gateway
Environment="HOME=/home/clawusr"
EnvironmentFile=/home/clawusr/.hermes/.env
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable hermes-gateway
sudo systemctl start hermes-gateway
sudo systemctl status hermes-gateway
```

---

## 9. Implementation Order

### Phase 1 — Core (2–3 days)

| # | Task | File |
|---|---|---|
| 1 | Add `hermes` to `ExecutionPath` enum | `execution_path.dart` |
| 2 | Create `HermesClient` | `core/hermes/hermes_client.dart` |
| 3 | Create `HermesSseParser` | `core/hermes/hermes_sse_parser.dart` |
| 4 | Create `hermes_providers.dart` | `data/providers/hermes_providers.dart` |
| 5 | Create `HermesSettings` screen | `features/settings/hermes_settings.dart` |
| 6 | Add route `/settings/hermes` | `app/router.dart` |
| 7 | Add Hermes tile to Settings screen | `settings_screen.dart` |

### Phase 2 — Chat Integration (1–2 days)

| # | Task | File |
|---|---|---|
| 8 | Add Hermes colour + icon to `ExecutionPathChip` | `execution_path_chip.dart` |
| 9 | Add Hermes send branch to chat providers | `chat_providers.dart` |
| 10 | Update Smart Router to honour `default_execution_path = hermes` | `smart_router.dart` |
| 11 | Add Hermes option to router/memory settings | `router_memory_settings.dart` |

### Phase 3 — Polish (1 day)

| # | Task |
|---|---|
| 12 | Make Hermes gateway a systemd service (VPS) |
| 13 | Test streaming end-to-end on physical Android device |
| 14 | Test fallback: if Hermes unreachable, Smart Router falls back to server/local |
| 15 | Remove hardcoded credentials from `core_providers.dart` (overdue) |

---

## 10. What This Sprint Does NOT Include

| Feature | Reason |
|---|---|
| Sessions management UI | Not exposed by Hermes REST API in v0.12 |
| Skills browser | Not exposed by Hermes REST API in v0.12 |
| Cron management | Not exposed by Hermes REST API in v0.12 |
| Hermes memory viewer | Not exposed by Hermes REST API in v0.12 |
| Paperclip Company tab wiring | On hold per sprint scope |

If Hermes v0.13+ exposes these endpoints, a follow-on sprint can add them with minimal client-side changes — the `HermesClient` just needs new methods added.

---

## 11. Known Risks

| Risk | Mitigation |
|---|---|
| `prompt_tokens: 17,273` on a simple "hello" | Hermes loads full memory + skills context on every request. Streaming keeps UX responsive but response time will be longer than a raw LLM call. Set user expectations. |
| API server bound to Tailscale IP only | Phone must have Tailscale active. Handle `isReachable() = false` gracefully — show "Hermes unavailable, switching to OpenClaw" in chat. |
| API key in `SharedPreferences` | Acceptable for a self-hosted gateway token. Upgrade to `flutter_secure_storage` if the key ever becomes user-specific. |
| Hermes gateway not surviving reboots | Addressed by systemd service in Phase 3. Until then, restart manually: `hermes gateway run &` |

---

*End of SPEC-HermesIntegration-v1.0.md*  
*CARMEN PTY LTD — Pocket Claw × Hermes Agent*  
*All API contracts verified against live VPS 100.78.70.2 — 2026-05-08*
