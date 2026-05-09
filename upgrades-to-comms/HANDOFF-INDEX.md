# Pocket Claw — Developer Handoff Package
## Master Index & Reading Order

**Prepared:** 2026-05-08  
**Prepared by:** Alister Witbooy / CARMEN PTY LTD  

---

> ## 👋 START HERE
> **This is the first document you read. Before you open the source code, before you open any spec, read this index from top to bottom. It tells you what everything is, in what order to read it, and the rules that govern all work on this project. It takes 10 minutes. Do not skip it.**

---

## What's in This Package

```
Handoff Package
├── 📋 HANDOFF-INDEX.md                      ← You are here
│
├── 🗺️  DEVELOPER-BRIEFING.md                ← START HERE — product overview,
│                                               VPS setup, sprint roadmap, conventions
│
├── 📊 ProjectProgress.md                    ← Current build state: what's done,
│                                               what's stubbed, known issues
│
├── 💻 PocketClaw-source-2026-05-08.zip      ← Source code (139 Dart files, 29,292 lines)
│
└── 📐 Specs/
    ├── SPEC-HermesIntegration-v1.0.md       ← Sprint 1: Hermes REST chat
    ├── SPEC-OpenClaw-Improvements-v1.0.md   ← Sprint 2 + 4: OpenClaw gaps
    ├── SPEC-MultiTransport-v1.0.md          ← Sprint 3 + 5: SSH transport + Hermes management
    ├── PocketClaw-Paperclip-Architecture-v2.0.md ← Sprint 6: Paperclip (on hold)
    └── Scarf-PocketClaw-Analysis.md         ← Background: iOS reference app study
```

---

## Reading Order

> ⚠️ **This order is not a suggestion.** Reading the specs before the briefing, or the briefing before the progress doc, will result in confusion. Follow the sequence exactly.

### Step 1 — You are here ✅
You are reading `HANDOFF-INDEX.md`. Finish this document completely before opening anything else.

### Step 2 — Before You Write a Single Line of Code

**Read `DEVELOPER-BRIEFING.md` next (20 min)**  
This is the only document that explains what the product is, what the VPS runs, how the three agents connect, and what conventions the codebase uses. Everything else references this.

**Step 3 — Read `ProjectProgress.md` next (10 min)**  
This tells you what's already built, what's stubbed, and what the known bugs are. Prevents you from building something that already exists or reproducing a known bug.

**Step 4 — Extract and explore the source code**  
Unzip `PocketClaw-source-2026-05-08.zip`. Run `flutter analyze` — should report zero errors. Scan the directory structure. The briefing document maps to what you find here.

---

### Step 5 — Sprint 1: Hermes REST Chat

**Read: `SPEC-HermesIntegration-v1.0.md`**

This is the current active sprint. Most infrastructure is already built (HermesClient, SSE parser, settings screen, execution path). What's left is wiring the chat send branch and setting up the hermes-gateway systemd service.

**First commit on this sprint:**  
Remove hardcoded credentials from `lib/data/providers/core_providers.dart` lines 54–67. This is a pre-ship security issue, not negotiable, must be done before any other code changes.

---

### Step 6 — Sprint 2: OpenClaw Quick Wins

**Read: `SPEC-OpenClaw-Improvements-v1.0.md` (sections 2–5, 7)**

No SSH required. Pure WebSocket/RPC work:
- Repurpose the dead Tasks screen as Session History (§3)
- New Devices management screen (§4)  
- New Model status screen (§5)
- Exponential backoff reconnection (§7)

These are independent of the SSH transport work and can be done in parallel with Sprint 3 if two developers are available.

---

### Step 7 — Sprint 3: SSH Transport + Hermes Management

**Read: `SPEC-MultiTransport-v1.0.md`**

**Also read before starting: `Scarf-PocketClaw-Analysis.md`**  
This is background on how the Scarf iOS app (a production reference app doing the same thing on iOS) solved the Hermes management problem. The SQL queries, data models, and file paths in the MultiTransport spec come directly from Scarf's verified source.

