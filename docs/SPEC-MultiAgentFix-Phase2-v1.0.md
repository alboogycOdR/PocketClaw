# ClawCommander — Multi-Agent Fix Phase 2
## Developer Specification v1.0

**Date:** 2026-05-09  
**Author:** CARMEN PTY LTD  
**Depends on:** ADR-001, SPEC-MultiAgentFix-Phase1-v1.0.md (must be complete first)  
**Status:** Implement after Phase 1 is shipped and tested  
**Estimated effort:** 1 week  

---

## Overview

Phase 2 promotes agents from a "chat mode" to a first-class **active server** concept. When the user's active server is OpenClaw, the Management tab shows OpenClaw surfaces. When it's Hermes, it shows Hermes surfaces. The entire app re-scopes, not just chat.

`chatModeProvider` is preserved for chat path selection but becomes **derived from** `activeServerProvider` rather than being the independent top-level concept. This permanently eliminates the mode tag bug class.

---

## 1. New Provider — `activeServerProvider`

```dart
// lib/data/providers/server_providers.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core_providers.dart';
import 'hermes_providers.dart';

/// The three server types ClawCommander can connect to.
enum ActiveServer { openclaw, hermes, local }

/// The currently active server. Determines which management surfaces
/// are shown in the Management tab and which agent the chat defaults to.
///
/// Persisted in SharedPreferences. Defaults to whichever server
/// is configured — OpenClaw takes priority if both are configured.
final activeServerProvider = StateProvider<ActiveServer>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);

  // Respect explicit user choice
  final stored = prefs.getString('active_server');
  if (stored != null) {
    try {
      return ActiveServer.values.byName(stored);
    } catch (_) {}
  }

  // Auto-detect based on what is configured
  return _detectActiveServer(ref);
});

ActiveServer _detectActiveServer(Ref ref) {
  // OpenClaw configured?
  final gatewayUrl = ref.read(gatewayUrlProvider);
  if (gatewayUrl.isNotEmpty) return ActiveServer.openclaw;

  // Hermes configured?
  final hermesUrl = ref.read(hermesBaseUrlProvider);
  if (hermesUrl.isNotEmpty) return ActiveServer.hermes;

  // Fall back to local
  return ActiveServer.local;
}

/// Persist the user's active server choice.
Future<void> setActiveServer(WidgetRef ref, ActiveServer server) async {
  await ref.read(sharedPrefsProvider).setString('active_server', server.name);
  ref.read(activeServerProvider.notifier).state = server;
}
```

---

## 2. Derive `chatModeProvider` from `activeServerProvider`

**File:** `lib/data/providers/chat_mode_providers.dart`

The existing `chatModeProvider` stays, but its default value is now derived from `activeServerProvider` rather than auto-detecting independently. This ensures chat mode and active server are always consistent:

```dart
final chatModeProvider = StateProvider<ChatMode>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);

  // User has explicitly selected a chat mode — respect it
  final stored = prefs.getString('chat_mode');
  if (stored != null) {
    try {
      return ChatMode.values.byName(stored);
    } catch (_) {}
  }

  // Derive from active server — keeps chat and management in sync
  final server = ref.watch(activeServerProvider);
  return switch (server) {
    ActiveServer.openclaw => ChatMode.openclaw,
    ActiveServer.hermes   => ChatMode.hermes,
    ActiveServer.local    => ChatMode.local,
  };
});
```

When the user explicitly picks a different chat mode (e.g. switches from OpenClaw to Hermes in the chat mode selector), that selection is persisted to `chat_mode` in SharedPreferences. But the **active server** also updates:

```dart
// In chat mode selector — add after existing setMode logic:
Future<void> _onModeTap(ChatMode newMode) async {
  // 1. Flush current session FIRST (fixes §3.2 bug from Phase 1)
  await ref.read(sessionManagerProvider).flushCurrentSession();

  // 2. Update chat mode
  await ref.read(sharedPrefsProvider).setString('chat_mode', newMode.name);
  ref.read(chatModeProvider.notifier).state = newMode;

  // 3. Sync active server to match (NEW in Phase 2)
  final correspondingServer = switch (newMode) {
    ChatMode.openclaw => ActiveServer.openclaw,
    ChatMode.hermes   => ActiveServer.hermes,
    ChatMode.local    => ActiveServer.local,
    ChatMode.cloud    => ActiveServer.local, // cloud is a local variant
  };
  await setActiveServer(ref, correspondingServer);
}
```

---

## 3. Server Switcher in AppBar

