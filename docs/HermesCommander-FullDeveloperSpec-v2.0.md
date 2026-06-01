# HermesCommander — Full Developer Specification v2.0

**Date:** 2026-05-31  
**Previous version:** v1.0 (uploaded by architect)  
**Changes in v2.0:** Colour palette resolved (gold), typography resolved (Geist), design spec integrated, Osiris spec referenced, AgentMemory/Open-Notebook filled from research, message layout decision added, minor corrections applied  
**Source baseline:** `AI_PocketClaw_source_no_secrets_20260531.zip`  
**Target product:** HermesCommander  
**Target platform:** Android only  
**Android package ID:** `com.nuburo.hermescommander`  
**Display name:** `HermesCommander`  
**Repository strategy:** branch from ClawCommander now; separate repo later  
**MVP goal:** feature-complete developer plan, implemented in phases  
**Visual target:** Hermes WebUI translated into native Flutter mobile — not a pixel clone, but recognisably the same product family  

---

## Companion Documents

This spec is the product and architecture authority. Read it alongside:

| Document | Role |
|---|---|
| `SPEC-HermesCommanderDesign-v1.0.md` | Complete visual design system — HCTheme, Geist fonts, all component code |
| `SPEC-OsirisIntegration-v1.0.md` | Intel tab — full Dart implementation of OsirisClient, intelligence models, WorldIntelligenceScreen, ReconPanel |

Do not implement Intel without `SPEC-OsirisIntegration-v1.0.md`. Do not implement visual components without `SPEC-HermesCommanderDesign-v1.0.md`.

---

## 0. Executive Summary

HermesCommander is a Hermes-only native mobile command centre branched from the current ClawCommander source.

ClawCommander remains the broad multi-agent platform. HermesCommander becomes the focused daily-driver app for operators who run Hermes Agent on their own VPS and want the best possible native Android interface for chat, sessions, memory, cron, skills, logs, analytics, swarm missions, intelligence lookups, and ambient work mode.

The current source snapshot already contains much of the required implementation:

- Hermes REST client
- Hermes ACP client over SSH
- Hermes SSH data service
- sessions, memory, cron, skills, logs, analytics screens
- approvals provider and panel
- capability gates
- Swarm and Office View
- Ambient tab with Focus Sounds and Radio Garden
- Supertonic TTS implementation
- voice input settings and STT path
- Sprint A/B/C chat polish widgets, including TUI Activity Card and Thinking Indicator

The work is therefore not a ground-up rebuild. It is a product split, cleanup, and completion sprint.

---

## 1. Non-Negotiable Product Scope

### 1.1 In Scope

| Feature | Surface |
|---|---|
| Hermes chat over REST and ACP | Chat |
| ACP streaming, tool timeline, thinking panel, cancellation, approvals | Chat |
| Hermes WebUI-style mobile chat layout (full-width messages, no bubbles) | Chat |
| Session drawer with search and date grouping | Chat |
| Context ring and token/cost visibility | Chat |
| Mermaid/code/math markdown fallback rendering | Chat |
| Edit, resend, regenerate, copy, read aloud | Chat |
| Hermes sessions | Control |
| Hermes memory: MEMORY.md, USER.md, SOUL.md, section-sign entry editor | Control |
| Hermes cron jobs | Control |
| Hermes skills | Control |
| Hermes logs | Control |
| Hermes analytics: 7-day tokens, cost ledger, insights | Control |
| Approvals bell and approvals panel | Control + Chat |
| Capability gates | Control |
| AgentMemory integration (see §13.11) | Control |
| Open-Notebook integration (see §13.12) | Control |
| Swarm compose | Swarm |
| Swarm mission tree | Swarm |
| Office View | Swarm |
| Osiris World Intelligence | Intel |
| RECON toolkit: DNS, WHOIS, SSL, IP intel, CVE lookup | Intel |
| Focus Sound Player | Ambient |
| World Radio / Radio Garden globe | Ambient |
| Persistent ambient mini-player | Ambient |
| Voice input | Throughout |
| Supertonic TTS | Throughout |
| Hermes-only settings | Settings |

### 1.2 Out of Scope

These must not appear in HermesCommander UI:

| Feature | Keep In |
|---|---|
| OpenClaw gateway, Mission Control, agents, channels, devices | ClawCommander only |
| OpenClaw WebSocket chat path | ClawCommander only |
| OpenClaw REST / gateway diagnostics | ClawCommander only |
| Local GGUF models | ClawCommander only |
| fllama / llamadart local inference | ClawCommander only |
| HuggingFace local model downloads | ClawCommander only |
| On-device RAG / knowledge base | ClawCommander only |
| Academy Mode | ClawCommander only |
| Life Architect / GROW | ClawCommander only |
| Paperclip Company OS | ClawCommander only |
| ClawHub | ClawCommander only |
| LAN discovery | ClawCommander only |

---

## 2. Source Baseline Audit

### 2.1 Existing Code That Should Be Reused

| Area | Current files |
|---|---|
| Router shell | `lib/app/router.dart` |
| Hermes REST | `lib/core/hermes/hermes_client.dart`, `lib/data/providers/hermes_providers.dart` |
| Hermes SSE parser | `lib/core/hermes/hermes_sse_parser.dart` |
| Hermes ACP | `lib/core/hermes/acp/*` |
| Hermes SSH | `lib/core/ssh/hermes_ssh_client.dart`, `lib/data/providers/ssh_providers.dart` |
| Hermes data service | `lib/core/hermes/hermes_data_service.dart`, `lib/data/providers/hermes_data_providers.dart` |
| Hermes management UI | `lib/features/hermes/*` |
| Swarm / Office | `lib/features/swarm/*`, `lib/core/hermes/models/swarm_tree.dart` |
| Approvals | `lib/data/providers/approvals_providers.dart`, `lib/shared/widgets/approvals_panel.dart` |
| Capability gates | `lib/data/providers/capability_providers.dart`, `lib/shared/widgets/feature_not_available_card.dart` |
| Chat polish | `lib/shared/widgets/tui_activity_card.dart`, `thinking_indicator.dart`, `message_actions_bar.dart` |
| Ambient | `lib/core/ambient/*`, `lib/features/ambient/*`, `assets/scenes.json` |
| Radio Garden | `lib/core/ambient/radio_garden_service.dart` |
| Supertonic TTS | `lib/core/tts/*`, `lib/features/settings/tts_settings_screen.dart`, `lib/data/providers/tts_providers.dart` |
| Voice input | `lib/features/chat/voice_input_widget.dart`, `lib/features/settings/voice_settings_screen.dart` |

