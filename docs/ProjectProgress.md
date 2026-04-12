# Pocket Claw — Project Progress

**Version:** 1.0.0  
**Last Updated:** 2026-04-09  
**Author:** Alister Witbooy / Nuburo.DIGITAL (PTY) LTD  
**Repo:** https://github.com/alboogycOdR/PocketClaw

---

## Build Summary

- **74 Dart source files** across the full architecture
- **4 bundled SKILL.md assets** (notes, calculator, forex-calc, reminder)
- **15,416 lines of code** committed
- **Zero errors, zero warnings** on `flutter analyze`
- **Web build compiles and runs** on Chrome (localhost:8080)

---

## What's Done

### Phase 1: Foundation

| Component | Status | Files |
|-----------|--------|-------|
| Flutter project scaffold | Done | pubspec.yaml, main.dart |
| Material 3 dark theme | Done | lib/app/theme.dart |
| GoRouter navigation | Done | lib/app/router.dart |
| Bottom nav (Chat, Control, Memory, Skills, Settings) | Done | lib/app/router.dart |
| sqflite database schema (4 tables) | Done | lib/data/database/ |
| SharedPreferences settings persistence | Done | lib/data/providers/core_providers.dart |

### Phase 2: Core Engine

| Component | Status | Files |
|-----------|--------|-------|
| Data models (Agent, Task, Session, Skill, MemoryNote, UsageStats, SystemHealth, ChatMessage, GatewayEvent) | Done | lib/data/models/ (8 files) |
| Smart Router (local/server/bridge/device/missionControl) | Done | lib/core/router/smart_router.dart |
| Gateway WebSocket client (auth, streaming, reconnect) | Done | lib/core/gateway/gateway_client.dart |
| Gateway REST client (agents, tasks, cron, usage, memory, skills, health) | Done | lib/core/gateway/gateway_rest.dart |
| Local Agent Engine (agent loop, prompt builder, tool definitions) | Done | lib/core/local_agent/ (6 files) |
| LLM Engine wrapper | Stubbed | Placeholder responses — needs flutter_gemma model files |
| Model Selector (auto-select by device RAM) | Done | lib/core/local_agent/model_selector.dart |
| Tool Executor (maps function calls to device APIs) | Done | lib/core/local_agent/tool_executor.dart |

### Phase 3: Skill System

| Component | Status | Files |
|-----------|--------|-------|
| SKILL.md YAML parser | Done | lib/core/skills/skill_parser.dart |
| Skill Registry (3-tier: bundled, downloaded, user) | Done | lib/core/skills/skill_registry.dart |
| Bundled skill: Notes | Done | assets/skills/notes.md |
| Bundled skill: Calculator | Done | assets/skills/calculator.md |
| Bundled skill: Forex Position Calculator | Done | assets/skills/forex-calc.md |
| Bundled skill: Reminder | Done | assets/skills/reminder.md |

### Phase 4: Memory & Session

| Component | Status | Files |
|-----------|--------|-------|
| Local Memory (Markdown files + sqflite index) | Done | lib/core/memory/local_memory.dart |
| Server Memory (Gateway REST wrapper) | Done | lib/core/memory/server_memory.dart |
| Memory Sync (timestamp-based, respects syncEnabled) | Done | lib/core/memory/memory_sync.dart |
| Memory Manager (unified local + server) | Done | lib/core/memory/memory_manager.dart |
| Session Manager (in-memory buffer + sqflite) | Done | lib/core/session/session_manager.dart |
| Session History (persistence, list, delete) | Done | lib/core/session/session_history.dart |

### Phase 5: Device API Layer

| Component | Status | Files |
|-----------|--------|-------|
| Calendar Service | Stubbed | lib/core/device/calendar_service.dart |
| Camera Service | Stubbed | lib/core/device/camera_service.dart |
| Notification Service | Stubbed | lib/core/device/notification_service.dart |
| TTS Service | Stubbed | lib/core/device/tts_service.dart |
| Share Service | Done | lib/core/device/share_service.dart |
| File Service | Done | lib/core/device/file_service.dart |

> "Stubbed" = wrapper code exists and compiles, but requires a physical Android/iOS device to function.

### Phase 6: UI Screens