This sprint adds `dartssh2` to the project, builds the SSH transport layer, then uses it to add: sessions browser, memory editor, cron manager, skills browser, log viewer.

---

### Step 8 — Sprint 4: OpenClaw SSH Diagnostics

**Read: `SPEC-OpenClaw-Improvements-v1.0.md` (section 6)**

Reuses the SSH transport from Sprint 3. Adds OpenClaw log viewer, doctor output, and gateway restart button. Short sprint — 1–2 days.

---

### Step 9 — Sprint 5: Hermes ACP Chat

**Read: `SPEC-MultiTransport-v1.0.md` (section 13)**

The most complex sprint. Replaces the REST chat path with the ACP protocol (richer streaming with live tool call events). Requires SSH transport from Sprint 3 to be stable and tested first.

---

### Step 10 — Sprint 6: Paperclip Resume

**Read: `PocketClaw-Paperclip-Architecture-v2.0.md`**

Paperclip is deployed and working on the VPS. The Flutter client (all 7 Company tabs, REST client, onboarding wizard) is fully built. This sprint tests it end-to-end and connects OpenClaw to Paperclip via the invite flow. Deferred until after the Hermes sprint sequence is complete.

---

## Critical Rules

These are non-negotiable. Raise any questions about them before starting work.

### 🔴 Never commit credentials
The file `lib/data/providers/core_providers.dart` currently has a hardcoded VPS IP and auth token. **Sprint 1, first commit: remove them.** Replace with SharedPreferences reads. Never commit API keys, tokens, IPs, or passwords to the repo.

### 🔴 Specs are authoritative
If the spec says build X, build X. If something in the spec seems wrong, raise it before building the alternative. The specs were written after reviewing the live VPS, the actual source code, and a reference iOS app (Scarf). They are not first drafts.

### 🟠 Test before marking done
"Done" means tested on a physical Android device against the live VPS over Tailscale. "Compiles" is not done. "Works on Chrome" is not done for networking features.

### 🟠 Preserve the existing WebSocket integration
`lib/core/gateway/gateway_client.dart` is production code that is working correctly. Do not refactor it without explicit approval. The SSH transport layer is additive — it sits alongside the WebSocket, not instead of it.

### 🟡 Paperclip is on hold
The Company tab and all Paperclip code compiles and is built. Do not touch it during Sprints 1–5. It will be activated in Sprint 6.

---

## Quick Reference — Key Files

| What you're looking for | Where it is |
|---|---|
| OpenClaw WebSocket protocol | `lib/core/gateway/gateway_client.dart` |
| OpenClaw REST endpoints | `lib/core/gateway/gateway_rest.dart` |
| Hermes REST client | `lib/core/gateway/paperclip_rest.dart` ← misnamed, was renamed internally |
| Smart Router logic | `lib/core/router/smart_router.dart` |
| Execution path enum | `lib/core/router/execution_path.dart` |
| All Riverpod providers | `lib/data/providers/core_providers.dart` |
| Chat send logic | `lib/data/providers/chat_providers.dart` |
| Mission Control data | `lib/features/mission_control/mission_control_providers.dart` |
| Theme colours | `lib/app/theme.dart` |
| App router (all routes) | `lib/app/router.dart` |
| Hardcoded credentials 🔴 | `lib/data/providers/core_providers.dart` lines 54–67 |

---

## VPS Quick Reference

```
Host:       100.78.70.2 (Tailscale — phone + dev machine must be on Tailscale)
SSH:        ssh clawusr@100.78.70.2
OpenClaw:   ws://100.78.70.2:18789/ws
Hermes:     http://100.78.70.2:8642/v1/chat/completions
Paperclip:  http://100.78.70.2:3100/api

# Test all services are up
ss -tlnp | grep -E "18789|3100|8642"

# Hermes health
curl -s http://100.78.70.2:8642/v1/models \
  -H "Authorization: Bearer <YOUR_HERMES_API_KEY>"
```

---

*Pocket Claw Developer Handoff Package — CARMEN PTY LTD — May 2026*