### 2.2 Missing or Placeholder-Only Areas

| Area | Current state | Action |
|---|---|---|
| Osiris runtime code | Not in `lib/`. Spec and full implementation code exists in `SPEC-OsirisIntegration-v1.0.md` | Build from spec — all Dart code is provided |
| AgentMemory | Placeholder only. Full integration details now in §13.11 | Implement from §13.11 |
| Open-Notebook | Placeholder only. Full integration details now in §13.12 | Implement from §13.12 |
| Hermes WebUI visual assets | Not in ZIP. Implement from `SPEC-HermesCommanderDesign-v1.0.md` | Build from design spec |
| HermesCommander icon/splash | Not in ZIP | Create placeholder assets; replace before release |

### 2.3 Startup Issue To Fix

`lib/main.dart` currently preloads the local model catalogue through `ModelAllowlistService`. HermesCommander must not initialise or preload local model infrastructure at startup.

Required change:

```dart
if (!kAppFlavor.isHermesOnly) {
  final allowlistService = ModelAllowlistService();
  final catalogue = await allowlistService.loadModels();
  allowlistService.refreshFromRemote();
  overrides.add(modelCatalogueProvider.overrideWithValue(catalogue));
}
```

---

## 3. Branch and Repository Strategy

### 3.1 Branch First

```bash
git checkout hermes-commander
```

This branch becomes the HermesCommander product line. ClawCommander main remains the full platform.

### 3.2 Separate Repo Later

When the Android APK builds and the first release candidate exists, create a separate repo if desired. Until then, branch-based development is safer because code reuse is still heavy.

---

## 4. Android Product Identity

### 4.1 Required App Identity

| Item | Value |
|---|---|
| Android package ID | `com.nuburo.hermescommander` |
| Android namespace | `com.nuburo.hermescommander` |
| Display name | `HermesCommander` |
| Organisation | Nuburo.DIGITAL (PTY) LTD |
| Version start | Inherit current version, then increment after first successful APK |
| Minimum SDK | Keep current `minSdk >= 24` |
| Target platform | Android arm64 first |

### 4.2 Gradle Changes

```kotlin
android {
    namespace = "com.nuburo.hermescommander"

    defaultConfig {
        applicationId = "com.nuburo.hermescommander"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }
}
```

Verify the existing file is `build.gradle.kts` (Kotlin DSL) before applying. If it is `build.gradle` (Groovy), the syntax differs slightly.

### 4.3 Manifest Changes

```xml
android:label="@string/app_name"
```

Add or update `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="app_name">HermesCommander</string>
</resources>
```

### 4.4 Kotlin Package Directory

```text
android/app/src/main/kotlin/com/nuburo/hermescommander/MainActivity.kt
```

```kotlin
package com.nuburo.hermescommander
```

### 4.5 Launcher Icons

```text
assets/icon/hermescommander_icon.png
assets/icon/hermescommander_icon_foreground.png
```

Update `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/hermescommander_icon.png"
  adaptive_icon_background: "#080A12"
  adaptive_icon_foreground: "assets/icon/hermescommander_icon_foreground.png"
```

```bash
flutter pub run flutter_launcher_icons
```

---

## 5. App Flavor and Compile-Time Gating

```text
lib/app/app_flavor.dart
```

```dart
library;

enum AppFlavor { clawCommander, hermesCommander }

const _rawFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'hermesCommander',
);

const AppFlavor kAppFlavor = _rawFlavor == 'clawCommander'
    ? AppFlavor.clawCommander
    : AppFlavor.hermesCommander;

extension AppFlavorConfig on AppFlavor {
  bool get isHermesOnly => this == AppFlavor.hermesCommander;

  String get appName => switch (this) {
        AppFlavor.clawCommander => 'ClawCommander',
        AppFlavor.hermesCommander => 'HermesCommander',
      };

  String get packageId => switch (this) {
        AppFlavor.clawCommander => 'com.carmen.clawcommander',
        AppFlavor.hermesCommander => 'com.nuburo.hermescommander',
      };
}
```

Final branch build command:

```bash
flutter build apk --release --dart-define=APP_FLAVOR=hermesCommander
```

---

## 6. App Constants

```dart
import '../app/app_flavor.dart';

class AppConstants {
  AppConstants._();

  static String get appName => kAppFlavor.appName;
  static const String appVersion = '2.8.5';
  static const String orgName = 'Nuburo.DIGITAL (PTY) LTD';
  static const String defaultSessionKey = 'hermes-commander-main';
}
```

---

## 7. Main Startup Changes

```dart
final overrides = <Override>[
  if (prefs != null) sharedPrefsProvider.overrideWithValue(prefs),
];

if (!kAppFlavor.isHermesOnly) {
  final allowlistService = ModelAllowlistService();
  final catalogue = await allowlistService.loadModels();
  allowlistService.refreshFromRemote();
  overrides.add(modelCatalogueProvider.overrideWithValue(catalogue));
}
```

---

## 8. Router Specification

### 8.1 Top-Level Routes

```text
/                     -> ChatScreen
/control              -> HermesControlScreen
/control/sessions     -> HermesSessionsTab
/control/memory       -> HermesMemoryScreen
/control/cron         -> HermesCronTab
/control/skills       -> HermesSkillsTab
/control/logs         -> HermesLogsTab
/control/analytics    -> HermesAnalyticsTab
/control/approvals    -> ApprovalsPanel screen
/control/agent-memory -> AgentMemoryScreen (§13.11)
/control/notebook     -> OpenNotebookScreen (§13.12)
/swarm                -> SwarmMonitorScreen
/swarm/compose        -> SwarmComposeScreen
/office               -> OfficeViewScreen
/intel                -> IntelScreen
/intel/recon          -> ReconPanel bottom sheet
/ambient              -> AmbientScreen
/settings             -> HermesCommanderSettingsScreen
/settings/hermes      -> HermesSettings
/settings/ssh         -> SshSettings
/settings/osiris      -> OsirisSettings
/settings/voice       -> VoiceSettingsScreen
/settings/tts         -> TtsSettingsScreen
/settings/security    -> SecuritySettings
/settings/backup      -> BackupRestoreSettings
```

