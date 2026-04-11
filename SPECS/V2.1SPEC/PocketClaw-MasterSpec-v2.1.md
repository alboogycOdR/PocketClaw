# Pocket Claw — Master Specification
## Version 2.1 — "Company in Your Pocket"
### Consolidated Reference Document — April 2026

**Product:** Pocket Claw Mobile AI Agent + Paperclip Orchestrator  
**Owner:** CARMEN PTY LTD  
**Maintainer:** Alister Witbooy  
**Status:** Stabilisation Phase → Commercial Launch Preparation  
**Platforms:** Android · iOS · Web  
**Target Market:** Individuals, SMBs, and Enterprises adopting AI Automation  
**Document Version:** 2.1  
**Supersedes:** Functional Spec v1.0, Developer Spec v2.0  

> ⚠️ **Verification Note:** Security vulnerability details referencing specific OpenClaw CVEs and Paperclip API schemas in this document were produced by a prior AI session and have not been independently verified against official changelogs. Developers should validate these details against the official OpenClaw and Paperclip repositories before building against them.

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [User Personas](#2-user-personas)
3. [Core Concepts](#3-core-concepts)
4. [Architectural Overview](#4-architectural-overview)
5. [Execution Paths](#5-execution-paths)
6. [Functional Areas](#6-functional-areas)
7. [Memory System](#7-memory-system)
8. [Security Model](#8-security-model)
9. [Data Architecture](#9-data-architecture)
10. [Integration Architecture](#10-integration-architecture)
11. [Non-Functional Requirements](#11-non-functional-requirements)
12. [Design System](#12-design-system)
13. [Commercial Launch Scope](#13-commercial-launch-scope)
14. [Developer Specification v2.1](#14-developer-specification-v21)
15. [Sprint Roadmap](#15-sprint-roadmap)
16. [Implementation Artefacts — Ordered](#16-implementation-artefacts--ordered)
17. [Starter Packs](#17-starter-packs)
18. [Marketing Assets](#18-marketing-assets)
19. [Known Constraints & Risks](#19-known-constraints--risks)
20. [Out of Scope — v2.1](#20-out-of-scope--v21)

---

## 1. Product Vision

### 1.1 What Pocket Claw Is

Pocket Claw is a **cross-platform mobile AI agent** that turns a smartphone into the mobile boardroom of a fully functional AI company. The phone is the **body** — providing camera, microphone, device APIs, and the human interface. OpenClaw agents are the **employees** — providing reasoning, tools, and 64K+ context. **Paperclip** is the **company itself** — providing orchestration, governance, budgets, org charts, goals, and accountability.

**Tagline:** *"A zero-human company in your pocket."*

### 1.2 Problem Statement

Current mobile AI solutions force a binary choice:

- **Cloud-only** apps (ChatGPT, Claude.ai mobile) are fast and capable but require internet, expose all queries to third parties, and cannot access device APIs.
- **Local-only** apps (llama.cpp frontends) are private and offline but lack the context window, tooling, and reasoning depth for complex agentic workflows.

Pocket Claw eliminates this trade-off by intelligently routing each request to the most appropriate execution environment, while wrapping everything in a governed, budget-aware company structure.

### 1.3 Value Proposition by Market Segment

| Segment | Value |
|---|---|
| **Individuals** | Personal AI team running 24/7 — health, fitness, learning, career |
| **Solo founders** | Fill every company role — marketing, ops, admin, strategy — without hiring |
| **Small businesses** | Affordable AI department with governance and org chart |
| **Enterprises** | Self-hosted, private, auditable AI automation platform |

No SaaS subscriptions. No vendor lock-in. Full ownership.

### 1.4 Design Principles

| Principle | Expression |
|---|---|
| Private by default | Local-first routing; sensitive data never leaves the device |
| Agentic when needed | Transparent escalation to server path |
| Company in Your Pocket | OpenClaw = employees; Paperclip = company; Pocket Claw = mobile HQ |
| Governance-first | Budgets, goals, approval gates on all consequential actions |
| Commercial-ready | One-tap company setup for any user size |
| Token-efficient | Smart context management + Claude Prompt Caching |
| Draft-and-Confirm | No uncontrolled autonomy — every consequential action requires user approval |

---

## 2. User Personas

### Primary: The Mobile Power User
A technical professional (developer, analyst, consultant) running complex workflows from their phone. Needs AI assistance without cloud dependency for sensitive tasks. Example: Operational Readiness Analyst managing contract work and a consulting practice simultaneously.

### Secondary: The Solo Founder / One-Person Business Owner
**Example:** Sarah — runs a boutique marketing + life-coaching practice. Handles strategy, delivery, admin, sales, and content alone. With Pocket Claw, she gets a complete virtual company that runs alongside her 24/7. She is the CEO who delegates to her AI team and steps in only for high-value decisions.

### Tertiary: The Secondary School Student (Grades 8–12)
Needs subject-specific tutoring, exam preparation, and motivational support across multiple subjects. Can use Pocket Claw in Academy Mode with subject tutors auto-generated from their subject selection.

### Quaternary: The Enterprise IT Professional
Large organisation deploying AI automation. Needs a full virtual IT project delivery team with governance, audit trails, and per-project memory isolation.

### Quinary: The Privacy-Conscious Professional
In a regulated industry (finance, legal, healthcare). Cannot send sensitive data to external APIs. Needs on-device inference for confidential queries with agentic capability for general work.

---

## 3. Core Concepts

| Concept | Definition |
|---|---|
| **Paperclip Orchestrator** | Open-source company OS (Node.js + React) that turns multiple OpenClaw agents into a governed organization |
| **AI Company** | Pocket Claw (mobile HQ) + OpenClaw (employees) + Paperclip (company infrastructure) |
| **Smart Router** | Decision engine classifying each message and routing to optimal execution path |
| **Skill (SKILL.md)** | A SKILL.md file with YAML frontmatter + Markdown instructions. Three runtime tiers: `local`, `server`, `bridge` |
| **Skill Registry** | In-memory index of all skills. Only names/descriptions loaded; full body loaded on trigger |
| **Tool Executor** | Runs device-side tool calls (file, camera, calendar, notifications, TTS) |
| **Mission Control** | Dashboard consuming OpenClaw Gateway + Paperclip — mirrors server dashboard natively in Flutter |
| **Bridge Skill** | Device captures input (camera, mic) → server processes → response to chat |
| **Draft-and-Confirm** | Agent produces draft; user confirms before execution. No unconfirmed sends/deletes/posts |
| **Project Memory** | Isolated namespace per project shared by all agents working on it |
| **Living Project Brief** | Auto-maintained summary (≤2K tokens) used as primary context for all agents |
| **Memory Router** | Lightweight component selecting minimal relevant context before each agent call |
| **Claude Prompt Caching** | Optimization caching stable context prefixes (Project Brief, governance rules, agent roles) to reduce token cost |
| **Heartbeat** | Paperclip keeps agents alive and coordinated |
| **Goal-Aware Tasks** | Every action traces to a company OKR |
| **Governance Gate** | Mandatory approval for budgets, high-cost tasks, or external actions |

---

## 4. Architectural Overview

```
╔══════════════════════════════════════════════════════════════════════╗
║                    POCKET CLAW MOBILE (Flutter 3.41+)                ║
╠══════════════════════════════════════════════════════════════════════╣
║  ┌──────────────────────────────────────────────────────────────┐    ║
║  │                        UI LAYER                               │    ║
║  │  Chat  │  Company (Mission Control)  │  Memory  │  Skills     │    ║
║  │        │  Overview/Org/Goals/Budgets │  Browser │  List       │    ║
║  │        │  Tickets/Governance/Security│  Editor  │  Detail     │    ║
║  └────────────────────────┬─────────────────────────────────────┘    ║
║                           │ Riverpod                                   ║
║  ┌────────────────────────▼─────────────────────────────────────┐    ║
║  │                  PROVIDER LAYER (Riverpod 2.6+)               │    ║
║  │  chatProvider  │  sessionProvider  │  memoryRouterProvider    │    ║
║  │  smartRouter   │  skillProvider    │  paperclipProvider       │    ║
║  │  llmEngine     │  missionProvider  │  academyModeProvider     │    ║
║  └────────────────────────┬─────────────────────────────────────┘    ║
║                           │                                            ║
║  ┌────────────────────────▼─────────────────────────────────────┐    ║
║  │                      CORE LAYER                               │    ║
║  │  SmartRouter  │  MemoryRouter  │  SkillRegistry  │  GROW FSM │    ║
║  │  ToolExecutor │  SessionMgr    │  SafetyClassifier            │    ║
║  │                                                               │    ║
║  │    ┌────────────────────────────────────────────────────┐    │    ║
║  │    │              Execution Paths                        │    │    ║
║  │    │   LOCAL          SERVER            BRIDGE           │    │    ║
║  │    │  ┌──────┐     ┌──────────┐      ┌──────────┐      │    │    ║
║  │    │  │Local │     │OpenClaw  │      │Device    │      │    │    ║
║  │    │  │Agent │     │+Paperclip│      │Capture → │      │    │    ║
║  │    │  │Engine│     │Client    │      │Server    │      │    │    ║
║  │    │  └──┬───┘     └────┬─────┘      └──────────┘      │    │    ║
║  │    └─────┼──────────────┼────────────────────────────────┘    │    ║
║  │          │              │                                       │    ║
║  │  ┌───────▼──────┐  ┌───▼──────────────────────┐              │    ║
║  │  │AbstractLLM   │  │Gateway WebSocket :18789   │              │    ║
║  │  │Engine        │  │+ Paperclip REST :3100     │              │    ║
║  │  │┌────┐ ┌────┐ │  └──────────────────────────┘              │    ║
║  │  ││Gem │ │LLM │ │                                              │    ║
║  │  ││ma  │ │Cpp │ │  ┌────────────────────────────────────┐    │    ║
║  │  │└────┘ └────┘ │  │  Memory System                      │    │    ║
║  │  └──────────────┘  │  ProjectMemory │ CompanyMem │ Sync  │    │    ║
║  │                    └────────────────────────────────────┘    │    ║
║  └───────────────────────────────────────────────────────────────┘    ║
║                                                                        ║
║  ┌──────────────────────────────────────────────────────────────┐     ║
║  │                     DATA LAYER                                │     ║
║  │   sqflite (sessions, messages, projects, tickets, sync queue) │     ║
║  │   flutter_secure_storage (tokens) │ App Documents (memory)   │     ║
║  └──────────────────────────────────────────────────────────────┘     ║
╚══════════════════════════════════════════════════════════════════════╝
                    │                          │
          ┌─────────▼──────┐        ┌──────────▼──────────┐
          │  On-Device LLM  │        │   VPS Backend        │
          │  .task (Gemma)  │        │  OpenClaw :18789     │
          │  .gguf (fllama) │        │  Paperclip :3100     │
          │  No network     │        │  Claude API          │
          │  Privacy-first  │        │  Tailscale access    │
          └─────────────────┘        └─────────────────────┘
```

### 4.1 Layer Responsibilities

| Layer | Responsibility |
|---|---|
| **UI Layer** | Flutter screens and widgets. Stateless where possible. Reads from providers. |
| **Provider Layer** | Riverpod providers. All business state. Bridges UI to Core. |
| **Core Layer** | Domain logic — routing, sessions, skills, engines, memory, device services. No Flutter imports. |
| **Data Layer** | Persistence — sqflite, SecureStorage, filesystem. |
| **Runtime Layer** | On-device LLM (flutter_gemma / fllama) and remote OpenClaw + Paperclip. |

### 4.2 Key Architectural Decisions

| Decision | Rationale |
|---|---|
| Flutter + Dart | Single codebase for Android, iOS, Web |
| Riverpod (not BLoC/GetX) | Compile-safe, testable, reactive, no singleton anti-patterns |
| GoRouter | Type-safe declarative routing; deep-link support |
| sqflite | Embedded SQL on device; no Firebase dependency |
| SKILL.md format | Interoperable with OpenClaw server |
| Draft-and-Confirm | Non-negotiable safety pattern for all consequential actions |
| AbstractLLMEngine | Decouples routing from model runtime — new engines without changing callers |
| Tailscale | Zero-trust encrypted mesh for VPS access — no public ports |
| Per-project memory isolation | Prevents cross-project context leakage |
| Claude Prompt Caching | Aggressive use of stable prefix caching for token efficiency |
---

## 5. Execution Paths

### 5.1 Smart Router Decision Logic (v2.1)

```
User Message
     │
     ▼
┌─────────────────────────────────────────────────────┐
│              Smart Router v2.1                       │
│                                                      │
│  1. User override? → Force path                     │
│  2. Server reachable? No → LOCAL (forced)           │
│  3. Local model loaded? No → SERVER (forced)        │
│                                                      │
│  4. Memory Router step:                             │
│     - Determine active project                      │
│     - Load Project Brief + targeted items           │
│     - Mark cacheable sections for Prompt Caching    │
│     - Estimate token count                          │
│                                                      │
│  5. Classification fallback chain:                  │
│     a. Privacy-sensitive keywords → LOCAL           │
│     b. Device hardware required → BRIDGE            │
│     c. Multi-step / tools / agentic → SERVER        │
│     d. Estimated tokens > 4K → SERVER               │
│     e. Short factual question → LOCAL               │
│     f. Default → LOCAL                              │
│                                                      │
│  6. Log RoutingReason + token count used            │
└─────────────────────────────────────────────────────┘
```

### 5.2 Routing Classification Rules

| Signal | Route |
|---|---|
| Short factual question (< 50 tokens) | Local |
| Privacy keywords detected | Local (forced) |
| Tool call required: `browse`, `send`, `email`, `shell` | Server |
| Estimated response > 4K tokens | Server |
| Multi-step agentic workflow | Server |
| Camera / mic input required | Bridge |
| No server connection | Local (forced) |
| No local model | Server (forced) |
| Paperclip governance gate triggered | Server |

### 5.3 Path Characteristics

| Attribute | Local | Server | Bridge |
|---|---|---|---|
| Network required | No | Yes | Yes |
| Privacy | Full | User-controlled (own Claude key) | Partial |
| Context window | 4–8K (model dependent) | 64K+ | 64K+ (server side) |
| Tools available | Device APIs only | Full OpenClaw + Paperclip toolset | Both |
| Latency | Low (CPU inference) | Medium (network RTT) | Medium–High |
| Token cost | Free | Claude API tokens | Claude API tokens |

### 5.4 Memory Router Responsibilities

Before every server-path call:
- Identifies active project from message context or session
- Retrieves Project Brief + minimal relevant supporting items
- Constructs cacheable prefix (Project Brief + governance rules + agent roles)
- Enforces token budget before routing to server
- Falls back to local memory when server unavailable

---

## 6. Functional Areas

### 6.1 Chat Interface

**Purpose:** Primary human interface. Consistent regardless of which execution path handles the response.

**Features:**

- Text input with send button
- Voice input button (Phase 2 — Gemma E2B native audio)
- Attachment button: file, image, camera
- **Execution Path Chip:** Always visible above input bar — teal (LOCAL) / red (SERVER) / amber (BRIDGE). Tappable to view routing reason and override.
- Streamed token output (local and server)
- Markdown rendering with syntax highlighting
- Collapsible tool-call blocks
- Inline memory citations
- **Draft-and-Confirm cards** for all consequential actions
- Loading indicator and error state with retry

**Session Management:**
- Named sessions persisted in sqflite
- Swipe to delete, search history
- Model indicator shows active local model or "OpenClaw"

---

### 6.2 Company Tab (Replaces "Control")

**Purpose:** Central hub for Paperclip company management. The core of the v2.0 experience.

**Tab Navigation:** Overview | Org Chart | Goals | Budgets | Tickets | Governance | Security

#### Overview Sub-tab
- Summary cards: Agents Online, Today's Spend, Active Goals (with progress), Connection Health
- Quick actions: New Project, Spawn Agent, Activate Pack, Daily Briefing
- Recent Activity list

#### Org Chart Sub-tab
- Hierarchical agent tree (using `flutter_graph_view`)
- Tap agent → Agent Card with current task, cost today, goal alignment
- Project filter dropdown
- Drag-and-drop reorg (Phase 2)

#### Goals Sub-tab
- Company → Department → Agent OKR Kanban
- Real-time progress bars from Paperclip WebSocket
- Assign to Agent button

#### Budgets Sub-tab
- Token usage per agent + company total
- Charts (`fl_chart`)
- Daily/weekly/monthly toggle
- Alert when >80% used → Smart Router auto-prefers local

#### Tickets Sub-tab
- Full threaded Kanban (Todo | In Progress | Done)
- Drag-and-drop task cards
- Goal linkage and tool-call tracing

#### Governance Sub-tab
- Pending approval queue (Draft-and-Confirm previews)
- Audit log summary
- Pause/terminate agent controls

#### Security Sub-tab *(New in v2.0)*
- Tailscale connection status (connected / disconnected)
- Recent governance events (last 10)
- Token usage anomaly alerts
- Security health score
- Quick actions: Rotate Tokens, Pause All Agents, Export Audit Log

**Disconnected State:**
- Friendly cloud icon + "Set Up My AI Company" CTA → launches Paperclip onboarding wizard

---

### 6.3 Local Agent Engine

**Purpose:** Orchestrates on-device inference and tool use for Local path messages.

**Flow:**
1. Receive routed message from Smart Router
2. Build prompt with system context, active skill, Memory Router context
3. Stream response from `AbstractLLMEngine`
4. Parse tool calls embedded in model output
5. Execute tool calls via `ToolExecutor`
6. Inject tool results back into context
7. Return completed response to Chat provider

**Tool Executor — Device Tools:**

| Tool | Status |
|---|---|
| `read_file` | Done |
| `write_file` | Done |
| `share_content` | Done |
| `list_files` | Done |
| `get_calendar_events` | Stubbed |
| `create_calendar_event` | Stubbed (Draft-and-Confirm required) |
| `take_photo` | Stubbed |
| `send_notification` | Stubbed |
| `speak_text` | Stubbed |
| `set_reminder` | Stubbed |

---

### 6.4 OpenClaw + Paperclip Integration

**Connection:**
- Gateway WebSocket: `ws://<vps>:18789/ws` (persistent, exponential backoff reconnect)
- Paperclip REST: `http://<vps>:3100/api`
- All access via Tailscale only (no public ports)
- Bearer tokens stored in `flutter_secure_storage`

**Paperclip WebSocket Events consumed:**
- `paperclip:org:update`
- `paperclip:goal:progress`
- `paperclip:budget:alert`
- `paperclip:ticket:created`
- `paperclip:governance:event`
- `project:phase:update`

**Paperclip adapter configuration (on VPS):**
```json
{
  "adapter": "openclaw",
  "webhookUrl": "http://localhost:18789/hooks/agent",
  "webhookAuthHeader": "Bearer YOUR_OPENCLAW_TOKEN",
  "timeoutSec": 30
}
```

---

### 6.5 Model Management

**Supported Runtimes:**

| Runtime | Package | Format | Models |
|---|---|---|---|
| MediaPipe / LiteRT | `flutter_gemma` | `.task` | Gemma 3 270M, Gemma 3 1B, Gemma 4 E2B |
| llama.cpp | `fllama` | `.gguf` | Llama 3.2 1B, 3B; Phi-3.5 Mini, Phi-3 Mini; Qwen 2.5 0.5B, 1.5B; SmolLM2 1.7B |

**Model Catalogue (10 models):**

| Model | Provider | Size | RAM | Format | Capabilities |
|---|---|---|---|---|---|
| Gemma 4 E2B | Google | 1.5 GB | 6 GB | .task | text, vision, audio, function calling |
| Gemma 3 1B | Google | 0.6 GB | 4 GB | .task | text |
| Gemma 3 270M | Google | 0.3 GB | 2 GB | .task | text |
| Llama 3.2 3B | Meta | 1.8 GB | 4 GB | .gguf | text, reasoning |
| Llama 3.2 1B | Meta | 0.7 GB | 2 GB | .gguf | text |
| Phi-3.5 Mini | Microsoft | 2.2 GB | 4 GB | .gguf | text, reasoning, code |
| Phi-3 Mini 3.8B | Microsoft | 2.3 GB | 4 GB | .gguf | text, reasoning, code |
| Qwen 2.5 1.5B | Alibaba | 0.9 GB | 2 GB | .gguf | text, code, multilingual |
| Qwen 2.5 0.5B | Alibaba | 0.4 GB | 1 GB | .gguf | text, multilingual |
| SmolLM2 1.7B | HuggingFace | 1.0 GB | 2 GB | .gguf | text, reasoning |

**All models require a HuggingFace token for download.** Token stored in `flutter_secure_storage`. Validated via `GET https://huggingface.co/api/whoami`.

---

### 6.6 Skills System

**SKILL.md Format:**
```yaml
---
name: skill-name
description: "What this skill does"
version: 1.0.0
tier: local | server | bridge | hybrid
triggers:
  - "trigger phrase"
tools:
  - read_file
author: CARMEN PTY LTD
---
# Full skill instructions loaded only when triggered
```

**Runtime Tiers:**

| Tier | Execution | Use Cases |
|---|---|---|
| `local` | On-device | Notes, calculations, private queries |
| `server` | OpenClaw/Paperclip | Web research, email, complex multi-step |
| `bridge` | Device capture + server | Photo → OCR, voice → analysis |
| `hybrid` | Both | Pack-level orchestration |

**Bundled Skills (v1):** notes, calculator, forex-calc, reminder

---

### 6.7 Settings & Configuration

**Sections:**
- **General** — Default execution path, theme
- **API Keys** — HuggingFace Token, OpenClaw Server URL + Token, Claude API Key (reserved)
- **Paperclip Company** — Company Name, Mission, Governance Mode (Strict/Advisory), Monthly Budget, Connect/Disconnect
- **Local Models** — Model catalogue, download, delete, active model
- **Memory & Context** — Project memory isolation (on), Auto Project Brief Refresh, Claude Prompt Caching (on), Clear Project Memory
- **Smart Router** — Token threshold, privacy keywords, show routing reason (debug)
- **Skills** — Enable/disable, user skill directory
- **Security & Privacy** — Biometric lock, local data handling
- **About** — App version, OpenClaw version, licenses

---

### 6.8 Onboarding (Commercial Edition)

**Flow:**
1. Welcome → "Build Your AI Company" + tagline
2. Choose starter template: Solo Founder OS / Small Business / Enterprise IT / Academy / Life Architect / Custom
3. VPS setup wizard (paste IP or run installer)
4. HuggingFace token input
5. Auto-import selected pack into Paperclip
6. First agent heartbeat test
7. Ready → "Your company is live!"

**Target:** 90 seconds to first meaningful action.

---

## 7. Memory System

### 7.1 Architecture (v2.1)

```
Memory System
├── Project Memory (per-project isolation by default)
│   ├── /projects/{projectId}/brief.md   ← Living Project Brief (≤2K tokens)
│   ├── /projects/{projectId}/tickets/
│   ├── /projects/{projectId}/requirements/
│   ├── /projects/{projectId}/design/
│   ├── /projects/{projectId}/risks/
│   └── /projects/{projectId}/archive/
│
├── Company Memory (Paperclip managed)
│   ├── Goals / OKRs
│   ├── Org Chart
│   ├── Budgets
│   └── Audit Logs
│
├── Local Memory Manager
│   ├── On-device Markdown files + sqflite index
│   ├── Full offline read/write
│   └── Offline write queue → sync on reconnect
│
├── Server Memory (OpenClaw + Paperclip)
│   ├── OpenClaw native memory
│   └── Paperclip structured store
│
└── SyncManager
    ├── Last-write-wins (timestamp)
    ├── Offline queue in sqflite
    └── Claude Prompt Caching for stable prefixes
```

### 7.2 Design Decisions (Locked)

| Decision | Value |
|---|---|
| Per-project memory isolation | **Enabled by default** |
| Agents sharing memory within a project | **Yes — all share one project store** |
| Living Project Brief | **≤2K tokens, auto-maintained** |
| Claude Prompt Caching | **Enabled — stable prefixes: Brief + governance + agent roles** |
| On-device vector RAG | **Deferred to Sprint 4 (v2.2)** |

### 7.3 Token Efficiency Strategy

- Default calls inject only summaries (Project Brief + relevant ticket summaries) → ~1–2K tokens
- Claude caching makes repeated company/project context very cheap (cache read: ~0.1× normal cost)
- Local models handle quick recall / offline tasks at zero Claude API cost
- Only deep reasoning or multi-agent coordination escalates to full context
- Budget alerts at 80% trigger Smart Router to prefer local path automatically

### 7.4 Context Injection Pattern

Every agent call receives:
1. Short system prompt + role definition
2. **Project Brief** (always — Claude cached)
3. Relevant recent tickets/goals (summarized — 2–4 items)
4. User's last 3–5 interactions (if relevant)
5. Governance rules (Claude cached)

### 7.5 Project Brief Summarization Prompt

```
You are an expert technical project memory manager for an AI company platform.

Project ID: {projectName}
Current Phase: {phase}

Recent Activity Summary:
{recentActivity}

Previous Project Brief:
{previousBrief}

Create a fresh, concise Project Brief (maximum 1800 tokens) that any agent on the team
can use as primary context.

Requirements:
- Start with current status and phase.
- List active goals and key deliverables with deadlines if known.
- Highlight major decisions, risks, and open blockers.
- Include important technical constraints or architecture notes.
- Use clear bullet points and short paragraphs.
- End with "Last updated: {timestamp}"

Output ONLY the brief. No extra text, explanations, or markdown headers outside the content.
```

---

## 8. Security Model

### 8.1 Credential Storage

All API tokens stored exclusively in `flutter_secure_storage`:
- Android: EncryptedSharedPreferences (AES-256)
- iOS: Keychain Services
- Web: No sensitive tokens (local-only mode recommended)

### 8.2 Data Privacy

| Data Type | Storage | Leaves Device |
|---|---|---|
| Local-path messages | sqflite (device only) | Never |
| Server-path messages | sqflite + OpenClaw | Via user's own Claude key / Tailnet |
| Project & Company memory | Per-project isolation | Only when explicitly synced |
| Model files | App Documents filesystem | Never |
| API tokens | flutter_secure_storage | Never |

Sensitive queries are forced to LOCAL path by Smart Router.

### 8.3 Draft-and-Confirm Security

All consequential actions — send email, create calendar event, deploy code, external API calls, file writes affecting external systems — must go through Draft-and-Confirm. The Tool Executor and Paperclip governance layer enforce this. Agents cannot bypass it.

### 8.4 No Uncontrolled Autonomy

- Mobile app processes one user turn at a time
- No background autonomous loops on device
- Cron/scheduled work runs server-side under Paperclip governance only

### 8.5 Threat Model

| Threat | Mitigation |
|---|---|
| Phone compromised/lost | Local data protected by device encryption + secure storage. Remote wipe via MDM. |
| VPS compromised | Blast radius limited by Tailscale isolation + per-project memory. Local device data remains private. |
| Network MITM / public exposure | All remote access via Tailscale only. Ports 18789 and 3100 never exposed publicly. |
| Malicious skills / prompt injection | Only vetted commercial packs bundled. Governance + Draft-and-Confirm blocks dangerous actions. |
| Token theft | All tokens in secure storage. Rotation reminder in Settings. |

### 8.6 OpenClaw & Paperclip Hardening

- **Network Isolation:** Tailscale is the required and recommended secure access method. Services bound to localhost inside VPS. No public port exposure.
- **Docker & Container Hardening:** Optional. One-click installer provides basic Docker Compose. Advanced hardening (user namespaces, read-only volumes, seccomp) left to user or enterprise IT.
- **Authentication:** Strong Bearer tokens for OpenClaw Gateway and Paperclip. Token rotation encouraged.
- **Governance:** Strict mode enabled by default for Enterprise and commercial packs.
- **Skill Vetting:** Only audited SKILL.md files in commercial starter packs.

> ⚠️ **Risk Acceptance:** OpenClaw and Paperclip are treated as high-privilege execution environments. Users are responsible for maintaining Tailscale, keeping the VPS updated, and monitoring governance logs. Sensitive workflows should prefer the Local path.

### 8.7 Security Dashboard (New in v2.0)

Located in Company tab → Security sub-tab:
- **Tailscale Status:** Connected / Disconnected + indicator
- **Recent Governance Events:** Last 10 approval actions, blocked attempts, escalations
- **Token Usage Anomalies:** Unusual spend patterns, budget threshold alerts
- **Security Health Score:** Good / Review Recommended
- **Quick Actions:** Rotate tokens, Pause all agents, Export audit log

---

## 9. Data Architecture

### 9.1 sqflite Schema (v2.1)

```sql
-- Sessions
CREATE TABLE sessions (
  id TEXT PRIMARY KEY, title TEXT, created_at INTEGER,
  updated_at INTEGER, model_id TEXT, path TEXT
);

-- Messages
CREATE TABLE messages (
  id TEXT PRIMARY KEY, session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
  role TEXT, content TEXT, path TEXT, model_id TEXT,
  tool_calls TEXT, created_at INTEGER
);

-- Tool execution log
CREATE TABLE tool_executions (
  id TEXT PRIMARY KEY, message_id TEXT REFERENCES messages(id),
  tool_name TEXT, parameters TEXT, result TEXT,
  status TEXT, created_at INTEGER
);

-- Local memory index
CREATE TABLE memory_items (
  id TEXT PRIMARY KEY, title TEXT, tags TEXT,
  file_path TEXT, created_at INTEGER, updated_at INTEGER, synced_at INTEGER
);

-- Model downloads
CREATE TABLE model_downloads (
  model_id TEXT PRIMARY KEY, status TEXT, progress REAL DEFAULT 0,
  local_path TEXT, downloaded_at INTEGER, error_message TEXT
);

-- Projects (v2.0)
CREATE TABLE projects (
  id TEXT PRIMARY KEY, name TEXT, status TEXT,
  phase TEXT, budget_used INTEGER DEFAULT 0, created_at INTEGER,
  last_brief_update INTEGER
);

-- Project tickets
CREATE TABLE project_tickets (
  id TEXT PRIMARY KEY, project_id TEXT REFERENCES projects(id),
  content TEXT, status TEXT, created_at INTEGER
);

-- Project agents
CREATE TABLE project_agents (
  project_id TEXT REFERENCES projects(id),
  agent_name TEXT, role TEXT, status TEXT
);

-- Paperclip company
CREATE TABLE paperclip_companies (
  id TEXT PRIMARY KEY, name TEXT, mission TEXT,
  budget_limit INTEGER, governance_mode TEXT, last_sync INTEGER
);

-- Paperclip events
CREATE TABLE paperclip_events (
  id TEXT PRIMARY KEY, company_id TEXT, event_type TEXT,
  payload TEXT, created_at INTEGER
);

-- Sync queue
CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY, entity_type TEXT, entity_id TEXT,
  operation TEXT, payload TEXT, created_at INTEGER
);
```

### 9.2 Filesystem Layout

```
App Documents Directory/
├── projects/
│   └── {projectId}/
│       ├── brief.md
│       ├── tickets/
│       ├── requirements/
│       ├── design/
│       ├── risks/
│       └── archive/
├── memory/
│   ├── notes/
│   ├── forex/
│   └── work/
├── models/
│   ├── gemma/          ← .task files
│   └── gguf/           ← .gguf files
├── skills/             ← user skill packs
└── exports/
```

### 9.3 Secure Storage Keys

| Key | Contents |
|---|---|
| `hf_token` | HuggingFace API token |
| `openclaw_token` | OpenClaw bearer token |
| `paperclip_token` | Paperclip bearer token |
| `claude_api_key` | Direct Claude API key (reserved) |
| `vertex_api_key` | Google Vertex AI key (Academy mode) |

---

## 10. Integration Architecture

### 10.1 HuggingFace
- All model downloads (`.task` and `.gguf`)
- Auth: Bearer token (`hf_` prefix)
- Token validation: `GET https://huggingface.co/api/whoami`

### 10.2 OpenClaw Gateway
- Protocol: WebSocket + HTTP REST on port 18789
- Auth: Bearer token in Authorization header
- Reconnect: Exponential backoff, max 60s, indefinite retry

### 10.3 Paperclip
- Protocol: HTTP REST + WebSocket on port 3100
- Official OpenClaw adapter configuration
- Events proxied through existing Gateway WebSocket where possible

### 10.4 Claude API (via OpenClaw)
- Pocket Claw does **not** call Claude API directly in v2.1
- All Claude API calls proxied through OpenClaw server
- Server manages context, system prompts, tool orchestration, token accounting

### 10.5 Google Vertex AI RAG (Academy Mode only)
- **Direct API call from mobile app** — no OpenClaw/Paperclip dependency
- Used by Subject Tutor agents for textbook content retrieval
- Endpoint and API key stored in `flutter_secure_storage`
- Query format: `{ "query": question, "subject": subject, "topK": 3 }`

---

## 11. Non-Functional Requirements

| Metric | Target |
|---|---|
| App cold start | < 3 seconds |
| First token (local, Gemma 270M) | < 2 seconds |
| First token (server path) | < 1.5 seconds (network dependent) |
| Memory search response | < 500ms |
| Mission Control WebSocket latency | Real-time (< 200ms) |
| App base RAM (no model) | < 150 MB |
| Storage (app + assets, no models) | < 50 MB |

**Platform Support:**

| Platform | Minimum | Notes |
|---|---|---|
| Android | API 24 (7.0) | Required by fllama |
| iOS | iOS 15 | flutter_gemma requirement |
| Web | Latest 2 Chrome versions | Server path only; no local LLM |

**Offline capability:** Local path chat, file read/write, memory read/write all work offline. Sync queued.

---

## 12. Design System

### 12.1 Colour Palette

| Token | Hex | Usage |
|---|---|---|
| `lobsterRed` | `#E53935` | Server path indicator, CTAs, active tab |
| `charcoal` | `#1A1A2E` | Primary background |
| `electricTeal` | `#00E5CC` | Local path indicator, success states |
| `surfaceDark` | `#16213E` | Card backgrounds |
| `surfaceMid` | `#0F3460` | Elevated surfaces |
| `warningAmber` | `#FFB74D` | Bridge path, warnings, beta badges |
| `textPrimary` | `#FFFFFF` | Body text |
| `textSecondary` | `#B0BEC5` | Metadata, captions |
| `errorRed` | `#CF6679` | Error states |

### 12.2 Typography

| Role | Font | Weight | Size |
|---|---|---|---|
| Code | JetBrains Mono | Regular | 13sp |
| Body | Roboto | Regular | 14sp |
| Heading | Roboto | Bold | 18sp |
| Display | Roboto | Black | 24sp |

### 12.3 Execution Path Visual Language

| Path | Colour | Icon |
|---|---|---|
| Local | `electricTeal` | `Icons.phone_android` |
| Server | `lobsterRed` | `Icons.cloud` |
| Bridge | `warningAmber` | `Icons.sync_alt` |

### 12.4 Bottom Navigation (v2.0)

| Tab | Icon | Notes |
|---|---|---|
| Chat | `speech_bubble` | Primary interface |
| Company | `business` | Replaces "Control" |
| Memory | `book` | Unchanged |
| Skills | `extension` | Unchanged |
| Settings | `settings` | Unchanged |

---

## 13. Commercial Launch Scope

**Target Segments:** Individuals, SMBs (2–50 agents), Enterprises (self-hosted)

**Starter Packs (bundled at launch):**
- Solo Founder OS (Marketing + Life Coaching one-person business)
- Forex Power User
- Enterprise IT Project Team (12-agent full IT delivery team)

**Launch Assets:**
- One-click VPS installer (Docker Compose, Tailscale recommended)
- Mobile app on Google Play + TestFlight
- Marketing site + demo video
- Vetted, audited SKILL.md packs

**Pricing Model (proposed):**
- Free: 1 agent, local models only
- Pro ($29/mo): Full server path, all packs
- Enterprise: Self-hosted license, support SLA
---

## 14. Developer Specification v2.1

### 14.1 Tech Stack

**Mobile (Flutter 3.41+)**

| Package | Purpose |
|---|---|
| `flutter_riverpod: ^2.6.1` | State management |
| `go_router: ^17.1.0` | Navigation |
| `flutter_gemma` | Gemma .task model runtime |
| `fllama` | GGUF model runtime (llama.cpp) |
| `sqflite: ^2.4.0` | Local database |
| `flutter_secure_storage: ^9.2.0` | Token storage |
| `http: ^1.3.0` | HTTP client |
| `web_socket_channel: ^3.0.0` | WebSocket for Gateway |
| `share_plus` | System share sheet |
| `file_picker` | File access |
| `camera` | Camera capture |
| `device_calendar` | Calendar integration |
| `flutter_tts` | Text-to-speech |
| `flutter_local_notifications` | Local push |
| `fl_chart` | Budgets and cost charts |
| `flutter_graph_view` | Org Chart visualization |
| `path_provider` | App documents directory |

**VPS Backend**
- OpenClaw (existing, port 18789)
- Paperclip (port 3100) with official `openclaw` adapter
- Docker Compose (one-click installer)
- Tailscale (mandatory for secure remote access)
- PostgreSQL (embedded in Paperclip)

### 14.2 Project Structure

```
pocket_claw/
├── lib/
│   ├── core/
│   │   ├── smart_router.dart
│   │   ├── memory_router.dart           ← New v2.1
│   │   ├── memory_service.dart          ← New v2.1
│   │   ├── abstract_llm_engine.dart
│   │   ├── llm_engine_factory.dart
│   │   ├── tool_executor.dart
│   │   ├── skill_registry.dart
│   │   └── coaching/
│   │       ├── grow_state_machine.dart  ← New v2.1
│   │       └── safety_classifier.dart   ← New v2.1
│   ├── features/
│   │   ├── chat/
│   │   ├── company/                     ← New v2.0 (replaces control)
│   │   │   ├── company_screen.dart
│   │   │   ├── overview_tab.dart
│   │   │   ├── org_chart_tab.dart
│   │   │   ├── goals_tab.dart
│   │   │   ├── budgets_tab.dart
│   │   │   ├── tickets_tab.dart
│   │   │   ├── governance_tab.dart
│   │   │   └── security_dashboard_tab.dart
│   │   ├── academy/                     ← New Sprint 11
│   │   │   ├── academy_screen.dart
│   │   │   └── academy_mode_provider.dart
│   │   ├── life_architect/              ← New Sprint 12
│   │   ├── memory/
│   │   ├── skills/
│   │   └── onboarding/
│   ├── providers/
│   │   ├── smart_router_provider.dart
│   │   ├── memory_router_provider.dart  ← New
│   │   ├── paperclip_provider.dart      ← New
│   │   ├── llm_providers.dart
│   │   └── session_provider.dart
│   ├── data/
│   │   └── repositories/
│   │       └── project_memory_repository.dart ← New
│   ├── services/
│   │   ├── paperclip_client.dart        ← New
│   │   ├── hf_token_service.dart
│   │   └── vertex_rag_service.dart      ← New (Academy)
│   └── widgets/
│       ├── execution_path_chip.dart     ← New
│       └── draft_confirm_modal.dart     ← New
├── assets/
│   └── skills/
│       ├── forex-power-user/
│       ├── solo-founder-os/
│       ├── enterprise-it-project-team/
│       ├── personal-ai-academy/
│       └── life-architect/
├── pubspec.yaml
└── docker/
    └── install-pocket-claw-company.sh
```

### 14.3 Riverpod Providers (Complete List)

```dart
// Core providers
final routerProvider = Provider<GoRouter>((ref) => ...);
final smartRouterProvider = Provider<SmartRouter>((ref) => SmartRouter(ref));
final memoryRouterProvider = Provider<MemoryRouter>((ref) => MemoryRouter(ref));
final memoryServiceProvider = Provider<MemoryService>((ref) => MemoryService(ref));

// LLM
final selectedModelProvider = StateProvider<LocalModelConfig>((ref) => kDefaultModel);
final llmEngineProvider = FutureProvider<AbstractLLMEngine>((ref) async { ... });
final hasHFTokenProvider = FutureProvider<bool>((ref) async { ... });

// Paperclip / Company
final paperclipProvider = StateNotifierProvider<PaperclipNotifier, PaperclipState>((ref) => PaperclipNotifier());
final missionProvider = Provider.family<MissionState, String>((ref, tab) => ...);

// Session
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>(...);

// Skills
final skillRegistryProvider = Provider<SkillRegistry>((ref) => SkillRegistry());

// Vertical modes
final academyModeProvider = StateNotifierProvider<AcademyModeNotifier, AcademyModeState>((ref) => AcademyModeNotifier());
```

### 14.4 VPS One-Click Installer

```bash
#!/bin/bash
# docker/install-pocket-claw-company.sh
echo "=== Pocket Claw + OpenClaw + Paperclip Installer ==="

apt update && apt upgrade -y
apt install -y docker.io docker-compose git curl

mkdir -p /opt/pocketclaw/data
cd /opt/pocketclaw

cat > docker-compose.yml <<EOF
version: '3.9'
services:
  openclaw:
    image: openclaw/openclaw:latest
    ports:
      - "127.0.0.1:18789:18789"
    environment:
      - CLAUDE_API_KEY=\${CLAUDE_API_KEY}
    volumes:
      - ./data:/data

  paperclip:
    image: paperclipai/paperclip:latest
    ports:
      - "127.0.0.1:3100:3100"
    depends_on:
      - openclaw
    environment:
      - OPENCLAW_ENDPOINT=http://openclaw:18789
      - PAPERCLIP_TOKEN=\${PAPERCLIP_TOKEN}
    volumes:
      - ./data:/data

  postgres:
    image: postgres:16
    environment:
      - POSTGRES_DB=paperclip
      - POSTGRES_USER=paperclip
      - POSTGRES_PASSWORD=paperclip
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
EOF

OPENCLAW_TOKEN=$(openssl rand -hex 32)
PAPERCLIP_TOKEN=$(openssl rand -hex 32)
echo "OPENCLAW_TOKEN=$OPENCLAW_TOKEN" > .env
echo "PAPERCLIP_TOKEN=$PAPERCLIP_TOKEN" >> .env
echo "CLAUDE_API_KEY=sk-..." >> .env

docker compose up -d

echo "=== Security Recommendations ==="
echo "1. Install Tailscale: curl -fsSL https://tailscale.com/install.sh | sh"
echo "2. Run: tailscale up"
echo "3. Use Tailscale ACLs to restrict access to only trusted devices"
echo "4. Services are bound to 127.0.0.1 — access ONLY via Tailscale"
echo "5. Never expose ports 18789 or 3100 publicly"
echo ""
echo "Tokens saved in .env — copy to Pocket Claw Settings > API Keys"
```

---

## 15. Sprint Roadmap

### Sprint 1 — Core Foundation (7–10 days)
**Goal:** Unblock development, establish v2.0 UI skeleton, fix 401 bug.

1. HuggingFace token management + fix Gemma 401 error
2. AbstractLLMEngine + GemmaEngine + LlamaCppEngine + LLMEngineFactory
3. MemoryRouter + ProjectMemoryRepository (sqflite + filesystem)
4. MemoryService + Project Brief summarization service
5. Execution Path Chip widget
6. Company Tab structure (7 sub-tabs skeleton)
7. Company Overview sub-tab
8. Security Dashboard sub-tab
9. Draft-and-Confirm modal system

### Sprint 2 — Integration & Polish (5–7 days)
**Goal:** Wire all components together end-to-end.

1. Project Brief auto-summarization background service
2. Starter Pack auto-import and activation (Solo Founder, Forex, Enterprise IT)
3. Tailscale status detection + enhanced connection handling
4. PaperclipNotifier full class
5. Smart Router + Memory Router integration
6. Bottom nav rename (Control → Company)

### Sprint 3 — Stabilisation & Testing (5–7 days)
**Goal:** Production-ready core before vertical modes.

1. Bug fixing from Sprints 1–2
2. flutter analyze — zero errors/warnings
3. Test with Enterprise IT Project Team pack (12-agent shared memory)
4. Performance testing (model load times, cold start)
5. Offline mode validation
6. UI polish (animations, empty states, error handling)

### Sprint 4 — Advanced Memory & RAG (8–12 days)
**Goal:** Intelligent long-term context at scale.

- On-device vector embeddings (flutter_gemma embeddings API)
- Hybrid retrieval: local vector search + server fallback
- Multi-level hierarchical summarization
- Cross-project knowledge sharing with privacy controls
- Memory health dashboard
- Token usage forecasting

### Sprint 5 — Multi-Agent Collaboration (10–14 days)
**Goal:** True agent-to-agent coordination.

- Agent-to-agent communication protocol via Paperclip tickets
- Multi-agent workflows with handoff chains (BA → Architect → Dev → QA)
- Shared workspace real-time collaboration view
- Agent delegation and sub-tasks with approval chains
- Multi-agent chat view (group conversation simulation)

### Sprint 6 — Enterprise Readiness (12–16 days)
**Goal:** Multi-user, regulated environments.

- Multi-user support with role-based access (Admin, Manager, Viewer)
- SSO integration (OAuth2 / OIDC)
- Immutable audit logging with compliance export
- GDPR-style data handling (export, deletion, consent)
- Governance rule builder UI
- Support for 50+ agents, multiple concurrent projects
- Backup and restore for entire company state

### Sprint 7 — AI Company Self-Improvement (14–18 days)
- Agent self-improvement loop (propose → vote → human approval)
- Company Constitution (version-controlled principles)
- Automated agent performance reviews
- Company memory timeline
- Company Annual Report auto-generation

### Sprint 8 — Physical-Digital Bridge (16–20 days)
- Deep device hardware integration (GPS, IoT APIs)
- Bridge Skill 2.0 (control external devices via secure APIs)
- Document scan → OCR → project memory pipeline
- Voice-first Company Mode ("Hey Claw, run morning standup")
- Field Operator Mode (offline-heavy, voice commands)

### Sprint 9 — Multi-Company Ecosystem (18–22 days)
- Switch between multiple AI companies (personal, clients, side businesses)
- Company Templates Marketplace (user-generated)
- Inter-company secure collaboration
- ClawHub 2.0 (vetted skill marketplace with reputation system)
- Company Health Scoring
- Company Merger mode

### Sprint 10 — Autonomous Company (20–25 days)
- Autonomous Mode with configurable trust levels and kill switch
- Long-term strategic planning (1/3/5-year scenario modeling)
- Succession and continuity rules
- Ethical oversight layer (configurable review board)
- Digital Twin Company (parallel simulation for what-if scenarios)

### Sprint 11 — Personal AI Academy (Education Vertical)
**Full vertical mode — separate purchasable pack**

- Full vertical mode with Academy tab
- Dynamic subject tutor creation (student selects subjects)
- Student Success Coach (always present)
- Student Profile brief (learning style, strengths, weaknesses, exam dates)
- Per-subject memory isolation under `/academy/subjects/{subject}/`
- Vertex RAG Bridge Skill — direct API call to existing Google Vertex AI RAG pipeline
- Exam countdown widget, study streak, daily check-in
- Offline-first priority (local models for daily tutoring)
- Parental oversight: **Backlogged**

**Supported subjects (dynamic):** Mathematics, Physical Sciences, Life Sciences, English, History, Accounting, Geography, Business Studies, and more.

### Sprint 12 — Life Architect (Personal Life Coaching Vertical)
**Full vertical mode — separate purchasable pack**

- Master Life Architect agent (always present — conductor)
- Modular facet coaches (user-selectable): Fitness & Movement, Health & Bio, Mind & Emotional, Business & Career, Learning & Growth, Habit & Discipline
- GROW session scaffold state machine
- Accountability loop with commitment capture and check-ins
- Adaptive mode switching (Supportive / Challenging / Exploratory / Executional)
- Safety classifier (crisis detection + therapy drift guard) on every message
- Living Life Blueprint (shared by all agents)
- Per-facet memory sub-namespaces under `/life/{facet}/`
- Health report secure upload with strong disclaimers
- Fitness tracker API integration (or manual import)

---

## 16. Implementation Artefacts — Ordered

### Phase 0 — Foundation (Start Here)

#### Artefact 1: Execution Path Chip Widget

```dart
// lib/widgets/execution_path_chip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/smart_router_provider.dart';

enum ExecutionPath { local, server, bridge }

class ExecutionPathChip extends ConsumerWidget {
  const ExecutionPathChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(smartRouterProvider);
    final path = router.currentPath;
    final color = _getColor(path);

    return GestureDetector(
      onTap: () => _showPathOptions(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIcon(path), size: 16, color: color),
            const SizedBox(width: 6),
            Text(path.name.toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Color _getColor(ExecutionPath path) => switch (path) {
    ExecutionPath.local  => Colors.tealAccent,
    ExecutionPath.server => Colors.redAccent,
    ExecutionPath.bridge => Colors.amberAccent,
  };

  IconData _getIcon(ExecutionPath path) => switch (path) {
    ExecutionPath.local  => Icons.phone_android,
    ExecutionPath.server => Icons.cloud,
    ExecutionPath.bridge => Icons.sync_alt,
  };

  void _showPathOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const PathOverrideBottomSheet(),
    );
  }
}

class PathOverrideBottomSheet extends StatelessWidget {
  const PathOverrideBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: const Text("Force Local"), onTap: () => Navigator.pop(context)),
        ListTile(title: const Text("Force Server"), onTap: () => Navigator.pop(context)),
        ListTile(title: const Text("Force Bridge"), onTap: () => Navigator.pop(context)),
        ListTile(title: const Text("Cancel"), onTap: () => Navigator.pop(context)),
      ]),
    );
  }
}
```

---

#### Artefact 2: MemoryRouter

```dart
// lib/core/memory_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/project_memory_repository.dart';

final memoryRouterProvider = Provider<MemoryRouter>((ref) => MemoryRouter(ref));

class MemoryContext {
  final String projectBrief;
  final List<String> relevantItems;
  final List<String> cacheableSections;
  final int estimatedTokens;

  const MemoryContext({
    required this.projectBrief,
    this.relevantItems = const [],
    this.cacheableSections = const [],
    this.estimatedTokens = 0,
  });

  factory MemoryContext.empty() => const MemoryContext(projectBrief: '');
}

class MemoryRouter {
  final Ref _ref;
  MemoryRouter(this._ref);

  Future<MemoryContext> getContextForMessage({
    required String userMessage,
    String? activeProjectId,
    bool forceFullContext = false,
  }) async {
    if (activeProjectId == null) return MemoryContext.empty();

    final repo = _ref.read(projectMemoryRepositoryProvider);
    final brief = await repo.loadProjectBrief(activeProjectId) ?? "No brief available.";
    final items = await _selectRelevantItems(repo, activeProjectId, userMessage,
        forceFullContext ? 8 : 3);

    return MemoryContext(
      projectBrief: brief,
      relevantItems: items,
      cacheableSections: [brief, "All consequential actions require user confirmation."],
      estimatedTokens: (brief.length + items.join().length) ~/ 4,
    );
  }

  Future<List<String>> _selectRelevantItems(
    ProjectMemoryRepository repo, String projectId,
    String userMessage, int limit,
  ) async {
    return await repo.getRecentTickets(projectId, limit: limit);
  }
}
```

---

#### Artefact 3: ProjectMemoryRepository + MemoryService

```dart
// lib/data/repositories/project_memory_repository.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

abstract class ProjectMemoryRepository {
  Future<String?> loadProjectBrief(String projectId);
  Future<void> updateProjectBrief(String projectId, String brief);
  Future<List<String>> getRecentTickets(String projectId, {int limit = 5});
  Future<void> saveTicket(String projectId, String content);
}

final projectMemoryRepositoryProvider = Provider<ProjectMemoryRepository>((ref) {
  return ProjectMemoryRepositoryImpl();
});

class ProjectMemoryRepositoryImpl implements ProjectMemoryRepository {
  late Database _db;
  late String _basePath;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _basePath = '${dir.path}/projects';
    await Directory(_basePath).create(recursive: true);
    _db = await openDatabase('${dir.path}/pocket_claw.db', version: 2,
        onCreate: (db, v) async {
      await db.execute('''CREATE TABLE projects(
        id TEXT PRIMARY KEY, name TEXT, last_brief_update INTEGER)''');
      await db.execute('''CREATE TABLE project_tickets(
        id TEXT PRIMARY KEY, project_id TEXT, content TEXT, created_at INTEGER)''');
    });
  }

  String _dir(String id) => '$_basePath/$id';

  @override
  Future<String?> loadProjectBrief(String projectId) async {
    final f = File('${_dir(projectId)}/brief.md');
    return await f.exists() ? await f.readAsString() : null;
  }

  @override
  Future<void> updateProjectBrief(String projectId, String brief) async {
    await Directory(_dir(projectId)).create(recursive: true);
    await File('${_dir(projectId)}/brief.md').writeAsString(brief);
  }

  @override
  Future<List<String>> getRecentTickets(String projectId, {int limit = 5}) async {
    final rows = await _db.query('project_tickets',
        where: 'project_id = ?', whereArgs: [projectId],
        orderBy: 'created_at DESC', limit: limit);
    return rows.map((r) => r['content'] as String).toList();
  }

  @override
  Future<void> saveTicket(String projectId, String content) async {
    await _db.insert('project_tickets', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'project_id': projectId,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
```

```dart
// lib/core/memory_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/project_memory_repository.dart';
import '../core/prompts/project_brief_prompt.dart';

final memoryServiceProvider = Provider<MemoryService>((ref) => MemoryService(ref));

class MemoryService {
  final Ref _ref;
  MemoryService(this._ref);

  Future<void> updateProjectBrief(String projectId, String newActivity) async {
    final repo = _ref.read(projectMemoryRepositoryProvider);
    final current = await repo.loadProjectBrief(projectId) ?? '';
    final updated = await _summarize(current, newActivity, projectId);
    await repo.updateProjectBrief(projectId, updated);
  }

  Future<String> _summarize(String oldBrief, String activity, String projectId) async {
    // Call LLM engine with project_brief_prompt. Returns updated brief.
    final prompt = projectBriefSummarizationPrompt
        .replaceAll('{projectName}', projectId)
        .replaceAll('{phase}', 'Active')
        .replaceAll('{recentActivity}', activity)
        .replaceAll('{previousBrief}', oldBrief)
        .replaceAll('{timestamp}', DateTime.now().toIso8601String());
    // TODO: call LLM engine with prompt and return result
    return "Updated brief — $activity";
  }
}
```

---

### Phase 1 — Company Experience

#### Artefact 4: Company Screen Structure

```dart
// lib/features/company/company_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompanyScreen extends ConsumerWidget {
  const CompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Company"),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: "Overview"),
            Tab(text: "Org Chart"),
            Tab(text: "Goals"),
            Tab(text: "Budgets"),
            Tab(text: "Tickets"),
            Tab(text: "Governance"),
            Tab(text: "Security"),
          ]),
        ),
        body: const TabBarView(children: [
          CompanyOverviewTab(),
          Center(child: Text("Org Chart — Sprint 2")),
          Center(child: Text("Goals — Sprint 2")),
          Center(child: Text("Budgets — Sprint 2")),
          Center(child: Text("Tickets — Sprint 2")),
          Center(child: Text("Governance — Sprint 2")),
          SecurityDashboardTab(),
        ]),
      ),
    );
  }
}
```

#### Artefact 5: Company Overview Tab

```dart
// lib/features/company/overview_tab.dart
class CompanyOverviewTab extends ConsumerWidget {
  const CompanyOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Welcome to ${state.companyName}",
            style: Theme.of(context).textTheme.headlineMedium),
        Text(state.mission ?? '', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _card("Agents Online", "${state.onlineAgents}", Icons.people),
            _card("Today's Spend", "${state.todaySpend} tokens", Icons.attach_money),
            _card("Goal Progress", "${state.overallProgress}%", Icons.flag),
            _card("Connection", state.isConnected ? "Healthy" : "Offline",
                Icons.wifi, color: state.isConnected ? Colors.tealAccent : Colors.red),
          ],
        ),
        const SizedBox(height: 32),
        Text("Quick Actions", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(spacing: 12, children: [
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text("New Project")),
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.person_add), label: const Text("Spawn Agent")),
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.inventory_2), label: const Text("Activate Pack")),
        ]),
      ]),
    );
  }

  Widget _card(String title, String value, IconData icon, {Color? color}) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color ?? Colors.white70),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    )),
  );
}
```

#### Artefact 6: Security Dashboard Tab

```dart
// lib/features/company/security_dashboard_tab.dart
class SecurityDashboardTab extends ConsumerWidget {
  const SecurityDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(
        leading: Icon(Icons.vpn_key,
            color: state.isTailscaleConnected ? Colors.tealAccent : Colors.redAccent,
            size: 40),
        title: const Text("Tailscale Status"),
        subtitle: Text(state.isTailscaleConnected
            ? "Secure • Connected" : "Disconnected — Check Tailscale"),
      )),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Recent Governance Events",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (state.recentEvents.isEmpty)
            const Text("No recent activity", style: TextStyle(color: Colors.grey))
          else
            ...state.recentEvents.map((e) => ListTile(dense: true, title: Text(e))),
        ],
      ))),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Token Usage Today"),
          Text("${state.todaySpend ?? 0} tokens",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          if (state.isNearLimit == true)
            const Text("Approaching monthly budget limit",
                style: TextStyle(color: Colors.amber)),
        ],
      ))),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.refresh),
            label: const Text("Rotate Tokens")),
        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.pause),
            label: const Text("Pause Agents")),
        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.download),
            label: const Text("Export Log")),
      ]),
    ]);
  }
}
```

---

### Phase 2 — Coaching & Interaction

#### Artefact 7: Draft-and-Confirm Modal

```dart
// lib/widgets/draft_confirm_modal.dart
class DraftConfirmModal extends StatelessWidget {
  final String title;
  final String preview;
  final String riskSummary;
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  const DraftConfirmModal({super.key, required this.title,
    required this.preview, required this.riskSummary,
    required this.onApprove, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          Text(preview, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Text("Risk: $riskSummary", style: const TextStyle(color: Colors.amber)),
        ],
      )),
      actions: [
        TextButton(onPressed: onCancel, child: const Text("Cancel")),
        ElevatedButton(
          onPressed: onApprove,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text("Approve"),
        ),
      ],
    );
  }
}
```

#### Artefact 8: GROW Session State Machine

```dart
// lib/core/coaching/grow_state_machine.dart
enum GrowPhase { Goal, Reality, Options, Will, Review }

class GrowSession {
  GrowPhase currentPhase = GrowPhase.Goal;
  String? sessionGoal;
  List<String> commitments = [];

  String getNextQuestion() => switch (currentPhase) {
    GrowPhase.Goal    => "What do you want to achieve in this session?",
    GrowPhase.Reality => "What's the current reality? What have you tried?",
    GrowPhase.Options => "What options do you see? What else?",
    GrowPhase.Will    => "What will you commit to, and by when?",
    GrowPhase.Review  => "Last time you committed to something. What happened?",
  };

  void advance() {
    final phases = GrowPhase.values;
    final idx = phases.indexOf(currentPhase);
    if (idx < phases.length - 1) currentPhase = phases[idx + 1];
  }

  void addCommitment(String commitment) => commitments.add(commitment);
}
```

---

### Phase 3 — Integration

#### Artefact 9: PaperclipNotifier

```dart
// lib/providers/paperclip_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paperclipProvider =
    StateNotifierProvider<PaperclipNotifier, PaperclipState>(
        (ref) => PaperclipNotifier());

class PaperclipState {
  final bool isConnected;
  final bool isTailscaleConnected;
  final String companyName;
  final String? mission;
  final int onlineAgents;
  final int todaySpend;
  final int overallProgress;
  final List<String> recentEvents;
  final bool isNearLimit;

  const PaperclipState({
    this.isConnected = false,
    this.isTailscaleConnected = false,
    this.companyName = "My AI Company",
    this.mission,
    this.onlineAgents = 0,
    this.todaySpend = 0,
    this.overallProgress = 0,
    this.recentEvents = const [],
    this.isNearLimit = false,
  });

  PaperclipState copyWith({
    bool? isConnected, bool? isTailscaleConnected, String? companyName,
    String? mission, int? onlineAgents, int? todaySpend, int? overallProgress,
    List<String>? recentEvents, bool? isNearLimit,
  }) => PaperclipState(
    isConnected: isConnected ?? this.isConnected,
    isTailscaleConnected: isTailscaleConnected ?? this.isTailscaleConnected,
    companyName: companyName ?? this.companyName,
    mission: mission ?? this.mission,
    onlineAgents: onlineAgents ?? this.onlineAgents,
    todaySpend: todaySpend ?? this.todaySpend,
    overallProgress: overallProgress ?? this.overallProgress,
    recentEvents: recentEvents ?? this.recentEvents,
    isNearLimit: isNearLimit ?? this.isNearLimit,
  );
}

class PaperclipNotifier extends StateNotifier<PaperclipState> {
  PaperclipNotifier() : super(const PaperclipState());

  void updateConnection(bool connected) =>
      state = state.copyWith(isConnected: connected);

  void updateTailscale(bool connected) =>
      state = state.copyWith(isTailscaleConnected: connected);

  void updateCompany(String name, String mission) =>
      state = state.copyWith(companyName: name, mission: mission);

  void updateBudget(int spent, int limit) => state = state.copyWith(
    todaySpend: spent, isNearLimit: spent > (limit * 0.8));

  void addGovernanceEvent(String event) => state = state.copyWith(
    recentEvents: [event, ...state.recentEvents].take(10).toList());
}
```

#### Artefact 10: Smart Router + MemoryRouter Integration

```dart
// lib/core/smart_router.dart (integration snippet)
Future<ExecutionPath> routeMessage(String message, WidgetRef ref) async {
  final memoryCtx = await ref.read(memoryRouterProvider).getContextForMessage(
    userMessage: message,
    activeProjectId: _currentProjectId,
  );

  // Token budget check → prefer server for large contexts
  if (memoryCtx.estimatedTokens > 4000) return ExecutionPath.server;

  // Privacy keywords
  if (_containsPrivacyKeywords(message)) return ExecutionPath.local;

  // Agentic / tool signals
  if (_requiresTools(message)) return ExecutionPath.server;

  // Default → local
  return ExecutionPath.local;
}
```

---

### Phase 4 — Vertical Modes

#### Artefact 11: Academy Mode Skeleton

```dart
// lib/features/academy/academy_mode_provider.dart
final academyModeProvider =
    StateNotifierProvider<AcademyModeNotifier, AcademyModeState>(
        (ref) => AcademyModeNotifier());

class AcademyModeState {
  final bool isActive;
  final List<String> selectedSubjects;
  final String? studentProfileBrief;
  const AcademyModeState({
    this.isActive = false,
    this.selectedSubjects = const [],
    this.studentProfileBrief,
  });
}

class AcademyModeNotifier extends StateNotifier<AcademyModeState> {
  AcademyModeNotifier() : super(const AcademyModeState());

  void activate(List<String> subjects, String profile) => state = AcademyModeState(
    isActive: true, selectedSubjects: subjects, studentProfileBrief: profile);

  void deactivate() => state = const AcademyModeState();
}
```

#### Artefact 12: Vertex RAG Bridge Service

```dart
// lib/services/vertex_rag_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final vertexRAGServiceProvider = FutureProvider<VertexRAGService>((ref) async {
  const storage = FlutterSecureStorage();
  final key = await storage.read(key: 'vertex_api_key') ?? '';
  final url = await storage.read(key: 'vertex_endpoint_url') ?? '';
  return VertexRAGService(endpointUrl: url, apiKey: key);
});

class VertexRAGService {
  final String endpointUrl;
  final String apiKey;

  VertexRAGService({required this.endpointUrl, required this.apiKey});

  Future<String> queryTextbook({
    required String subject,
    required String question,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(endpointUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({"query": question, "subject": subject, "topK": 3}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['excerpts']?.join('\n\n') ?? "No relevant content found.";
      }
      return "Error ${response.statusCode} retrieving textbook content.";
    } catch (e) {
      return "Failed to connect to textbook database: $e";
    }
  }
}
```
---

## 17. Starter Packs

### 17.1 Solo Founder OS Pack

**Target:** One-person marketing + coaching businesses, consultants, solo professionals.

```yaml
---
name: solo-founder-os
description: "Complete AI company for one-person startups (marketing, life coaching, consulting)"
version: 2.0.0
tier: hybrid
triggers:
  - "run my business"
  - "activate my company"
  - "solo founder mode"
author: CARMEN PTY LTD
---
```

**Paperclip Company Template:**
- Mission: "Deliver high-impact services while maintaining work-life balance"
- Default Budget: $120/month Claude spend
- Governance Mode: Advisory

**Bundled Agents (5):**

| Agent | Role | Tier |
|---|---|---|
| Marketing Agent | LinkedIn, Instagram, email campaigns, content | server |
| Client Success Agent | Onboarding, follow-ups, retention, testimonials | server |
| Coaching Operations Agent | Session notes, action plans, progress tracking | bridge |
| Growth Agent | Outreach, nurturing, pipeline, conversion | server |
| Executive Assistant Agent | Calendar, invoices, admin, reminders | server |

**Key Scenario:**
"Create a LinkedIn carousel about boundary-setting for coaches" → Marketing Agent delivers draft → user confirms → schedules.

---

### 17.2 Forex Power User Pack

**Target:** Independent forex traders using ICT/SMC methodology.

**Bundled Skills:** CRT Analysis, Position Sizing Calculator, Trade Journal, Session Timer (NY focus), Risk Management Calculator

**Key Triggers:** "analyse chart", "CRT setup", "H4 candle", "position size", "trade journal"

---

### 17.3 Enterprise IT Project Team Pack

**Target:** Corporate IT departments, system integrators, digital transformation programs.

```yaml
---
name: enterprise-it-project-team
description: "Full virtual IT project delivery team (ERP, SaaS, digital transformation, etc.)"
version: 2.0.0
tier: hybrid
triggers:
  - "activate it project team"
  - "run it project"
  - "enterprise it delivery"
  - "start digital transformation"
author: CARMEN PTY LTD
---
```

**Paperclip Company Template:**
- Governance Mode: **Strict**
- Default Budget: 800K–2M tokens/month
- Project Phases: Initiation → Requirements → Design → Development → Testing → Deployment → Hypercare → Closeout

**Full 12-Agent IT Project Team:**

| # | Agent | Role | Tier |
|---|---|---|---|
| 1 | Project Manager / Scrum Master | Sprint planning, standups, risk, burndown | server |
| 2 | Product Owner / Business Analyst | Requirements, user stories, backlog | bridge |
| 3 | Solution Architect | High-level design, ADRs, integration architecture | server |
| 4 | Backend / Systems Developer | API development, database design, core logic | server |
| 5 | Frontend / Mobile Developer | UI/UX implementation, responsive apps | server |
| 6 | QA / Test Automation Engineer | Test plans, automation scripts, bug reports | server |
| 7 | DevOps / Cloud Engineer | CI/CD, Terraform, Kubernetes, monitoring | server |
| 8 | Security & Compliance Officer | Threat modeling, OWASP, GDPR/SOC2 checks | server |
| 9 | Data Analyst / BI Specialist | Data migration, reporting, SQL, dashboards | server |
| 10 | UI/UX Designer | Wireframes, user flows, accessibility | bridge |
| 11 | Change Management Lead | Training, comms, adoption tracking | server |
| 12 | Program Governance / PMO Analyst | Executive dashboards, risk registers, steering packs | server |

**All 12 agents share one project memory store. Per-project isolation by default.**

**Paperclip Company Template JSON:**
```json
{
  "companyName": "IT Delivery Department",
  "mission": "Deliver high-quality, on-time, secure IT projects with full governance",
  "governanceMode": "strict",
  "defaultBudget": 1500000,
  "phases": ["Initiation","Requirements","Design","Development",
             "Testing","Deployment","Hypercare","Closeout"],
  "agents": [
    {"role": "Project Manager", "name": "Project Manager Agent"},
    {"role": "Business Analyst", "name": "Business Analyst Agent"},
    {"role": "Solution Architect", "name": "Solution Architect Agent"},
    {"role": "Backend Developer", "name": "Backend Developer Agent"},
    {"role": "Frontend Developer", "name": "Frontend Developer Agent"},
    {"role": "QA Engineer", "name": "QA Engineer Agent"},
    {"role": "DevOps Engineer", "name": "DevOps Engineer Agent"},
    {"role": "Security Officer", "name": "Security Officer Agent"},
    {"role": "Data Analyst", "name": "Data Analyst Agent"},
    {"role": "UI/UX Designer", "name": "UI/UX Designer Agent"},
    {"role": "Change Management", "name": "Change Management Lead Agent"},
    {"role": "PMO Analyst", "name": "PMO Governance Analyst Agent"}
  ]
}
```

---

### 17.4 Personal AI Academy Pack (Sprint 11)

**Target:** Secondary school students (Grades 8–12). Separate purchasable pack.

**Architecture:** Direct Vertex AI RAG API call from mobile — **no OpenClaw/Paperclip dependency required.**

**Dynamic Agent Creation:** Student selects subjects → one Subject Tutor Agent auto-created per subject + Student Success Coach always present.

**Memory:** `/academy/subjects/{subject}/` per-subject isolation. Shared Student Profile brief.

**Key SKILL.md Files:**

```yaml
# personal-ai-academy.md (Master manifest)
---
name: personal-ai-academy
version: 2.0.0
tier: hybrid
triggers: ["activate academy mode", "school tutor", "exam preparation"]
author: CARMEN PTY LTD
---
```

```yaml
# student-success-coach.md
---
name: student-success-coach
tier: server
triggers: ["motivation check", "study plan", "exam preparation", "career advice"]
---
# Student Success Coach
Responsibilities: Daily/weekly motivation, study plans, exam strategies,
career exploration, burnout detection. Always encouraging, empathetic, non-judgmental.
```

```yaml
# subject-tutor-template.md (instantiated per subject)
---
name: {subject}-tutor
tier: hybrid
triggers: ["help with {subject}", "explain {topic}"]
---
# {Subject} Tutor
Expert, patient tutor for {Subject} (Grades 8–12).
Step-by-step explanations. Real-world examples. Uses Vertex RAG for textbook content.
Ends every session with summary + one actionable next step.
```

```yaml
# vertex-rag-bridge.md
---
name: vertex-rag-bridge
tier: bridge
triggers: ["lookup textbook", "find in textbook"]
---
Direct HTTPS call from Flutter app to Vertex AI RAG pipeline.
Returns relevant textbook excerpts with page references.
No OpenClaw/Paperclip dependency.
```

**UI Additions:**
- Academy tab (or mode switcher)
- Subject icons with progress rings
- Daily motivational check-in from Success Coach
- Exam countdown widget
- Study streak counter

---

### 17.5 Life Architect Pack (Sprint 12)

**Target:** Individuals seeking holistic personal development. Separate purchasable pack.

**Core Philosophy:** Ask-Don't-Tell (80/20 question-to-reflection), GROW scaffold, accountability loops, adaptive mode switching, hard safety layer.

**Key SKILL.md Files:**

```yaml
# life-architect.md (Master manifest)
---
name: life-architect
version: 2.0.0
tier: hybrid
triggers: ["activate life architect", "personal life coach", "holistic coaching"]
author: CARMEN PTY LTD
---
```

```yaml
# master-life-architect.md
---
name: master-life-architect
tier: server
triggers: ["life review", "weekly synthesis", "how is my life going"]
---
# Master Life Architect
Conductor of the user's personal development system.
Maintains Living Life Blueprint. Coordinates all facet coaches.
Delivers weekly syntheses. Detects imbalances.
Adaptive modes: Supportive / Challenging / Exploratory / Executional.
```

**Modular Facet Coaches (user-selectable):**

| Coach | Tier | Key Triggers |
|---|---|---|
| Fitness & Movement Coach | hybrid | "fitness plan", "workout help", "recovery" |
| Health & Bio Coach | bridge | "blood work review", "nutrition advice" |
| Mind & Emotional Coach | server | "stress", "mindset", "emotional regulation" |
| Business & Career Coach | server | "business coaching", "career strategy" |
| Learning & Growth Coach | server | "learning plan", "course progress" |
| Habit & Discipline Coach | server | "habit tracker", "accountability check" |

**Safety Classifier Prompt:**
```
You are a safety classifier for a life coaching AI.
User message: {userMessage}

Classify as one of:
- NORMAL: Safe coaching conversation
- CRISIS: Suicidal ideation, self-harm, abuse, acute distress
- THERAPY_DRIFT: User seeking clinical therapy / trauma processing
- HIGH_RISK: Medical emergency or dangerous advice requested

If CRISIS or HIGH_RISK: respond ONLY with tag + recommended hotline/resource.
Never continue normal coaching.
```

**GROW State Machine:** (see Artefact 8)

**Memory:**
- `/life/blueprint/` — Living Life Blueprint (Master Architect reads all)
- `/life/fitness/`, `/life/health/bloodwork/`, `/life/mind/`, etc.
- Shared Student Profile across all facet coaches

---

## 18. Marketing Assets

### 18.1 Primary Product Write-Up

**Pocket Claw — Your AI Company in Your Pocket**

Tired of being the bottleneck in your own life?

Pocket Claw turns your smartphone into a **complete personal AI company** — a private, intelligent team that works with you 24/7 to handle your goals, projects, health, learning, business, and personal growth.

No more fragmented apps. No more forgetting commitments. No more doing everything yourself.

**One App. Your Entire Support System.**

- Subject Tutors for every academic area
- Fitness & Movement Coach that builds sustainable training plans
- Health & Bio Coach that analyses blood work and gives practical recommendations
- Mind & Emotional Coach for stress, mindset, and emotional resilience
- Business & Career Coach for skills, productivity, and strategic decisions
- Life Architect that ties everything together with motivation, planning, and accountability

All agents share a living, evolving **Life Blueprint** — your personal knowledge base that grows smarter every day.

**Private by design.** Smart routing. Governance & safety. Works offline.

**One phone. One AI company. Working for you.**

---

### 18.2 Short Punchy Version (Ads / App Store)

**Pocket Claw — Your AI Company in Your Pocket**

Stop doing everything alone.

Pocket Claw turns your phone into a complete personal AI team that handles your health, fitness, studies, career, habits, and growth — 24/7.

- Dedicated tutors for every subject
- Fitness & Health coaches that analyse your data
- A Master Life Architect that coordinates everything
- Smart memory that actually remembers you

Private. Powerful. Always on your side.

---

### 18.3 Targeted Variants

**A. Secondary School Students (Grades 8–12)**

Tired of struggling alone with homework, exams, and stress? Get your own team of AI tutors — one for every subject — plus a Success Coach that keeps you motivated, organised, and on track. Learn smarter. Stress less. Ace your year. **Pocket Claw — Your AI Academy in your pocket.**

**B. Professionals & Solo Founders**

Running a business or career while trying to stay healthy and balanced is exhausting. Pocket Claw gives you a full AI support squad: Business Coach, Fitness Coach, Mind Coach, Life Architect. Never drop a ball again. **Pocket Claw — Your AI company in your pocket.**

**C. Personal Growth / Life Optimization**

One app. A whole team dedicated to your success. Fitness. Health. Mind. Career. Habit. All coordinated by your personal Life Architect. Stop guessing. Start improving — with intelligence, memory, and real accountability. **Pocket Claw — Design your best life.**

---

### 18.4 NANO BANANA2 Image Generation Prompts

**Prompt 1 — Hero / General:**
```
Premium cinematic marketing image for Pocket Claw app. Sleek black smartphone
floating center against dark navy gradient with electric teal glows. Screen shows
"Company" dashboard with professional AI agent avatars (coach, tutor, fitness,
health) in modern org-chart style, connected by soft glowing lines. Small orange
crab logo corner. Tagline: "Your AI Company in Your Pocket". Apple-level product
photography, futuristic yet warm, 8k, ultra-clean composition.
```

**Prompt 2 — Academy / Student:**
```
Vibrant professional marketing for Pocket Claw Personal AI Academy. Smartphone
centered on dark background with teal accents. Screen shows Academy mode with
friendly AI tutor avatars (Math, Science, English) plus Success Coach, subject
icons and progress rings. Motivated teenage student silhouette in background.
Tagline: "Your Personal AI Academy in Your Pocket". Clean, energetic, trustworthy,
Apple product ad quality.
```

**Prompt 3 — Solo Founder / Executive:**
```
Sophisticated dark-mode marketing for Pocket Claw. Premium smartphone against
deep charcoal and electric teal. Screen: Company dashboard with agents "Business
Coach", "Health Coach", "Mind Coach", "Life Architect" in professional network.
Subtle charts and calendars background. Tagline: "Your Executive AI Team in Your
Pocket". High-end corporate tech, minimalist, cinematic, luxury product photography.
```

**Prompt 4 — Life Architect / Personal Growth:**
```
Elegant inspiring marketing for Pocket Claw Life Architect mode. Sleek smartphone
on dark navy with gentle teal and warm accents. Screen: Life Blueprint dashboard
with AI coaches (Fitness, Health, Mind, Career, Learning) in harmonious circle
around central glowing user icon. Tagline: "Design Your Best Life — One Agent at
a Time". Calm, aspirational, premium wellness-tech, soft cinematic, 8k.
```

---

## 19. Known Constraints & Risks

| Constraint | Impact | Mitigation |
|---|---|---|
| CPU-only inference on most Android devices | Slow token generation for larger GGUF models | Default to Gemma 270M or Llama 1B; document minimum device spec |
| Gemma 4 E2B `flutter_gemma` API not yet stable | May break on package updates | Marked Beta in registry; pin package version |
| Web platform: no local LLM | Web users limited to server path | Clear messaging in onboarding; local features hidden |
| No background execution on iOS | Agent cannot run when app backgrounded | Server cron handles scheduled tasks |
| HuggingFace token required for all model downloads | Friction in onboarding | Prominent token setup in onboarding Step 2 |
| sqflite not supported on web | No session history persistence on web | Web uses in-memory session store |
| Large model files (0.3–2.3 GB) | Long download times on mobile data | Show download size pre-download; recommend Wi-Fi |
| OpenClaw CVE claims | Security vulnerability details from prior AI session require independent verification | Verify against official OpenClaw/Paperclip repos before building |
| Paperclip `npx paperclip onboard` command | May not be the exact official install command | Verify against official Paperclip documentation |
| fllama may not support all GGUF quantization types | Some models may fail to load | Constrain registry to Q4_K_M quantization |
| Google Vertex RAG API format | Exact endpoint schema depends on user's existing implementation | Vertex RAG Bridge Service must be configured against user's actual endpoint |

---

## 20. Out of Scope — v2.1

| Feature | Deferred To |
|---|---|
| On-device vector RAG (semantic search) | Sprint 4 (v2.2) |
| Multi-agent collaboration workflows | Sprint 5 |
| Multi-user / role-based access | Sprint 6 |
| SSO / enterprise auth | Sprint 6 |
| AI Company self-improvement | Sprint 7 |
| Physical-digital bridge (IoT actuation) | Sprint 8 |
| Multi-company ecosystem | Sprint 9 |
| Autonomous company mode | Sprint 10 |
| Parental oversight for Academy mode | Sprint 11 (Phase 2) |
| Voice input (Gemma E2B audio) | Requires stable Gemma 4 E2B |
| ClawHub skill marketplace | Sprint 9 |
| iOS App Store submission | After Android stabilization |
| Direct Claude API access (bypassing OpenClaw) | Not planned — OpenClaw proxy preferred |
| MLC-LLM runtime | fllama covers v2.x use cases |
| Marketing one-pager / demo video | Separate asset |

---

*End of Pocket Claw Master Specification v2.1*  
*CARMEN PTY LTD — Confidential — Commercial Launch Ready*  
*Document covers conversations 1–44 from the specification design session — 11 April 2026*
