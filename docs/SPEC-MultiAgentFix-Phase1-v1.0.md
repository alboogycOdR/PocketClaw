# ClawCommander — Multi-Agent Fix Phase 1
## Developer Specification v1.0

**Date:** 2026-05-09  
**Author:** CARMEN PTY LTD  
**Depends on:** ADR-001-MultiAgentArchitecture.md  
**Status:** Implement immediately — unblocks users before Phase 2 refactor  
**Estimated effort:** 2 days  

---

## Overview

Three targeted fixes that unblock users today without any architectural change. Phase 2 (server-scoped model) builds on these — none of these changes conflict with it or need to be undone.

---

## Fix 1 — Mode Tag Bug (§3.2 in problem statement)

### The Bug

In `lib/features/chat/chat_mode_selector.dart`, `_onModeTap` calls `SessionManager.setMode(newMode)` **before** the buffered messages from the current session are flushed to disk. When `SessionManager.loadSession` subsequently writes those messages, it tags them with the **new** mode. Result: an OpenClaw conversation appears in Hermes' session history.

### Exact Fix

**File:** `lib/features/chat/chat_mode_selector.dart`

Find `_onModeTap` (or equivalent mode switch handler). The current order is:

```dart
// WRONG ORDER — current code
await ref.read(sessionManagerProvider).setMode(newMode);   // ← sets mode first
await ref.read(sessionManagerProvider).flushCurrentSession(); // ← then flushes with wrong tag
```

Change to:

```dart
// CORRECT ORDER
await ref.read(sessionManagerProvider).flushCurrentSession(); // ← flush with current mode tag
await ref.read(sessionManagerProvider).setMode(newMode);      // ← then switch mode
```

**File:** `lib/core/session/session_manager.dart`

In `loadSession`, add a guard that validates the incoming messages' mode tag matches the current mode before writing. If there is a mismatch, log a warning and do not overwrite:

```dart
Future<void> loadSession(String sessionId) async {
  final messages = await _storage.loadMessages(sessionId);

  // Guard: reject messages whose stored mode tag does not match
  // the current mode. This catches any residual cases where the
  // flush/setMode order was wrong in a previous build.
  final filteredMessages = messages.where((m) {
    if (m.modeTag == null) return true;  // untagged — allow
    if (m.modeTag == _currentMode.name) return true; // correct tag — allow
    // Mismatched tag — log and exclude
    debugPrint('[SessionManager] loadSession: skipping message '
        '${m.id} with wrong mode tag ${m.modeTag} '
        '(current mode: ${_currentMode.name})');
    return false;
  }).toList();

  _messages.value = filteredMessages;
}
```

### Test

1. Start an OpenClaw chat session with several messages
2. Switch mode to Hermes via the mode selector
3. Open Hermes session history
4. **Before fix:** the OpenClaw messages appear in Hermes history
5. **After fix:** Hermes history is empty (or shows only Hermes sessions)

---

## Fix 2 — Scope Badge on Non-Chat Tabs

### The Problem

Mission Control, Memory, and Skills screens show OpenClaw data with no UI signal identifying the data source. A user who switched to Hermes for chat reasonably assumes these tabs reflect Hermes.

### What to Add

Add a persistent scope badge to the AppBar of each affected screen. The badge is **informational only** — it does not make the tabs mode-aware (that is Phase 2).

**Badge widget:**

```dart
// lib/shared/widgets/agent_scope_badge.dart
library;

import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// A small chip shown in screen AppBars to indicate which agent
/// owns the data on that screen. Informational only — Phase 2
/// will make screens dynamically mode-aware.
class AgentScopeBadge extends StatelessWidget implements PreferredSizeWidget {
  final String agentName;
  final Color color;
  final IconData icon;

  const AgentScopeBadge.openclaw({super.key})
      : agentName = 'OpenClaw',
        color = const Color(0xFFE53935),   // lobsterRed
        icon = Icons.rss_feed;

  const AgentScopeBadge.hermes({super.key})
      : agentName = 'Hermes',
        color = const Color(0xFF7C3AED),   // purple
        icon = Icons.psychology_outlined;

  const AgentScopeBadge.local({super.key})
      : agentName = 'Local',
        color = const Color(0xFF00E5CC),   // electricTeal
        icon = Icons.phone_android;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 12, color: color),
      label: Text(
        agentName,
        style: TextStyle(fontSize: 10, color: color),
      ),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(24);
}
```