Add a server switcher chip to the main app shell's AppBar. Tapping it opens a bottom sheet to switch the active server without going to Settings.

```dart
// lib/app/server_switcher.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../data/providers/server_providers.dart';
import '../data/providers/hermes_providers.dart';
import '../data/providers/core_providers.dart';

class ServerSwitcherChip extends ConsumerWidget {
  const ServerSwitcherChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);

    return GestureDetector(
      onTap: () => _showServerPicker(context, ref),
      child: Chip(
        avatar: Icon(_icon(server), size: 12, color: _color(server)),
        label: Text(
          _label(server),
          style: TextStyle(fontSize: 10, color: _color(server)),
        ),
        backgroundColor: _color(server).withOpacity(0.12),
        side: BorderSide(color: _color(server).withOpacity(0.4)),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  IconData _icon(ActiveServer s) => switch (s) {
    ActiveServer.openclaw => Icons.rss_feed,
    ActiveServer.hermes   => Icons.psychology_outlined,
    ActiveServer.local    => Icons.phone_android,
  };

  Color _color(ActiveServer s) => switch (s) {
    ActiveServer.openclaw => const Color(0xFFE53935),
    ActiveServer.hermes   => const Color(0xFF7C3AED),
    ActiveServer.local    => const Color(0xFF00E5CC),
  };

  String _label(ActiveServer s) => switch (s) {
    ActiveServer.openclaw => 'OpenClaw',
    ActiveServer.hermes   => 'Hermes',
    ActiveServer.local    => 'Local',
  };

  void _showServerPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ServerPickerSheet(ref: ref),
    );
  }
}

class _ServerPickerSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _ServerPickerSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(activeServerProvider);
    final gatewayUrl   = ref.watch(gatewayUrlProvider);
    final hermesUrl    = ref.watch(hermesBaseUrlProvider);

    final servers = [
      if (gatewayUrl.isNotEmpty)
        (server: ActiveServer.openclaw, label: 'OpenClaw',
         subtitle: 'Gateway · WebSocket'),
      if (hermesUrl.isNotEmpty)
        (server: ActiveServer.hermes, label: 'Hermes Agent',
         subtitle: 'REST + SSH management'),
      (server: ActiveServer.local, label: 'Local Model',
       subtitle: 'On-device GGUF inference'),
    ];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Active Server',
                style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.w600)),
          ),
          ...servers.map((entry) => ListTile(
            leading: Radio<ActiveServer>(
              value: entry.server,
              groupValue: current,
              onChanged: (s) async {
                if (s == null) return;
                Navigator.pop(context);
                await setActiveServer(ref, s);
              },
            ),
            title: Text(entry.label),
            subtitle: Text(entry.subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
            onTap: () async {
              Navigator.pop(context);
              await setActiveServer(ref, entry.server);
            },
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

**Add to the main app shell's AppBar:**

```dart
// In lib/app/router.dart — _AppShell build method
// Add to the shell AppBar actions (or the persistent top bar):

AppBar(
  // ... existing title ...
  actions: [
    const ServerSwitcherChip(),
    const SizedBox(width: 8),
    // ... existing actions ...
  ],
)
```

---

## 4. Mode-Aware Management Tab

The Management tab (Mission Control) becomes a router that renders the correct surfaces based on `activeServerProvider`.

**File:** `lib/features/mission_control/dashboard_screen.dart`

Replace the current fixed OpenClaw dashboard with a server-aware container:

```dart
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);

    return switch (server) {
      ActiveServer.openclaw => const OpenClawDashboard(),
      ActiveServer.hermes   => const HermesDashboardProxy(),
      ActiveServer.local    => const LocalModelDashboard(),
    };
  }
}
```

**`OpenClawDashboard`** — the existing Mission Control tabs. No changes needed.

**`HermesDashboardProxy`** — a thin wrapper that renders `HermesManagementScreen` inline instead of as a modal route. The user no longer navigates to `/hermes`; Hermes management appears directly in the Management tab when Hermes is active:

```dart
class HermesDashboardProxy extends StatelessWidget {
  const HermesDashboardProxy({super.key});

  @override
  Widget build(BuildContext context) {
    // HermesManagementScreen is already a 5-tab screen.
    // Remove its outer Scaffold (it's inside the main shell now).
    return const HermesManagementScreen(embeddedMode: true);
  }
}
```

Add `embeddedMode` parameter to `HermesManagementScreen` — when true, suppress the top AppBar (the main shell provides it) and the back button.

**`LocalModelDashboard`** — a simple screen showing the active model, download status, and inference stats. Can be a minimal new screen.

---

## 5. Update `AgentScopeBadge` to be Dynamic

The static `AgentScopeBadge.openclaw()` constructors from Phase 1 are replaced with a dynamic provider-aware version:

```dart
// Add to lib/shared/widgets/agent_scope_badge.dart

