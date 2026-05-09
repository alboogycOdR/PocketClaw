# ClawCommander — Sprint B: Capability Gate + Approvals
## Developer Specification v1.0

**Date:** 2026-05-09  
**Author:** CARMEN PTY LTD  
**Verified against:** `PocketClaw-source-2026-05-09`  
**Status:** Implementation-ready  
**Estimated effort:** 2 days  
**Depends on:** `SPEC-MultiAgentFix-Phase2-v1.0.md` — `activeServerProvider` must exist before this sprint starts. Sprint A (chat polish) is independent and can run in parallel.

---

## Overview

Three features that complete the server-scoped architecture introduced in Phase 2:

1. **Capability Gate** — prevents empty/broken management screens when switching servers. When Hermes is active but SSH is not configured, Cron/Memory/Sessions show a graceful "feature unavailable" card instead of crashing or loading infinitely.
2. **Pending Approvals Bell** — your Hermes config has `approvals.mode: manual`. Background cron jobs can block silently waiting for approval while you're not in chat. This adds a badge to the Control tab and a quick-resolve panel.
3. **Session Auto-Title** — both OpenClaw and Hermes sessions currently show raw IDs or "New Chat" in the history list. Auto-titles make sessions navigable.

---

## Item 1 — Capability Gate

### The Problem

When the user switches to Hermes via `activeServerProvider` but hasn't configured SSH, the Memory, Cron, Sessions, and Skills screens will show loading spinners forever (SSH client is null, providers return empty). There's no signal to the user about why. The workspace solves this with a capability gate that shows a clear "feature unavailable" card instead.

### New File: `lib/data/providers/capability_providers.dart`

```dart
// lib/data/providers/capability_providers.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'server_providers.dart';
import 'ssh_providers.dart';

/// What features the currently active server actually exposes.
/// Derived statically from activeServerProvider + SSH configuration.
/// No network probing needed — capabilities follow from server type.
class ServerCapabilities {
  final bool hasCron;
  final bool hasSessions;
  final bool hasMemory;
  final bool hasSkills;
  final bool hasAgents;
  final bool hasChannels;
  final bool hasCost;
  final bool hasLogs;
  final bool hasSsh;

  const ServerCapabilities({
    this.hasCron     = false,
    this.hasSessions = false,
    this.hasMemory   = false,
    this.hasSkills   = false,
    this.hasAgents   = false,
    this.hasChannels = false,
    this.hasCost     = false,
    this.hasLogs     = false,
    this.hasSsh      = false,
  });

  factory ServerCapabilities.forServer(
    ActiveServer server, {
    required bool sshConfigured,
  }) {
    return switch (server) {
      ActiveServer.openclaw => const ServerCapabilities(
        hasCron:     true,
        hasSessions: true,
        hasMemory:   true,
        hasSkills:   true,
        hasAgents:   true,
        hasChannels: true,
        hasCost:     true,
        hasLogs:     false, // OpenClaw logs available only via SSH
      ),
      ActiveServer.hermes => ServerCapabilities(
        hasCron:     sshConfigured,
        hasSessions: sshConfigured,
        hasMemory:   sshConfigured,
        hasSkills:   sshConfigured,
        hasAgents:   false,
        hasChannels: false,
        hasCost:     sshConfigured,
        hasLogs:     sshConfigured,
        hasSsh:      sshConfigured,
      ),
      ActiveServer.local => const ServerCapabilities(),
    };
  }

  /// Whether this capability is available — use to gate UI surfaces.
  bool operator [](String feature) => switch (feature) {
    'cron'     => hasCron,
    'sessions' => hasSessions,
    'memory'   => hasMemory,
    'skills'   => hasSkills,
    'agents'   => hasAgents,
    'channels' => hasChannels,
    'cost'     => hasCost,
    'logs'     => hasLogs,
    'ssh'      => hasSsh,
    _          => false,
  };
}

final serverCapabilitiesProvider = Provider<ServerCapabilities>((ref) {
  final server    = ref.watch(activeServerProvider);
  final sshHost   = ref.watch(sshHostProvider);
  return ServerCapabilities.forServer(
    server,
    sshConfigured: sshHost.isNotEmpty,
  );
});
```

