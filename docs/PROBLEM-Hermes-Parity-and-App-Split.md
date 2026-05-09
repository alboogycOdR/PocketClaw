# Problem statement: multi-agent scope confusion in PocketClaw

**Audience:** Architect — for review and direction
**Author:** Product owner (with engineering notes)
**Status:** Open question — needs architectural decision before further build

---

## 1. Background

PocketClaw was originally a single-agent client for the **OpenClaw** gateway.
It has since grown to support a second agent — **Hermes** (Nous Research) —
plus a fully on-device "Local" mode (fllama / GGUF). All three live behind
one chat surface via a mode selector.

The chat path is the only surface that has been retrofitted for multi-agent.
The non-chat surfaces (Mission Control, Memory, Skills) were never expanded
beyond OpenClaw and are now causing user-facing confusion.

## 2. Current state — concrete

| Tab            | Backed by                              | Hermes equivalent? | Local equivalent? |
|----------------|----------------------------------------|--------------------|-------------------|
| Chat           | local / OpenClaw / Hermes (mode-aware) | Yes                | Yes               |
| Mission Control (Dashboard, Agents, Sessions, Cost, Cron, Activity, Channels) | OpenClaw gateway (WS JSON-RPC) | **None**           | N/A               |
| Memory         | OpenClaw gateway (`memory.*` RPCs)     | **None**           | N/A               |
| Skills         | OpenClaw gateway (`skills.*` RPCs)     | **None**           | N/A               |

The non-chat tabs:
- never read the active chat mode,
- never branch on which agent the user is talking to,
- show no badge identifying the agent / scope,
- are silently scoped to OpenClaw regardless of what the user is doing.

## 3. Observed user-facing problems

### 3.1 Scope confusion ("which agent am I configuring?")

Mid-session, user switches the chat mode selector to Hermes, then opens
Skills or Memory or Mission Control. The screens render OpenClaw data
(agent list, memory rows, sessions, costs) with no UI signal that says so.
The user reasonably assumes these are Hermes' settings — they aren't, and
toggling them has no effect on Hermes.

### 3.2 Chat history crossover (separate but related)

A real cross-contamination bug exists in the chat-mode switch flow.
`chat_mode_selector.dart::_onModeTap` calls
`SessionManager.setMode(newMode)` *before* the buffered messages from the
previous mode are flushed to disk. The flush in
`SessionManager.loadSession` then writes those messages with the **new**
mode tag. Result: an OpenClaw conversation can appear in Hermes' history
list (which filters by mode tag).

This is a code bug, fixable in isolation, but it's a symptom of the same
underlying problem: mode is treated as a chat-only concept, not as a
first-class scope for *all* per-agent state.

### 3.3 No Hermes parity

Even with the bugs above fixed, Hermes still has no equivalent of:
- a sessions / activity / cost dashboard,
- a memory inspector / editor,
- a skills catalogue + toggle UI,
- an agents view (if Hermes has multiple sub-agents),
- a cron / scheduling surface,
- a channels / routing surface.

Whether any of these are even *possible* on Hermes depends on what the
Hermes server exposes — which is the first question for the architect.

## 4. Open questions for the architect

### 4.1 Hermes server capabilities

For each surface, does Hermes expose a control-plane API today, and if not,
is one planned?

1. **Memory** — read / list / search / upsert / delete? What is the auth
   boundary (per-user, per-agent, global)? What is the storage model
   (vector store, key/value, hybrid)?
2. **Skills** — does Hermes have a notion of installable / toggleable
   skills or tools? List / status / enable-disable? Or are tools fixed
   per deployment?
3. **Agents** — single-agent or multi-agent topology? Is there an agent
   directory we can render? Are agents user-scoped or shared?
4. **Sessions / activity** — history listing per user, with timestamps,
   token counts, costs, status?
5. **Cost** — per-session / per-day / per-model usage telemetry exposed
   on a stable endpoint?
6. **Cron / scheduling** — does Hermes support scheduled runs? Listable?
7. **Channels** — does Hermes have a concept analogous to OpenClaw's
   channels (routing inbound messages from Slack / Telegram / email)?
8. **Health** — single canonical health endpoint we can poll for the
   indicator pill?

For each: shape of request/response, auth header, rate limits, expected
latency.

### 4.2 Auth model

OpenClaw uses Ed25519 device pairing + per-session JWTs over WS. Hermes
today uses a single API key over REST + SSE.
- Will Hermes ever support per-device pairing the way OpenClaw does?
- Should the control plane share the chat API key, or have a separate
  scope/credential?

### 4.3 Multi-tenant boundaries