class AgentScopeBadge extends ConsumerWidget {
  const AgentScopeBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    return _badge(server);
  }

  Widget _badge(ActiveServer s) {
    final (icon, color, label) = switch (s) {
      ActiveServer.openclaw => (Icons.rss_feed, const Color(0xFFE53935), 'OpenClaw'),
      ActiveServer.hermes   => (Icons.psychology_outlined, const Color(0xFF7C3AED), 'Hermes'),
      ActiveServer.local    => (Icons.phone_android, const Color(0xFF00E5CC), 'Local'),
    };
    return Chip(
      avatar: Icon(icon, size: 12, color: color),
      label: Text(label, style: TextStyle(fontSize: 10, color: color)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
```

The static constructors from Phase 1 can be kept for backward compat or removed — the dynamic version replaces their role in AppBars.

---

## 6. Update Memory and Skills Tabs

When `activeServerProvider == ActiveServer.hermes`, Memory and Skills should show Hermes data, not OpenClaw data.

**Memory tab:**

```dart
// lib/features/memory/memory_screen.dart

class MemoryScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    return switch (server) {
      ActiveServer.hermes   => const HermesMemoryTab(),   // already built
      ActiveServer.openclaw => const OpenClawMemoryScreen(), // existing screen
      ActiveServer.local    => const LocalMemoryScreen(),  // new: simple notes
    };
  }
}
```

**Skills tab:**

```dart
// lib/features/skills/skills_screen.dart

class SkillsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    return switch (server) {
      ActiveServer.hermes   => const HermesSkillsTab(),   // already built
      ActiveServer.openclaw => const OpenClawSkillsScreen(), // existing screen
      ActiveServer.local    => const LocalSkillsScreen(),  // existing bundled skills
    };
  }
}
```

---

## 7. Remove the `/hermes` Standalone Route

Once Phase 2 is complete, the `/hermes` route is no longer needed — Hermes management appears directly in the tab shell. Remove the route from `router.dart` to avoid confusion.

Keep the route during the Phase 2 transition period (while testing) and remove it only when the embedded mode is confirmed working.

---

## 8. New Files

```
lib/data/providers/server_providers.dart     ← activeServerProvider + setActiveServer
lib/app/server_switcher.dart                ← ServerSwitcherChip + _ServerPickerSheet
lib/features/mission_control/
  local_model_dashboard.dart               ← LocalModelDashboard (minimal)
lib/features/hermes/
  hermes_dashboard_proxy.dart              ← HermesDashboardProxy wrapper
```

## 9. Changed Files

| File | Change |
|---|---|
| `lib/data/providers/chat_mode_providers.dart` | Derive from `activeServerProvider` |
| `lib/features/chat/chat_mode_selector.dart` | Sync `activeServerProvider` on mode switch |
| `lib/features/mission_control/dashboard_screen.dart` | Server-aware router |
| `lib/features/memory/memory_screen.dart` | Server-aware router |
| `lib/features/skills/skills_screen.dart` | Server-aware router |
| `lib/shared/widgets/agent_scope_badge.dart` | Dynamic provider-aware version |
| `lib/features/hermes/hermes_management_screen.dart` | Add `embeddedMode` param |
| `lib/app/router.dart` | Add `ServerSwitcherChip` to shell AppBar; eventually remove `/hermes` |

---

## 10. Implementation Order

1. Create `server_providers.dart` — `activeServerProvider` + `setActiveServer`
2. Update `chat_mode_providers.dart` — derive from `activeServerProvider`
3. Update `chat_mode_selector.dart` — sync server on mode switch
4. Create `server_switcher.dart` — chip + picker sheet
5. Add `ServerSwitcherChip` to app shell AppBar
6. Update `AgentScopeBadge` to dynamic
7. Add `embeddedMode` param to `HermesManagementScreen`
8. Update `DashboardScreen` to server-aware router
9. Update `MemoryScreen` to server-aware router
10. Update `SkillsScreen` to server-aware router
11. Test full switch cycle: OpenClaw → Hermes → Local on physical device
12. Remove standalone `/hermes` route (only after step 11 passes)

---

*CARMEN PTY LTD — Multi-Agent Fix Phase 2 Spec v1.0 — 2026-05-09*