### New File: `lib/shared/widgets/feature_not_available_card.dart`

```dart
// lib/shared/widgets/feature_not_available_card.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/providers/capability_providers.dart';
import '../../data/providers/server_providers.dart';

/// Shown in place of a management tab when the active server doesn't
/// expose that feature (e.g. Hermes without SSH configured).
///
/// Provides a contextual action button — e.g. "Configure SSH" when
/// the gate is SSH, "Switch to OpenClaw" when the feature only exists
/// there.
class FeatureNotAvailableCard extends ConsumerWidget {
  final String feature;     // human-readable: "Sessions", "Memory", etc.
  final String featureKey;  // capability key: 'sessions', 'memory', etc.

  const FeatureNotAvailableCard({
    super.key,
    required this.feature,
    required this.featureKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    final caps   = ref.watch(serverCapabilitiesProvider);

    // Determine why this feature is unavailable and what to suggest
    final (reason, actionLabel, actionRoute) = _resolveContext(
      server: server,
      caps: caps,
      featureKey: featureKey,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              feature,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white38,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && actionRoute != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.push(actionRoute),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(actionLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PocketClawTheme.electricTeal,
                  side: const BorderSide(color: PocketClawTheme.electricTeal),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String reason, String? actionLabel, String? actionRoute) _resolveContext({
    required ActiveServer server,
    required ServerCapabilities caps,
    required String featureKey,
  }) {
    // Hermes without SSH
    if (server == ActiveServer.hermes && !caps.hasSsh) {
      return (
        '$feature requires SSH access to your VPS.\n'
        'Configure your SSH credentials in Settings.',
        'Configure SSH',
        '/settings/ssh',
      );
    }

    // Local model — no management surfaces
    if (server == ActiveServer.local) {
      return (
        '$feature is not available for the Local model.\n'
        'Switch to OpenClaw or Hermes for management features.',
        null,
        null,
      );
    }

    // OpenClaw missing a feature (rare — all main features exposed)
    return (
      '$feature is not available for the current server.',
      null,
      null,
    );
  }
}
```

### Wire Gates onto Management Tab Items

The management tab items that need gates are in `DashboardScreen` (Mission Control) and the nested tab screens. After Phase 2 lands, the `DashboardScreen` routes to either `OpenClawDashboard` or `HermesDashboardProxy` based on `activeServerProvider`. The gates apply within each dashboard.

**For Hermes Management** — update each tab in `HermesManagementScreen`:

```dart
// lib/features/hermes/hermes_management_screen.dart

// Add import:
import '../../data/providers/capability_providers.dart';
import '../../shared/widgets/feature_not_available_card.dart';

// In the TabBarView children, wrap each tab:
TabBarView(
  children: [
    // Sessions tab
    Consumer(builder: (_, ref, __) {
      final caps = ref.watch(serverCapabilitiesProvider);
      return caps.hasSessions
          ? const HermesSessionsTab()
          : const FeatureNotAvailableCard(
              feature: 'Sessions', featureKey: 'sessions');
    }),
    // Memory tab
    Consumer(builder: (_, ref, __) {
      final caps = ref.watch(serverCapabilitiesProvider);
      return caps.hasMemory
          ? const HermesMemoryTab()
          : const FeatureNotAvailableCard(
              feature: 'Memory', featureKey: 'memory');
    }),
    // Cron tab
    Consumer(builder: (_, ref, __) {
      final caps = ref.watch(serverCapabilitiesProvider);
      return caps.hasCron
          ? const HermesCronTab()
          : const FeatureNotAvailableCard(
              feature: 'Cron', featureKey: 'cron');
    }),
    // Skills tab
    Consumer(builder: (_, ref, __) {
      final caps = ref.watch(serverCapabilitiesProvider);
      return caps.hasSkills
          ? const HermesSkillsTab()
          : const FeatureNotAvailableCard(
              feature: 'Skills', featureKey: 'skills');
    }),
    // Logs tab
    Consumer(builder: (_, ref, __) {
      final caps = ref.watch(serverCapabilitiesProvider);
      return caps.hasLogs
          ? const HermesLogsTab()
          : const FeatureNotAvailableCard(
              feature: 'Logs', featureKey: 'logs');
    }),
  ],
),
```

