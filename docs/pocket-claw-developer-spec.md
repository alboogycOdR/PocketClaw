# Pocket Claw — Developer Specification
## Mobile AI Agent with OpenClaw Integration

**Version:** 1.0.0  
**Author:** Alister Witbooy / Nuburo.DIGITAL (PTY) LTD  
**Date:** 2026-04-09  
**License:** Proprietary (Nuburo.DIGITAL (PTY) LTD)  
**Status:** Architecture & Design Complete

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Smart Router](#3-smart-router)
4. [Local Agent Engine](#4-local-agent-engine)
5. [OpenClaw Server Integration](#5-openclaw-server-integration)
6. [Skill System](#6-skill-system)
7. [Mission Control Mobile](#7-mission-control-mobile)
8. [Memory System](#8-memory-system)
9. [Device API Layer](#9-device-api-layer)
10. [User Interface](#10-user-interface)
11. [Security Model](#11-security-model)
12. [Technology Stack](#12-technology-stack)
13. [Flutter Project Structure](#13-flutter-project-structure)
14. [Data Models](#14-data-models)
15. [Gateway Protocol](#15-gateway-protocol)
16. [Performance Budgets](#16-performance-budgets)
17. [Development Roadmap](#17-development-roadmap)
18. [Risk Register](#18-risk-register)

---

## 1. Executive Summary

### 1.1 What Is Pocket Claw?

Pocket Claw is a **cross-platform mobile AI agent** (Flutter) that combines a local on-device LLM with a remote OpenClaw server to deliver maximum agentic functionality from a phone. It is a personal productivity and automation tool for the developer/power user who wants an AI agent that **does things**, not just chats.

### 1.2 Core Concept

```
LOCAL LLM (fast, private, offline)  +  OPENCLAW SERVER (powerful, full tools)
              │                                      │
              └──────────┬───────────────────────────┘
                         │
                   SMART ROUTER
              (decides who handles what)
                         │
                         ▼
              UNIFIED CHAT INTERFACE
           + MISSION CONTROL DASHBOARD
           + DEVICE API ACCESS (camera, calendar, etc.)
```

The phone is the **body** (eyes, ears, hands — camera, mic, device APIs). The VPS is the **brain** for complex work (shell commands, web browsing, email, multi-step reasoning). The local LLM handles quick reflexes (simple tasks, offline, private). A Smart Router transparently decides which path every request takes.

### 1.3 Key Capabilities

| Capability | How |
|-----------|-----|
| Quick tasks offline | Local LLM (Gemma 4 E2B) with function calling |
| Complex agentic workflows | Routes to OpenClaw server (Claude/GPT, 64K+ context) |
| Mission Control dashboard | Native Flutter UI consuming Gateway WebSocket API |
| Voice interaction | Gemma E2B native audio processing |
| Camera/OCR | On-device vision model for receipts, whiteboards, documents |
| Notes & memory | Local RAG-searchable notes, synced with server memory |
| Extensible skills | OpenClaw-compatible SKILL.md format with local/server/bridge tiers |
| Device integration | Calendar, contacts, alarms, notifications, file system |
| Cost tracking | Real-time token usage and API spend from server |
| Skill management | Browse, install, write, edit SKILL.md from the phone |

### 1.4 Design Principles

1. **Offline-first**: Every core feature works without connectivity. Server is a power boost, not a dependency.
2. **Privacy-first**: Sensitive data stays on-device unless explicitly routed to server. No telemetry.
3. **OpenClaw-compatible**: Skills use the AgentSkills SKILL.md standard. Cross-compatible with Claude Code, Codex, OpenClaw.
4. **Draft-and-confirm**: The agent drafts actions (emails, events, messages). The user confirms with one tap. No uncontrolled autonomy on mobile.
5. **Progressive disclosure**: Show only what's needed. Chat first. Mission Control for power users. Skill editor for developers.

---

## 2. Architecture Overview

### 2.1 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPS / HOME SERVER                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    OPENCLAW INSTANCE                    │  │
│  │                                                        │  │
│  │  Gateway (port 18789) ◄──── WebSocket ────►            │  │
│  │  ├── Agent Core (Claude / GPT / DeepSeek API)          │  │
│  │  ├── Model Router (multi-LLM, cost-aware)              │  │
│  │  ├── Tools: exec, browser, email, file, cron, nodes    │  │
│  │  ├── Skills: 50+ bundled + custom                      │  │
│  │  ├── Memory: persistent Markdown files                 │  │
│  │  ├── Sessions: isolated per channel/agent              │  │
│  │  └── Mission Control API (REST + WebSocket events)     │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬────────────────────────────────┘
                               │
              Secured WebSocket (wss://) + REST API
                               │
┌──────────────────────────────▼────────────────────────────────┐
│                     MOBILE DEVICE                              │
│                   Flutter "Pocket Claw" App                    │
│                   (Android • iOS • Web)                        │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    PRESENTATION LAYER                     │  │
│  │  ┌──────────┐ ┌──────────────┐ ┌──────────┐ ┌────────┐  │  │
│  │  │   CHAT   │ │   MISSION    │ │  MEMORY  │ │ SKILLS │  │  │
│  │  │  (voice, │ │   CONTROL    │ │ BROWSER  │ │MANAGER │  │  │
│  │  │  text,   │ │  (dashboard, │ │ (local + │ │(browse,│  │  │
│  │  │  photo)  │ │   agents,    │ │  server) │ │ edit,  │  │  │
│  │  │          │ │   tasks,     │ │          │ │install)│  │  │
│  │  │          │ │   cron,cost) │ │          │ │        │  │  │
│  │  └──────────┘ └──────────────┘ └──────────┘ └────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    ORCHESTRATION LAYER                    │  │
│  │                                                          │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │              SMART ROUTER                        │    │  │
│  │  │  Classifies every request → routes to:           │    │  │
│  │  │  • LOCAL (Gemma E2B + local skills)              │    │  │
│  │  │  • SERVER (OpenClaw Gateway + server skills)     │    │  │
│  │  │  • BRIDGE (device captures → server processes)   │    │  │
│  │  │  • DEVICE (native API: calendar, alarm, etc.)    │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │                                                          │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │  │
│  │  │ SKILL       │  │  PROMPT       │  │  SESSION       │  │  │
│  │  │ REGISTRY    │  │  BUILDER      │  │  MANAGER       │  │  │
│  │  │ (loads      │  │  (system +    │  │  (context,     │  │  │
│  │  │  SKILL.md,  │  │   skill +     │  │   history,     │  │  │
│  │  │  classifies │  │   memory +    │  │   state)       │  │  │
│  │  │  runtime)   │  │   query)      │  │                │  │  │
│  │  └─────────────┘  └──────────────┘  └────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    ENGINE LAYER                           │  │
│  │                                                          │  │
│  │  ┌─────────────────┐     ┌────────────────────────────┐  │  │
│  │  │  LOCAL LLM       │     │  GATEWAY CLIENT            │  │  │
│  │  │  (flutter_gemma)  │     │  (WebSocket + REST)        │  │  │
│  │  │                  │     │                            │  │  │
│  │  │  • Gemma 4 E2B   │     │  • Connect to OpenClaw     │  │  │
│  │  │  • Qwen3 0.6B    │     │  • Stream responses        │  │  │
│  │  │  • SmolLM 135M   │     │  • Send tasks              │  │  │
│  │  │                  │     │  • Receive events           │  │  │
│  │  │  • Inference      │     │  • Auth (token/pairing)    │  │  │
│  │  │  • Embeddings     │     │                            │  │  │
│  │  │  • Function calls │     │                            │  │  │
│  │  └─────────────────┘     └────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    DATA LAYER                             │  │
│  │                                                          │  │
│  │  ┌──────────┐  ┌───────────┐  ┌────────────┐            │  │
│  │  │ sqflite  │  │ local_hnsw│  │ Markdown   │            │  │
│  │  │ (SQLite) │  │ (vectors) │  │ Files      │            │  │
│  │  │          │  │           │  │ (notes,    │            │  │
│  │  │ settings │  │ note      │  │  memory,   │            │  │
│  │  │ sessions │  │ embeddings│  │  skills)   │            │  │
│  │  │ history  │  │ for RAG   │  │            │            │  │
│  │  │ tasks    │  │ search    │  │            │            │  │
│  │  └──────────┘  └───────────┘  └────────────┘            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    DEVICE LAYER                           │  │
│  │  Camera • Microphone • Calendar • Contacts • Files       │  │
│  │  Notifications • Alarms • Share Sheet • GPS • Clipboard  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### 2.2 Connectivity States

| State | Available | Behaviour |
|-------|-----------|-----------|
| **Offline** | Local LLM, local skills, device APIs, local notes | Fully functional for quick tasks. Mission Control shows cached last-known state. Server tasks queued for later. |
| **Online (metered)** | Above + Gateway API | Smart Router can use server for complex tasks. Mission Control live. Memory sync background. |
| **Online (Wi-Fi)** | Above + bulk operations | Full Mission Control, skill installation from ClawHub, model downloads, memory bulk sync. |

---

## 3. Smart Router

### 3.1 Purpose

The Smart Router is the decision engine that classifies every user request and routes it to the optimal execution path. The user never manually chooses — the router is transparent.

### 3.2 Routing Decision Tree

```
User Input (text / voice / photo)
       │
       ▼
┌──────────────────────┐
│ 1. CONNECTIVITY CHECK │
│    Is server reachable?│
└──────┬───────────────┘
       │
       ├── NO (offline) ──────────────────────► LOCAL ENGINE (forced)
       │                                        All processing on-device
       │
       ├── YES (online) ──► continue to classification
       │
       ▼
┌──────────────────────┐
│ 2. TASK CLASSIFICATION│
│    What kind of task?  │
└──────┬───────────────┘
       │
       ├── DEVICE-ONLY ──────────────────────► DEVICE API
       │   "Set alarm for 6am"                 (no LLM needed)
       │   "Take a photo"
       │
       ├── QUICK / SIMPLE ──────────────────► LOCAL LLM
       │   "Remind me to..."                   (Gemma E2B function call)
       │   "Save this as a note"
       │   "What's 15% of 2340?"
       │   "Read my last note"
       │   Response < 100 tokens expected
       │
       ├── COMPLEX / MULTI-STEP ────────────► OPENCLAW SERVER
       │   "Clear my inbox and summarise"      (full agent, cloud LLM)
       │   "Research X and draft a report"
       │   "Send email to Y about Z"
       │   "Create a PR for the bug fix"
       │   Needs: shell, browser, email, APIs
       │   Needs: long-context reasoning
       │
       ├── BRIDGE ──────────────────────────► DEVICE + SERVER
       │   "Photo this receipt and categorise"  (phone captures,
       │   "Transcribe this and email it"        server processes)
       │
       └── MISSION CONTROL ─────────────────► GATEWAY API
           "Show agent status"                  (REST/WebSocket query)
           "What's running?"
           "How much have I spent today?"
```

### 3.3 Classification Signals

The router uses these signals to classify (no LLM call needed — fast heuristics):

| Signal | Method | Example |
|--------|--------|---------|
| **Keyword match** | Regex patterns for known intents | "set alarm", "take photo", "remind me" → DEVICE/LOCAL |
| **Skill match** | Check if input matches a loaded skill description | "manage my inbox" → matches `inbox-manager` → check runtime field |
| **Complexity estimate** | Token count of expected response + required tools | Multi-tool tasks → SERVER |
| **Connectivity** | Network reachability check | No connection → LOCAL (forced) |
| **User override** | Explicit prefix commands | `/local ...` forces local, `/server ...` forces server |
| **Skill runtime field** | SKILL.md `metadata.pocketclaw.runtime` | `local`, `server`, or `bridge` |

### 3.4 Router Implementation (Dart)

```dart
enum RouteTarget { local, server, bridge, device, missionControl }

class SmartRouter {
  final ConnectivityService _connectivity;
  final SkillRegistry _skills;
  
  Future<RouteTarget> route(String input, {bool hasImage = false}) async {
    // 1. User override
    if (input.startsWith('/local ')) return RouteTarget.local;
    if (input.startsWith('/server ')) return RouteTarget.server;
    if (input.startsWith('/mc ')) return RouteTarget.missionControl;
    
    // 2. Device-only patterns (no LLM needed)
    if (_isDeviceOnly(input)) return RouteTarget.device;
    
    // 3. Mission Control queries
    if (_isMissionControlQuery(input)) return RouteTarget.missionControl;
    
    // 4. Check connectivity
    final isOnline = await _connectivity.isServerReachable();
    
    // 5. If offline, everything goes local
    if (!isOnline) return RouteTarget.local;
    
    // 6. Check if a skill claims this input
    final matchedSkill = _skills.matchSkill(input);
    if (matchedSkill != null) {
      return _skillRuntime(matchedSkill);
    }
    
    // 7. Bridge pattern: device input + complex processing
    if (hasImage && _isComplexProcessing(input)) {
      return RouteTarget.bridge;
    }
    
    // 8. Complexity classification
    if (_isSimpleTask(input)) return RouteTarget.local;
    
    // 9. Default: route to server for best quality
    return RouteTarget.server;
  }
  
  bool _isSimpleTask(String input) {
    final simplePatterns = [
      RegExp(r'remind me', caseSensitive: false),
      RegExp(r'save.*(note|this)', caseSensitive: false),
      RegExp(r'(calculate|what.s|how much)', caseSensitive: false),
      RegExp(r'(read|show|list).*(note|memo)', caseSensitive: false),
      RegExp(r'set.*(alarm|timer)', caseSensitive: false),
    ];
    return simplePatterns.any((p) => p.hasMatch(input));
  }
  
  bool _isDeviceOnly(String input) {
    final devicePatterns = [
      RegExp(r'^(take|snap).*(photo|picture|selfie)', caseSensitive: false),
      RegExp(r'^set alarm', caseSensitive: false),
      RegExp(r'^(start|set) timer', caseSensitive: false),
      RegExp(r'^open (camera|calendar|contacts)', caseSensitive: false),
    ];
    return devicePatterns.any((p) => p.hasMatch(input));
  }
  
  bool _isMissionControlQuery(String input) {
    final mcPatterns = [
      RegExp(r'(agent|agents).*(status|running|active)', caseSensitive: false),
      RegExp(r'(cost|spend|usage|tokens)', caseSensitive: false),
      RegExp(r'(cron|schedule|jobs)', caseSensitive: false),
      RegExp(r'(mission|task).*(control|board|kanban)', caseSensitive: false),
      RegExp(r'(gateway|server).*(health|status)', caseSensitive: false),
    ];
    return mcPatterns.any((p) => p.hasMatch(input));
  }
  
  RouteTarget _skillRuntime(Skill skill) {
    switch (skill.runtime) {
      case 'local': return RouteTarget.local;
      case 'server': return RouteTarget.server;
      case 'bridge': return RouteTarget.bridge;
      default: return RouteTarget.server;
    }
  }
}
```

---

## 4. Local Agent Engine

### 4.1 Purpose

Handles all on-device processing: LLM inference, embedding generation, vector search, function calling, and local skill execution. Powered by `flutter_gemma`.

### 4.2 Model Selection

```dart
class ModelSelector {
  /// Auto-selects best model based on device capabilities
  Future<LocalModelConfig> selectModel() async {
    final ram = await getAvailableRamMb();
    final hasGpu = await hasGpuDelegate();
    
    if (ram >= 6000 && hasGpu) {
      return LocalModelConfig(
        id: 'gemma-4-e2b',
        path: 'gemma-4-e2b-it.task',
        displayName: 'Gemma 4 E2B',
        capabilities: {
          ModelCap.text, ModelCap.vision, ModelCap.audio,
          ModelCap.functionCalling, ModelCap.thinking,
        },
        maxTokens: 1024,
        temperature: 0.3,
        ramRequiredMb: 1500,
      );
    } else if (ram >= 4000) {
      return LocalModelConfig(
        id: 'qwen3-06b',
        path: 'qwen3-0.6b.task',
        displayName: 'Qwen3 0.6B',
        capabilities: {
          ModelCap.text, ModelCap.functionCalling, ModelCap.thinking,
        },
        maxTokens: 768,
        temperature: 0.3,
        ramRequiredMb: 500,
      );
    } else {
      return LocalModelConfig(
        id: 'smollm-135m',
        path: 'smollm-135m.task',
        displayName: 'SmolLM 135M',
        capabilities: {ModelCap.text},
        maxTokens: 256,
        temperature: 0.3,
        ramRequiredMb: 200,
      );
    }
  }
}
```

### 4.3 Function Calling (Local Tools)

The local LLM uses Gemma 4 E2B's native function calling to interact with device APIs and local storage. Tools are registered as JSON schemas that the model can invoke:

```dart
/// Tool definitions provided to the local LLM
final localTools = [
  ToolDefinition(
    name: 'create_note',
    description: 'Save a note to local storage with a title and optional folder',
    parameters: {
      'title': {'type': 'string', 'required': true},
      'content': {'type': 'string', 'required': true},
      'folder': {'type': 'string', 'required': false, 'default': 'general'},
    },
  ),
  ToolDefinition(
    name: 'search_notes',
    description: 'Search local notes by keyword or semantic query',
    parameters: {
      'query': {'type': 'string', 'required': true},
      'limit': {'type': 'integer', 'required': false, 'default': 5},
    },
  ),
  ToolDefinition(
    name: 'create_reminder',
    description: 'Set a reminder notification at a specific time',
    parameters: {
      'title': {'type': 'string', 'required': true},
      'datetime': {'type': 'string', 'format': 'iso8601', 'required': true},
    },
  ),
  ToolDefinition(
    name: 'query_calendar',
    description: 'Query device calendar for events in a date range',
    parameters: {
      'start_date': {'type': 'string', 'format': 'iso8601', 'required': true},
      'end_date': {'type': 'string', 'format': 'iso8601', 'required': true},
    },
  ),
  ToolDefinition(
    name: 'calculate',
    description: 'Perform a mathematical calculation',
    parameters: {
      'expression': {'type': 'string', 'required': true},
    },
  ),
  ToolDefinition(
    name: 'draft_message',
    description: 'Draft a message for the user to review and send via share sheet',
    parameters: {
      'recipient': {'type': 'string', 'required': false},
      'subject': {'type': 'string', 'required': false},
      'body': {'type': 'string', 'required': true},
      'channel': {'type': 'string', 'enum': ['email', 'whatsapp', 'sms', 'generic']},
    },
  ),
  ToolDefinition(
    name: 'read_file',
    description: 'Read a file from local storage',
    parameters: {
      'path': {'type': 'string', 'required': true},
    },
  ),
  ToolDefinition(
    name: 'capture_photo',
    description: 'Open camera to capture a photo for OCR or processing',
    parameters: {
      'purpose': {'type': 'string', 'enum': ['ocr', 'save', 'process']},
    },
  ),
  ToolDefinition(
    name: 'text_to_speech',
    description: 'Read text aloud using device TTS',
    parameters: {
      'text': {'type': 'string', 'required': true},
      'language': {'type': 'string', 'required': false, 'default': 'en'},
    },
  ),
];
```

### 4.4 Local Agent Loop

```dart
class LocalAgent {
  final LlmEngine _llm;
  final ToolExecutor _tools;
  final MemoryManager _memory;
  final SkillRegistry _skills;
  
  /// Process a user request locally
  Stream<AgentResponse> process(UserMessage message) async* {
    // 1. Load relevant skill instructions (if skill matched)
    final skill = _skills.matchSkill(message.text);
    final skillInstructions = skill?.loadBody() ?? '';
    
    // 2. Retrieve relevant memory context
    final memoryContext = await _memory.searchLocal(
      message.text, limit: 3,
    );
    
    // 3. Build prompt with system + skill + memory + tools
    final prompt = PromptBuilder.build(
      systemPrompt: _buildSystemPrompt(),
      skillInstructions: skillInstructions,
      memoryContext: memoryContext,
      tools: localTools,
      userMessage: message.text,
      conversationHistory: _sessionManager.recentHistory(limit: 10),
    );
    
    // 4. Stream LLM response
    await for (final chunk in _llm.generateStream(prompt)) {
      // 5. Check for function calls in response
      if (chunk.isFunctionCall) {
        final result = await _tools.execute(chunk.functionCall);
        
        // 6. Feed result back to LLM for natural language response
        yield* _llm.continueWithResult(result);
      } else {
        yield AgentResponse.text(chunk.text);
      }
    }
    
    // 7. Log interaction to session history
    _sessionManager.log(message, response);
  }
  
  String _buildSystemPrompt() => '''
You are Pocket Claw, a personal AI assistant running on the user's phone.
You are helpful, concise, and action-oriented.

CAPABILITIES:
- Create and search notes (local, private)
- Set reminders and alarms
- Query the device calendar
- Perform calculations
- Draft messages (user confirms before sending)
- Capture and process photos (OCR)
- Read files from local storage
- Read text aloud

RULES:
1. Be concise. This is a mobile screen — short responses.
2. When you need to take action, use function calling.
3. For messages/emails: ALWAYS draft first, never claim to send.
4. If a task is beyond your capabilities, say so clearly.
5. Protect user privacy — never suggest sending data externally.
''';
}
```

---

## 5. OpenClaw Server Integration

### 5.1 Gateway Client

The Gateway Client manages the WebSocket connection to the OpenClaw instance on the VPS. It handles authentication, message routing, streaming responses, and event subscriptions for Mission Control.

```dart
class GatewayClient {
  WebSocketChannel? _channel;
  final String gatewayUrl;       // wss://your-vps:18789
  final String authToken;
  
  // Connection state
  final _connectionState = ValueNotifier<GatewayState>(GatewayState.disconnected);
  ValueListenable<GatewayState> get connectionState => _connectionState;
  
  // Event streams
  final _agentEvents = StreamController<AgentEvent>.broadcast();
  Stream<AgentEvent> get agentEvents => _agentEvents.stream;
  
  final _responses = StreamController<ServerResponse>.broadcast();
  Stream<ServerResponse> get responses => _responses.stream;
  
  /// Connect to OpenClaw Gateway
  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(gatewayUrl),
        headers: {'Authorization': 'Bearer $authToken'},
      );
      
      _connectionState.value = GatewayState.connected;
      
      _channel!.stream.listen(
        (data) => _handleMessage(jsonDecode(data)),
        onError: (e) => _handleError(e),
        onDone: () => _handleDisconnect(),
      );
    } catch (e) {
      _connectionState.value = GatewayState.error;
    }
  }
  
  /// Send a task to OpenClaw for processing
  Future<void> sendTask(String message, {String? sessionKey}) async {
    _channel?.sink.add(jsonEncode({
      'type': 'message',
      'content': message,
      'sessionKey': sessionKey ?? 'pocket-claw-main',
      'source': 'pocket-claw',
    }));
  }
  
  /// Handle incoming messages from Gateway
  void _handleMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'response':
        _responses.add(ServerResponse.fromJson(data));
        break;
      case 'event':
        _agentEvents.add(AgentEvent.fromJson(data));
        break;
      case 'heartbeat':
        // Agent proactive check-in
        _agentEvents.add(AgentEvent.heartbeat(data));
        break;
    }
  }
  
  /// Graceful reconnect with exponential backoff
  Future<void> _handleDisconnect() async {
    _connectionState.value = GatewayState.reconnecting;
    for (int delay in [1, 2, 4, 8, 16, 30]) {
      await Future.delayed(Duration(seconds: delay));
      try {
        await connect();
        if (_connectionState.value == GatewayState.connected) return;
      } catch (_) {}
    }
    _connectionState.value = GatewayState.disconnected;
  }
}
```

### 5.2 REST API Client (Mission Control Data)

```dart
class GatewayRestClient {
  final String baseUrl;   // https://your-vps:18789
  final String authToken;
  final Dio _dio;
  
  // ── Agent Management ──
  Future<List<Agent>> getAgents() async {
    final res = await _dio.get('/api/agents');
    return (res.data as List).map((a) => Agent.fromJson(a)).toList();
  }
  
  // ── Session Management ──
  Future<List<Session>> getSessions({String? agentId}) async {
    final res = await _dio.get('/api/sessions', 
      queryParameters: {'agentId': agentId});
    return (res.data as List).map((s) => Session.fromJson(s)).toList();
  }
  
  // ── Task / Mission Board ──
  Future<List<Task>> getTasks({String? status}) async {
    final res = await _dio.get('/api/tasks',
      queryParameters: {'status': status});
    return (res.data as List).map((t) => Task.fromJson(t)).toList();
  }
  
  Future<Task> createTask(TaskCreate task) async {
    final res = await _dio.post('/api/tasks', data: task.toJson());
    return Task.fromJson(res.data);
  }
  
  Future<void> updateTaskStatus(String taskId, String status) async {
    await _dio.patch('/api/tasks/$taskId', data: {'status': status});
  }
  
  // ── Cron Jobs ──
  Future<List<CronJob>> getCronJobs() async {
    final res = await _dio.get('/api/cron');
    return (res.data as List).map((c) => CronJob.fromJson(c)).toList();
  }
  
  // ── Cost Tracking ──
  Future<UsageStats> getUsageStats({String? period}) async {
    final res = await _dio.get('/api/usage',
      queryParameters: {'period': period ?? 'today'});
    return UsageStats.fromJson(res.data);
  }
  
  // ── Memory (Server) ──
  Future<List<MemoryFile>> getMemoryFiles({String? path}) async {
    final res = await _dio.get('/api/memory',
      queryParameters: {'path': path ?? '/'});
    return (res.data as List).map((m) => MemoryFile.fromJson(m)).toList();
  }
  
  Future<String> getMemoryFileContent(String path) async {
    final res = await _dio.get('/api/memory/content',
      queryParameters: {'path': path});
    return res.data['content'];
  }
  
  // ── Skills ──
  Future<List<SkillInfo>> getInstalledSkills() async {
    final res = await _dio.get('/api/skills');
    return (res.data as List).map((s) => SkillInfo.fromJson(s)).toList();
  }
  
  Future<void> installSkill(String slug) async {
    await _dio.post('/api/skills/install', data: {'slug': slug});
  }
  
  // ── System Health ──
  Future<SystemHealth> getSystemHealth() async {
    final res = await _dio.get('/api/health');
    return SystemHealth.fromJson(res.data);
  }
}
```

---

## 6. Skill System

### 6.1 SKILL.md Format (OpenClaw-Compatible)

Pocket Claw uses the standard AgentSkills SKILL.md format, with one extension: a `pocketclaw` metadata block that declares the runtime tier.

```yaml
---
name: my-skill
description: >
  What this skill does and when to trigger it.
  Include specific trigger phrases and contexts.
metadata:
  pocketclaw:
    runtime: local          # local | server | bridge
    requires:
      device_apis: []       # camera, calendar, contacts, files, tts, stt
      env: []               # environment variables (server skills)
      bins: []              # CLI tools (server skills)
  openclaw:                 # standard OpenClaw metadata (for server skills)
    requires:
      env: []
      bins: []
    primaryEnv: ""
emoji: "📝"
---

# Skill Instructions (Markdown)

## Workflow
1. Step one...
2. Step two...

## Output Format
...

## Error Handling
...
```

### 6.2 Skill Runtime Tiers

| Tier | Runtime | Executed By | When To Use |
|------|---------|-------------|-------------|
| **Local** | `local` | Gemma E2B on phone | Quick tasks, device APIs, privacy-sensitive, offline capable |
| **Server** | `server` | OpenClaw on VPS | Shell commands, web browsing, email, complex multi-step, API integrations |
| **Bridge** | `bridge` | Phone captures → server processes | Device input needed (camera, mic) + complex processing (OCR + categorise + email) |

### 6.3 Skill Registry (Dart)

```dart
class SkillRegistry {
  final List<Skill> _skills = [];
  
  /// Load skills from all sources (precedence order)
  Future<void> loadSkills() async {
    _skills.clear();
    
    // 1. Bundled skills (shipped with app)
    _skills.addAll(await _loadFromAssets('assets/skills/'));
    
    // 2. Downloaded/installed skills
    _skills.addAll(await _loadFromDirectory(
      '${appDir}/skills/',
    ));
    
    // 3. User-created skills (highest precedence)
    _skills.addAll(await _loadFromDirectory(
      '${appDir}/user-skills/',
    ));
    
    // Deduplicate by name (later sources win)
    _deduplicate();
    
    log('Loaded ${_skills.length} skills '
        '(${_skills.where((s) => s.runtime == "local").length} local, '
        '${_skills.where((s) => s.runtime == "server").length} server, '
        '${_skills.where((s) => s.runtime == "bridge").length} bridge)');
  }
  
  /// Match a user input to the best skill
  /// Uses the description field only (progressive disclosure)
  Skill? matchSkill(String input) {
    // Simple keyword matching against skill descriptions
    // The LLM can also be asked to select if ambiguous
    for (final skill in _skills) {
      if (skill.matchesInput(input)) return skill;
    }
    return null;
  }
  
  /// Get compact skill list for system prompt injection
  /// (names + descriptions only, ~24 tokens per skill)
  String formatForPrompt() {
    return _skills
      .where((s) => s.runtime == 'local' && !s.disableModelInvocation)
      .map((s) => '<skill name="${s.name}">${s.description}</skill>')
      .join('\n');
  }
}
```

### 6.4 Example Skills

**Local Skill: Forex Position Calculator**

```yaml
---
name: forex-position-calc
description: >
  Calculate forex position size, lot size, and risk amount.
  Trigger when user mentions: position size, lot size, risk calculation,
  money management, forex risk, pip value, or "how much to trade".
metadata:
  pocketclaw:
    runtime: local
    requires:
      device_apis: []
emoji: "💱"
---

# Forex Position Calculator

## Workflow

1. Extract from user message or ask for:
   - Account balance (in account currency)
   - Risk percentage (e.g., 1%, 2%)
   - Stop loss distance in pips
   - Currency pair (default: XAUUSD)

2. Calculate:
   - Risk amount = balance × (risk% / 100)
   - Pip value for the pair (XAUUSD: $0.10 per pip per micro lot)
   - Position size = risk_amount / (stop_loss_pips × pip_value)
   - Convert to standard lots (÷ 100,000) and micro lots (÷ 1,000)

3. Return formatted result:
   ```
   Account: $10,000 | Risk: 1% ($100)
   Stop Loss: 50 pips
   Position Size: 0.20 standard lots (20 micro lots)
   Pip Value: $2.00 per pip
   ```

4. Warn if position size exceeds 5% of account balance (over-leveraged).

## Common Pairs Reference
- XAUUSD: pip = 0.1, pip value per micro = $0.10
- EURUSD: pip = 0.0001, pip value per micro = $0.10
- GBPUSD: pip = 0.0001, pip value per micro = $0.10
- USDJPY: pip = 0.01, pip value per micro ≈ $0.07
```

**Server Skill: Inbox Manager**

```yaml
---
name: inbox-manager
description: >
  Triage, summarise, and manage email inbox.
  Trigger when user mentions: email, inbox, messages, unread,
  "check my mail", "clear inbox", "summarise emails".
metadata:
  pocketclaw:
    runtime: server
    requires:
      env: [IMAP_HOST, IMAP_USER, IMAP_PASS]
      bins: [himalaya]
  openclaw:
    requires:
      env: [IMAP_HOST, IMAP_USER, IMAP_PASS]
      bins: [himalaya]
    primaryEnv: IMAP_HOST
emoji: "📧"
---

# Inbox Manager

## Workflow

1. List unread emails: `himalaya list --folder INBOX --filter unseen`
2. Categorise each email:
   - URGENT: needs immediate response
   - ACTION: needs response but not urgent
   - INFO: read-only, no response needed
   - SPAM: can be archived/deleted
3. Present summary to user grouped by category
4. For each email user wants to respond to:
   - Draft a response based on user's instruction
   - Present draft for approval (draft-and-confirm pattern)
   - On approval, send via himalaya

## Rules
- NEVER send an email without user approval
- NEVER delete emails without user approval
- Always show sender, subject, and first 2 lines of body in summaries
```

**Bridge Skill: Receipt Scanner**

```yaml
---
name: receipt-scanner
description: >
  Photograph a receipt or invoice, extract data, categorise expense.
  Trigger when user mentions: receipt, invoice, expense, scan receipt,
  "photo this bill", "log expense".
metadata:
  pocketclaw:
    runtime: bridge
    requires:
      device_apis: [camera]
emoji: "🧾"
---

# Receipt Scanner

## Bridge Workflow

### Phase 1: Device (Phone)
1. Open camera via `capture_photo` tool
2. User takes photo of receipt
3. Run on-device OCR (Gemma vision) to extract raw text
4. Send extracted text to server for processing

### Phase 2: Server (OpenClaw)
1. Parse extracted text into structured data:
   - Vendor name
   - Date
   - Line items with amounts
   - Total amount
   - Payment method (if visible)
   - VAT amount (if visible)
2. Categorise expense (food, transport, office, client, etc.)
3. Return structured JSON to phone

### Phase 3: Device (Phone)
1. Display parsed receipt for user review
2. Save to local expense tracker (SQLite)
3. Optionally: create note with receipt data
4. Optionally: forward to server for accounting integration

## Output Format
```
🧾 Receipt Captured
Vendor: Woolworths
Date: 2026-04-09
Items: 5
Total: R342.50
Category: Groceries
Saved to: Expenses/April 2026
```
```

---

## 7. Mission Control Mobile

### 7.1 Purpose

A native Flutter implementation of the OpenClaw Mission Control dashboard, consuming the same Gateway WebSocket and REST APIs that the web-based Mission Control uses. Provides real-time visibility into the OpenClaw server from the phone.

### 7.2 Screens

#### 7.2.1 Dashboard (Home)

```
┌─────────────────────────────────────┐
│  MISSION CONTROL                    │
│  ● Connected to gateway             │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────┐ ┌─────────┐ ┌───────┐ │
│  │ AGENTS  │ │  TASKS  │ │ COST  │ │
│  │  3 / 3  │ │  7 open │ │$12.40 │ │
│  │ active  │ │  2 doing│ │ today │ │
│  └─────────┘ └─────────┘ └───────┘ │
│                                     │
│  SYSTEM HEALTH                      │
│  CPU ████████░░ 78%                 │
│  RAM ██████░░░░ 62%                 │
│  DSK ████░░░░░░ 41%                 │
│                                     │
│  RECENT ACTIVITY                    │
│  ● inbox-agent cleared 12 emails    │
│  ● code-agent opened PR #42         │
│  ● research-agent saved 3 notes     │
│                                     │
│  NEXT CRON                          │
│  📅 Daily briefing — in 2h 15m     │
│  📊 Usage report — in 6h 43m       │
│                                     │
└─────────────────────────────────────┘
```

#### 7.2.2 Agent List

```
┌─────────────────────────────────────┐
│  ◀ AGENTS                           │
├─────────────────────────────────────┤
│                                     │
│  🟢 inbox-agent                     │
│     Model: claude-sonnet-4-20250514 │
│     Session: active (12 min)        │
│     Tokens: 14,230 today            │
│     [Chat] [Pause] [Sessions]       │
│                                     │
│  🟢 code-agent                      │
│     Model: claude-sonnet-4-20250514 │
│     Session: idle                   │
│     Tokens: 8,412 today             │
│     [Chat] [Pause] [Sessions]       │
│                                     │
│  🟡 research-agent                  │
│     Model: deepseek-v3              │
│     Session: processing...          │
│     Tokens: 22,100 today            │
│     [Chat] [Pause] [Sessions]       │
│                                     │
└─────────────────────────────────────┘
```

#### 7.2.3 Task Kanban

```
┌──────────────────────────────────────────┐
│  ◀ TASKS                                  │
├──────────────────────────────────────────┤
│  [Inbox] [Assigned] [Doing] [Review] [Done]│
│                                           │
│  ── INBOX (3) ──                          │
│  ┌─────────────────────────────────────┐  │
│  │ 🔴 Review SS&C SLA proposal         │  │
│  │    Created: 2h ago                  │  │
│  │    [Assign] [→ Doing]              │  │
│  └─────────────────────────────────────┘  │
│  ┌─────────────────────────────────────┐  │
│  │ 🟡 Update CRT EA documentation      │  │
│  │    Created: 5h ago                  │  │
│  │    [Assign] [→ Doing]              │  │
│  └─────────────────────────────────────┘  │
│                                           │
│  ── DOING (2) ──                          │
│  ┌─────────────────────────────────────┐  │
│  │ 🟢 Research CAPS Grade 11 Physics   │  │
│  │    Agent: research-agent            │  │
│  │    Progress: 67%                    │  │
│  │    [View] [→ Review]               │  │
│  └─────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

#### 7.2.4 Cost Tracker

```
┌─────────────────────────────────────┐
│  ◀ COST TRACKING                    │
├─────────────────────────────────────┤
│                                     │
│  TODAY: $12.40                      │
│  THIS WEEK: $67.22                  │
│  THIS MONTH: $189.50                │
│                                     │
│  BY MODEL            ████████       │
│  Claude Sonnet       $8.20 (66%)    │
│  DeepSeek V3         $3.10 (25%)    │
│  GPT-4o              $1.10 (9%)     │
│                                     │
│  BY AGENT            ████████       │
│  inbox-agent         $4.50          │
│  code-agent          $3.80          │
│  research-agent      $4.10          │
│                                     │
│  TOKEN USAGE                        │
│  Input:  142,300 tokens             │
│  Output:  38,200 tokens             │
│                                     │
│  [Daily] [Weekly] [Monthly]         │
└─────────────────────────────────────┘
```

#### 7.2.5 Memory Browser

```
┌─────────────────────────────────────┐
│  ◀ MEMORY                           │
│  [Local] [Server]                   │
├─────────────────────────────────────┤
│                                     │
│  📁 Server Memory                   │
│  ├── 📁 projects/                   │
│  │   ├── 📄 sanlam-iap.md          │
│  │   ├── 📄 carmen-ai-rd.md         │
│  │   └── 📄 lekkerswot.md          │
│  ├── 📁 people/                     │
│  │   ├── 📄 brendon-fxhd.md        │
│  │   └── 📄 contacts.md            │
│  ├── 📁 forex/                      │
│  │   ├── 📄 crt-model1.md          │
│  │   └── 📄 daily-bias.md          │
│  └── 📄 daily-briefing.md          │
│                                     │
│  🔍 Search: [________________]     │
│                                     │
│  📱 Local Memory                    │
│  ├── 📄 quick-notes.md             │
│  ├── 📄 meeting-notes-apr.md       │
│  └── 📄 expenses-apr.md            │
│                                     │
│  ↻ Last sync: 5 min ago            │
└─────────────────────────────────────┘
```

### 7.3 Real-Time Event Handling

```dart
class MissionControlService {
  final GatewayClient _gateway;
  final GatewayRestClient _rest;
  
  // Reactive state holders (Riverpod providers)
  final agents = StateNotifier<List<Agent>>([]);
  final tasks = StateNotifier<List<Task>>([]);
  final activity = StateNotifier<List<ActivityEvent>>([]);
  final health = StateNotifier<SystemHealth?>(null);
  final usage = StateNotifier<UsageStats?>(null);
  
  /// Subscribe to real-time Gateway events
  void startListening() {
    _gateway.agentEvents.listen((event) {
      switch (event.type) {
        case EventType.agentStart:
        case EventType.agentEnd:
        case EventType.agentError:
          _refreshAgents();
          break;
        case EventType.taskProgress:
          _updateTask(event.taskId, event.data);
          break;
        case EventType.heartbeat:
          activity.add(ActivityEvent.fromHeartbeat(event));
          break;
      }
    });
    
    // Periodic refresh for non-event data
    Timer.periodic(Duration(seconds: 30), (_) => _refreshHealth());
    Timer.periodic(Duration(minutes: 5), (_) => _refreshUsage());
  }
  
  Future<void> _refreshAgents() async {
    agents.state = await _rest.getAgents();
  }
  
  Future<void> _refreshHealth() async {
    health.state = await _rest.getSystemHealth();
  }
  
  Future<void> _refreshUsage() async {
    usage.state = await _rest.getUsageStats();
  }
}
```

---

## 8. Memory System

### 8.1 Dual Memory Architecture

```
┌────────────────────────┐     ┌────────────────────────┐
│    LOCAL MEMORY         │     │    SERVER MEMORY        │
│    (always available)   │     │    (when connected)     │
│                         │     │                         │
│  Markdown files on      │◄───►│  OpenClaw persistent    │
│  device storage         │sync │  memory (~/.openclaw/   │
│                         │     │  memory/)               │
│  + Vector embeddings    │     │                         │
│    for RAG search       │     │  Managed by OpenClaw    │
│                         │     │  agent automatically    │
│  User-created notes     │     │                         │
│  Quick captures         │     │  Project context        │
│  Private/sensitive      │     │  Research findings      │
│  Offline-first          │     │  Email summaries        │
└────────────────────────┘     └────────────────────────┘
```

### 8.2 Memory Sync Strategy

| Scenario | Behaviour |
|----------|-----------|
| **New local note** | Saved to device immediately. Queued for server sync. |
| **Server memory updated** | Next refresh pulls changes. Conflicts resolved by timestamp (latest wins). |
| **Offline edits** | Stored locally with pending flag. Synced when connection restored. |
| **Private notes** | Marked `sync: false` in frontmatter. Never leave device. |
| **Search** | Local vector search first (instant). Server search second (if online). Merged results. |

### 8.3 Note Format (Markdown with Frontmatter)

```markdown
---
id: "note-20260409-143022"
title: "SS&C SLA Review Notes"
folder: "sanlam/iap"
tags: ["sanlam", "sla", "ss&c"]
created: "2026-04-09T14:30:22Z"
modified: "2026-04-09T15:12:00Z"
sync: true
source: "local"
---

# SS&C SLA Review Notes

Key points from the SLA proposal review:

- Response times: P1 = 15 min, P2 = 1 hour
- Uptime SLA: 99.95% (excludes planned maintenance)
- ...
```

---

## 9. Device API Layer

### 9.1 Available Device APIs

| API | Flutter Plugin | What It Enables | Platform |
|-----|---------------|-----------------|----------|
| **Camera** | `camera` | Photo capture for OCR, document scanning | Android, iOS |
| **Calendar** | `device_calendar` | Query/create events | Android, iOS |
| **Contacts** | `contacts_service` | Search contacts by name | Android, iOS |
| **Notifications** | `flutter_local_notifications` | Reminders, alerts, agent messages | Android, iOS |
| **Alarms** | `android_alarm_manager_plus` | Wake-up alarms, scheduled tasks | Android |
| **Files** | `path_provider` + `file_picker` | Read/write local files | All |
| **Share Sheet** | `share_plus` | Send drafted messages via any app | Android, iOS |
| **Clipboard** | `clipboard` (built-in) | Read/write clipboard | All |
| **TTS** | `flutter_tts` | Read notes/responses aloud | Android, iOS |
| **STT** | Gemma E2B native audio | Voice input processing | Android (6GB+) |
| **GPS** | `geolocator` | Location context (weather, nearby) | Android, iOS |
| **Biometrics** | `local_auth` | Fingerprint/face unlock for app | Android, iOS |

### 9.2 Tool Executor (Maps Function Calls to Device APIs)

```dart
class ToolExecutor {
  final CalendarService _calendar;
  final NotesService _notes;
  final CameraService _camera;
  final NotificationService _notifications;
  final TtsService _tts;
  final FileService _files;
  final CalculatorService _calculator;
  final ShareService _share;
  
  /// Execute a function call from the LLM
  Future<ToolResult> execute(FunctionCall call) async {
    switch (call.name) {
      case 'create_note':
        return _notes.create(
          title: call.args['title'],
          content: call.args['content'],
          folder: call.args['folder'] ?? 'general',
        );
        
      case 'search_notes':
        return _notes.search(
          query: call.args['query'],
          limit: call.args['limit'] ?? 5,
        );
        
      case 'create_reminder':
        return _notifications.scheduleReminder(
          title: call.args['title'],
          dateTime: DateTime.parse(call.args['datetime']),
        );
        
      case 'query_calendar':
        return _calendar.getEvents(
          start: DateTime.parse(call.args['start_date']),
          end: DateTime.parse(call.args['end_date']),
        );
        
      case 'calculate':
        return _calculator.evaluate(call.args['expression']);
        
      case 'draft_message':
        return _share.draft(
          body: call.args['body'],
          recipient: call.args['recipient'],
          subject: call.args['subject'],
          channel: call.args['channel'] ?? 'generic',
        );
        
      case 'capture_photo':
        return _camera.capture(purpose: call.args['purpose']);
        
      case 'read_file':
        return _files.read(call.args['path']);
        
      case 'text_to_speech':
        return _tts.speak(
          call.args['text'],
          language: call.args['language'] ?? 'en',
        );
        
      default:
        return ToolResult.error('Unknown tool: ${call.name}');
    }
  }
}
```

---

## 10. User Interface

### 10.1 Navigation Structure

```
┌──────────────────────────────────────┐
│  POCKET CLAW                         │
├──────────────────────────────────────┤
│                                      │
│  Bottom Navigation:                  │
│                                      │
│  🏠 Chat    📊 Control   🧠 Memory   │
│  🔧 Skills  ⚙️ Settings              │
│                                      │
└──────────────────────────────────────┘
```

### 10.2 Chat Screen (Primary)

The default screen. Voice-first or text input. Shows responses from both local and server agents seamlessly. A small indicator shows which engine handled each response.

Design features:
- Streaming token display (typewriter effect)
- Function call indicators ("Setting reminder..." with spinner)
- Draft-and-confirm cards for actions (email, calendar event, message)
- Photo preview for bridge skill captures
- Voice waveform during audio input
- Connection status indicator (🟢 online, 🟡 local-only, 🔴 error)

### 10.3 Design Language

- **Primary colour:** Lobster red (#E53935) — nod to OpenClaw's lobster mascot
- **Secondary:** Deep charcoal (#1A1A2E)
- **Accent:** Electric teal (#00E5CC) — for local processing indicators
- **Typography:** JetBrains Mono (display/code) + Inter (body)
- **Dark mode:** Default (power users prefer dark)
- **Tone:** Technical but approachable. Developer tool, not consumer app.

---

## 11. Security Model

### 11.1 Principles

| Principle | Implementation |
|-----------|---------------|
| **Local data stays local** | Private notes never sync. Local LLM processes sensitive queries on-device. |
| **Gateway auth** | Token-based authentication. Token stored in Flutter secure storage (encrypted). |
| **Transport security** | WSS (TLS) for all Gateway communication. Certificate pinning optional. |
| **App lock** | Optional biometric (fingerprint/face) to open app. |
| **Draft-and-confirm** | Agent NEVER sends emails/messages autonomously. Always shows draft for user approval. |
| **Skill sandboxing** | Local skills can only access registered tools. No arbitrary code execution on mobile. |
| **No telemetry** | Zero analytics. No data leaves device except to your own VPS. |
| **Skill review** | Warn user when installing third-party skills. Show permissions required. |

### 11.2 Authentication Flow

```
First Launch:
1. User enters Gateway URL (wss://your-vps:18789)
2. App generates a pairing request
3. User confirms pairing via SSH terminal on VPS (same as OpenClaw web pairing)
4. Gateway returns auth token
5. Token stored in flutter_secure_storage (encrypted, biometric-protected)

Subsequent launches:
1. App reads token from secure storage
2. Connects to Gateway with token in header
3. If token expired → re-pair flow
```

---

## 12. Technology Stack

### 12.1 Mobile Application (Flutter)

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Framework** | Flutter 3.x (Dart) | Cross-platform: Android, iOS, Web |
| **UI** | Material 3 + custom widgets | Adaptive layout |
| **State** | Riverpod | Reactive state management |
| **LLM** | `flutter_gemma` | On-device inference, embeddings, vector search |
| **Vector search** | `local_hnsw` (via flutter_gemma) | Local RAG over notes |
| **Database** | `sqflite` | Settings, sessions, tasks, history |
| **Files** | `path_provider` | Local notes, skills, memory as Markdown |
| **WebSocket** | `web_socket_channel` | Gateway real-time connection |
| **HTTP** | `dio` | Gateway REST API calls |
| **Camera** | `camera` | Photo capture |
| **Calendar** | `device_calendar` | Calendar integration |
| **Notifications** | `flutter_local_notifications` | Reminders, alerts |
| **TTS** | `flutter_tts` | Text-to-speech |
| **Share** | `share_plus` | Draft-and-confirm message sending |
| **Security** | `flutter_secure_storage` | Encrypted token storage |
| **Auth** | `local_auth` | Biometric app lock |
| **Charts** | `fl_chart` | Cost tracking, dashboard visuals |
| **Markdown** | `flutter_markdown` | Render notes, memory files |
| **YAML** | `yaml` | Parse SKILL.md frontmatter |

### 12.2 Server (OpenClaw on VPS)

| Component | Technology |
|-----------|------------|
| **Runtime** | OpenClaw (Node.js/TypeScript) |
| **LLM** | Claude API / GPT-4o / DeepSeek V3 (BYOK) |
| **Gateway** | Built-in, port 18789 (WebSocket + REST) |
| **Memory** | Persistent Markdown files |
| **Skills** | 50+ bundled + custom SKILL.md |
| **Tools** | exec, browser (Playwright), email (himalaya), file, cron, nodes |
| **Mission Control** | robsannaa/openclaw-mission-control or built-in Control UI |
| **Process manager** | PM2 or systemd |
| **OS** | Ubuntu 22.04+ (recommended) |

---

## 13. Flutter Project Structure

```
pocket_claw/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart                      # MaterialApp, theme, router
│   │   ├── theme.dart                    # Design tokens
│   │   └── router.dart                   # GoRouter navigation
│   │
│   ├── features/
│   │   ├── chat/                         # Primary chat interface
│   │   │   ├── chat_screen.dart
│   │   │   ├── chat_bubble.dart
│   │   │   ├── voice_input_widget.dart
│   │   │   ├── draft_confirm_card.dart   # Action confirmation cards
│   │   │   ├── function_call_indicator.dart
│   │   │   └── photo_preview.dart
│   │   │
│   │   ├── mission_control/              # Dashboard screens
│   │   │   ├── dashboard_screen.dart     # Overview
│   │   │   ├── agents_screen.dart        # Agent list + status
│   │   │   ├── tasks_screen.dart         # Kanban board
│   │   │   ├── cost_screen.dart          # Token/cost tracking
│   │   │   ├── cron_screen.dart          # Scheduled jobs
│   │   │   ├── activity_screen.dart      # Event log
│   │   │   └── health_widget.dart        # System health bars
│   │   │
│   │   ├── memory/                       # Memory browser
│   │   │   ├── memory_screen.dart
│   │   │   ├── note_editor.dart
│   │   │   ├── file_browser.dart
│   │   │   └── search_view.dart
│   │   │
│   │   ├── skills/                       # Skill management
│   │   │   ├── skills_screen.dart
│   │   │   ├── skill_detail.dart
│   │   │   ├── skill_editor.dart         # Write/edit SKILL.md
│   │   │   ├── clawhub_browser.dart      # Browse ClawHub registry
│   │   │   └── skill_installer.dart
│   │   │
│   │   ├── settings/                     # App settings
│   │   │   ├── settings_screen.dart
│   │   │   ├── gateway_config.dart       # Server connection setup
│   │   │   ├── model_config.dart         # Local model selection
│   │   │   └── security_settings.dart
│   │   │
│   │   └── onboarding/                   # First launch
│   │       ├── welcome_screen.dart
│   │       ├── gateway_setup.dart
│   │       └── model_download.dart
│   │
│   ├── core/
│   │   ├── router/
│   │   │   └── smart_router.dart         # Task classification + routing
│   │   │
│   │   ├── local_agent/
│   │   │   ├── local_agent.dart          # On-device agent loop
│   │   │   ├── llm_engine.dart           # flutter_gemma wrapper
│   │   │   ├── model_selector.dart       # Auto-select best model
│   │   │   ├── prompt_builder.dart       # System + skill + context prompt
│   │   │   └── tool_executor.dart        # Function call → device API
│   │   │
│   │   ├── gateway/
│   │   │   ├── gateway_client.dart       # WebSocket connection
│   │   │   ├── gateway_rest.dart         # REST API client
│   │   │   └── gateway_models.dart       # Agent, Task, Session, etc.
│   │   │
│   │   ├── skills/
│   │   │   ├── skill_registry.dart       # Load, match, manage skills
│   │   │   ├── skill_parser.dart         # Parse SKILL.md YAML + body
│   │   │   └── skill.dart                # Skill data model
│   │   │
│   │   ├── memory/
│   │   │   ├── memory_manager.dart       # Dual local/server memory
│   │   │   ├── local_memory.dart         # Markdown files + RAG
│   │   │   ├── server_memory.dart        # Gateway memory API
│   │   │   └── memory_sync.dart          # Bi-directional sync
│   │   │
│   │   ├── session/
│   │   │   ├── session_manager.dart      # Conversation context
│   │   │   └── session_history.dart      # Persistence
│   │   │
│   │   └── device/
│   │       ├── calendar_service.dart
│   │       ├── camera_service.dart
│   │       ├── notification_service.dart
│   │       ├── tts_service.dart
│   │       ├── share_service.dart
│   │       └── file_service.dart
│   │
│   ├── data/
│   │   ├── database/
│   │   │   ├── app_database.dart         # sqflite schema
│   │   │   └── daos/                     # Data access objects
│   │   ├── models/                       # Data classes
│   │   └── providers/                    # Riverpod providers
│   │
│   └── shared/
│       ├── widgets/                      # Reusable components
│       ├── constants.dart
│       └── extensions.dart
│
├── assets/
│   ├── skills/                           # Bundled default skills
│   │   ├── notes/SKILL.md
│   │   ├── calculator/SKILL.md
│   │   ├── forex-calc/SKILL.md
│   │   └── reminder/SKILL.md
│   ├── fonts/
│   └── images/
│
├── android/
├── ios/
├── web/
├── test/
├── pubspec.yaml
└── README.md
```

---

## 14. Data Models

### 14.1 Core Models (Dart)

```dart
// ── Agent ──
class Agent {
  final String id;
  final String name;
  final String model;
  final AgentStatus status;   // active, idle, error
  final String? currentSession;
  final int tokensToday;
  final String? emoji;
  final String? color;
}

// ── Task ──
class Task {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;    // inbox, assigned, inProgress, review, done
  final TaskPriority priority; // low, medium, high, urgent
  final String? assignedAgent;
  final DateTime createdAt;
  final DateTime? completedAt;
}

// ── Session ──
class Session {
  final String key;
  final String agentId;
  final String source;        // pocket-claw, telegram, whatsapp, etc.
  final DateTime startedAt;
  final int messageCount;
  final int tokenCount;
  final bool isActive;
}

// ── Skill ──
class Skill {
  final String name;
  final String description;
  final String runtime;       // local, server, bridge
  final String? emoji;
  final Map<String, dynamic> metadata;
  final String bodyPath;      // path to full SKILL.md
  final List<String> requiredDeviceApis;
  final List<String> requiredEnv;
  final List<String> requiredBins;
  
  bool matchesInput(String input) {
    // Match against description keywords
    final keywords = description.toLowerCase().split(RegExp(r'[\s,.:]+'));
    final inputWords = input.toLowerCase().split(RegExp(r'[\s]+'));
    final matchCount = inputWords.where((w) => keywords.contains(w)).length;
    return matchCount >= 2; // At least 2 keyword matches
  }
  
  String? loadBody() {
    // Lazy load — only when skill triggers
    // This is the progressive disclosure pattern
  }
}

// ── Memory Note ──
class MemoryNote {
  final String id;
  final String title;
  final String content;
  final String folder;
  final List<String> tags;
  final DateTime created;
  final DateTime modified;
  final bool syncEnabled;
  final String source;        // local, server
}

// ── Usage Stats ──
class UsageStats {
  final double costToday;
  final double costWeek;
  final double costMonth;
  final int inputTokens;
  final int outputTokens;
  final Map<String, double> costByModel;
  final Map<String, double> costByAgent;
}

// ── System Health ──
class SystemHealth {
  final double cpuPercent;
  final double ramPercent;
  final double diskPercent;
  final bool gatewayRunning;
  final int activeAgents;
  final int activeSessions;
  final DateTime lastHeartbeat;
}
```

---

## 15. Gateway Protocol

### 15.1 WebSocket Messages (Phone → Server)

```json
// Send a message to an agent
{
  "type": "message",
  "content": "Clear my inbox and summarise the important ones",
  "sessionKey": "pocket-claw-main",
  "source": "pocket-claw"
}

// Request agent list
{
  "type": "query",
  "resource": "agents"
}

// Create a task
{
  "type": "task",
  "action": "create",
  "data": {
    "title": "Review SS&C SLA proposal",
    "priority": "high"
  }
}
```

### 15.2 WebSocket Messages (Server → Phone)

```json
// Streaming text response
{
  "type": "response",
  "sessionKey": "pocket-claw-main",
  "chunk": "I found 12 unread emails...",
  "done": false
}

// Agent event
{
  "type": "event",
  "action": "progress",
  "runId": "run-abc123",
  "sessionKey": "pocket-claw-main",
  "prompt": "Clear my inbox",
  "source": "pocket-claw"
}

// Heartbeat
{
  "type": "heartbeat",
  "agentId": "inbox-agent",
  "message": "HEARTBEAT_OK"
}
```

---

## 16. Performance Budgets

| Metric | Target | Notes |
|--------|--------|-------|
| App install size | < 60 MB | Excludes models |
| Local model download | 0.4–1.3 GB | One-time, based on device tier |
| Local query → first token | < 3 seconds | On-device Gemma E2B |
| Server query → first token | < 2 seconds | Cloud LLM via Gateway (depends on network) |
| Smart Router classification | < 50 ms | Regex + heuristics, no LLM call |
| Local note search (RAG) | < 100 ms | local_hnsw vector search |
| Mission Control refresh | 2–5 seconds | REST API polling + WebSocket events |
| Gateway WebSocket latency | < 200 ms | Depends on VPS location |
| App cold start | < 3 seconds | Model lazy-loaded on first query |
| RAM (local LLM active) | < 2 GB | Model + app + RAG |
| RAM (no local LLM) | < 150 MB | Gateway-only mode |
| Battery (30 min active) | < 8% | With local LLM inference |

---

## 17. Development Roadmap

### Phase 1: Foundation (Weeks 1–2)
- [ ] Flutter project scaffold with Material 3
- [ ] `flutter_gemma` integration — local LLM inference + embeddings
- [ ] Basic chat UI with streaming responses
- [ ] Local tool executor (notes, calculator, reminders)
- [ ] Auto-model selection based on device
- [ ] sqflite database schema

### Phase 2: OpenClaw Integration (Weeks 3–4)
- [ ] Set up OpenClaw on VPS with preferred LLM
- [ ] Gateway WebSocket client in Flutter
- [ ] Gateway REST client for Mission Control data
- [ ] Smart Router: local vs server routing
- [ ] Server-routed chat (send message → stream response from OpenClaw)
- [ ] Auth/pairing flow

### Phase 3: Mission Control (Weeks 5–6)
- [ ] Dashboard screen (agents, health, activity)
- [ ] Agent list with status indicators
- [ ] Task Kanban board (CRUD + drag status)
- [ ] Cost tracking charts
- [ ] Cron job viewer
- [ ] Activity feed with real-time events

### Phase 4: Skill System (Weeks 7–8)
- [ ] SKILL.md parser (YAML frontmatter + Markdown body)
- [ ] Skill registry with three-tier runtime classification
- [ ] Bundled default skills (notes, calculator, forex, reminder)
- [ ] Skill browser (installed skills list)
- [ ] Skill editor (write/edit SKILL.md in-app)
- [ ] ClawHub integration (browse + install community skills)

### Phase 5: Memory & Sync (Weeks 9–10)
- [ ] Local memory (Markdown files + vector embeddings)
- [ ] RAG search over local notes
- [ ] Server memory browser (via Gateway API)
- [ ] Memory sync (local ↔ server, conflict resolution)
- [ ] Private notes (sync: false flag)
- [ ] Search across both local + server

### Phase 6: Device Integration (Weeks 11–12)
- [ ] Camera capture + on-device OCR (Gemma vision)
- [ ] Calendar integration (query + create events)
- [ ] Voice input (Gemma E2B native audio)
- [ ] Share sheet (draft-and-confirm for messages/emails)
- [ ] TTS (read notes/responses aloud)
- [ ] Notifications (reminders, agent alerts)
- [ ] Bridge skills (device capture → server process → local save)

### Phase 7: Polish (Weeks 13–14)
- [ ] Biometric app lock
- [ ] Onboarding flow (Gateway setup + model download)
- [ ] Offline mode UX (cached Mission Control, queued tasks)
- [ ] iOS testing and App Store preparation
- [ ] Performance profiling and optimisation
- [ ] Error handling and edge cases

### Phase 8: Distribution (Week 15+)
- [ ] Google Play Store (Android)
- [ ] Apple App Store (iOS)
- [ ] Web PWA deployment
- [ ] Custom skill pack for personal workflows (Sanlam, CARMEN, forex)
- [ ] Documentation (user guide + skill authoring guide)

---

## 18. Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Local 2B model unreliable for function calling | High | Medium | Use constrained decoding (LiteRT-LM). Fallback to server for failed local calls. |
| Gateway connection unstable | Medium | Medium | Exponential backoff reconnect. Offline mode graceful degradation. Queue tasks for later. |
| VPS costs (OpenClaw + LLM API) | Medium | Low | Cost dashboard in Mission Control. Model routing (cheap model for simple tasks). |
| Security: exposed Gateway | High | Low | WSS (TLS). Token auth. Biometric app lock. Never expose 18789 without SSH tunnel or Tailscale. |
| Skill injection / malicious skills | High | Medium | Warn on third-party install. Show required permissions. Local skills sandboxed to registered tools only. |
| iOS LiteRT-LM limitations | Low | Medium | MediaPipe .task format works today. NPU acceleration is a future bonus. |
| Flutter app size with local model | Medium | Low | Model downloaded separately, not bundled. App shell < 60 MB. |
| Battery drain from local inference | Medium | Medium | Session timeout. Aggressive model unloading when idle. Background inference disabled. |
| Memory sync conflicts | Low | Medium | Timestamp-based last-write-wins. Conflict markers for manual resolution. |

---

## Appendix A: Shared Foundation with LekkerSwot

Pocket Claw and LekkerSwot share the following Flutter components:

| Component | Shared Code |
|-----------|-------------|
| `flutter_gemma` LLM engine | Identical — same model loading, inference, streaming |
| `local_hnsw` vector search | Identical — same embedding + search |
| `sqflite` database layer | Shared base schema, app-specific extensions |
| Model selector | Identical — same device capability detection |
| Chat UI widgets | Shared base chat bubble, streaming indicator |
| Voice input | Shared Gemma audio processing |
| Camera service | Shared camera capture + vision processing |

This shared foundation can be extracted into a `pocket_ai_core` Flutter package used by both apps.

---

## Appendix B: Quick Reference — Skill Runtime Decision

```
Is internet required for this skill?
├── NO → runtime: local
│   Does it need device APIs?
│   ├── YES → requires.device_apis: [camera, calendar, ...]
│   └── NO → Pure LLM function calling
│
├── YES, needs server tools (shell, browser, email, APIs)
│   → runtime: server
│
└── YES, but also needs device input first
    → runtime: bridge
    (Phone captures → server processes → phone displays)
```

---

*Pocket Claw v1.0.0 — Nuburo.DIGITAL (PTY) LTD — April 2026*  
*"Your phone is the body. Your server is the brain. Together, they're unstoppable."*