### 8.2 Remove From HermesCommander Routes

Do not expose:

```text
/settings/academy
/settings/life-architect
/knowledge-base
/packs
/control/agents
/control/channels (OpenClaw-specific only)
/company
/onboarding local model flows
```

### 8.3 App Shell — Bottom Nav

Exactly five tabs:

```dart
NavigationDestination(
  icon: const Icon(Icons.chat_outlined),
  selectedIcon: const Icon(Icons.chat),
  label: 'Chat',
),
NavigationDestination(
  icon: NavIconWithBadge(icon: Icons.tune_outlined, count: approvalCount),
  selectedIcon: NavIconWithBadge(icon: Icons.tune, count: approvalCount),
  label: 'Control',
),
const NavigationDestination(
  icon: Icon(Icons.account_tree_outlined),
  selectedIcon: Icon(Icons.account_tree),
  label: 'Swarm',
),
const NavigationDestination(
  icon: Icon(Icons.public_outlined),
  selectedIcon: Icon(Icons.public),
  label: 'Intel',
),
const NavigationDestination(
  icon: Icon(Icons.headphones_outlined),
  selectedIcon: Icon(Icons.headphones),
  label: 'Ambient',
),
```

Active icon colour: `HCTheme.gold` — see §11.

### 8.4 Mini Player

Keep `AmbientMiniPlayer` above the bottom nav, globally across all five tabs.

---

## 9. Server and Chat Mode Simplification

### 9.1 Active Server

```dart
final activeServerProvider = StateProvider<ActiveServer>((ref) {
  if (kAppFlavor.isHermesOnly) return ActiveServer.hermes;
  // existing ClawCommander detection only if retained
});

Future<void> setActiveServer(WidgetRef ref, ActiveServer server) async {
  if (kAppFlavor.isHermesOnly) {
    ref.read(activeServerProvider.notifier).state = ActiveServer.hermes;
    await ref.read(sharedPrefsProvider).setString('active_server', 'hermes');
    return;
  }
  await ref.read(sharedPrefsProvider).setString('active_server', server.name);
  ref.read(activeServerProvider.notifier).state = server;
}
```

### 9.2 Chat Mode

```dart
final chatModeProvider = StateProvider<ChatMode>((ref) {
  if (kAppFlavor.isHermesOnly) return ChatMode.hermes;
  // existing behavior only if retained
});
```

### 9.3 Chat Mode Selector

In HermesCommander, hide the mode picker. Show a Hermes status chip instead displaying one of:

- `Hermes · ACP`
- `Hermes · REST`
- `Hermes · SSH missing`
- `Hermes · not configured`

---

## 10. Capability Model

Replace broad multi-agent capability logic with Hermes-specific flags:

```dart
class HermesCommanderCapabilities {
  final bool hasRest;
  final bool hasSsh;
  final bool hasAcp;
  final bool hasSessions;
  final bool hasMemory;
  final bool hasCron;
  final bool hasSkills;
  final bool hasLogs;
  final bool hasAnalytics;
  final bool hasApprovals;
  final bool hasSwarm;
  final bool hasOsiris;
  final bool hasAmbient;
  final bool hasSupertonic;
  final bool hasAgentMemory;
  final bool hasOpenNotebook;
}
```

Derivation rules:

| Capability | Rule |
|---|---|
| REST | Hermes base URL and API key configured |
| SSH | SSH host and username configured, client connects |
| ACP | SSH configured and `hermes acp` starts successfully |
| Sessions | SSH configured |
| Memory | SSH configured |
| Cron | SSH configured |
| Skills | SSH configured |
| Logs | SSH configured |
| Analytics | SSH configured and `state.db` readable |
| Swarm | SSH configured and sessions readable |
| Osiris | Osiris base URL configured and health check succeeds |
| AgentMemory | AgentMemory server URL configured and health check succeeds |
| OpenNotebook | Open-Notebook URL configured and `/api/notebooks` responds |
| Ambient | Always true |
| Supertonic | Model files downloaded and active voice available |

---

## 11. Visual Design System

**Read `SPEC-HermesCommanderDesign-v1.0.md` in full before implementing any UI.**

That document contains complete, compilable Dart code for every component listed below. This section provides the authoritative decisions; the design spec provides the code.

### 11.1 Colour Palette — Gold System (Resolved)

HermesCommander uses the **gold/amber palette matching the Hermes WebUI**. The WebUI uses gold as its only accent — the caduceus logo, the active session indicator, the send button, the context ring fill. HermesCommander inherits this identity.

Do NOT use purple (`#8B5CF6`) as the primary accent. Purple was in an earlier draft and is incorrect.

The complete `HCTheme` class is defined in `SPEC-HermesCommanderDesign-v1.0.md`. Key values:

```dart
// Primary accent — gold
static const gold      = Color(0xFFC9A227);
static const goldLight = Color(0xFFD4A017);
static const goldMuted = Color(0xFF8B6914);
static const goldBg    = Color(0xFF1A1509);

// Backgrounds
static const bgBase    = Color(0xFF0D1117);
static const bgPanel   = Color(0xFF161B22);
static const bgSurface = Color(0xFF1C2128);
static const bgActive  = Color(0xFF21262D);

// Text
static const textPrimary   = Color(0xFFE6EDF3);
static const textSecondary = Color(0xFF8B949E);
static const textMuted     = Color(0xFF484F58);
```

### 11.2 Typography — Geist (Resolved)

HermesCommander uses **Geist Sans + Geist Mono** — the same typefaces as the Hermes WebUI.

Download from: https://github.com/vercel/geist-font/releases (OFL licence — free)

Add to `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: GeistSans
      fonts:
        - asset: assets/fonts/Geist-Regular.ttf    # weight: 400
        - asset: assets/fonts/Geist-Medium.ttf     # weight: 500
        - asset: assets/fonts/Geist-SemiBold.ttf   # weight: 600
    - family: GeistMono
      fonts:
        - asset: assets/fonts/GeistMono-Regular.ttf  # weight: 400
        - asset: assets/fonts/GeistMono-Medium.ttf   # weight: 500
```