| Screen | Status | Files |
|--------|--------|-------|
| Chat (streaming, input bar, photo, voice, function call indicators) | Done | lib/features/chat/ (6 files) |
| Mission Control Dashboard | Done | lib/features/mission_control/dashboard_screen.dart |
| Agent List | Done | lib/features/mission_control/agents_screen.dart |
| Task Kanban | Done | lib/features/mission_control/tasks_screen.dart |
| Cost Tracker (pie charts) | Done | lib/features/mission_control/cost_screen.dart |
| Cron Job Viewer | Done | lib/features/mission_control/cron_screen.dart |
| Activity Feed (live WebSocket events) | Done | lib/features/mission_control/activity_screen.dart |
| Memory Browser (Local + Server tabs) | Done | lib/features/memory/memory_screen.dart |
| Note Editor | Done | lib/features/memory/note_editor.dart |
| File Browser (server memory tree) | Done | lib/features/memory/file_browser.dart |
| Memory Search (local + server) | Done | lib/features/memory/search_view.dart |
| Skills List (grouped by runtime) | Done | lib/features/skills/skills_screen.dart |
| Skill Detail (markdown body) | Done | lib/features/skills/skill_detail.dart |
| Skill Editor (write SKILL.md) | Done | lib/features/skills/skill_editor.dart |
| Settings (gateway, model, security) | Done | lib/features/settings/ (4 files) |
| Onboarding (welcome, gateway setup, model download) | Done | lib/features/onboarding/ (3 files) |
| Shared Widgets (connection indicator, source badge, health bar, stat card, empty state, loading shimmer) | Done | lib/shared/widgets/ (6 files) |

### Phase 7: Wiring (Riverpod Providers)

| Component | Status | Files |
|-----------|--------|-------|
| Core providers (all services wired) | Done | lib/data/providers/core_providers.dart |
| Chat providers (messages, routing, streaming) | Done | lib/data/providers/chat_providers.dart |
| Mission Control providers (REST data fetching) | Done | lib/features/mission_control/mission_control_providers.dart |
| All screens connected to real providers | Done | — |

---

## What Needs Real Hardware / External Setup

### 1. Local LLM (requires Android device with 6GB+ RAM)

The `LlmEngine` at `lib/core/local_agent/llm_engine.dart` is stubbed with placeholder responses. To activate:
- Download a Gemma 4 E2B `.task` model file onto the device
- Integrate `flutter_gemma` package for actual inference
- The `ModelSelector` already handles auto-detection by device RAM

### 2. Device APIs (requires physical Android/iOS device)

Camera, calendar, notifications, TTS, and biometrics all require native platform access. They compile but will not function on web.

### 3. OpenClaw Server (requires VPS with OpenClaw running)

Mission Control, server-routed chat, server memory, and memory sync all need a running OpenClaw instance. Configure in Settings > Gateway Configuration with your `wss://` URL and auth token.

### 4. Android SDK (not installed on build machine)

Required to build APKs and run on a real phone. Flutter is installed (v3.41.6) and web builds work.

---

## Not Yet Built (Spec Phases 5-8)

| Feature | Spec Phase | Priority |
|---------|------------|----------|
| Voice input (Gemma E2B native audio) | Phase 6 | High |
| On-device OCR (Gemma vision) | Phase 6 | High |
| Bridge skill flow (device capture -> server process) | Phase 6 | Medium |
| Memory vector embeddings / RAG search | Phase 5 | Medium |
| ClawHub skill marketplace browser | Phase 4 | Low |
| Onboarding flow (real model download) | Phase 7 | Medium |
| iOS testing & App Store prep | Phase 7 | Low |
| Performance profiling | Phase 7 | Medium |
| Google Play / App Store distribution | Phase 8 | Low |
| Custom skill packs (Sanlam, CARMEN, forex) | Phase 8 | Low |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.41.6 (Dart 3.11.4) |
| State Management | Riverpod 2.6.1 |
| Navigation | GoRouter 14.8.1 |
| Networking | Dio 5.7.0 + web_socket_channel 3.0.2 |
| Database | sqflite 2.4.2 |
| Settings | shared_preferences 2.3.5 |
| Security | flutter_secure_storage 9.2.4 |
| Charts | fl_chart 0.70.2 |
| Markdown | flutter_markdown 0.7.6 |
| YAML | yaml 3.1.3 |
| Theme | Material 3 Dark (Lobster Red #E53935, Charcoal #1A1A2E, Electric Teal #00E5CC) |
| Font | JetBrains Mono (display) + System (body) |

---

*Pocket Claw v1.0.0 — Nuburo.DIGITAL (PTY) LTD — April 2026*
