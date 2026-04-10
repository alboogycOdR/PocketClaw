# Pocket Claw — Product Specification

## The AI Agent That Lives in Your Pocket

**Version:** 1.0.0
**Developer:** CARMEN PTY LTD
**Platform:** Android, iOS, Web (Flutter)
**Status:** Feature-Complete, Production-Ready

---

## Executive Summary

Pocket Claw is a **cross-platform mobile AI agent** that gives users a personal AI assistant capable of real action — not just chat. It combines a **local on-device LLM** (private, offline, instant) with a **remote OpenClaw server** (powerful, multi-tool, cloud-backed) through a transparent Smart Router that automatically picks the best path for every request.

The phone becomes the **body** — camera, microphone, calendar, contacts, GPS, notifications. The server becomes the **brain** — shell commands, web browsing, email automation, multi-step reasoning. Together they create an AI agent that can **do things**, not just talk about them.

**Key differentiator:** Pocket Claw is the first mobile AI agent platform that seamlessly blends on-device inference with remote agentic execution, while maintaining an offline-first, privacy-first architecture with a draft-and-confirm safety model.

---

## Why Pocket Claw?

### The Problem

Current mobile AI assistants are either:
- **Cloud-only** (ChatGPT, Gemini) — require internet, no device integration, no action-taking
- **Voice assistants** (Siri, Google Assistant) — limited intelligence, no agentic workflows
- **Dev tools** (Claude Code, Cursor) — desktop-only, not mobile

There is no mobile-native AI agent that can work offline, take real actions on the device, integrate with a powerful server-side agent, and remain fully under the user's control.

### The Solution

Pocket Claw fills this gap with a **hybrid architecture**:

| Capability | How It Works |
|---|---|
| Quick tasks offline | On-device Gemma LLM with function calling |
| Complex agentic workflows | Routes to OpenClaw server (Claude, GPT, DeepSeek) |
| Device integration | Camera, calendar, notifications, TTS, file system, share sheet |
| Mission Control | Monitor server agents, tasks, costs, and cron jobs from the phone |
| Notes & Memory | Local RAG-searchable notes synced with server memory |
| Extensible skills | OpenClaw-compatible SKILL.md format (local, server, or bridge) |
| Voice & Vision | On-device voice input and OCR/image analysis |
| Privacy-first | Sensitive data stays on-device. No telemetry. No cloud lock-in. |

---

## Feature Overview

### 1. Intelligent Chat Interface

The primary screen is a conversational AI interface with capabilities far beyond simple chat:

- **Streaming responses** with real-time token display
- **Smart routing** — requests are automatically classified and sent to the optimal engine (local LLM, server, or hybrid bridge)
- **Photo attachment** — pick from camera or gallery, send for vision/OCR analysis
- **Voice input** — tap-to-record with waveform animation
- **Function call indicators** — visual feedback when the agent executes tools ("Setting reminder...", "Searching notes...")
- **Draft-and-confirm cards** — the agent drafts sensitive actions (emails, calendar events, messages) and presents them for user approval before execution
- **Source badges** — every response is tagged with its origin (LOCAL, SERVER, BRIDGE, DEVICE)
- **Connection indicator** — real-time gateway status in the header

### 2. Smart Router — The Decision Engine

Every user request passes through a transparent routing layer that classifies and routes to the optimal execution path:

```
User Input
    |
    v
[1] User override?     /local, /server, /mc prefixes
[2] Device-only?        "take photo", "set alarm" -> direct API call
[3] Mission Control?    "agent status", "cost today" -> REST query
[4] Offline?            No server -> force local
[5] Skill match?        Matched skill declares its runtime
[6] Bridge pattern?     Image + complex task -> device capture + server process
[7] Simple task?        Notes, reminders, calc -> local LLM
[8] Default             -> server for best quality
```

The user never manually chooses an engine — the router is transparent. But power users can override with `/local`, `/server`, or `/mc` prefixes.

### 3. On-Device LLM (Local Agent)

A complete on-device inference pipeline powered by **flutter_gemma**:

| Model | Size | RAM | Capabilities |
|---|---|---|---|
| **Gemma 4 E2B** | 1.5 GB | 6 GB+ | Text, vision, audio, function calling, thinking |
| **Gemma 3 1B** | 0.6 GB | 4 GB+ | Text, function calling |
| **Gemma 3 270M** | 0.3 GB | 2 GB+ | Text only |

**What the local agent can do without any server:**
- Create and search notes (with vector-based semantic search)
- Set reminders and alarms
- Query the device calendar
- Perform calculations
- Draft messages (email, SMS, WhatsApp via share sheet)
- Capture and analyse photos (OCR)
- Read files from local storage
- Read text aloud (TTS)
- Execute any local-runtime skill

**Auto-model selection** detects device RAM and GPU capability, automatically picking the best model the hardware can support.

### 4. OpenClaw Server Integration

When connected to a self-hosted OpenClaw instance, Pocket Claw gains access to a full agentic platform:

- **Cloud LLMs** — Claude, GPT-4o, DeepSeek with 64K+ context
- **Server tools** — shell commands, web browsing (Playwright), email (himalaya), file operations
- **Multi-agent orchestration** — multiple agents running concurrently
- **Cron scheduling** — automated recurring tasks
- **50+ bundled skills** — inbox management, research, coding, and more

