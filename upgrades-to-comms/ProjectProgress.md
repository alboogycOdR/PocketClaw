# Pocket Claw — Project Progress

**Version:** 1.0.0  
**Last Updated:** 2026-05-08  
**Author:** Alister Witbooy / CARMEN PTY LTD  
**Repo:** https://github.com/alboogycOdR/PocketClaw

---

## Build Summary

- **139 Dart source files** across the full architecture
- **14 bundled SKILL.md assets** (notes, calculator, forex-calc, reminder, academy-tutor, enterprise-it, fitness-coach, forex-starter, life-architect, master-life-architect, solo-founder, student-success-coach, subject-tutor-template, vertex-rag-bridge)
- **29,292 lines of code**
- **Flutter 3.41.6 / Dart 3.11.4**
- **Web build compiles and runs** on Chrome (localhost:8080)

> **⚠️ Critical pre-ship bug:** VPS Tailscale IP and OpenClaw auth token are hardcoded in `lib/data/providers/core_providers.dart` lines 54–67. Must be removed before any public or shared build. See SPEC-OpenClaw-Improvements-v1.0.md §2.

> **⚠️ App name conflict:** "PocketClaw" (one word) exists on the iOS App Store as a claw machine game by Magic Cube. Rename required before iOS submission. Candidates: ClawHQ, ClawBoard, ClawDesk — decision pending.

---

## Architecture Overview

```
lib/
├── app/            Theme, GoRouter, biometric lock
├── core/
│   ├── chat/       Chat mode definitions
│   ├── coaching/   GROW state machine, safety classifier
│   ├── device/     Calendar, camera, notifications, TTS, share, file services
│   ├── gateway/    OpenClaw WebSocket client, REST client, offline queue, proactive notifier
│   ├── hermes/     Hermes REST client (chat), SSE parser — IN PROGRESS
│   ├── llm/        AbstractLLMEngine, LlamaCppEngine (fllama), CloudLLMEngine, model registry
│   ├── local_agent/ Local agent loop, prompt builder, tool executor
│   ├── memory/     Local memory, server memory, memory sync, memory router
│   ├── packs/      Starter pack service
│   ├── router/     Smart Router, ExecutionPath enum
│   ├── session/    Session manager, session history
│   └── skills/     SKILL.md parser, skill registry, bridge runner
├── data/
│   ├── database/   sqflite schema, DAOs (messages, notes, settings)
│   ├── models/     Agent, Channel, ChatMessage, GatewayEvent, MemoryNote, Session, Skill, Task, UsageStats
│   ├── providers/  Core, chat, chat-mode, paperclip, paperclip-onboarding providers
│   └── repositories/ ProjectMemoryRepository
└── features/
    ├── academy/    Academy Mode (skeleton)
    ├── chat/       Chat screen, bubbles, command palette, draft-confirm, banners
    ├── company/    7 Paperclip Company tabs (on hold)
    ├── life_architect/ Life Architect (skeleton)
    ├── memory/     Memory browser, note editor, file browser, search
    ├── mission_control/ Dashboard, Agents, Tasks*, Cost, Cron, Activity, Channels
    ├── onboarding/ Welcome, gateway setup, model download, commercial wizard
    ├── packs/      Starter pack picker
    ├── settings/   Gateway config, model config, device identity, security,
    │               Paperclip settings, Paperclip onboarding wizard, router/memory settings
    └── skills/     Skills list, detail, editor, ClawHub browser
```

---

## What's Done

### Core Infrastructure
| Component | Status | Notes |
|---|---|---|
| Flutter scaffold, Material 3 dark theme | ✅ Done | Lobster Red #E53935, Charcoal #1A1A2E, Electric Teal #00E5CC |
| GoRouter navigation + bottom nav | ✅ Done | 5 tabs: Chat, Control, Memory, Skills, Settings |
| sqflite schema (messages, notes, settings DAOs) | ✅ Done | |
| SharedPreferences + flutter_secure_storage | ✅ Done | Sensitive keys in secure storage |
| Biometric lock screen | ✅ Done | |
| Offline queue + connectivity awareness | ✅ Done | |