### Files Changed

| File | Change |
|---|---|
| `lib/data/providers/capability_providers.dart` | **New** |
| `lib/shared/widgets/feature_not_available_card.dart` | **New** |
| `lib/features/hermes/hermes_management_screen.dart` | Wrap each tab in capability gate |

### Test

1. Configure Hermes URL + API key but **no SSH**
2. Switch active server to Hermes (Phase 2)
3. Open Control tab → Sessions, Memory, Cron, Skills, Logs
4. Each tab shows "Configure SSH →" card instead of loading forever
5. Tap "Configure SSH" → navigates to SSH settings screen
6. After configuring SSH: refresh → tabs load normally
7. Switch to Local → all management tabs show "not available" cards

---

## Item 2 — Pending Approvals Bell

### The Problem

`approvals.mode: manual` is set in your Hermes config. When Hermes runs a background task (cron job, scheduled run) that hits a tool requiring approval, it blocks silently. The only current resolution paths are the `/approve` chat command (requires being in an active session) or the Telegram bot. This adds a proactive badge on the Control tab and a quick-resolve drawer accessible from anywhere in the app.

### The Architecture

`pendingAcpPermissionProvider` already exists and is populated during ACP chat sessions. The gap is:
1. Background approvals (cron jobs) don't go through the ACP client — they surface via the Hermes gateway REST endpoint
2. No badge on the Control tab icon
3. No UI reachable outside of chat

This sprint adds both the in-chat approval queue persistence and a REST polling fallback for background approvals.

### Step 1 — Persistent Approvals Notifier

```dart
// lib/data/providers/approvals_providers.dart
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/hermes/acp/acp_models.dart';
import '../../core/hermes/hermes_client.dart';
import 'hermes_providers.dart';
import 'server_providers.dart';

/// A single pending approval — either from ACP (in-chat) or
/// polled from the Hermes REST /v1/approvals endpoint.
class PendingApproval {
  final String id;           // requestId (int) or REST approval ID
  final String toolCallTitle;
  final String toolCallKind;
  final List<AcpPermissionOption> options;
  final DateTime receivedAt;
  final ApprovalSource source;

  const PendingApproval({
    required this.id,
    required this.toolCallTitle,
    required this.toolCallKind,
    required this.options,
    required this.receivedAt,
    required this.source,
  });

  bool get isExecuteKind => toolCallKind == 'execute';
}

enum ApprovalSource { acp, rest }

class ApprovalsNotifier extends StateNotifier<List<PendingApproval>> {
  ApprovalsNotifier() : super(const []);

  /// Called by the ACP event listener when a permission request arrives
  /// during an active chat session.
  void addAcpApproval(AcpPermissionRequestEvent event) {
    final approval = PendingApproval(
      id: event.requestId.toString(),
      toolCallTitle: event.toolCallTitle,
      toolCallKind: event.toolCallKind,
      options: event.options,
      receivedAt: DateTime.now(),
      source: ApprovalSource.acp,
    );
    if (state.any((a) => a.id == approval.id)) return;
    state = [...state, approval];
  }

  /// Called from REST polling for background approvals.
  void addRestApproval(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty || state.any((a) => a.id == id)) return;
    state = [
      ...state,
      PendingApproval(
        id: id,
        toolCallTitle: json['action'] as String? ?? 'Approval requested',
        toolCallKind: json['tool'] as String? ?? 'other',
        options: const [
          AcpPermissionOption(optionId: 'allow', name: 'Allow'),
          AcpPermissionOption(optionId: 'deny', name: 'Deny'),
        ],
        receivedAt: DateTime.now(),
        source: ApprovalSource.rest,
      ),
    ];
  }

  /// Remove after the user resolves it.
  void resolve(String id) {
    state = state.where((a) => a.id != id).toList();
  }

  void clearAll() => state = const [];
}

final approvalsProvider =
    StateNotifierProvider<ApprovalsNotifier, List<PendingApproval>>(
  (_) => ApprovalsNotifier(),
);

final pendingApprovalCountProvider = Provider<int>(
  (ref) => ref.watch(approvalsProvider).length,
);
```