Usage rules:
- UI body, prose, messages → `GeistSans` 14px, line-height 1.6
- Code blocks, file paths, session IDs, tokens, tool names → `GeistMono` 12px
- Composer input → `GeistSans` 15px
- Section labels (TODAY, PINNED, EARLIER) → `GeistSans` 11px, ALL CAPS, `textMuted`, letter-spacing 0.8
- Composer footer chips → `GeistSans` 11–12px

Do NOT continue using JetBrains Mono as the technical font in HermesCommander. Use GeistMono.

### 11.3 Message Layout — Full-Width, No Bubbles (Resolved)

**HermesCommander does not use chat bubbles.**

Messages are full-width with an avatar column on the left and content filling the remaining width — exactly as in the Hermes WebUI. This is architecturally different from ClawCommander.

Use `HermesMessageRow` from `SPEC-HermesCommanderDesign-v1.0.md`. Do not use `ChatBubble` from ClawCommander in HermesCommander.

Layout structure:
```
[avatar 36px] [12px gap] [content — fills remaining width]
                         [role label + timestamp]
                         [message body — GeistSans 14px]
                         [tool cards if ACP]
                         [thinking indicator if reasoning]
```

### 11.4 Mobile Translation Table

| Hermes WebUI concept | HermesCommander mobile equivalent |
|---|---|
| Left session sidebar | Session drawer (slide from left) |
| Centre chat | Chat tab |
| Right workspace/file panel | Slide-up workspace sheet (Phase 5+) |
| Composer footer controls | Horizontal chip row above keyboard |
| Circular context ring | `ContextRing` widget in composer footer |
| Control Center | Control tab |
| Tool timeline | `TuiActivityCard` |
| Project/session filters | Session drawer date grouping + search |
| Workspace file browser | Control → Open-Notebook screen |

---

## 12. Chat Tab Specification

### 12.1 Transport Priority

1. If SSH client is available, try ACP.
2. If ACP starts and runs, use ACP for the turn.
3. If ACP fails before output, fall back to REST.
4. If REST is unavailable, show Hermes configuration error.
5. If image attachment present and ACP unavailable, show clear warning.

### 12.2 Header

```text
HermesCommander    [context ring] [approval bell] [settings gear]
```

Status chips (below or inline):
- `ACP` / `REST` transport indicator
- Connected / reconnecting / not configured
- Active model name if known

### 12.3 Session Drawer

```text
lib/features/chat/hermes_session_drawer.dart
```

Contents:
- Search field
- TODAY / YESTERDAY / THIS WEEK / EARLIER groupings
- Per session: title, source chip (REST/ACP/CLI/Cron/Swarm), message count, cost
- Pinned sessions with gold star at top
- Tap to load session
- Long-press: rename, export transcript, delete (if safe)

See `SPEC-HermesCommanderDesign-v1.0.md` for the session tile widget code.

### 12.4 Context Ring

```text
lib/shared/widgets/context_ring.dart
```

Full implementation is in `SPEC-HermesCommanderDesign-v1.0.md`.

```dart
class ContextRing extends StatelessWidget {
  final int usedTokens;
  final int maxTokens;
  final double? estimatedCost;
  final String? model;
  final VoidCallback? onTap;
}
```

Colour behaviour:
- Green under 60%
- Amber 60–85%
- Red over 85%

Tap opens a context sheet showing session ID, model, input/output/cache tokens, estimated cost, current transport.

### 12.5 Composer

Full implementation is in `SPEC-HermesCommanderDesign-v1.0.md` as `HermesComposer`.

Layout:
```text
[attach] [voice]  [message input.................] [send/stop]
[Hermes·ACP] [model chip] [profile chip] [workspace chip] [context ring]
```

Rules:
- No Local/OpenClaw mode controls visible.
- Attachment button present.
- Image attachment requires ACP — show warning if ACP unavailable.
- Voice input inserts transcript into composer.
- Send button: gold arrow-up circle when text present, muted when empty.
- Stop button: replaces send while processing.

### 12.6 Tool Activity

Use existing `lib/shared/widgets/tui_activity_card.dart`.

Must display:
- Tool name and kind
- Status (pending/running/complete/failed)
- Elapsed time while running
- Argument preview
- Output preview
- Expandable raw JSON

### 12.7 Thinking Indicator

Use existing `lib/shared/widgets/thinking_indicator.dart`.

Rules:
- Expanded while streaming
- Collapsed after completion
- Never show as normal chat body
- Label as "Thinking" — not "internal thoughts"

### 12.8 Markdown Rendering

Required:
- Standard markdown body
- Fenced code blocks — `GeistMono` 12px, dark background
- Tables
- Checklists
- Links in `HCTheme.textLink` blue
- Blockquotes with left border

**Mermaid v1:** Detect fenced `mermaid` blocks. Render as a styled code card. Show "Diagram — tap to open in browser" action. Preserve source text. Do not attempt native rendering in v1.

**Mermaid v2 (future):** WebView-based diagram rendering.

### 12.9 Message Actions

User message actions:
- Copy
- Edit
- Resend

Assistant message actions:
- Copy
- Regenerate
- Continue
- Read aloud
- Stop speaking

Regenerate behaviour:
1. Select prior user message
2. Optionally edit it
3. Truncate messages after that turn in UI
4. Resend through Hermes
5. Optionally fork session when persistent session branching exists

### 12.10 Approval Flow

ACP permission requests surface in two places:
- Immediate chat dialog/sheet
- Global approvals queue with Control tab badge

Rules:
- Never silently approve
- Deny must be one tap
- Show: tool name, purpose, path/target, raw payload preview
- Resolve back to ACP client
- Badge persists across navigation until resolved

### 12.11 Voice and TTS

Requirements:
- Mic transcript fills composer
- Voice loop can auto-send
- Assistant replies can auto-speak after streaming ends
- Manual speaker icon per assistant message
- Supertonic if loaded; system TTS fallback otherwise
- No blocking TTS during streaming

---

## 13. Control Tab Specification

### 13.1 Control Home

```text
lib/features/hermes/hermes_control_screen.dart
```

