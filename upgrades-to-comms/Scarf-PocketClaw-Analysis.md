# Scarf × Pocket Claw — Comparative Analysis
## What We Can Borrow for the Hermes Integration

**Date:** 2026-05-08  
**Source:** `scarf-main` repository (v2.7.1) — verified from source  
**Prepared by:** CARMEN PTY LTD  

---

## 1. What Scarf Is

Scarf is a native macOS/iOS Swift application that provides a full graphical interface for Hermes Agent. It is the closest existing analog to what Pocket Claw is building — a mobile/desktop companion for a self-hosted Hermes instance. It is further along than Pocket Claw on Hermes-specific features, and studying it reveals both what is possible and exactly how to achieve it.

**Key facts:**
- macOS app (v1.x–v2.x) that evolved to include iOS support (v2.5+)
- Zero external dependencies — uses system SQLite3, Foundation JSON, SSH via Citadel
- Reads Hermes data directly from `~/.hermes/` (not via REST API)
- For iOS: accesses remote Hermes via SSH (not HTTP)
- MIT licensed — can be studied and adapted freely

---

## 2. The Critical Architectural Difference

This is the most important finding from the analysis.

**Pocket Claw (current):**
```
Phone ──── HTTP REST ────► Hermes API :8642
                           /v1/chat/completions only
```

**Scarf (iOS):**
```
iPhone ──── SSH (Citadel) ──► VPS
                               ├── sqlite3 -json ~/.hermes/state.db → sessions, messages, stats
                               ├── cat ~/.hermes/cron/jobs.json     → cron jobs
                               ├── cat ~/.hermes/memories/MEMORY.md → agent memory
                               └── hermes acp (subprocess via SSH)  → rich chat events
```

Scarf does not use the Hermes REST API at all. It bypasses it entirely and talks directly to the filesystem and the `hermes acp` subprocess over SSH. This is why Scarf can show sessions, memory, skills, cron, and tool call traces — none of which the REST API exposes in v0.12.

**This is the solution to Pocket Claw's v0.12 REST API limitation.** The REST API gives us chat. SSH gives us everything else.

---

## 3. Feature Comparison

| Feature | Scarf (iOS) | Pocket Claw (current) | Gap |
|---|---|---|---|
| Chat with agent | ✅ ACP via SSH (tool call streaming) | ✅ REST `/v1/chat/completions` | Scarf sees tool calls; Pocket Claw sees only final text |
| Sessions browser | ✅ SQLite query via SSH | ❌ Not implemented | Sessions invisible to Pocket Claw |
| Session detail / history | ✅ Full message thread | ❌ Not implemented | — |
| Full-text search | ✅ FTS5 via SSH | ❌ Not implemented | — |
| Memory editor | ✅ MEMORY.md + USER.md via SFTP | ❌ Not implemented | — |
| Skills browser | ✅ Reads `~/.hermes/skills/` via SSH | ❌ Not implemented | — |
| Cron manager | ✅ `jobs.json` via SFTP | ❌ Not implemented | — |
| Log viewer | ✅ Tail `errors.log` via SSH | ❌ Not implemented | — |
| Gateway status | ✅ `gateway_state.json` | ❌ Not implemented | — |
| Tool call cards | ✅ Rich ToolCallCard UI | ❌ Basic function indicator | — |
| Cost / token stats | ✅ Aggregated from SQLite | ❌ Not implemented | — |
| Dashboard widgets | ✅ 12 widget types | ❌ Not implemented | — |
| Multi-server | ✅ Server list, server switcher | ❌ Single server | — |
| Connection test | ✅ SSH preflight + SQLite probe | ✅ HTTP isReachable() | — |
| MCP server management | ✅ Full CRUD | ❌ Not implemented | — |

---

## 4. What to Borrow — Prioritised

### 4.1 SSH Transport Layer (Highest Priority — Unlocks Everything)