### OpenClaw Integration
| Component | Status | Notes |
|---|---|---|
| Gateway WebSocket client | ✅ Done | Handshake, streaming, reconnect, Ed25519 pairing |
| Gateway REST client | ✅ Done | `/__openclaw__/api` prefix, agents, sessions, cron, usage, memory, skills, health |
| Device Identity (Ed25519) | ✅ Done | Own device public key viewer + reset |
| Pairing banner | ✅ Done | Shows when pairing approval pending |
| Smart Router | ✅ Done | local / server / bridge / hermes paths |
| Mission Control — Dashboard | ✅ Done | Health, cost, agents, sessions count, cron |
| Mission Control — Agents | ✅ Done | Agent list from `agents.list` RPC |
| Mission Control — Cost | ✅ Done | Today/week/month from `usage.cost` RPC |
| Mission Control — Cron | ✅ Done | List, toggle, run-now, delete |
| Mission Control — Activity | ✅ Done | Live WebSocket agent events |
| Mission Control — Channels | ✅ Done | Platform status + disconnect |
| Mission Control — Tasks | ⚠️ Dead | Always empty — OpenClaw has no `tasks.*` RPC. Needs repurposing as Session History. See SPEC-OpenClaw §3 |
| Chat — streaming | ✅ Done | Delta accumulation, run ID tracking |
| Chat — 49-command palette | ✅ Done | Categories, slash-trigger, search |
| Chat — draft-confirm dialog | ✅ Done | For destructive commands |
| Chat — photo attachment | ✅ Done | Base64 encoding, 5MB limit |
| Chat — voice widget shell | ⚠️ Shell only | UI exists, no audio pipeline wired |
| Chat — function call indicator | ✅ Done | |
| Chat — proactive push notifications | ✅ Done | `proactive:true` agent events → flutter_local_notifications |
| Chat — privacy warning banner | ✅ Done | Smart Router path privacy detection |

### Hermes Integration (Sprint 1 — IN PROGRESS)
| Component | Status | Notes |
|---|---|---|
| HermesClient (REST `/v1/chat/completions`) | ✅ Done | Verified against live VPS 100.78.70.2:8642 |
| HermesSseParser (SSE streaming) | ✅ Done | Verified SSE format from live VPS |
| hermes_providers.dart | ✅ Done | Base URL + API key providers, reachability |
| HermesSettings screen | ✅ Done | URL, API key, test connection |
| `hermes` ExecutionPath | ✅ Done | Added to enum + Smart Router |
| Chat routing through Hermes | ⏳ To wire | Settings screen done; chat send branch pending |

### Paperclip Integration (ON HOLD)
| Component | Status | Notes |
|---|---|---|
| PaperclipRestClient | ✅ Done | All 7 tab endpoints, error handling, models |
| PaperclipNotifier | ✅ Done | Poll-based AsyncNotifier (push events removed) |
| PaperclipOnboardingWizard | ✅ Done | Invite token → claim API key flow |
| PaperclipCompanySettings | ✅ Done | URL, API key, test connection |
| Company tab (7 screens) | ✅ Done | Overview, Org Chart, Goals, Budgets, Tickets, Governance, Security |
| **Paperclip deployed on VPS** | ✅ Done | Running on 100.78.70.2:3100, systemd-managed |
| **Company/board claim** | ✅ Done | Admin account created, company set up |
| End-to-end Company tab test | ⏳ Deferred | On hold until Hermes sprint complete |

### LLM Engines
| Component | Status | Notes |
|---|---|---|
| AbstractLLMEngine interface | ✅ Done | |
| LlamaCppEngine (fllama GGUF) | ✅ Done | Engine wired; no model downloaded on device yet |
| CloudLLMEngine (Anthropic/OpenAI/Google) | ✅ Done | Full streaming support |
| Legacy LlmEngine stub | ✅ Done | Kept for compile compat; routes to AbstractLLMEngine |
| flutter_gemma | ✅ Removed | Replaced by fllama — cleaner, wider GGUF catalogue |
| Model registry + download manager | ✅ Done | Auto-select by device RAM |

### Memory & Skills
| Component | Status | Notes |
|---|---|---|
| Local memory (Markdown + sqflite index) | ✅ Done | |
| Server memory (Gateway REST wrapper) | ✅ Done | |
| Memory sync (timestamp-based) | ✅ Done | |
| Memory Router | ✅ Done | Project-scoped memory routing |
| Session manager + history | ✅ Done | |
| SKILL.md parser | ✅ Done | YAML frontmatter |
| Skill registry (bundled/downloaded/user) | ✅ Done | |
| ClawHub browser | ✅ Done | Search, install, enable/disable |

### Coaching & Special Modes
| Component | Status | Notes |
|---|---|---|
| GROW state machine | ✅ Done | Goal/Reality/Options/Will |
| Safety classifier | ✅ Done | |
| Academy Mode | ⚠️ Skeleton | Screen exists; not wired to data providers |
| Life Architect | ⚠️ Skeleton | Screen exists; not wired to data providers |
| Commercial onboarding wizard | ✅ Done | Gateway + Paperclip setup flow |
| Starter pack picker | ✅ Done | 14 bundled SKILLs |