Summary cards:
- REST status (online/offline)
- SSH status
- ACP status
- Current model/profile
- Pending approvals count
- Today's tokens + cost
- Recent session count
- Cron health (last failure if any)

### 13.2 Control Sections

```text
Sessions
Memory
Cron
Skills
Logs
Analytics
Approvals
AgentMemory
Open-Notebook
```

### 13.3 Sessions

Use `lib/features/hermes/hermes_sessions_screen.dart`.

Required:
- TODAY / YESTERDAY / THIS WEEK / EARLIER grouping
- Search
- Source chips (REST/ACP/CLI/Cron/Swarm)
- Model, message count, tokens, cost, duration
- Tap for transcript
- Export transcript
- Identify Swarm/conductor sessions

### 13.4 Memory

Use `lib/features/hermes/hermes_memory_screen.dart`.

Files: `MEMORY.md`, `USER.md`, `SOUL.md`.

Rules:
- Do not expose raw `§` delimiter as editable text
- One card per memory entry
- Add / edit / delete entries
- Save by reconstructing delimiter format
- Raw view behind an advanced toggle only

### 13.5 Cron

Use `lib/features/hermes/hermes_cron_screen.dart` and `lib/features/hermes/widgets/schedule_builder.dart`.

Required:
- List jobs
- Enable/disable toggle
- Run now
- Create job via schedule builder
- Delete job
- Delivery target selector
- Last run / next run / failure state

### 13.6 Skills

Use `lib/features/hermes/hermes_skills_screen.dart`.

Rules:
- Hermes skills only — do not show ClawHub
- Skills from `~/.hermes/skills/` via SSH
- File path and last modified if available
- Read SKILL.md content via SSH/SFTP
- Editing is read-only in v1

### 13.7 Logs

Use `lib/features/hermes/hermes_logs_screen.dart`.

Tabs: agent log, errors log, gateway log.

Required:
- Tail latest lines
- Refresh
- Copy line
- Filter by error/warning/info
- Graceful empty state if file missing

### 13.8 Analytics

Use existing analytics screens and widgets.

Required cards:
- 7-day token chart (input/output split)
- Sessions per day
- Cost ledger by model (paid vs local)
- Insights summary
- Cron failure count

### 13.9 Approvals

Show in Control home:
- Pending count
- Newest pending approval preview
- Full queue
- Approve/deny actions
- Stale approval state

### 13.10 AgentMemory (Implemented)

**Source:** MIT-licensed. `github.com/rohitg00/agentmemory`.

**VPS setup** (do once, not Flutter code):
```bash
npx @agentmemory/agentmemory
# Copies integrations/openclaw to ~/.openclaw/plugins/memory/agentmemory
cp -r integrations/hermes ~/.hermes/plugins/agentmemory
```

AgentMemory server runs at `http://localhost:3111` on the VPS.

**Flutter screen:**
```text
lib/features/hermes/agent_memory_screen.dart
```

Client connects via the Osiris client pattern (HTTP GET against the VPS over Tailscale).

Key REST endpoints:
```text
GET  /health                          → server status
GET  /api/memories?q={query}          → search memories
GET  /api/memories?session={id}       → memories for a session
POST /api/memories                    → save a memory manually
GET  /api/sessions                    → session list with memory counts
GET  /api/stats                       → total memories, sessions, storage
```

**Screen contents:**
- Server health card (online/offline, total memories, total sessions)
- Search field — semantic search across all memories
- Memory list — each card shows: content preview, session source, timestamp, tags
- Stats card — memory count, session count, last indexed
- "Attach to current session" action — injects search result into next Hermes prompt

**SharedPreferences key:** `agentmemory_base_url` (default `http://100.78.70.2:3111`)

### 13.11 Open-Notebook (Implemented)

**Source:** MIT-licensed. `github.com/lfnovo/open-notebook`.

**Stack:** Python + FastAPI (port 5055) + SurrealDB. Docker Compose deployment on VPS.

**VPS setup** (do once):
```bash
git clone https://github.com/lfnovo/open-notebook.git
cd open-notebook
docker compose up -d
# API available at http://localhost:5055
```

**Flutter screen:**
```text
lib/features/hermes/open_notebook_screen.dart
```

Key REST endpoints:
```text
GET  /api/notebooks                   → list all notebooks
POST /api/notebooks                   → create notebook
GET  /api/notebooks/{id}/sources      → sources in a notebook
POST /api/sources                     → add source (PDF, URL, text)
GET  /api/notes?notebook={id}         → notes in a notebook
POST /api/notes                       → create note
POST /api/chat                        → chat with notebook context
GET  /api/search?q={query}            → semantic search across all notebooks
```

**Screen contents:**
- Server health card
- Notebook list — name, source count, last updated
- Tap notebook → source list + note list
- "Chat with this notebook" → opens a Hermes chat session with notebook context injected as system prompt
- "Add note from clipboard" action
- Search field across all notebooks
- Stats card — notebooks, sources, notes

**SharedPreferences key:** `opennotebook_base_url` (default `http://100.78.70.2:5055`)

---

## 14. Swarm Tab Specification

Use existing files:
```text
lib/features/swarm/swarm_monitor_screen.dart
lib/features/swarm/swarm_compose_screen.dart
lib/features/swarm/office_view_screen.dart
lib/core/hermes/models/swarm_tree.dart
```

Routes: `/swarm`, `/swarm/compose`, `/office`

Swarm home must show:
- Active swarms with orchestrator + worker sessions
- Status per worker: running/thinking/complete/failed/idle
- Last activity timestamp
- Launch button

Compose must support:
- Mission description
- Worker count (1–3)
- Optional behavior/profile selection
- Launch via Hermes ACP path

Office View must show:
- Active workers as pixel avatars
- Current state per worker
- Tap worker to show session detail
- Refresh loop respecting battery

---

## 15. Intel Tab Specification

**Read `SPEC-OsirisIntegration-v1.0.md` in full before implementing this tab.**

That document contains complete Dart code for all files listed below.

### 15.1 New Files

```text
lib/core/intelligence/osiris_client.dart
lib/core/intelligence/intelligence_models.dart
lib/data/providers/intelligence_providers.dart
lib/features/intel/intel_screen.dart
lib/features/intel/world_intelligence_screen.dart
lib/features/intel/recon_panel.dart
lib/features/settings/osiris_settings.dart
```

