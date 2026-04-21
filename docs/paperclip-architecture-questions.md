# Paperclip — Architecture Questions for the Architect

**Author:** PocketClaw client team (Claude)
**Date:** 2026-04-21
**Context for the architect:** I have the PocketClaw Flutter client, the OpenClaw gateway (deployed on the VPS), and the Paperclip *client-side* scaffolding in front of me. I do **not** have a Paperclip spec or a deployed Paperclip server. Before we wire the Company tab end-to-end, we need alignment on what Paperclip actually is, where it lives, and whether we need it at all.

---

## 1. What I see on the ground today

### PocketClaw (client)
Fully functional for these domains against OpenClaw:
- **Chat** — streaming, history, attachments, 49-command palette, destructive-confirm dialog, offline-aware banner.
- **Mission Control** — Agents roster (`agents.list`), Sessions count (`sessions.usage`), Cost Today/Week/Month (`usage.cost`), System Health (live `event:"health"` ping), Cron Jobs (`cron.list/update/run/remove`), Recent Activity (live `agent` events).
- **Memory (read-only)** — server files via `agents.files.list/get`, `doctor.memory.status`.
- **Skills** — "On server" list via `skills.status`, ClawHub search/install via `skills.search`/`skills.install`, enable/disable via `skills.update`.
- **Pairing** — Ed25519 device identity, pairing-required banner, `openclaw devices approve <id>` flow.
- **Proactive notifications** — fires `flutter_local_notifications` when a `proactive:true` agent push arrives while app is backgrounded.

### Company tab — orphaned scaffold
- 7 tabs exist: **Overview, Org Chart, Goals, Budgets, Tickets, Governance, Security**.
- A `PaperclipNotifier` holds state and has a `handleWebSocketEvent(Map)` method that expects typed pushes: `overview`, `orgChart`, `goals`, `budget`, `tickets`, `governance`, `security`, `full_sync`.
- `paperclip_connection_provider` derives a URL of `<gateway-url>/paperclip` and reuses the gateway token.
- **Nothing currently drives this state container.** `isConnected` is always `false`. All 7 tabs render empty states.
- No Paperclip service is deployed on the VPS (user confirmed 2026-04-21).

### OpenClaw gateway
Does **not** expose anything company-shaped today. No `company.*`, `budget.*`, `ticket.*`, `governance.*`, `org.*` RPC namespaces. Its domain model is: agents, sessions, skills, cron, memory, usage, chat. Purely AI-runtime; no business-state concerns.

---

## 2. The architectural question in one sentence

> **Is Paperclip a separate service, an OpenClaw plugin, or a concept we should retire in favour of lighter alternatives?**

The client scaffold leans toward "separate WebSocket service with typed push events and its own auth token", but no such service exists. Before we spend days wiring it, we need the architect to declare the model.

---

## 3. Open questions for the architect

### 3.1 Topology
- **Is Paperclip a standalone service** (e.g. its own Node/Python process, own port, own database) colocated on the VPS?
- **Or an OpenClaw plugin** (lives inside the gateway process, reachable via `company.*` RPCs on the same WebSocket)?
- **Or a reverse-proxied path** (`<gateway>/paperclip` terminating at a separate upstream)?
- If standalone: which port, and should it sit behind the same Tailscale-only binding as OpenClaw?

### 3.2 Protocol shape
- **Push vs. pull.** Everything we've wired so far is pull-RPC (`req`/`res`) except `chat` streaming and `event:"health"`. The Paperclip client assumes typed push events (`{type:"overview", payload:{…}}`). **Is that still the intended model, or should Paperclip conform to the pull-RPC style we standardised on?** A consistent protocol is cheaper to maintain.
- If push: what's the reconciliation strategy when the client reconnects? (Currently the code expects a `full_sync` on connect; is that still the contract?)

### 3.3 Data ownership — where does the truth live?
For each of the 7 tabs, what is the authoritative source?

| Tab | Possible sources | Architect decision needed |
|---|---|---|
| **Overview** | Derived from agents.list + sessions.usage + usage.cost? Or a curated summary? | Which? |
| **Org Chart** | The AI agents roster (`agents.list` with emoji/avatar) — OR a separate human-organisation concept (stakeholders, owners, contractors)? | Which? |
| **Goals** | Human-authored objectives? AI-generated from chat? Linked to OKRs? | Schema? |
| **Budgets** | Is this LLM cost (already in `usage.cost`) or operational budget (human spend, cloud bills, subscriptions)? | Overlap with Cost tab? |
| **Tickets** | Helpdesk tickets? Agent-generated tasks? Third-party integration (Linear/Jira) or Paperclip-native? | Source of truth? |
| **Governance** | Policy docs? Pending approvals? AI-generated draft contracts? | What gets approved, by whom, with what effect? |
| **Security** | Device pairing + scope table (we can derive this from gateway) — OR security audit log, anomaly alerts, compliance posture? | Scope? |

