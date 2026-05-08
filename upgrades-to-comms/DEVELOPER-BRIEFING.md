# Pocket Claw — Developer Briefing
## Onboarding Document for New / Returning Developers

**Prepared by:** Alister Witbooy / CARMEN PTY LTD  
**Date:** 2026-05-08  
**Version:** 2.0  

---

## 1. What Is Pocket Claw?

Pocket Claw is a Flutter mobile application (Android-first, iOS pending) that puts a full AI agent management console in your pocket. It is not a chat wrapper — it is a command centre for self-hosted AI agents running on a private VPS.

**The one-sentence description:**  
> Pocket Claw connects to your own AI agent infrastructure over Tailscale and lets you chat, manage, monitor, and diagnose your agents from anywhere.

**What it is NOT:**
- Not a cloud service (zero data leaves your own infrastructure)
- Not a simple chat app (Mission Control, Memory, Skills, Cron are first-class features)
- Not tied to a single agent runtime (supports OpenClaw, Hermes, and Paperclip simultaneously)

---

## 2. The Three-Agent Stack

The VPS at `100.78.70.2` (Tailscale) runs three AI services. Pocket Claw connects to all three:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     VPS — Ubuntu Server 24.04                        │
│                  Tailscale IP: 100.78.70.2                          │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │   OpenClaw       │  │    Hermes Agent  │  │    Paperclip     │  │
│  │   :18789         │  │    :8642         │  │    :3100         │  │
│  │   WebSocket      │  │    REST (OpenAI) │  │    REST          │  │
│  │   systemd ✅     │  │    background ⚠️ │  │    systemd ✅    │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                │                                     │
│              SSH :22  ─────────┘ (also reaches OpenClaw files)      │
└─────────────────────────────────────────────────────────────────────┘
```

### OpenClaw
- **What it is:** Self-hosted AI agent runtime, WebSocket protocol, Ed25519 device pairing
- **Model:** `neurometric/clawpack` (via Neurometric API)
- **App connection:** WebSocket `ws://100.78.70.2:18789/ws` + auth token
- **Current app coverage:** Chat ✅, Mission Control ✅, Skills ✅, Memory ✅, Cron ✅, Channels ✅
- **Gaps to fix:** See `SPEC-OpenClaw-Improvements-v1.0.md`

### Hermes Agent
- **What it is:** Self-improving AI agent by Nous Research (v0.12.0), MIT licensed
- **Model:** Claude Haiku 4.5 via Anthropic (also has Ollama fallback)
- **App connection (REST):** `http://100.78.70.2:8642/v1/chat/completions` — OpenAI-compatible
- **App connection (SSH):** Port 22 → `sqlite3 ~/.hermes/state.db`, SFTP for memory/cron files
- **Current app coverage:** REST chat client built ✅, SSH management pending ⏳
- **Next sprint work:** See `SPEC-HermesIntegration-v1.0.md` + `SPEC-MultiTransport-v1.0.md`

### Paperclip
- **What it is:** Company OS — orchestrates AI agents into a virtual company with goals, org chart, budgets, tickets, governance
- **App connection:** `http://100.78.70.2:3100/api` — REST
- **Current app coverage:** Full REST client built, all 7 Company tabs built, Paperclip deployed and admin account created ✅
- **Sprint status:** ON HOLD — deferred until Hermes sprint complete
- **When to resume:** After Sprint 3 (SSH + Hermes management)

---

## 3. How Pocket Claw Connects to Each Service

| Service | Protocol | Auth | Port | Tailscale required? |
|---|---|---|---|---|
| OpenClaw | WebSocket (custom JSON-RPC) | Bearer token | 18789 | ✅ Yes |
| OpenClaw | HTTP REST `/__openclaw__/api` | Bearer token | 18789 | ✅ Yes |
| Hermes | HTTP REST (OpenAI-compatible) | Bearer token | 8642 | ✅ Yes |
| Hermes | SSH exec + SFTP (Sprint 3) | Password or SSH key | 22 | ✅ Yes |
| Paperclip | HTTP REST `/api` | Agent API key | 3100 | ✅ Yes |

**Tailscale must be active on the phone.** All services bind to `100.78.70.2` (Tailscale interface only) — nothing is publicly exposed. The phone must have Tailscale running and be on the same tailnet.

---

## 4. Current App State

**139 Dart files · 29,292 lines · Flutter 3.41.6**

The app compiles and runs. The core chat and Mission Control features work end-to-end against the live VPS. Some screens exist but are empty or skeleton-only.