### 15.2 Osiris Client

Base URL stored in SharedPreferences as `osiris_base_url`. Default placeholder: `http://100.78.70.2:3001`. Must be configurable — never hardcoded.

Client methods (all implemented in spec):
```dart
Future<List<EarthquakeEvent>> getEarthquakes();
Future<List<FlightState>> getFlights();
Future<List<FireHotspot>> getFires();
Future<List<NewsItem>> getNews();
Future<List<ConflictZone>> getConflictZones();
Future<List<SatellitePosition>> getSatellites();
Future<Map<String, dynamic>> dnsLookup(String domain);
Future<Map<String, dynamic>> whoisLookup(String target);
Future<Map<String, dynamic>> ipIntelligence(String ip);
Future<Map<String, dynamic>> sslInspect(String domain);
Future<List<dynamic>> cveLookup(String keyword);
Future<bool> isReachable();
```

Do not include port scanning in v1.

### 15.3 World Intelligence Layers

Map layers (toggleable):
- Earthquakes — coloured by magnitude
- Flights — aircraft heading arrows
- Fires — NASA FIRMS hotspots
- Conflict zones — severity-coded markers
- News broadcaster dots
- Satellites (if endpoint exists)
- Radio stations (Radio Garden — already implemented)

Use existing: `flutter_map`, `latlong2`, `http`.

### 15.4 RECON Toolkit

Tools: DNS, WHOIS, SSL inspect, IP intelligence, CVE lookup.

Safety rules:
- Frame as defensive analysis only
- No exploitation workflows
- No intrusive scanning
- No automatic lookups against third-party targets

### 15.5 RECON as Hermes Tools

The RECON tools are also added to the Hermes tool registry (`tool_registry.dart`) so Hermes can call them during a conversation. Implementation is in `SPEC-OsirisIntegration-v1.0.md §2.3`.

---

## 16. Ambient Tab Specification

Use existing files:
```text
lib/features/ambient/ambient_screen.dart
lib/features/ambient/focus_sound_section.dart
lib/features/ambient/world_radio_section.dart
lib/features/ambient/ambient_mini_player.dart
lib/core/ambient/focus_sound_engine.dart
lib/core/ambient/radio_garden_service.dart
lib/data/providers/ambient_providers.dart
assets/scenes.json
```

### 16.1 Focus Sounds

- 8 scenes minimum from `assets/scenes.json`
- 10-channel mixer with per-channel volume
- Play/pause, scene switching
- Sleep timer
- Persist active scene/volume

### 16.2 World Radio

- Search stations by name or city
- List stations by place from Radio Garden API
- Play/stop stream via `just_audio`
- Favourites persisted in SharedPreferences
- Graceful failure if Radio Garden API changes

### 16.3 Mini Player

Globally visible above bottom nav. Shows:
- Active focus scene or radio station name
- Play/pause/stop
- Tap to open Ambient tab

---

## 17. Settings Specification

### 17.1 Show These Settings

```text
Hermes REST
Hermes SSH
Hermes ACP status / diagnostics
AgentMemory
Open-Notebook
Osiris Intelligence
Voice & Transcription
Voice & TTS / Supertonic
Ambient audio
Theme
Security & Privacy
Backup & Restore
About
```

### 17.2 Hide These Settings

```text
OpenClaw Gateway
Device Identity / Ed25519 OpenClaw pairing
Paired OpenClaw Devices
OpenClaw Models
Local Model downloads
HuggingFace Token
Smart Router & Memory (local)
Knowledge Base / RAG
Academy Mode
Life Architect
Paperclip Company
LAN Scan
Storage (if primarily local model cleanup)
Device Info (if primarily local model hardware)
```

### 17.3 Hermes REST Settings

- Base URL
- API key in secure storage
- Test connection
- Model list if available

### 17.4 SSH Settings

- Host, port, username
- Auth method: password or key
- Credentials in secure storage
- Test connection
- Warning: Tailscale must be active if using tailnet IP

### 17.5 Osiris Settings

```text
lib/features/settings/osiris_settings.dart
```

- Base URL
- Test connection
- Show enabled endpoints
- Clear recent lookup cache

### 17.6 AgentMemory Settings

- Server URL
- Test connection
- Total memory count (from `/api/stats`)
- Clear all memories (with confirmation)

### 17.7 Open-Notebook Settings

- Server URL
- Test connection
- Notebook count (from `/api/notebooks`)

### 17.8 About

```text
HermesCommander
Native mobile command centre for Hermes Agent.
Nuburo.DIGITAL (PTY) LTD
```

---

## 18. Supertonic TTS

### 18.1 Current State

Supertonic code exists in source:
```text
lib/core/tts/supertonic_model_manager.dart
lib/core/tts/supertonic_tts_service.dart
lib/core/tts/supertonic_chunker.dart
lib/core/tts/supertonic_text_preprocessor.dart
lib/features/settings/tts_settings_screen.dart
lib/data/providers/tts_providers.dart
```

### 18.2 Required Behaviour

- System TTS fallback always works without setup
- Supertonic download is optional
- Auto-speak replies toggle
- Hands-free voice loop toggle
- Per-message speak button
- Stop speaking button
- No API keys for on-device inference

### 18.3 MVP Note

If Supertonic has device-specific issues, keep `flutter_tts` fallback and mark Supertonic as beta. Do not let it block the APK.

---

## 19. Data and Storage

### 19.1 SharedPreferences Keys

```text
onboarded
hermes_base_url
hermes_api_key_set          (boolean — actual key in secure storage)
ssh_host
ssh_port
ssh_username
ssh_auth_method
ssh_key_id
osiris_base_url
agentmemory_base_url
opennotebook_base_url
supertonic_voice_id
tts_auto_speak_replies
tts_voice_loop_mode
radio_favorites
ambient_active_scene
ambient_channel_volumes
rolling_context_buffer_v1
active_server               (always 'hermes' in HermesCommander)
```

### 19.2 Secure Storage Keys

```text
hermes_api_key
ssh_password
ssh_private_key_<id>
```

Never put secrets in SharedPreferences.

---

## 20. Security Requirements