### 3.4 Interaction model
- Is the Company tab **read-only** (dashboard) or **CRUD** (user can create goals, close tickets, approve governance drafts on the phone)?
- If CRUD: do writes flow through Paperclip RPCs, or do they become instructions to the AI agents to execute?
- Are there destructive actions that need the same confirm dialog as destructive slash-commands in chat?

### 3.5 Multi-tenancy
- Is "Company" a single-tenant concept (one company per OpenClaw install) or multi-tenant (the user can switch companies)?
- If the latter: how does the user select/switch, and where is the selection persisted?

### 3.6 Identity overlap
- **Org Chart vs. Agents roster** — these seem to overlap. Are agents part of the org chart, or is the org chart strictly humans? If both, how are they visually distinguished?
- **Budgets vs. Cost Today** — if Budgets tracks LLM cost, we duplicate Mission Control → Cost. If it tracks something else, what?

### 3.7 Auth model
- Does Paperclip use the same Ed25519 device identity as OpenClaw, a separate token, or a forwarded session?
- Does it respect the same `operator.read`/`operator.write`/`operator.admin` scopes?

### 3.8 Migration path
- If we decide to retire Paperclip (see Section 4), what's the migration story for the existing client scaffold — delete the 7 tabs, or remap them to gateway concepts?

---

## 4. The honest question — *do we even need Paperclip?*

The user raised this: could we achieve the same goal with multiple Claude Code subagents?

### Where subagents could replace Paperclip
- **Ephemeral analysis** — "summarise this month's spend and flag anomalies" is a subagent job, not a persistent dashboard.
- **Document drafting** — governance drafts, contract templates, policy proposals can be subagent outputs written to memory.
- **Triage** — a ticket-triage subagent can read inbound messages and categorise them into memory files.
- **Specialisation** — budget-analyst subagent, org-chart-maintainer subagent, etc., with their own SKILL.md definitions.

### Where subagents fall short
- **Persistent structured state.** "Show me all open tickets sorted by priority" needs a queryable store. Subagents read memory files but can't efficiently query 500 tickets.
- **Reactive UI.** A dashboard with live counts needs a data layer subagents don't provide. Every view would re-spawn an agent to re-read memory — slow and expensive.
- **Concurrent writes.** Two humans (or human + agent) editing the same budget creates a merge problem memory files don't solve.
- **Auditability.** "Who approved this governance draft and when?" needs structured logs, not chat transcripts.

### A middle path worth considering
- Build Paperclip as a **thin SQLite-backed service on the VPS** that exposes `company.*` RPCs on the gateway (plugin model). Let specialised subagents read/write through those RPCs via tool calls. Client polls the RPCs on a timer (same pattern as `usage.cost` + `sessions.usage`).
- This gives us persistent structured state without a second WebSocket service, and subagents still do the *work* — Paperclip is just the shared filing cabinet they all write to.
- Cost: one new plugin module on the gateway, one SQLite file, ~300 lines of client code per tab. Days, not weeks.

### Recommendation to put to the architect
Either:
1. **Retire Paperclip as a separate service.** Reframe the Company tab: Overview/Org Chart/Security become gateway-data views, Goals/Budgets/Tickets/Governance move into structured memory files edited by specialised subagents. Fewer moving parts, accepts that those four tabs are best-effort text-file-ish.
2. **Build Paperclip as an OpenClaw plugin** (thin DB + `company.*` RPCs on the existing WS). Keep the 7-tab structure, but the client conforms to the pull-RPC model we already use everywhere else. No push, no separate token, no second service.

Option 2 preserves the original vision at the lowest realistic cost. Option 1 is the cheapest by far and tests whether anyone actually missed those tabs.

---

## 5. What I need from the architect to unblock the Company wire-up

A short spec containing:

1. **Topology decision** (§3.1) — standalone / plugin / retire.
2. **Protocol decision** (§3.2) — push vs. pull, event shapes or RPC signatures.
3. **Per-tab data contract** (§3.3) — for each of the 7 tabs: source of truth + field list + scope required.
4. **Interaction scope** (§3.4) — read-only vs. CRUD, and if CRUD, the mutation RPCs.
5. **Auth model** (§3.7) — same device identity or separate?
6. **Ordering** — which tabs ship first; which tabs are acceptable stubs on day one.

With those six answers I can wire the Company tab in one focused session, reusing the same patterns we used for Agents / Skills / Cron.

---

## Appendix — artefacts I can share with the architect

- `lib/features/company/*.dart` — the 7 tab implementations (all read from `paperclipProvider` state).
- `lib/data/providers/paperclip_provider.dart` — the state notifier and the event-type contract it expects.
- `lib/data/models/paperclip_state.dart` — the existing model shapes (`CompanyOverview`, `OrgMember`, `CompanyGoal`, `BudgetInfo`, `CompanyTicket`, `GovernanceDraft`, `SecurityDashboard`).
- `docs/PocketClaw-Product-Spec.md` / `docs/pocket-claw-developer-spec.md` — if Paperclip is specified there, the architect's decision may already be partly made.
- `memory/gateway_protocol_reference.md` + `memory/gateway_control_surface.md` — the authoritative record of every RPC OpenClaw currently exposes, so the architect knows what's already in the protocol vs. what's new.
