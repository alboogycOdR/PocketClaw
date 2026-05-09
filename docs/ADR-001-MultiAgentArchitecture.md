# ADR-001 — Multi-Agent Scope Architecture
## Response to PROBLEM-Hermes-Parity-and-App-Split.md

**Date:** 2026-05-09  
**Author:** CARMEN PTY LTD (Architecture)  
**Status:** Decided — implement as specified  
**Responding to:** `PROBLEM-Hermes-Parity-and-App-Split.md` §6 decisions  

---

## Decision Summary

| Question (§6) | Decision |
|---|---|
| §6.1 Scope inventory | Hermes parity is largely built — see §2 below |
| §6.2 Path selection | **Option 5.3.2 — Server-scoped model, single binary** |
| §6.3 Sequencing | Phase 1 now (2 days) → Phase 2 next sprint → Phase 3 only if needed |
| §5 App split | **Rejected** — do not split |
| App rename | **ClawCommander** |

---

## 1. Do Not Split the App

The full fork (§5.1) is rejected for the next 12 months.

The shared infrastructure — SSH transport, ACP client, chat engine, TTS/STT, Riverpod provider tree, secure storage, onboarding wizard, theme — represents 40–50% of the total codebase. Splitting it doubles the maintenance surface on everything that matters most, in exchange for a navigational benefit achievable with two days of focused work.

The app name rename required by the iOS App Store conflict (PocketClaw exists as a claw machine game) is **independent** of this decision. We rename the app. We do not split it.

---

## 2. Hermes Parity — Scope Inventory Answer (§4.1)

The document asks what Hermes exposes. The answer from verified VPS diagnostics and the May 9 build:

| Surface | Hermes exposes | Already in app? |
|---|---|---|
| Memory | MEMORY.md + USER.md + SOUL.md via SSH SFTP | ✅ `HermesMemoryTab` |
| Skills | `~/.hermes/skills/` directory via SSH exec | ✅ `HermesSkillsTab` |
| Sessions / Activity | `state.db` via SSH `sqlite3 -json` | ✅ `HermesSessionsTab` |
| Cost | Aggregated from `state.db` sessions table | ✅ `HermesCostSummary` |
| Cron / Scheduling | `cron/jobs.json` via SSH SFTP | ✅ `HermesCronTab` |
| Logs | `errors.log` + `gateway.log` via SSH tail | ✅ `HermesLogsTab` |
| Health | `GET /v1/models` REST | ✅ `hermesReachableProvider` |
| Channels | `config.yaml` readable via SSH | ⏳ Not yet built |
| Agents | ❌ Hermes is single-agent — no agent directory | N/A |

**The parity gap is navigation, not features.** All major management surfaces exist under `/hermes`. The user cannot find them because the route is not reachable from the main navigation.

### §4.2 Auth model

Keep auth models separate. OpenClaw uses Ed25519 device pairing + bearer token over WebSocket. Hermes uses a REST API key. `activeServerProvider` (Phase 2) selects which credential set is active — no need to unify them.

### §4.3 Multi-tenant boundaries

Treat as siblings on the same Tailscale node for now — the common case. If multi-box support is needed (different physical servers), `activeServerProvider` is extended to hold a list of `ServerConfig` objects. The Phase 2 architecture supports this without a rewrite.

---

## 3. Chosen Path: Option 5.3.2 — Server-Scoped Model

**Promote agents from a "chat mode" to a first-class active server concept.** When the user's active server is OpenClaw, the management tabs show OpenClaw surfaces. When it's Hermes, they show Hermes surfaces. The entire app re-scopes, not just chat.

`chatModeProvider` remains for chat path selection but is **derived from** the new `activeServerProvider` rather than being the top-level concept. This eliminates the mode tag bug class (§3.2) permanently — mode is no longer chat-only state.

### Why not 5.3.1 (mode-scoped tabs)?

It fixes scope confusion with minimal engineering but leaves `chatModeProvider` as the authority, which means the mode tag bug and its variants remain possible. It is a patch, not a fix.

### Why not 5.3.3 (shared core package)?

Highest engineering cost, justified only when a third agent class with genuinely divergent management surfaces arrives. Premature at current team size and stage.

---

## 4. Implementation Phases

### Phase 1 — Unblock users now (2 days)
See `SPEC-MultiAgentFix-Phase1-v1.0.md`

- Fix the mode tag bug in `chat_mode_selector.dart` / `session_manager.dart`
- Add scope badge ("🦞 OpenClaw") to Mission Control, Memory, Skills AppBars
- Add Hermes management entry point from Mission Control
- Rename app to ClawCommander (see `SPEC-AppRename-v1.0.md`)

### Phase 2 — Server-scoped architecture (1 week)
See `SPEC-MultiAgentFix-Phase2-v1.0.md`

- Introduce `activeServerProvider` as the top-level scoping concept
- Make Management tab mode-aware (OpenClaw surfaces ↔ Hermes surfaces)
- Add server switcher chip to AppBar
- Derive `chatModeProvider` from `activeServerProvider`

### Phase 3 — Shared core package (only if needed)
Extract `clawcommander_core` only when a third agent class arrives. Not before.

---

## 5. App Rename Decision

**New name: ClawCommander**

- No existing App Store conflict (verified)
- Retains the claw/lobster brand identity
- Signals authority and control — appropriate for an agent command centre
- Short enough for all UI contexts

See `SPEC-AppRename-v1.0.md` for the complete file-by-file rename instruction.

---

## 6. What This Does Not Change

- The Hermes REST chat path, ACP protocol, and SSH transport are unaffected
- All existing specs (HermesIntegration, MultiTransport, OpenClaw-Improvements, ACP WireProtocol, LocalModels, Academy, LifeArchitect, VoiceInput, HermesDesktopImprovements) remain valid — they implement into the Phase 2 architecture without change
- Paperclip remains on hold
- The three Hermes Desktop immediate fixes (SSE parser, memory delimiter, command palette) remain prioritised

---

*CARMEN PTY LTD — ADR-001 — 2026-05-09*