**Add to each affected screen's AppBar `actions:` list:**

```dart
// lib/features/mission_control/dashboard_screen.dart
AppBar(
  title: const Text('Mission Control'),
  actions: [
    const AgentScopeBadge.openclaw(),
    const SizedBox(width: 8),
  ],
),

// lib/features/memory/memory_screen.dart
AppBar(
  title: const Text('Memory'),
  actions: [
    const AgentScopeBadge.openclaw(),
    const SizedBox(width: 8),
  ],
),

// lib/features/skills/skills_screen.dart
AppBar(
  title: const Text('Skills'),
  actions: [
    const AgentScopeBadge.openclaw(),
    const SizedBox(width: 8),
  ],
),
```

**Phase 2 note:** In Phase 2, `AgentScopeBadge` becomes dynamic — it reads `activeServerProvider` and renders the correct badge automatically. The widget interface does not need to change; the constructor call changes from `AgentScopeBadge.openclaw()` to `AgentScopeBadge.fromProvider(ref)`.

### Files Changed

| File | Change |
|---|---|
| `lib/shared/widgets/agent_scope_badge.dart` | **New** |
| `lib/features/mission_control/dashboard_screen.dart` | Add badge to AppBar |
| `lib/features/memory/memory_screen.dart` | Add badge to AppBar |
| `lib/features/skills/skills_screen.dart` | Add badge to AppBar |

---

## Fix 3 — Hermes Management Entry Point

### The Problem

The Hermes management screen lives at `/hermes` and is never reachable from the main navigation. A user with Hermes configured has no way to find sessions, memory, cron, skills, or logs. The route exists; it just has no door.

### What to Add

**Option A — Mission Control tile (implement now):**

In `lib/features/mission_control/dashboard_screen.dart`, add a Hermes section below the existing OpenClaw cards. Show it only when Hermes is configured:

```dart
// In DashboardScreen body, after existing OpenClaw cards:

Consumer(builder: (context, ref, _) {
  final hermesReachable = ref.watch(hermesReachableProvider);
  final hermesUrl = ref.watch(hermesBaseUrlProvider);

  // Only show if Hermes is configured
  if (hermesUrl.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          const Icon(Icons.psychology_outlined,
              size: 14, color: Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          Text('Hermes Agent',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white54)),
        ]),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: hermesReachable.when(
            data: (ok) => Icon(
              ok ? Icons.check_circle_outline : Icons.error_outline,
              color: ok ? Colors.tealAccent : Colors.redAccent,
            ),
            loading: () => const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Icon(
                Icons.error_outline, color: Colors.redAccent),
          ),
          title: const Text('Hermes Management'),
          subtitle: hermesReachable.when(
            data: (ok) => Text(ok ? 'Online' : 'Unreachable',
                style: TextStyle(
                    color: ok ? Colors.tealAccent : Colors.redAccent)),
            loading: () => const Text('Checking…'),
            error: (_, __) => const Text('Error'),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/hermes'),
        ),
      ),
    ],
  );
}),
```

**Option B — Bottom nav (Phase 2):**

In Phase 2, the Hermes management surfaces move into the main tab structure. Until then, Option A (the tile) is sufficient and takes 30 minutes.

### Files Changed

| File | Change |
|---|---|
| `lib/features/mission_control/dashboard_screen.dart` | Add Hermes management tile |

---

## Implementation Order

1. Fix mode tag bug — `chat_mode_selector.dart` (30 min)
2. Fix mode tag guard — `session_manager.dart` (30 min)
3. Create `agent_scope_badge.dart` (20 min)
4. Add badge to Dashboard, Memory, Skills (20 min)
5. Add Hermes tile to Dashboard (30 min)
6. Test mode switching end-to-end on physical device

Total: approximately half a day of focused work.

---

*CARMEN PTY LTD — Multi-Agent Fix Phase 1 Spec v1.0 — 2026-05-09*