### Step 2 — Feed ACP Approvals into the Notifier

In `lib/data/providers/chat_providers.dart`, find the `AcpPermissionRequestEvent` case and add a feed to the new notifier:

```dart
// EXISTING code (keep):
case AcpPermissionRequestEvent():
  ref.read(pendingAcpPermissionProvider.notifier).state = event;

// ADD after the existing line:
  ref.read(approvalsProvider.notifier).addAcpApproval(event);
```

Also clear the resolved approval when the user responds via the existing `_respondToPermission` method. Find where `pendingAcpPermissionProvider` is cleared and add:

```dart
// After existing permission resolution:
ref.read(approvalsProvider.notifier).resolve(event.requestId.toString());
```

### Step 3 — Control Tab Badge

In `lib/app/router.dart`, update the Control tab `NavigationDestination` to show a badge when approvals are pending:

```dart
// Replace the Control NavigationDestination:
NavigationDestination(
  icon: Consumer(builder: (_, ref, __) {
    final count = ref.watch(pendingApprovalCountProvider);
    if (count == 0) return const Icon(Icons.dashboard_outlined);
    return badges.Badge(
      badgeContent: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      badgeStyle: const badges.BadgeStyle(
        badgeColor: Color(0xFFE53935),
        padding: EdgeInsets.all(4),
      ),
      child: const Icon(Icons.dashboard_outlined),
    );
  }),
  selectedIcon: Consumer(builder: (_, ref, __) {
    final count = ref.watch(pendingApprovalCountProvider);
    if (count == 0) return const Icon(Icons.dashboard);
    return badges.Badge(
      badgeContent: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      badgeStyle: const badges.BadgeStyle(
        badgeColor: Color(0xFFE53935),
        padding: EdgeInsets.all(4),
      ),
      child: const Icon(Icons.dashboard),
    );
  }),
  label: 'Control',
),
```

**Add the `badges` package to `pubspec.yaml`:**
```yaml
flutter_badges: ^3.1.2   # or 'badges: ^3.1.2' — check pub.dev for latest
```

### Step 4 — Approvals Panel

Add a quick-resolve panel accessible from the Dashboard screen when approvals are pending. Place it as a card at the top of the OpenClaw Dashboard and the Hermes Management screen:

```dart
// lib/shared/widgets/approvals_panel.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/acp/acp_models.dart';
import '../../data/providers/approvals_providers.dart';
import '../../data/providers/chat_providers.dart';

/// Compact approvals panel. Shown at the top of the dashboard
/// when there are pending approvals. Hidden when empty.
class ApprovalsPanel extends ConsumerWidget {
  const ApprovalsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvals = ref.watch(approvalsProvider);
    if (approvals.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      color: const Color(0xFF2A1A10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: PocketClawTheme.lobsterRed.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  size: 16,
                  color: PocketClawTheme.lobsterRed,
                ),
                const SizedBox(width: 8),
                Text(
                  '${approvals.length} pending approval${approvals.length > 1 ? 's' : ''}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PocketClawTheme.lobsterRed,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.read(approvalsProvider.notifier).clearAll(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white38,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Dismiss all', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF3A2520)),

          // Approval rows
          ...approvals.map(
            (approval) => _ApprovalRow(approval: approval),
          ),
        ],
      ),
    );
  }
}

class _ApprovalRow extends ConsumerWidget {
  final PendingApproval approval;
  const _ApprovalRow({required this.approval});

  String _timeAgo(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inSeconds < 60) return '${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    return '${delta.inHours}h ago';
  }

  // Deterministic colour from agent name hash
  Color _kindColor(String kind) => switch (kind) {
    'execute' => const Color(0xFF34D399),
    'edit'    => const Color(0xFFFBBF24),
    'read'    => const Color(0xFF60A5FA),
    'fetch'   => const Color(0xFFA78BFA),
    _         => const Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _kindColor(approval.toolCallKind);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool name + time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  approval.toolCallKind,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  approval.toolCallTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _timeAgo(approval.receivedAt),
                style: const TextStyle(fontSize: 11, color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons
          Row(
            children: approval.options.map((opt) {
              final isAllow = opt.optionId != 'deny';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () => _resolve(ref, opt.optionId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAllow
                          ? PocketClawTheme.electricTeal.withOpacity(0.15)
                          : PocketClawTheme.lobsterRed.withOpacity(0.15),
                      foregroundColor: isAllow
                          ? PocketClawTheme.electricTeal
                          : PocketClawTheme.lobsterRed,
                      side: BorderSide(
                        color: isAllow
                            ? PocketClawTheme.electricTeal.withOpacity(0.4)
                            : PocketClawTheme.lobsterRed.withOpacity(0.4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      elevation: 0,
                    ),
                    child: Text(opt.name, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _resolve(WidgetRef ref, String optionId) {
    // If there's an active ACP client, respond through it
    final acpClient = ref.read(activeAcpClientProvider);
    if (acpClient != null && approval.source == ApprovalSource.acp) {
      acpClient.approvePermission(
        int.tryParse(approval.id) ?? 0,
        optionId,
      );
    }
    // Remove from the pending list regardless
    ref.read(approvalsProvider.notifier).resolve(approval.id);
  }
}
```

**Add `ApprovalsPanel` to `DashboardScreen` and `HermesManagementScreen`:**

```dart
// In DashboardScreen body ListView, at the very top:
const ApprovalsPanel(),

// In HermesManagementScreen, add above the TabBar in the Scaffold body
// (or as a persistent widget below the AppBar):
// Note: Scaffold doesn't support widgets between AppBar and body easily.
// Best approach: wrap the TabBarView in a Column with ApprovalsPanel at top.
```

### Files Changed

| File | Change |
|---|---|
| `lib/data/providers/approvals_providers.dart` | **New** |
| `lib/shared/widgets/approvals_panel.dart` | **New** |
| `lib/data/providers/chat_providers.dart` | Feed ACP approvals into `approvalsProvider` |
| `lib/app/router.dart` | Badge on Control tab |
| `lib/features/mission_control/dashboard_screen.dart` | Add `ApprovalsPanel` at top |
| `lib/features/hermes/hermes_management_screen.dart` | Add `ApprovalsPanel` |
| `pubspec.yaml` | Add `flutter_badges` |

### Test

1. Trigger a Hermes ACP session that requests a permission (e.g. a terminal command)
2. Permission request arrives → badge appears on Control tab icon
3. Navigate to Control → `ApprovalsPanel` appears at top with the pending item
4. Tap "Allow" → badge clears, approval resolved
5. Tap "Deny" → same result, agent receives deny response
6. "Dismiss all" removes all items without resolving (agent eventually times out)
7. Verify badge count increments correctly for multiple simultaneous approvals

---

## Item 3 — Session Auto-Title

### The Problem

Both `HermesSessionsTab` and `SessionsScreen` (OpenClaw) show session IDs or empty titles in the history list. Auto-titles make the list navigable.