### 20.1 Secret Scan

Before every release build:

```bash
grep -RInE "100\.78\.70\.2|hermes-pocket-claw|API_SERVER_KEY|Bearer [A-Za-z0-9_\-]{10,}|sk-[A-Za-z0-9]" lib android ios pubspec.yaml
```

No matches permitted in a release build.

### 20.2 Network Model

- Hermes REST uses bearer auth
- SSH uses user-provided credentials
- Osiris, AgentMemory, Open-Notebook reachable only over Tailscale private network
- No public port exposure assumed

### 20.3 RECON Safety

RECON is for defensive, owned-target analysis. The app must not guide users through exploitation, intrusive scanning, or unauthorised access.

---

## 21. File-Level Change Plan

### 21.1 Add

```text
lib/app/app_flavor.dart
lib/features/hermes/hermes_control_screen.dart
lib/features/hermes/agent_memory_screen.dart
lib/features/hermes/open_notebook_screen.dart
lib/features/chat/hermes_session_drawer.dart
lib/shared/widgets/context_ring.dart
lib/features/intel/intel_screen.dart
lib/features/intel/world_intelligence_screen.dart
lib/features/intel/recon_panel.dart
lib/core/intelligence/osiris_client.dart
lib/core/intelligence/intelligence_models.dart
lib/data/providers/intelligence_providers.dart
lib/features/settings/osiris_settings.dart
assets/icon/hermescommander_icon.png
assets/icon/hermescommander_icon_foreground.png
assets/fonts/Geist-Regular.ttf
assets/fonts/Geist-Medium.ttf
assets/fonts/Geist-SemiBold.ttf
assets/fonts/GeistMono-Regular.ttf
assets/fonts/GeistMono-Medium.ttf
android/app/src/main/res/values/strings.xml
```

### 21.2 Modify

```text
pubspec.yaml
android/app/build.gradle.kts
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/.../MainActivity.kt
lib/main.dart
lib/app/router.dart
lib/app/theme.dart
lib/shared/constants.dart
lib/data/providers/server_providers.dart
lib/data/providers/chat_mode_providers.dart
lib/data/providers/capability_providers.dart
lib/features/chat/chat_screen.dart
lib/features/chat/chat_mode_selector.dart
lib/features/settings/settings_screen.dart
lib/features/hermes/hermes_management_screen.dart
```

### 21.3 Hide Then Delete Later

```text
lib/features/academy/
lib/features/company/
lib/features/knowledge_base/
lib/features/life_architect/
lib/features/mission_control/
lib/features/onboarding/ (local model flows)
lib/features/packs/
lib/core/gateway/
lib/core/openclaw/
lib/core/llm/
lib/core/local_agent/
lib/core/rag/
lib/core/coaching/
lib/core/packs/
```

Do not delete shared widgets still used by Hermes chat until imports are verified.

---

## 22. Implementation Phases

### Phase 0 — Baseline Audit
- Branch confirmed
- Build result captured
- Secret scan captured
- Audit committed as `docs/HERMESCOMMANDER_BASELINE.md`

### Phase 1 — Identity and Startup
- Package ID `com.nuburo.hermescommander`
- Display name `HermesCommander`
- App constants updated (org: Nuburo.DIGITAL)
- Local model startup disabled
- HermesCommander icon placeholder added
- Geist fonts added to pubspec and assets

**Acceptance:** `flutter build apk --release --dart-define=APP_FLAVOR=hermesCommander` produces an APK

### Phase 2 — Hermes-Only Providers
- Active server forced to Hermes
- Chat mode forced to Hermes
- Mode selector hidden and replaced with status chip
- Capability provider Hermes-specific

**Acceptance:** No UI path selects OpenClaw or Local. Hermes REST sends a message.

### Phase 3 — Router and Settings Prune
- Five bottom tabs only
- Control routes to Hermes management
- Settings is Hermes-only
- Hidden routes removed

**Acceptance:** No Academy/Life Architect/Paperclip/OpenClaw/local model entries visible. All five tabs navigate cleanly.

### Phase 4 — Control Completion
- Control home with summary cards
- Sessions, Memory, Cron, Skills, Logs, Analytics, Approvals
- AgentMemory screen (§13.10)
- Open-Notebook screen (§13.11)

**Acceptance:** SSH not configured → helpful capability cards. SSH configured → data loads. Missing file → graceful empty state.

### Phase 5 — Chat WebUI Parity
- Session drawer (date-grouped, searchable)
- Context ring in composer
- Composer footer chip row (profile · workspace · model)
- `HermesMessageRow` — full-width, no bubbles
- `HermesEmptyState` with suggestion chips
- `UpdateBanner` component
- Mermaid fallback
- Edit/resend/regenerate
- Export transcript

**Acceptance:** Mobile chat feels like Hermes WebUI translated to Flutter. ACP tool timeline readable. REST fallback still works.

### Phase 6 — Intel / Osiris
- Osiris settings
- Osiris client and models
- Intel tab and world intelligence map
- RECON panel
- AgentMemory and Open-Notebook if not done in Phase 4

**Acceptance:** Osiris offline state works. DNS/WHOIS/SSL/IP/CVE lookups work. Map layers toggle.

### Phase 7 — Ambient Polish
- Focus sounds verified
- Radio Garden verified
- Favourites persist
- Mini-player persists across tabs
- Audio session conflicts with TTS resolved

**Acceptance:** Focus audio and radio do not crash across tab navigation. TTS and ambient coexist.

### Phase 8 — Release Hardening
- Secret scan clean
- Permissions reviewed
- Release APK builds
- ProGuard rules valid
- Physical Android smoke test passed

---

## 23. Codex Task Breakdown

### Task 1 — Identity and Hermes Startup
```text
Implement HermesCommander identity and startup cleanup only.
Use package ID com.nuburo.hermescommander and display name HermesCommander.
Add lib/app/app_flavor.dart.
Disable local model catalogue preload when APP_FLAVOR=hermesCommander.
Update Android namespace, applicationId, manifest label, strings.xml.
Add Geist font files to assets and pubspec.yaml.
Do not touch router yet.
Run flutter analyze and release APK build.
Reference: HermesCommander-FullDeveloperSpec-v2.0 §4, §5, §6, §7, §11.2
```