### Navigation Structure
```
Bottom nav (5 tabs):
├── Chat           → ChatScreen (streaming, 49 commands, photo, voice shell)
├── Control        → Mission Control tabs:
│   ├── /          → DashboardScreen
│   ├── /agents    → AgentsScreen
│   ├── /tasks     → TasksScreen ⚠️ DEAD — repurpose to Sessions
│   ├── /cost      → CostScreen
│   ├── /cron      → CronScreen
│   ├── /activity  → ActivityScreen
│   └── /channels  → ChannelsScreen
├── Memory         → MemoryScreen (local + server tabs)
├── Skills         → SkillsScreen (bundled + server + ClawHub)
└── Settings       → SettingsScreen
    ├── OpenClaw Gateway  → GatewayConfig
    ├── Device Identity   → DeviceIdentitySettings
    ├── Current Model     → ModelConfig (local LLM)
    ├── Paperclip Company → PaperclipCompanySettings
    │   └── Wizard        → PaperclipOnboardingWizard
    ├── Smart Router      → RouterMemorySettings
    ├── API Token         → (inline in settings)
    ├── Security          → SecuritySettings
    └── Academy Mode      → AcademyScreen (skeleton)
```

### Known Issues (fix before sharing with anyone)
1. **🔴 Hardcoded VPS credentials** — `core_providers.dart` lines 54–67 contain the live Tailscale IP and OpenClaw auth token compiled into the binary. **This is the first commit on any new sprint.**
2. **🟠 App name conflict** — "PocketClaw" on iOS App Store is a claw machine game. Rename before iOS submission. Candidates: ClawHQ, ClawBoard, ClawDesk.
3. **🟠 Tasks screen is empty** — OpenClaw has no tasks.* RPC. Repurpose as Session History (SPEC-OpenClaw §3).
4. **🟡 ProjectProgress.md was stale** — Now updated (this file replaces the April 9 version).

---

## 5. Codebase Conventions

### State Management
Riverpod 2.x throughout. Pattern:
- `FutureProvider` for async data fetched once
- `StreamProvider` for live WebSocket streams  
- `StateProvider` for mutable settings values
- `AsyncNotifierProvider` for complex async state (PaperclipNotifier pattern)

### File Naming
```
lib/core/[domain]/[feature].dart          ← Pure logic, no Flutter widgets
lib/data/models/[entity].dart             ← Data classes with fromJson
lib/data/providers/[domain]_providers.dart ← Riverpod providers
lib/features/[feature]/[feature]_screen.dart ← Screens
lib/shared/widgets/[widget_name].dart     ← Reusable widgets
```

### The Smart Router
`lib/core/router/smart_router.dart` — decides which execution path to use for a chat message:

```
ExecutionPath.local   → LlamaCppEngine (on-device GGUF)
ExecutionPath.server  → OpenClaw WebSocket gateway
ExecutionPath.bridge  → Device capture → OpenClaw
ExecutionPath.hermes  → Hermes REST API  ← newly added
```

Decision factors: token budget, connectivity, user preference, gateway availability.

### OpenClaw WebSocket Protocol
OpenClaw uses a custom JSON-RPC-style protocol over WebSocket. NOT standard REST. Key patterns:
```dart
// Request:
{"type": "req", "id": "pc-123", "method": "agents.list", "params": {}}

// Response:
{"type": "res", "id": "pc-123", "result": {...}}

// Streaming chat:
{"type": "event", "event": "agent", "runId": "...", "data": {"delta": "..."}}
```

The `GatewayClient.request()` method handles the RPC pattern. Use it for everything except streaming chat (which uses `sendMessage()`).

### Theme
```dart
PocketClawTheme.lobsterRed    = Color(0xFFE53935)  // primary, destructive actions
PocketClawTheme.electricTeal  = Color(0xFF00E5CC)  // secondary, success, connections
PocketClawTheme.deepCharcoal  = Color(0xFF1A1A2E)  // background
```

Font: `GoogleFonts.jetBrainsMono()` for code/labels, system font for body text.

### Git Conventions
Conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`  
Protected paths: `lib/core/gateway/` — coordinate before refactoring the WebSocket client.

---

## 6. VPS Quick Reference

**Access:** `ssh clawusr@100.78.70.2` (Tailscale required)

```bash
# Service status
sudo systemctl status openclaw-gateway
sudo systemctl status paperclip
ps aux | grep hermes        # not yet systemd — see Sprint 1

# Service logs
journalctl -u openclaw-gateway -f
journalctl -u paperclip -f

# Port check
ss -tlnp | grep -E "18789|3100|8642|3000"