**Hermes:** `state.db` `sessions.title` is already populated by Hermes itself when SSH is configured. No new work needed — `HermesSession.displayTitle` already returns `title ?? id`.

**OpenClaw:** `OpenClawSession.title` is empty. Titles need to be generated client-side from the first exchange.

### Step 1 — Session Title Store

```dart
// lib/core/session/session_title_store.dart
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists auto-generated titles keyed by session ID.
/// Used for OpenClaw sessions where the gateway doesn't provide titles.
class SessionTitleStore {
  static const _prefKey = 'session_titles_v1';

  final SharedPreferences _prefs;
  SessionTitleStore(this._prefs);

  /// Get the stored title for a session ID.
  String? getTitle(String sessionId) {
    final raw = _prefs.getString(_prefKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map[sessionId] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Save a generated title for a session ID.
  Future<void> setTitle(String sessionId, String title) async {
    final raw = _prefs.getString(_prefKey);
    final map = <String, dynamic>{};
    if (raw != null) {
      try {
        map.addAll(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    map[sessionId] = title;
    // Keep at most 200 entries — drop oldest if needed
    if (map.length > 200) {
      final keys = map.keys.toList();
      for (final k in keys.take(map.length - 200)) {
        map.remove(k);
      }
    }
    await _prefs.setString(_prefKey, jsonEncode(map));
  }
}
```

### Step 2 — Auto-Title Generation

Generate a title from the first user message after each chat turn completes. Keep it simple — use the first 6 words of the user message, or a summarised form.

```dart
// lib/core/session/session_title_generator.dart
library;

/// Generates a concise session title from the first user message.
///
/// Strategy:
///   1. Take the first line of the user message
///   2. Truncate to 40 chars, break on word boundary
///   3. Strip leading slash commands (e.g. "/btw ")
///
/// No AI call needed — user's own words are already the best title.
/// If an AI-generated title is desired in a future sprint, this is
/// the class to upgrade.
class SessionTitleGenerator {
  static String generate(String firstUserMessage) {
    var text = firstUserMessage.trim();

    // Strip slash commands
    if (text.startsWith('/')) {
      final spaceIdx = text.indexOf(' ');
      if (spaceIdx > 0) text = text.substring(spaceIdx + 1).trim();
    }

    // First line only
    final firstLine = text.split('\n').first.trim();
    if (firstLine.isEmpty) return 'Chat session';

    // Truncate to 40 chars on word boundary
    if (firstLine.length <= 40) return firstLine;
    final truncated = firstLine.substring(0, 40);
    final lastSpace = truncated.lastIndexOf(' ');
    return lastSpace > 20
        ? '${truncated.substring(0, lastSpace)}…'
        : '${truncated}…';
  }
}
```

### Step 3 — Auto-Title Provider

```dart
// Add to lib/data/providers/core_providers.dart (or new session_providers.dart)

final sessionTitleStoreProvider = Provider<SessionTitleStore>((ref) {
  return SessionTitleStore(ref.watch(sharedPrefsProvider));
});

// Provider that returns a title for a given session ID,
// using the store for OpenClaw sessions.
final sessionTitleProvider = Provider.family<String, String>((ref, sessionId) {
  final store = ref.watch(sessionTitleStoreProvider);
  return store.getTitle(sessionId) ?? sessionId;
});
```

### Step 4 — Save Title After First Chat Turn

In `lib/data/providers/chat_providers.dart`, after the first assistant response completes, save a title if this is a new session:

```dart
// In the sendMessage flow, after the first successful response:

Future<void> _maybeSaveSessionTitle(WidgetRef ref) async {
  final messages = ref.read(messagesProvider);
  final store = ref.read(sessionTitleStoreProvider);
  final sessionKey = ref.read(currentSessionKeyProvider);

  if (sessionKey == null) return;
  if (store.getTitle(sessionKey) != null) return; // already titled

  // Find first user message
  final firstUser = messages
      .where((m) => m.role == MessageRole.user)
      .firstOrNull;
  if (firstUser == null) return;

  final title = SessionTitleGenerator.generate(firstUser.content);
  await store.setTitle(sessionKey, title);
}
```