If a user runs *both* an OpenClaw gateway and a Hermes server, are these
typically:
- the same physical box (Tailscale-routed) — most common today, or
- different boxes / different operators — needs separate health and
  separate connection state in the app?

This affects whether we treat them as siblings under one "Servers" tab or
two completely separate connection profiles.

## 5. Strategic question: one app, or two?

The owner is leaning toward splitting PocketClaw into two products:

- **PocketClaw — OpenClaw edition** (the existing app, with cloud / Hermes
  paths removed).
- **PocketClaw — Hermes edition** (chat + Hermes-equivalent control,
  memory, skills surfaces).

### 5.1 Arguments for splitting

- **Mental model is clean.** Each app's tabs unambiguously belong to one
  agent. No mode badge, no scope confusion, no cross-history bugs.
- **Independent release cadence.** OpenClaw is moving fast; Hermes
  capabilities are still TBD. Coupling slows both down.
- **Smaller binary, faster startup, fewer permissions** per app.
- **Clear feature gating in app stores** — easier to describe and
  market: "Bring your own Hermes server", "Bring your own OpenClaw".
- **Settings backup/restore is simpler** — no opt-in matrix of "which
  mode's credentials are in this file?". Each app exports its own world.
- **Future divergence is likely.** Hermes' skills/memory model will not
  match OpenClaw's RPCs. Forcing one UI to render both will cost more
  than maintaining two UIs over time.

### 5.2 Arguments against splitting

- **Code duplication.** Chat input, theme, voice STT, settings backup,
  onboarding, secure storage — all currently shared. Splitting either
  duplicates them per app or extracts a shared package (real engineering
  cost).
- **Local mode has no obvious home.** It runs entirely on-device and
  doesn't belong to either agent. Either it ships in both apps (more
  duplication) or only in one (limits the other).
- **Discovery for users with one server.** A user who only has OpenClaw
  installs the OpenClaw edition; if they later spin up Hermes, they
  install a second app. Some friction.
- **Two store listings, two release pipelines, two crash dashboards.**
  Operational overhead, especially while we're a small team.
- **Cross-agent flows become impossible.** E.g. "ask Hermes a question,
  then hand the answer to an OpenClaw agent" — currently theoretically
  possible in one app, out of scope across two apps.

### 5.3 Hybrid options to consider

1. **Single app, mode-scoped tabs.** Keep one app; make Memory / Skills /
   Mission Control mode-aware (read `chatModeProvider`); show a clear
   scope badge in the AppBar; show empty/unsupported states for modes
   that don't expose that surface. Cheapest fix; preserves cross-agent
   flows. Does not address binary-size / store-positioning argument.
2. **Single app, separate "Servers" model.** Promote agents from a chat
   submode to a top-level concept. User selects an active server
   (OpenClaw-A, Hermes-B, Local) and the *entire* app — not just chat —
   re-scopes. Bigger refactor, but matches the user's mental model
   without forking the codebase.
3. **Shared core package, two thin shells.** Extract everything not
   agent-specific into a `pocketclaw_core` package; two app modules
   import it. Highest engineering cost, highest long-term flexibility,
   only worth it if (a) Hermes' surfaces diverge substantially from
   OpenClaw's and (b) we expect a third agent class later.

## 6. Decision the architect is asked to make

1. **Scope inventory:** confirm or correct the table in §2. What does
   Hermes actually expose today, and what is on its roadmap?
2. **Path selection:** between
   - 5.3.1 (mode-scoped tabs in one app),
   - 5.3.2 (server-scoped app, one binary),
   - 5.3.3 (shared core, two shells), or
   - full fork (5.1) — which best fits the next 12 months of OpenClaw
   and Hermes evolution?
3. **Sequencing:** if the answer is "split eventually, but not yet",
   what's the smallest fix that unblocks users today and doesn't lock
   us out of the split later? (Likely §3.2 chat-mode-tag bug + a scope
   badge on each tab.)

## 7. Appendix — relevant files

- `lib/features/chat/chat_mode_selector.dart` — mode switch flow with
  the ordering bug in §3.2.
- `lib/core/session/session_manager.dart` — `loadSession` / `setMode`
  ordering; no per-load mode validation.
- `lib/features/mission_control/mission_control_providers.dart` —
  OpenClaw-only providers, no `chatModeProvider` read.
- `lib/features/memory/memory_screen.dart` — same.
- `lib/features/skills/skills_providers.dart` — same.
- `lib/data/providers/chat_providers.dart::sessionListProvider` — the
  one place where mode-tag filtering exists; relies on the buggy tag
  being correct.
- `memory/gateway_protocol_reference.md`,
  `memory/gateway_control_surface.md` — the OpenClaw side of the wire,
  for comparison against whatever Hermes exposes.