# Hermes API health
curl -s http://100.78.70.2:8642/v1/models \
  -H "Authorization: Bearer hermes-pocket-claw-2026" | python3 -m json.tool

# Paperclip health
curl -s http://100.78.70.2:3100/api/health | python3 -m json.tool

# OpenClaw models
openclaw models status
```

**OpenClaw config:** `~/.openclaw/openclaw.json`  
**Hermes config:** `~/.hermes/config.yaml`  
**Hermes data:** `~/.hermes/state.db` (SQLite, WAL mode)  
**Paperclip config:** `~/.paperclip/instances/default/config.json`

---

## 7. Sprint Roadmap

Sprints are defined in detail in the spec documents. This is the ordering and dependencies only.

```
NOW ──► Sprint 1: Hermes REST Chat
         Wire chat_providers.dart to hermes path
         systemd service for hermes-gateway
         Spec: SPEC-HermesIntegration-v1.0.md

     ──► Sprint 2: OpenClaw Quick Wins (no SSH needed)
         Pre-condition: Remove hardcoded credentials FIRST
         Devices screen, Models screen, Session history, backoff reconnect
         Spec: SPEC-OpenClaw-Improvements-v1.0.md §3–5, §7

     ──► Sprint 3: SSH Transport + Hermes Management
         dartssh2, SSH settings, remote SQLite, sessions browser,
         memory editor, cron manager, skills browser, log viewer
         Spec: SPEC-MultiTransport-v1.0.md §§3–11

     ──► Sprint 4: OpenClaw SSH Diagnostics
         Reuses SSH transport from Sprint 3
         journalctl log viewer, openclaw doctor, gateway restart
         Spec: SPEC-OpenClaw-Improvements-v1.0.md §6

     ──► Sprint 5: Hermes ACP Chat
         hermes acp subprocess over SSH, tool call cards, live progress
         Spec: SPEC-MultiTransport-v1.0.md §13

     ──► Sprint 6: Paperclip Resume
         End-to-end Company tab test against live Paperclip
         Connect OpenClaw to Paperclip via invite flow
         Spec: PocketClaw-Paperclip-Architecture-v2.0.md

     ──► Sprint 7+: Academy Mode, Life Architect, Voice
         Per MasterSpec v2.1
```

---

## 8. Spec Documents — What Each One Covers

| Document | What it covers | Read when |
|---|---|---|
| `SPEC-HermesIntegration-v1.0.md` | Hermes REST chat: HermesClient, SSE parser, providers, settings screen, execution path | Sprint 1 |
| `SPEC-MultiTransport-v1.0.md` | SSH transport layer, remote SQLite, sessions browser, memory editor, cron manager, Hermes data models, ACP chat | Sprint 3 + 5 |
| `SPEC-OpenClaw-Improvements-v1.0.md` | OpenClaw gaps: credential fix, session history, devices screen, models screen, SSH diagnostics, reconnection | Sprint 2 + 4 |
| `PocketClaw-Paperclip-Architecture-v2.0.md` | Paperclip REST API reference, all 7 Company tab contracts, auth model | Sprint 6 |
| `Scarf-PocketClaw-Analysis.md` | Background reading — how the Scarf iOS app tackles the same Hermes integration problem, what to borrow | Before Sprint 3 |
| `ProjectProgress.md` *(this file)* | Current build state, what's done, what's stubbed, active sprints | Always |

---

## 9. Developer Environment Setup

```bash
# Clone
git clone https://github.com/alboogycOdR/PocketClaw.git
cd PocketClaw

# Flutter
flutter pub get
flutter analyze    # Should be zero errors, zero warnings

# Run on web (no physical device needed for basic development)
flutter run -d chrome

# Run on Android device
flutter run -d [device-id]

# Build release APK
flutter build apk --release
```

**Required:** Flutter 3.41.6+, Dart 3.11.4+, Android SDK (for device builds)

**Tailscale:** Install on your development machine to reach the VPS during testing.

---

## 10. Who to Contact

**Product Owner:** Alister Witbooy  
**Company:** CARMEN PTY LTD  
**VPS User:** `clawusr@clawsrv` (`100.78.70.2` via Tailscale)  
**Repo:** https://github.com/alboogycOdR/PocketClaw

For questions about the agent behaviour, VPS configuration, or business requirements, contact Alister directly. For technical implementation questions not covered in the specs, raise them before building — the specs are authoritative, not advisory.

---

*Pocket Claw Developer Briefing v2.0 — CARMEN PTY LTD — May 2026*