**Connection:** Secured WebSocket (wss://) with token-based authentication. Supports Tailscale VPN for zero-trust networking.

### 5. Mission Control Dashboard

A native mobile implementation of the OpenClaw Mission Control — monitor and manage everything from the phone:

- **Dashboard** — active agents, open tasks, daily cost, system health (CPU/RAM/disk)
- **Agent list** — status, model, session info, token usage per agent
- **Task Kanban** — visual board with inbox/assigned/in-progress/review/done columns
- **Cost tracker** — today/week/month spend, breakdown by model and agent, token counts
- **Cron jobs** — view schedules, last/next run, enable/disable toggle
- **Activity feed** — real-time WebSocket events from server agents

### 6. Memory System

A dual-layer memory architecture with semantic search:

**Local Memory:**
- Markdown notes with YAML frontmatter
- Organised by folders (general, work, personal, ideas, lists)
- **RAG vector search** — embeddings generated on note creation, cosine similarity ranking
- Falls back to text search if embeddings unavailable
- Full CRUD with in-app note editor

**Server Memory:**
- Browse OpenClaw's persistent memory files
- Read/write server documents
- **Bidirectional sync** — timestamp-based conflict resolution (latest wins)
- Private notes (`sync: false`) never leave the device

### 7. Skill System

An extensible plugin architecture using the OpenClaw-compatible SKILL.md format:

**Three runtime tiers:**
- **Local** — runs on-device (offline capable, private)
- **Server** — runs on OpenClaw (needs connection, full tool access)
- **Bridge** — device captures data, server processes it

**Bundled skills:** Notes, Calculator, Forex Position Calculator, Reminder

**Skill management:**
- Browse installed skills (grouped by runtime)
- **ClawHub browser** — discover and install skills from the server registry
- **Skill editor** — write custom SKILL.md files directly on the phone
- Skills declare required device APIs, environment variables, and binaries

### 8. Device Integration Layer

Full access to native device capabilities through the local agent's tool system:

| Capability | Integration | What It Enables |
|---|---|---|
| Camera | `camera` + `image_picker` | Photo capture, OCR, document scanning |
| Vision/OCR | `flutter_gemma` multimodal | On-device text extraction from images |
| Calendar | `device_calendar` | Query and create events |
| Notifications | `flutter_local_notifications` | Scheduled reminders and alerts |
| TTS | `flutter_tts` | Read notes and responses aloud |
| Share sheet | `share_plus` | Draft-and-confirm message sending |
| Files | `path_provider` + `file_picker` | Read/write sandboxed files |
| Biometrics | `local_auth` | Fingerprint/face app lock |
| Location | `geolocator` | GPS context (weather, proximity) |
| Connectivity | `connectivity_plus` | Online/offline detection |

### 9. Security Model

| Principle | Implementation |
|---|---|
| **Local data stays local** | Private notes never sync. Local LLM processes sensitive queries on-device. |
| **Biometric app lock** | Fingerprint/face required to open the app (optional, persisted) |
| **Gateway auth** | Token-based authentication stored in encrypted secure storage |
| **Draft-and-confirm** | Agent never sends emails/messages autonomously. Always shows draft for user approval. |
| **Offline-first** | Every core feature works without connectivity. Server is a power boost, not a dependency. |
| **No telemetry** | Zero analytics. No data leaves device except to the user's own server. |
| **File sandboxing** | File operations constrained to app documents directory |

### 10. Offline Resilience

Pocket Claw doesn't just "work offline" — it's designed offline-first:

- **Smart Router** forces local execution when no connection is detected
- **Offline queue** captures server-bound messages and replays them automatically on reconnect
- **Local LLM** handles quick tasks, notes, calculations, reminders without any network
- **Mission Control** shows cached last-known state when offline
- **Memory sync** queues changes and resolves conflicts on reconnection

---

## Opportunities & Growth Vectors

### For Buyers / Investors

| Opportunity | Description |
|---|---|
| **White-label enterprise agent** | Rebrand for corporate use — every employee gets a pocket AI agent connected to company infrastructure |
| **Vertical skill packs** | Industry-specific skill bundles (finance, legal, medical, education) sold as add-ons |
| **ClawHub marketplace** | Revenue-sharing platform for third-party skill developers |
| **Managed OpenClaw hosting** | SaaS offering — users pay for a managed server instead of self-hosting |
| **Education platform** | Adapt for student use (LekkerSwot shared foundation already exists) |
| **IoT / smart home bridge** | Phone as the interface layer between local AI and home automation |
| **Compliance-ready AI** | On-device processing for regulated industries (healthcare, finance) where data cannot leave the device |

### How Pocket Claw Unlocks Agentic AI

Traditional mobile AI is limited to **chat** — ask a question, get an answer. Pocket Claw breaks this barrier:

**1. Action-Taking, Not Just Answering**
The agent doesn't just tell you what to do — it does it. "Remind me to call John at 3pm" creates an actual notification. "Draft an email to the team about the deadline" opens a real share sheet with a composed message.

**2. Multi-Engine Intelligence**
Simple tasks run instantly on-device. Complex tasks route to a powerful server with shell access, web browsing, and email tools. The user doesn't manage this — the Smart Router handles it transparently.

**3. Sensor Fusion (Bridge Pattern)**
The phone's camera captures a receipt. The local model extracts text. The server categorises the expense and files it. This device-capture-plus-server-process pattern is unique to mobile agents.

**4. Persistent Memory & Context**
The agent remembers. Notes are vectorised for semantic retrieval. Conversation history persists across sessions. Server memory syncs bidirectionally. Every interaction builds on prior context.

**5. Extensible via Skills**
Anyone can write a SKILL.md file to teach the agent new capabilities. Skills declare their runtime, required APIs, and trigger patterns. The system automatically loads, matches, and executes them.

**6. Mission Control from Anywhere**
Monitor server-side agents, manage task boards, review costs, toggle cron schedules — all from the phone. This turns Pocket Claw into the mobile control surface for an entire agentic infrastructure.

**7. Privacy Without Compromise**
On-device inference means the user's data never leaves their phone unless they explicitly route to their own server. No third-party cloud. No telemetry. Full user sovereignty.

---

## Technical Architecture

```
+---------------------------------------------------------+
|                    VPS / HOME SERVER                     |
|                                                          |
|   OPENCLAW INSTANCE                                      |
|   Gateway (port 18789) <-- WebSocket + REST -->          |
|   +-- Agent Core (Claude / GPT / DeepSeek)               |
|   +-- Tools: exec, browser, email, file, cron            |
|   +-- 50+ Skills                                         |
|   +-- Memory: persistent Markdown files                  |
|   +-- Mission Control API                                |
+--------------------------+-------------------------------+
                           |
              Secured WebSocket (wss://) + REST API
              (Tailscale / SSH tunnel recommended)
                           |
+--------------------------v-------------------------------+
|                    MOBILE DEVICE                          |
|                  Flutter "Pocket Claw"                    |
|                                                          |
|   PRESENTATION LAYER                                     |
|   Chat | Mission Control | Memory | Skills | Settings    |
|                                                          |
|   ORCHESTRATION LAYER                                    |
|   Smart Router | Skill Registry | Prompt Builder         |
|   Session Manager | Offline Queue                        |
|                                                          |
|   ENGINE LAYER                                           |
|   Local LLM (flutter_gemma) | Gateway Client (WS+REST)  |
|   Tool Executor | Draft-and-Confirm                      |
|                                                          |
|   DATA LAYER                                             |
|   SQLite | Vector Embeddings | Markdown Files            |
|   SharedPreferences | Secure Storage                     |
|                                                          |
|   DEVICE LAYER                                           |
|   Camera | Calendar | TTS | Notifications | GPS          |
|   Share Sheet | Files | Biometrics | Connectivity        |
+----------------------------------------------------------+
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.41 (Dart 3.11) |
| State Management | Riverpod 2.6 |
| Navigation | GoRouter 14.8 |
| Local LLM | flutter_gemma 0.13 (Gemma 4 E2B / 3 1B / 3 270M) |
| Vector Search | Cosine similarity over flutter_gemma embeddings |
| Database | sqflite (SQLite) |
| Networking | Dio 5.7 + web_socket_channel 3.0 |
| Security | flutter_secure_storage + local_auth |
| Charts | fl_chart 0.70 |
| Math | math_expressions 2.6 |
| Device Info | device_info_plus 11.3 |
| UI | Material Design 3, JetBrains Mono, dark theme |

---

## Branding

| Element | Value |
|---|---|
| **Primary colour** | Lobster Red (#E53935) |
| **Background** | Deep Charcoal (#1A1A2E) |
| **Accent** | Electric Teal (#00E5CC) |
| **Font** | JetBrains Mono (display) + System (body) |
| **Mascot** | Crab (lobster nod to OpenClaw) |
| **Tone** | Technical but approachable. Developer tool, not consumer toy. |
| **Dark mode** | Default and only theme. Power users prefer dark. |

---

## Competitive Landscape

| Product | Chat | Offline | Device APIs | Agentic | Skills | Self-Hosted | Open |
|---|---|---|---|---|---|---|---|
| **Pocket Claw** | Yes | Yes | Full | Yes | Yes | Yes | Proprietary |
| ChatGPT Mobile | Yes | No | No | No | GPTs | No | No |
| Google Gemini | Yes | No | Limited | No | No | No | No |
| Siri / Google Asst | Voice | Partial | Full | No | No | No | No |
| Open WebUI Mobile | Yes | No | No | No | No | Yes | Yes |
| Jan.ai | Yes | Yes | No | No | No | No | Open |

**Pocket Claw is the only product that combines all seven columns.**

---

## Deployment Options

| Option | Description |
|---|---|
| **Standalone (offline)** | No server needed. Local LLM handles everything on-device. |
| **Self-hosted OpenClaw** | User runs OpenClaw on their own VPS. Full agentic capabilities. |
| **Tailscale-secured** | OpenClaw behind Tailscale VPN. Zero exposed ports. |
| **Managed hosting** | (Future) CARMEN-operated OpenClaw instances for paying users. |

---

## Codebase Summary

- **77 Dart source files** across the full architecture
- **4 bundled SKILL.md assets**
- **15,000+ lines of code**
- **Zero errors** on `flutter analyze`
- **267 MB APK** (includes MediaPipe native libraries for on-device inference)
- **Cross-platform:** Android APK builds verified, iOS and Web targets ready

---

*Pocket Claw v1.0.0 — CARMEN PTY LTD — April 2026*
*"Your personal AI agent, always in your pocket."*