### Device APIs
| Component | Status | Notes |
|---|---|---|
| Calendar service | ⚠️ Stub | Wrapper compiles; needs physical device |
| Camera service | ⚠️ Stub | Wrapper compiles; needs physical device |
| Notification service | ⚠️ Stub | Wrapper compiles; needs physical device |
| TTS service | ⚠️ Stub | Wrapper compiles; needs physical device |
| Share service | ✅ Done | |
| File service | ✅ Done | |

---

## Active VPS Services

| Service | Port | Bind | Status | Managed by |
|---|---|---|---|---|
| openclaw-gateway | 18789 | 100.78.70.2 (Tailscale) | ✅ Running | systemd |
| paperclip | 3100 | 100.78.70.2 (Tailscale) | ✅ Running | systemd |
| hermes-gateway | 3000 | 0.0.0.0 | ✅ Running | background process |
| hermes-api-server | 8642 | 100.78.70.2 (Tailscale) | ✅ Running | background process |

> **Note:** hermes-gateway and hermes-api-server are not yet systemd-managed. They will die on reboot. See SPEC-HermesIntegration-v1.0.md §8 for the systemd setup instruction (converted for Claude Code).

---

## Active Sprints

### Sprint 1 — Hermes REST Chat (Current)
Per `SPEC-HermesIntegration-v1.0.md`:
- [ ] Wire chat send branch to Hermes path in `chat_providers.dart`
- [ ] Add Hermes option to router/memory settings
- [ ] Test end-to-end streaming on physical Android device
- [ ] Set up hermes-gateway as systemd service

### Sprint 2 — OpenClaw Quick Wins (No SSH needed)
Per `SPEC-OpenClaw-Improvements-v1.0.md`:
- [ ] **Remove hardcoded credentials** from `core_providers.dart` (pre-sprint blocker)
- [ ] Repurpose Tasks screen → Session History
- [ ] Devices management screen
- [ ] Model status screen
- [ ] Exponential backoff reconnection

### Sprint 3 — SSH Transport + Hermes Management
Per `SPEC-MultiTransport-v1.0.md`:
- [ ] Add `dartssh2` dependency
- [ ] SSH transport layer + settings screen
- [ ] Sessions browser (via remote SQLite)
- [ ] Memory editor (MEMORY.md / USER.md / SOUL.md)
- [ ] Cron manager (via SFTP)
- [ ] Skills browser, log viewer, gateway status

### Sprint 4 — OpenClaw SSH Diagnostics
Per `SPEC-OpenClaw-Improvements-v1.0.md §6`:
- [ ] OpenClaw log viewer via journalctl over SSH
- [ ] `openclaw doctor` output in settings
- [ ] Gateway restart button

### Sprint 5 — Hermes ACP Chat
Per `SPEC-MultiTransport-v1.0.md §13`:
- [ ] ACP protocol via SSH exec
- [ ] Tool call card widget
- [ ] Live tool call progress in chat

---

## Deferred / Future Sprints

| Feature | Notes |
|---|---|
| Paperclip Company tab end-to-end test | Infrastructure ready; deferred to after Hermes sprint |
| Academy Mode data wiring | Screen exists; content providers not built |
| Life Architect data wiring | Screen exists; content providers not built |
| Voice input pipeline | UI shell exists; needs audio recording + whisper/STT |
| Physical device testing (device APIs) | Calendar, camera, notifications, TTS need real Android/iOS |
| iOS submission | Name conflict must be resolved first; use TestFlight |
| Google Play submission | Signing config needed |
| ACP chat (Hermes rich tool calls) | After SSH transport stable |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.41.6 (Dart 3.11.4) |
| State Management | Riverpod 2.6.1 |
| Navigation | GoRouter 14.8.1 |
| Networking | Dio 5.7.0 + web_socket_channel 3.0.2 + http 1.2.0 |
| Local LLM | fllama 0.0.1 (GGUF via llama.cpp) |
| Database | sqflite 2.4.2 |
| Secure Storage | flutter_secure_storage 9.2.4 |
| Settings | shared_preferences 2.3.5 |
| Charts | fl_chart 0.70.2 |
| Markdown | flutter_markdown 0.7.6 |
| YAML | yaml 3.1.3 |
| Biometrics | local_auth 2.3.0 |
| Notifications | flutter_local_notifications 18.0.1 |
| Theme | Material 3 Dark · Lobster Red #E53935 · Charcoal #1A1A2E · Electric Teal #00E5CC |
| Font | JetBrains Mono (display) + System (body) |
| SSH (pending) | dartssh2 (Sprint 3) |

---

*Pocket Claw — CARMEN PTY LTD — May 2026*