### Task 2 — Hermes-Only Providers and Settings
```text
Force activeServerProvider and chatModeProvider to Hermes in HermesCommander.
Hide OpenClaw/local model/Paperclip/Academy/Life Architect settings.
Replace chat mode selector with Hermes status chip.
Implement HermesCommanderCapabilities replacing the multi-agent capability model.
Keep ClawCommander-only code hidden, not deleted.
Run flutter analyze and build.
Reference: HermesCommander-FullDeveloperSpec-v2.0 §9, §10
```

### Task 3 — Five-Tab Router
```text
Rework HermesCommander router to exactly five tabs: Chat, Control, Swarm, Intel, Ambient.
Active tab icons use HCTheme.gold from SPEC-HermesCommanderDesign-v1.0.
Control routes to Hermes management surfaces only.
Intel can be placeholder if Osiris not done yet.
Ambient uses existing AmbientScreen.
Run flutter analyze and build.
Reference: HermesCommander-FullDeveloperSpec-v2.0 §8, SPEC-HermesCommanderDesign-v1.0 §4
```

### Task 4 — Control Completion
```text
Create Hermes Control home with summary cards.
Add sections for Sessions, Memory, Cron, Skills, Logs, Analytics, Approvals.
Implement AgentMemory screen with health card, search, and memory list.
Implement Open-Notebook screen with health card and notebook list.
Ensure missing SSH shows capability cards.
Run flutter analyze and build.
Reference: HermesCommander-FullDeveloperSpec-v2.0 §13
```

### Task 5 — Chat WebUI Parity
```text
Implement mobile Hermes WebUI parity using SPEC-HermesCommanderDesign-v1.0.
Add HermesMessageRow (full-width, no bubbles) replacing ChatBubble.
Add HermesEmptyState with suggestion chips.
Add session drawer with date grouping.
Add HermesComposer with footer chip row.
Add ContextRing widget.
Add UpdateBanner.
Add Mermaid fallback.
Add edit/resend/regenerate to message actions.
Add export transcript to session drawer.
Apply HCTheme gold colour system throughout.
Apply Geist Sans and Geist Mono fonts.
Do not break REST fallback or ACP streaming.
Run flutter analyze and build.
Reference: SPEC-HermesCommanderDesign-v1.0 (all sections)
```

### Task 6 — Intel / Osiris
```text
Implement Osiris Intel tab from SPEC-OsirisIntegration-v1.0.
Create osiris_client.dart, intelligence_models.dart, intelligence_providers.dart.
Create world_intelligence_screen.dart with flutter_map and layer toggles.
Create recon_panel.dart for DNS/WHOIS/SSL/IP/CVE.
Create osiris_settings.dart.
Add RECON tools to tool_registry.dart and tool_executor.dart.
Keep RECON defensive. No port scanning in v1.
Run flutter analyze and build.
Reference: SPEC-OsirisIntegration-v1.0 (full document)
```

### Task 7 — Ambient / Audio QA
```text
Verify Focus Sounds, Radio Garden, favourites, mini-player.
Fix audio session conflicts between TTS and ambient.
Fix bugs only. No major redesign.
Run flutter analyze and build.
Reference: HermesCommander-FullDeveloperSpec-v2.0 §16
```

---

## 24. Acceptance Checklist

### Identity
- [ ] App installs as `HermesCommander`
- [ ] Package ID is `com.nuburo.hermescommander`
- [ ] No ClawCommander name in user-facing UI
- [ ] Icon and splash are HermesCommander-branded
- [ ] About shows Nuburo.DIGITAL (PTY) LTD

### Navigation
- [ ] Bottom nav has exactly Chat, Control, Swarm, Intel, Ambient
- [ ] Active tab icons show in gold (`HCTheme.gold`)
- [ ] No OpenClaw screen reachable
- [ ] No Local Model screen reachable
- [ ] No Academy screen reachable
- [ ] No Life Architect screen reachable
- [ ] No Paperclip screen reachable

### Chat
- [ ] Hermes is the only chat mode
- [ ] REST works when only REST is configured
- [ ] ACP works when SSH is configured
- [ ] ACP falls back to REST if startup fails before output
- [ ] Messages are full-width with avatar — no chat bubbles
- [ ] Tool timeline (TUI Activity Card) works
- [ ] Approvals appear in chat and Control
- [ ] Context ring appears and colour-codes correctly
- [ ] Session drawer opens and is date-grouped
- [ ] Mermaid blocks render as fallback code cards
- [ ] Edit/resend/regenerate works
- [ ] TTS read aloud works
- [ ] Geist Sans renders for body text
- [ ] GeistMono renders for code/paths/tokens

### Control
- [ ] Control home loads with summary cards
- [ ] Sessions load with date grouping
- [ ] Memory loads and saves without corrupting delimiters
- [ ] Cron loads and toggles
- [ ] Skills load
- [ ] Logs load or fail gracefully
- [ ] Analytics loads with chart and cost ledger
- [ ] Approvals panel works
- [ ] AgentMemory screen shows health and search
- [ ] Open-Notebook screen shows health and notebook list

### Swarm
- [ ] Swarm monitor loads
- [ ] Compose screen launches mission prompt
- [ ] Office View loads
- [ ] Missing SSH shows helpful state

### Intel
- [ ] Osiris settings exist and are configurable
- [ ] Intel offline state shows gracefully
- [ ] World map loads when Osiris reachable
- [ ] Layer toggles work
- [ ] RECON panel works for DNS/WHOIS/SSL/IP/CVE
- [ ] No intrusive workflows

### Ambient
- [ ] Focus sounds play
- [ ] Radio search works or fails gracefully
- [ ] Favourites persist
- [ ] Mini-player persists across all tabs
- [ ] TTS and ambient do not conflict unpredictably

### Release
- [ ] `flutter analyze` passes
- [ ] Release APK builds
- [ ] Physical Android smoke test passes
- [ ] Secret scan clean

---

*HermesCommander — Full Developer Specification v2.0*  
*CARMEN PTY LTD / Nuburo.DIGITAL (PTY) LTD — 2026-05-31*  
*Companion specs: SPEC-HermesCommanderDesign-v1.0.md · SPEC-OsirisIntegration-v1.0.md*