**What Scarf does:** Uses the [Citadel](https://github.com/orlandos-nl/Citadel) SSH library on iOS to:
1. Open an SSH connection to the VPS with Ed25519 key auth
2. Run `sqlite3 -readonly -json "SELECT ..."` as remote exec commands
3. Read/write files via SFTP (memory files, cron jobs.json)
4. Run `hermes acp` as a remote subprocess for chat

**What Pocket Claw should do:** Use the [`dartssh2`](https://pub.dev/packages/dartssh2) package — the Dart equivalent of Citadel. It supports:
- SSH2 key authentication (Ed25519)
- Remote exec (`ssh.execute("sqlite3 -json ..."`)
- SFTP file read/write
- Subprocess stdio streaming (for ACP)

**New pubspec dependency:**
```yaml
dartssh2: ^4.0.0
```

**New files:**
```
lib/core/hermes/ssh/
├── hermes_ssh_client.dart        ← SSH connection + exec + SFTP wrapper
├── hermes_remote_sqlite.dart     ← sqlite3 -json query runner
└── hermes_sftp_service.dart      ← file read/write for memory, cron
```

**Why this matters:** Adding SSH transport changes Pocket Claw's Hermes feature set from "chat only" to "full management" — sessions, memory, cron, skills, logs — matching Scarf's iOS capabilities.

---

### 4.2 Sessions Browser (High Priority)

Scarf's `HermesDataService` reads from `~/.hermes/state.db` with verified SQL queries. The schema is fully documented in `HERMES_DISCOVERY.md`.

**SQL to borrow (translatable to Dart strings):**

```sql
-- Session list
SELECT id, source, model, title, started_at, ended_at,
       message_count, tool_call_count, input_tokens, output_tokens,
       estimated_cost_usd, actual_cost_usd
FROM sessions
ORDER BY started_at DESC
LIMIT 50;

-- Session messages
SELECT id, role, content, tool_calls, tool_name, timestamp
FROM messages
WHERE session_id = ?
ORDER BY timestamp ASC;

-- Full-text search
SELECT s.id, s.title, m.content
FROM messages_fts fts
JOIN messages m ON m.id = fts.rowid
JOIN sessions s ON s.id = m.session_id
WHERE messages_fts MATCH ?
LIMIT 20;

-- Cost summary
SELECT SUM(COALESCE(actual_cost_usd, estimated_cost_usd)) as total_cost,
       SUM(input_tokens + output_tokens) as total_tokens,
       COUNT(*) as session_count
FROM sessions
WHERE started_at > strftime('%s', 'now', '-30 days');
```

**Data models to create (translated from Scarf's Swift structs):**

```dart
// lib/core/hermes/models/hermes_session.dart
class HermesSession {
  final String id;
  final String source;         // 'cli', 'telegram', 'discord', etc.
  final String? model;
  final String? title;
  final String? parentSessionId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int messageCount;
  final int toolCallCount;
  final int inputTokens;
  final int outputTokens;
  final double? estimatedCostUSD;
  final double? actualCostUSD;
  final String? billingProvider;

  // Computed
  bool get isSubagent => parentSessionId != null;
  int get totalTokens => inputTokens + outputTokens;
  double? get displayCostUSD => actualCostUSD ?? estimatedCostUSD;
  String get displayTitle => title ?? id;
  
  // Platform icon mapping (from Scarf's KnownPlatforms)
  String get sourceIcon {
    return switch (source) {
      'telegram' => '📱',
      'discord'  => '💬',
      'cli'      => '⌨️',
      'slack'    => '💼',
      _          => '🤖',
    };
  }
}

// lib/core/hermes/models/hermes_message.dart
class HermesMessage {
  final int id;
  final String sessionId;
  final String role;         // 'user' | 'assistant'
  final String content;
  final String? toolName;
  final List<HermesToolCall>? toolCalls;
  final DateTime? timestamp;
  final int? tokenCount;
}

// lib/core/hermes/models/hermes_tool_call.dart
class HermesToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  
  // Scarf's tool kind classification for colour coding
  ToolKind get kind {
    return switch (name) {
      'read_file' || 'list_dir' || 'search_files' => ToolKind.read,
      'write_file' || 'edit_file' || 'delete_file' => ToolKind.edit,
      'terminal' || 'execute_code'                 => ToolKind.execute,
      'web_search' || 'browser' || 'fetch_url'     => ToolKind.fetch,
      _                                             => ToolKind.other,
    };
  }
}

enum ToolKind { read, edit, execute, fetch, search, think, other }
```

---

### 4.3 Cron Jobs (High Priority — JSON file, simple)

Scarf reads `~/.hermes/cron/jobs.json` via SFTP and writes it back on mutation. The schema is fully verified:

**Dart model (translated from Scarf's `HermesCronJob`):**

```dart
// lib/core/hermes/models/hermes_cron_job.dart
class HermesCronJob {
  final String id;
  final String name;
  final String prompt;
  final List<String>? skills;
  final String? model;
  final CronSchedule schedule;
  final bool enabled;
  final String state;      // 'scheduled' | 'running' | 'completed' | 'failed'
  final String? deliver;   // 'telegram' | 'discord:channel' | null
  final String? nextRunAt;
  final String? lastRunAt;
  final String? lastError;
  final String? workdir;

  String get stateIcon => switch (state) {
    'scheduled' => '🕐',
    'running'   => '▶️',
    'completed' => '✅',
    'failed'    => '❌',
    _           => '❓',
  };
}

class CronSchedule {
  final String kind;         // 'once' | 'cron'
  final String? runAt;       // ISO8601 for 'once'
  final String? display;     // human-readable
  final String? expression;  // cron expression
}

class CronJobsFile {
  final List<HermesCronJob> jobs;
  final String? updatedAt;
}
```

**Read/write via SSH:**
```dart
// Read
final raw = await hermesSSH.readFile('~/.hermes/cron/jobs.json');
final file = CronJobsFile.fromJson(jsonDecode(raw));

// Write (after mutation)
await hermesSSH.writeFile('~/.hermes/cron/jobs.json', jsonEncode(file));
```

---

### 4.4 Memory Editor (Medium Priority — Two files)

Scarf's `IOSMemoryViewModel` manages three files: `MEMORY.md`, `USER.md`, and `SOUL.md`.

```dart
// lib/core/hermes/models/hermes_memory.dart
enum MemoryKind {
  memory,   // ~/.hermes/memories/MEMORY.md — agent persistent memory
  user,     // ~/.hermes/memories/USER.md — user profile
  soul,     // ~/.hermes/SOUL.md — agent persona
}

// Access pattern (via SSH SFTP)
class HermesMemoryService {
  Future<String> read(MemoryKind kind) async {
    final path = switch (kind) {
      MemoryKind.memory => '~/.hermes/memories/MEMORY.md',
      MemoryKind.user   => '~/.hermes/memories/USER.md',
      MemoryKind.soul   => '~/.hermes/SOUL.md',
    };
    return hermesSSH.readFile(path);
  }

  Future<void> write(MemoryKind kind, String content) async {
    // Same path resolution, write via SFTP
  }
}
```

**UI:** A simple markdown editor with MEMORY / USER / SOUL toggle — show character count vs the configured limits from `config.yaml` (2,200 chars for memory, 1,375 for user profile — verified from your live config).

---

### 4.5 Tool Call Card UI (Medium Priority)

Scarf's `ToolCallCard.swift` renders a rich per-tool-call card with:
- Tool name + kind icon
- Colour-coded by tool kind (Scarf's token system)
- Collapsible arguments and result
- Duration timing

**Translate to Flutter:**
```dart
// lib/shared/widgets/tool_call_card.dart
class ToolCallCard extends StatelessWidget {
  final HermesToolCall toolCall;
  final String? result;
  final bool isExpanded;

  // Colour map from Scarf's tokens/colors-tool-kinds.html
  Color _kindColor(ToolKind kind) => switch (kind) {
    ToolKind.read    => const Color(0xFF60A5FA), // blue
    ToolKind.edit    => const Color(0xFFFBBF24), // amber
    ToolKind.execute => const Color(0xFF34D399), // emerald
    ToolKind.fetch   => const Color(0xFFA78BFA), // violet
    ToolKind.search  => const Color(0xFF38BDF8), // sky
    ToolKind.think   => const Color(0xFFF472B6), // pink
    ToolKind.other   => const Color(0xFF9CA3AF), // gray
  };
}
```

This can be wired into the chat bubble when Pocket Claw switches to ACP-based chat (the REST API doesn't send tool call events, but ACP over SSH does).

---

### 4.6 ACP Protocol via SSH (Future Sprint — Richer Chat)

Scarf's most sophisticated feature is the `SSHExecACPChannel` — it runs `hermes acp` as a remote subprocess via SSH and gets richer event streaming than the REST API provides.

**REST API gives you:**
```json
{"choices":[{"delta":{"content":"Here is your answer..."}}]}
```

**ACP via SSH gives you:**
```
ToolCallStart   → "Searching the web for XAUUSD..."
ToolCallProgress → "Found 5 results"
AgentThought    → "I'll analyse the top 3 sources"
AgentMessage    → "Based on the analysis..."
```

This is what makes Scarf's chat feel live and transparent versus Pocket Claw's current "black box" REST response. Tool call cards, thinking indicators, and live progress come from ACP.

**When to implement:** After SSH transport is working. ACP requires `dartssh2` exec, not just SFTP. It's a second-sprint Hermes feature, not first.

---

### 4.7 Dashboard Widget System (Low Priority — Future)

Scarf's `tools/widget-schema.json` defines 12 widget types that Hermes agents can write to `dashboard.json` in a project. The agent generates the dashboard; the app renders it.

Widget types worth adopting for Pocket Claw's Hermes Management screen:
- `stat` — single big number (e.g. sessions today, tokens used, cost)
- `progress` — budget utilisation bar
- `list` — recent activity with status badges
- `cron_status` — last/next run for a specific cron job
- `log_tail` — last N lines of errors.log
- `chart` — cost over time, token usage trend

These map cleanly to Pocket Claw's existing `StatCard` and `HealthBar` widgets.

---

## 5. What NOT to Borrow

| Scarf feature | Why not |
|---|---|
| `ProcessACPChannel` (macOS subprocess) | Can't spawn subprocesses on Android |
| `LocalSQLiteBackend` (direct SQLite3 C API) | Phone can't access VPS filesystem directly |
| Citadel SSH library | Swift/iOS only — use `dartssh2` instead |
| Scarf Template system (`.scarftemplate`) | Scarf-specific project scaffolding, not relevant |
| MCP server management | Future sprint, not Hermes integration sprint |
| Kanban board | Hermes-specific feature, lower priority |

---

## 6. Recommended Sprint Plan (Updated)

With Scarf as reference, the Hermes integration sprint now has a clear two-phase shape:

### Phase 1 — REST Chat (Current Sprint, 4–6 days)
As specified in `SPEC-HermesIntegration-v1.0.md`:
- `HermesClient` + SSE parser
- `hermes` execution path in Smart Router
- Settings screen
- Chat wired through Hermes REST

### Phase 2 — SSH Management (Next Sprint, 1–2 weeks)
Informed entirely by Scarf's approach:
1. Add `dartssh2` to pubspec
2. Build `HermesSSHClient` (connect, exec, SFTP read/write)
3. Build `HermesRemoteSqlite` (runs `sqlite3 -json` via SSH exec)
4. Sessions browser screen (list + detail + FTS search)
5. Memory editor (MEMORY.md + USER.md + SOUL.md)
6. Cron manager (read `jobs.json`, toggle enabled, view last error)
7. Log viewer (tail `errors.log` and `gateway.log`)
8. Gateway status (read `gateway_state.json`)

### Phase 3 — ACP Chat (Sprint after that)
Replace REST chat with ACP-over-SSH for tool call visibility:
1. `HermesACPChannel` via `dartssh2` exec
2. Tool call card widget
3. Live ToolCallProgress indicators in chat

---

## 7. Key Files to Keep Open When Building

| What you're building | Reference in Scarf |
|---|---|
| SSH transport | `ScarfIOS/CitadelSSHService.swift` + `SSHExecACPChannel.swift` |
| Remote SQLite | `ScarfCore/Services/Backends/RemoteSQLiteBackend.swift` |
| Sessions data model | `ScarfCore/Models/HermesSession.swift` |
| Messages data model | `ScarfCore/Models/HermesMessage.swift` |
| Cron jobs model + serialisation | `ScarfCore/Models/HermesCronJob.swift` |
| Memory editor ViewModel | `ScarfCore/ViewModels/IOSMemoryViewModel.swift` |
| Cron ViewModel | `ScarfCore/ViewModels/IOSCronViewModel.swift` |
| Tool call card UI | `scarf/Features/Chat/Views/ToolCallCard.swift` |
| File paths (`~/.hermes/...`) | `ScarfCore/Models/HermesPathSet.swift` |
| Dashboard widgets | `tools/widget-schema.json` |
| Design tokens | `design/static-site/tokens/colors-tool-kinds.html` |

---

## 8. One Paragraph for Your Developer

Scarf is the iOS/macOS equivalent of Pocket Claw for Hermes. The single most important thing it teaches us is this: **the Hermes REST API is intentionally minimal — chat only. Everything else (sessions, memory, cron, skills, logs) is only accessible by SSHing into the VPS and querying the filesystem directly.** Scarf does this on iOS using Citadel for SSH + running `sqlite3 -json` as remote exec commands to query `~/.hermes/state.db`. Pocket Claw should do the same using `dartssh2`. The data models (`HermesSession`, `HermesCronJob`, `HermesSkill`) are battle-tested and the SQL queries are documented — translation from Swift to Dart is mechanical work, not design work. The current sprint (REST chat) is correct as-is. The sprint after it should be SSH transport + sessions browser + memory editor + cron manager, following Scarf's approach exactly.

---

*CARMEN PTY LTD — Pocket Claw × Scarf Analysis*  
*Source verified from scarf-main repository — 2026-05-08*