Call `_maybeSaveSessionTitle(ref)` at the end of every successful `_send*` function (after `isStreaming: false` is set).

### Step 5 — Apply Titles in Sessions Screens

**OpenClaw `SessionsScreen`** — use `sessionTitleProvider` for display:

```dart
// In the session list item builder:
final title = ref.watch(sessionTitleProvider(session.id));

// Display title instead of session.id:
Text(
  title != session.id ? title : 'Session ${session.id.substring(0, 8)}',
  style: const TextStyle(fontWeight: FontWeight.w500),
),
```

**Hermes `HermesSessionsTab`** — already uses `session.displayTitle` which falls back to `id`. No change needed for Hermes sessions titled by the server. For untitled Hermes sessions (edge case), `sessionTitleProvider` can be used the same way.

### Files Changed

| File | Change |
|---|---|
| `lib/core/session/session_title_store.dart` | **New** |
| `lib/core/session/session_title_generator.dart` | **New** |
| `lib/data/providers/core_providers.dart` | Add `sessionTitleStoreProvider` + `sessionTitleProvider` |
| `lib/data/providers/chat_providers.dart` | Call `_maybeSaveSessionTitle` after each turn |
| `lib/features/mission_control/sessions_screen.dart` | Use `sessionTitleProvider` for display |

### Test

1. Start a new OpenClaw chat and send "How do I set up XAUUSD alerts?"
2. Complete the exchange
3. Navigate to Control → Sessions
4. Session now shows "How do I set up XAUUSD alerts?" instead of a raw ID
5. Second session with a longer opening message: verify truncation to 40 chars
6. Session started with `/btw what time is it?`: verify the `/btw` prefix is stripped

---

## Implementation Order

| Step | Task | File | Time |
|---|---|---|---|
| 1 | Create `capability_providers.dart` | new | 30 min |
| 2 | Create `feature_not_available_card.dart` | new | 45 min |
| 3 | Wire gates onto Hermes management tabs | `hermes_management_screen.dart` | 20 min |
| 4 | Test capability gates (Hermes no SSH) | — | 20 min |
| 5 | Create `approvals_providers.dart` | new | 45 min |
| 6 | Feed ACP approvals into notifier | `chat_providers.dart` | 15 min |
| 7 | Add `flutter_badges` to pubspec | `pubspec.yaml` | 5 min |
| 8 | Add badge to Control tab | `router.dart` | 20 min |
| 9 | Create `approvals_panel.dart` | new | 1.5 hours |
| 10 | Add panel to Dashboard + Hermes screens | both files | 20 min |
| 11 | Test approval flow end-to-end | — | 30 min |
| 12 | Create `session_title_store.dart` | new | 30 min |
| 13 | Create `session_title_generator.dart` | new | 15 min |
| 14 | Add providers + wire into chat flow | `core_providers.dart`, `chat_providers.dart` | 30 min |
| 15 | Apply titles in sessions screen | `sessions_screen.dart` | 20 min |
| 16 | Test titles end-to-end | — | 20 min |

**Total: ~2 days**

---

## New Files Summary

```
lib/data/providers/
└── capability_providers.dart          ← Item 1
    approvals_providers.dart           ← Item 2

lib/shared/widgets/
├── feature_not_available_card.dart    ← Item 1
└── approvals_panel.dart               ← Item 2

lib/core/session/
├── session_title_store.dart           ← Item 3
└── session_title_generator.dart       ← Item 3
```

---

*CARMEN PTY LTD — ClawCommander Sprint B: Capability Gate + Approvals Spec v1.0*  
*Verified against PocketClaw-source-2026-05-09 and hermes-workspace-main*  
*2026-05-09*
