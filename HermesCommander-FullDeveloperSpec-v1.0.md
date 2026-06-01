# HermesCommander — Full Developer Specification v1.0

**Date:** 2026-05-31  
**Source baseline:** `AI_PocketClaw_source_no_secrets_20260531.zip`  
**Target product:** HermesCommander  
**Target platform:** Android only  
**Android package ID:** `com.nuburo.hermescommander`  
**Display name:** `HermesCommander`  
**Repository strategy:** branch from ClawCommander now; separate repo later  
**MVP goal:** feature-complete developer plan, implemented in phases  
**Visual target:** Hermes WebUI translated into native Flutter mobile, not a pixel clone

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
| Hermes WebUI-style mobile chat layout | Chat |
| session drawer / session search / session detail | Chat + Control |
| context ring and token/cost visibility | Chat |
| Mermaid/code/math markdown fallback rendering | Chat |
| edit, resend, regenerate, copy, read aloud | Chat |
| Hermes sessions | Control |
| Hermes memory: MEMORY.md, USER.md, SOUL.md, section-sign entry editor | Control |
| Hermes cron jobs | Control |
| Hermes skills | Control |
| Hermes logs | Control |
| Hermes analytics: 7-day tokens, cost ledger, insights | Control |
| approvals bell and approvals panel | Control + Chat |
| capability gates | Control |
| AgentMemory placeholder or implementation, depending on available contract | Control |
| Open-Notebook placeholder or implementation, depending on available contract | Control |
| Swarm compose | Swarm |
| Swarm mission tree | Swarm |
| Office View | Swarm |
| Osiris World Intelligence | Intel |
| RECON toolkit: DNS, WHOIS, SSL, IP intel, CVE lookup | Intel |
| Focus Sound Player | Ambient |
| World Radio / Radio Garden globe | Ambient |
| persistent ambient mini-player | Ambient |
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
| local GGUF models | ClawCommander only |
| fllama / llamadart local inference | ClawCommander only |
| HuggingFace local model downloads | ClawCommander only |
| on-device RAG / knowledge base | ClawCommander only |
| Academy Mode | ClawCommander only |
| Life Architect / GROW | ClawCommander only |
| Paperclip Company OS | ClawCommander only |
| ClawHub | ClawCommander only |
| LAN discovery | ClawCommander only |

---

## 2. Source Baseline Audit

The uploaded ZIP was inspected directly. Current key findings:

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

| Area | Current state |
|---|---|
| Osiris runtime code | Not found in `lib/`; only spec exists in documents. Build from spec. |
| AgentMemory | No usable source/API contract found. Leave placeholder unless architect supplies contract. |
| Open-Notebook | No usable source/API contract found. Leave placeholder unless architect supplies contract. |
| Hermes WebUI exact visual assets | Not in ZIP. Implement native equivalent from WebUI reference. |
| HermesCommander icon/splash | Not in ZIP. Create placeholder assets. |

### 2.3 Startup Issue To Fix

`lib/main.dart` currently preloads the local model catalogue through `ModelAllowlistService`. HermesCommander must not initialise or preload local model infrastructure at startup.

Required change:

- Move local model catalogue preload behind `if (!kAppFlavor.isHermesOnly)`.
- In HermesCommander, do not override `modelCatalogueProvider` unless the provider is still required by hidden code.
- Remove model refresh fire-and-forget call from HermesCommander startup.

---

## 3. Branch and Repository Strategy

### 3.1 Branch First

Work inside the existing repository on branch:

```bash
git checkout hermes-commander
```

This branch becomes the HermesCommander product line. ClawCommander main remains the full platform.

### 3.2 Separate Repo Later

When the Android APK builds, the nav is clean, and the first release candidate exists, create a separate repo if desired:

```text
ClawCommander repo     -> broad platform
HermesCommander repo   -> Hermes-only daily driver
```

Until then, branch-based development is safer because code reuse is still heavy.

---

## 4. Android Product Identity

### 4.1 Required App Identity

| Item | Value |
|---|---|
| Android package ID | `com.nuburo.hermescommander` |
| Android namespace | `com.nuburo.hermescommander` unless migration cost is too high |
| Display name | `HermesCommander` |
| Version start | inherit current version, then increment after first successful APK |
| Minimum SDK | keep current `minSdk >= 24` |
| Target platform | Android arm64 first |

### 4.2 Gradle Changes

Current file:

```text
android/app/build.gradle.kts
```

Final branch target:

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

If the developer wants to preserve ClawCommander and HermesCommander builds from the same branch temporarily, add flavors instead. But the final HermesCommander branch does not need to build ClawCommander.

### 4.3 Manifest Changes

Current manifest has a hardcoded label. Change:

```xml
android:label="ClawCommander"
```

to:

```xml
android:label="@string/app_name"
```

Add or update:

```text
android/app/src/main/res/values/strings.xml
```

```xml
<resources>
    <string name="app_name">HermesCommander</string>
</resources>
```

### 4.4 Kotlin Package Directory

Current file:

```text
android/app/src/main/kotlin/com/carmen/clawcommander/MainActivity.kt
```

Target:

```text
android/app/src/main/kotlin/com/nuburo/hermescommander/MainActivity.kt
```

Update package declaration:

```kotlin
package com.nuburo.hermescommander
```

### 4.5 Launcher Icons

Add:

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

Run:

```bash
flutter pub run flutter_launcher_icons
```

---

## 5. App Flavor and Compile-Time Gating

Even though this branch becomes HermesCommander, add an app flavor gate to make migration safe.

Create:

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

Use `kAppFlavor.isHermesOnly` to gate UI and providers during transition.

Final branch build command:

```bash
flutter build apk --release --dart-define=APP_FLAVOR=hermesCommander
```

---

## 6. App Constants

Current file:

```text
lib/shared/constants.dart
```

Update `AppConstants` so it is flavor-aware:

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

Remove or quarantine constants that only exist for OpenClaw/local model behavior.

---

## 7. Main Startup Changes

Current `main.dart` imports local model code and preloads the model catalogue. HermesCommander must not do this.

### 7.1 Required Changes

In `lib/main.dart`:

- import `app_flavor.dart`
- remove unconditional imports of local model allowlist files
- only load local catalogue when `!kAppFlavor.isHermesOnly`

Pseudo-code:

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

If compile-time imports still pull local model packages into HermesCommander, defer physical deletion until Phase 3. The first goal is no visible local-model UI and no startup local-model work.

---

## 8. Router Specification

Current file:

```text
lib/app/router.dart
```

HermesCommander must have exactly five bottom tabs:

```text
Chat | Control | Swarm | Intel | Ambient
```

### 8.1 Top-Level Routes

```text
/                   -> ChatScreen
/control            -> HermesControlScreen or HermesManagementScreen wrapper
/control/sessions   -> HermesSessionsTab or screen
/control/memory     -> HermesMemoryScreen
/control/cron       -> HermesCronTab
/control/skills     -> HermesSkillsTab
/control/logs       -> HermesLogsTab
/control/analytics  -> HermesAnalyticsTab
/control/approvals  -> ApprovalsPanel screen
/control/agent-memory -> placeholder
/control/notebook     -> placeholder
/swarm              -> SwarmMonitorScreen
/swarm/compose      -> SwarmComposeScreen
/office             -> OfficeViewScreen
/intel              -> IntelScreen
/intel/recon        -> ReconPanel screen or bottom sheet
/ambient            -> AmbientScreen
/settings           -> HermesCommanderSettingsScreen
/settings/hermes    -> HermesSettings
/settings/ssh       -> SshSettings
/settings/voice     -> VoiceSettingsScreen
/settings/tts       -> TtsSettingsScreen
/settings/security  -> SecuritySettings
/settings/backup    -> BackupRestoreSettings
```

### 8.2 Remove From HermesCommander Routes

Do not expose:

```text
/settings/academy
/settings/life-architect
/knowledge-base
/packs
/memory
/skills
/control/agents
/control/channels if OpenClaw-specific
/control/activity if OpenClaw-specific
/company
/onboarding model/local flows
```

Memory and Skills are still present, but only as Hermes management surfaces inside Control.

### 8.3 App Shell

The bottom nav destinations must be:

```dart
const NavigationDestination(
  icon: Icon(Icons.chat_outlined),
  selectedIcon: Icon(Icons.chat),
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

### 8.4 Mini Player

Keep `AmbientMiniPlayer` above the bottom nav.

It must work globally across all five tabs.

---

## 9. Server and Chat Mode Simplification

### 9.1 Active Server

Current file:

```text
lib/data/providers/server_providers.dart
```

In HermesCommander, `activeServerProvider` must always resolve to `ActiveServer.hermes`.

```dart
final activeServerProvider = StateProvider<ActiveServer>((ref) {
  if (kAppFlavor.isHermesOnly) return ActiveServer.hermes;
  // existing ClawCommander detection only if needed
});
```

Update setter:

```dart
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

Current file:

```text
lib/data/providers/chat_mode_providers.dart
```

In HermesCommander:

```dart
final chatModeProvider = StateProvider<ChatMode>((ref) {
  if (kAppFlavor.isHermesOnly) return ChatMode.hermes;
  // existing behavior only if retained
});
```

Do not show Local or OpenClaw modes in the UI.

### 9.3 Chat Mode Selector

Current file:

```text
lib/features/chat/chat_mode_selector.dart
```

In HermesCommander:

- hide mode picker
- show a Hermes status chip instead
- status chip displays one of:
  - `Hermes · ACP`
  - `Hermes · REST`
  - `Hermes · SSH missing`
  - `Hermes · not configured`

---

## 10. Capability Model

Current file:

```text
lib/data/providers/capability_providers.dart
```

Replace broad multi-agent capability logic with Hermes-specific capability flags in HermesCommander.

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

  const HermesCommanderCapabilities({
    this.hasRest = false,
    this.hasSsh = false,
    this.hasAcp = false,
    this.hasSessions = false,
    this.hasMemory = false,
    this.hasCron = false,
    this.hasSkills = false,
    this.hasLogs = false,
    this.hasAnalytics = false,
    this.hasApprovals = true,
    this.hasSwarm = false,
    this.hasOsiris = false,
    this.hasAmbient = true,
    this.hasSupertonic = false,
  });
}
```

Derivation rules:

| Capability | Rule |
|---|---|
| REST | Hermes base URL and API key configured |
| SSH | SSH host and username configured, client can connect |
| ACP | SSH configured and `hermes acp` starts successfully |
| Sessions | SSH configured |
| Memory | SSH configured |
| Cron | SSH configured |
| Skills | SSH configured |
| Logs | SSH configured |
| Analytics | SSH configured and `state.db` readable |
| Swarm | SSH configured and sessions readable |
| Osiris | Osiris base URL configured and health check succeeds |
| Ambient | always true |
| Supertonic | model files downloaded and active voice available |

Where a capability is missing, show `FeatureNotAvailableCard` with a direct settings action.

---

## 11. Visual Design Target

Hermes WebUI’s current public description says the web interface uses a three-panel layout: left sessions/navigation, centre chat, right workspace file browsing; model/profile/workspace controls live in the composer footer; and a circular context ring shows token usage. HermesCommander must translate this into mobile-native patterns.

### 11.1 Mobile Translation

| Hermes WebUI concept | HermesCommander mobile equivalent |
|---|---|
| left session sidebar | session drawer or bottom sheet |
| centre chat | Chat tab |
| right workspace/file panel | slide-up workspace sheet |
| composer footer controls | horizontal chip row above keyboard |
| circular context ring | compact ring in header/composer |
| Control Center | Control tab |
| tool timeline | TUI Activity Card |
| project/session filters | session chips and drawer filters |
| workspace file browser | Control → Notebook / Workspace placeholder |

### 11.2 Theme

Add a Hermes dark theme.

```dart
class HermesCommanderPalette {
  static const background = Color(0xFF080A12);
  static const surface = Color(0xFF10131F);
  static const surfaceHigh = Color(0xFF171B2B);
  static const outline = Color(0xFF2A3045);

  static const hermesPurple = Color(0xFF8B5CF6);
  static const commandCyan = Color(0xFF22D3EE);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const text = Color(0xFFE5E7EB);
  static const muted = Color(0xFF94A3B8);
}
```

Keep JetBrains Mono for technical labels, tool rows, tokens, paths, and command outputs. Use system/body font for readable long text.

---

## 12. Chat Tab Specification

### 12.1 Purpose

The Chat tab is the main Hermes interaction surface. It must support REST fallback and ACP-first chat.

### 12.2 Transport Priority

Order:

1. If SSH client is available, try ACP.
2. If ACP starts and runs, use ACP for the turn.
3. If ACP fails before output, fall back to REST.
4. If REST is unavailable, show Hermes configuration error.
5. If image attachment is present and ACP is unavailable, show a clear warning.

Current code already follows most of this in `chat_providers.dart`.

### 12.3 Header

Header contents:

```text
HermesCommander       [context ring] [approval bell] [settings]
```

Required status chips:

- `ACP` / `REST`
- connected / reconnecting / missing config
- active model if known
- token/cost ring

### 12.4 Session Drawer

Add a session drawer or bottom sheet.

File target:

```text
lib/features/chat/hermes_session_drawer.dart
```

Contents:

- recent sessions
- search
- Today / Yesterday / This Week / Earlier grouping
- source chip: REST / ACP / CLI / Cron / Swarm
- cost and token summary
- tap to load session detail
- long press: rename, export, delete only if safe and supported

### 12.5 Context Ring

Add:

```text
lib/shared/widgets/context_ring.dart
```

```dart
class ContextRing extends StatelessWidget {
  final int usedTokens;
  final int maxTokens;
  final double? estimatedCost;
  final String? model;
  final VoidCallback? onTap;
}
```

Behavior:

- green under 60%
- amber 60–85%
- red over 85%
- tap opens context sheet
- sheet shows session ID, model, input/output tokens, cached tokens, estimated cost, current transport

### 12.6 Composer

Composer layout:

```text
[+] [message input.........................] [mic] [send]
[Hermes ACP] [model] [profile] [workspace] [tokens]
```

Rules:

- Do not show Local/OpenClaw mode controls.
- Keep attachment button.
- If image attachment is selected, require ACP.
- Voice input inserts transcript into composer.
- Voice-loop mode may auto-send after final transcript.

### 12.7 Tool Activity

Use existing:

```text
lib/shared/widgets/tui_activity_card.dart
```

It must display:

- tool name
- status
- elapsed time
- argument preview
- output preview
- failed/error state
- expandable raw JSON

ACP event sources:

- `AcpToolCallStartEvent`
- `AcpToolCallUpdateEvent`

REST event source:

- `SseToolProgress`

### 12.8 Thinking Indicator

Use existing:

```text
lib/shared/widgets/thinking_indicator.dart
```

Rules:

- expanded while streaming
- collapsed after completion
- never show private chain-of-thought as normal chat body
- label as “Thinking” or “Reasoning signal”, not “internal thoughts”

### 12.9 Markdown Rendering

Required support:

- standard markdown
- fenced code blocks
- syntax-like monospace styling
- tables where possible
- checklists
- links
- blockquotes
- Mermaid fallback

Mermaid v1 implementation:

- detect fenced `mermaid` blocks
- render as a styled code card
- show “Diagram preview coming later” action
- preserve source text

Mermaid v2 later:

- WebView-based diagram rendering or native graph rendering

### 12.10 Message Actions

Use / extend:

```text
lib/shared/widgets/message_actions_bar.dart
```

User message actions:

- copy
- edit
- resend

Assistant message actions:

- copy
- regenerate
- continue
- read aloud
- stop speaking

Regenerate behavior:

1. select prior user message
2. optionally edit it
3. truncate messages after that turn in UI
4. resend through Hermes
5. optionally fork session when persistent session branching exists

### 12.11 Approval Flow

ACP permission requests must surface in two places:

- immediate chat dialog/sheet
- global approvals queue with bottom nav badge

Current files:

```text
lib/data/providers/approvals_providers.dart
lib/shared/widgets/approvals_panel.dart
```

Rules:

- Never silently approve.
- Deny must be easy.
- Show tool name, purpose, path/target, and raw payload preview.
- Resolve pending approval back to ACP client.
- If app backgrounded or navigated away, badge persists until resolved.

### 12.12 Voice and TTS

Use existing:

```text
lib/features/chat/voice_input_widget.dart
lib/core/device/tts_service.dart
lib/core/tts/*
lib/data/providers/tts_providers.dart
```

Requirements:

- mic transcript can fill composer
- voice loop can auto-send
- assistant replies can auto-speak after streaming ends
- manual speaker icon per assistant bubble
- Supertonic if loaded; system TTS fallback otherwise
- no blocking TTS during streaming

---

## 13. Control Tab Specification

### 13.1 Purpose

Control is HermesCommander’s management hub. It replaces ClawCommander’s Mission Control, Memory tab, and Skills tab for Hermes-specific work.

### 13.2 Control Home

Create or adapt:

```text
lib/features/hermes/hermes_control_screen.dart
```

Top summary cards:

- REST status
- SSH status
- ACP status
- current model/profile if available
- pending approvals
- today’s tokens
- today’s estimated cost
- recent session count
- cron health
- logs health

### 13.3 Control Sections

Control must expose:

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

The existing `HermesManagementScreen` currently has Sessions, Cron, Skills, Logs, Analytics, and Channels. Add Memory back into Control for HermesCommander. Channels may remain only if they are Hermes-specific and useful; otherwise hide.

### 13.4 Sessions

Use:

```text
lib/features/hermes/hermes_sessions_screen.dart
lib/features/hermes/hermes_session_detail_screen.dart
```

Required features:

- Today / Yesterday / This Week / Earlier grouping
- search
- source chips
- model
- message count
- tokens
- cost
- duration
- tap for transcript
- export transcript
- identify Swarm/conductor sessions

### 13.5 Memory

Use:

```text
lib/features/hermes/hermes_memory_screen.dart
lib/core/hermes/models/hermes_memory_entry.dart
```

Required files:

- `MEMORY.md`
- `USER.md`
- `SOUL.md`

Rules:

- Do not expose raw `§` delimiter as editable normal text.
- Render one card per memory entry.
- Add/edit/delete entries.
- Save by reconstructing the delimiter format.
- Provide raw view behind an advanced toggle only.

### 13.6 Cron

Use:

```text
lib/features/hermes/hermes_cron_screen.dart
lib/features/hermes/widgets/schedule_builder.dart
```

Required features:

- list jobs
- enable/disable
- run now
- create job
- delete job
- schedule builder
- delivery target selector if Hermes data supports it
- last run / next run / failure state

### 13.7 Skills

Use:

```text
lib/features/hermes/hermes_skills_screen.dart
```

Rules:

- Hermes skills only.
- Do not show ClawHub.
- Show installed skills from `~/.hermes/skills/`.
- Show file path/source and last modified if available.
- Read SKILL.md content via SSH/SFTP.
- Editing can be read-only in v1 if safe write semantics are not done.

### 13.8 Logs

Use:

```text
lib/features/hermes/hermes_logs_screen.dart
```

Tabs:

- agent log
- errors log
- gateway log
- ACP/session log if available

Required behavior:

- tail latest lines
- refresh
- copy line
- filter by error/warning/info
- never crash on missing file

### 13.9 Analytics

Use:

```text
lib/features/hermes/hermes_analytics_screen.dart
lib/features/hermes/widgets/hermes_token_chart.dart
lib/features/hermes/widgets/hermes_cost_ledger.dart
lib/core/hermes/hermes_insights.dart
```

Required cards:

- 7-day token chart
- input/output/cache split if available
- sessions per day
- cost ledger by model
- insights summary
- cron failure count

### 13.10 Approvals

Use:

```text
lib/shared/widgets/approvals_panel.dart
```

Control home must show:

- pending count
- newest pending approval
- full queue
- approve/deny actions
- stale approval state

### 13.11 AgentMemory Placeholder

No usable AgentMemory source/API contract was found in the ZIP.

Create placeholder:

```text
lib/features/hermes/agent_memory_screen.dart
```

Placeholder content:

```text
AgentMemory integration not configured.
Ask architect for:
- repo URL
- install method
- API or CLI contract
- auth model
- storage paths
- expected Hermes integration
```

Expected future contract:

- health check
- list memories
- search memories
- inspect memory graph if supported
- attach memory result to current Hermes prompt

### 13.12 Open-Notebook Placeholder

No usable Open-Notebook source/API contract was found in the ZIP.

Create placeholder:

```text
lib/features/hermes/open_notebook_screen.dart
```

Placeholder content:

```text
Open-Notebook integration not configured.
Ask architect for:
- repo URL
- install method
- API or CLI contract
- notebook storage paths
- auth model
- expected Hermes workflow
```

Expected future contract:

- list notebooks
- create notebook
- open note
- append note from chat
- attach notebook context to Hermes session

---

## 14. Swarm Tab Specification

### 14.1 Purpose

Swarm is Hermes delegation / conductor mode. It is not Paperclip and not OpenClaw.

Use existing files:

```text
lib/features/swarm/swarm_monitor_screen.dart
lib/features/swarm/swarm_compose_screen.dart
lib/features/swarm/office_view_screen.dart
lib/core/hermes/models/swarm_tree.dart
lib/data/providers/hermes_data_providers.dart
```

### 14.2 Routes

```text
/swarm
/swarm/compose
/office
```

### 14.3 Swarm Home

Must show:

- active swarms
- orchestrator sessions
- worker sessions
- status: running, thinking, complete, failed, idle
- last activity
- output path if known
- launch button

### 14.4 Compose

Must support:

- mission description
- optional worker count
- optional behavior/profile selection
- output location hint
- launch via Hermes prompt/ACP path

### 14.5 Office View

Must show:

- active agents/workers as visual avatars
- current state per worker
- click/tap worker to show session detail
- refresh loop with reasonable battery use

---

## 15. Intel Tab Specification

### 15.1 Purpose

Intel contains Osiris World Intelligence and RECON tools. It is included because HermesCommander is intended as a daily-driver operator app, not only a chat console.

### 15.2 Current State

No Osiris Flutter implementation was found in the ZIP. A full Osiris implementation spec exists in the provided project documents. Build from that spec.

### 15.3 New Files

```text
lib/core/intelligence/osiris_client.dart
lib/core/intelligence/intelligence_models.dart
lib/data/providers/intelligence_providers.dart
lib/features/intel/intel_screen.dart
lib/features/intel/world_intelligence_screen.dart
lib/features/intel/recon_panel.dart
lib/features/settings/osiris_settings.dart
```

### 15.4 Osiris Client

Base setting:

```text
osiris_base_url
```

Default placeholder:

```text
http://100.78.70.2:3001
```

Do not hardcode this as the only value. It must be configurable.

Client methods:

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

Do not include port scanning in v1 unless the user confirms a defensive/owned-target-only policy. If included later, gate it with explicit warnings and target ownership confirmation.

### 15.5 Intel Screen

Sections:

- Osiris health
- World map
- layer toggles
- RECON toolkit
- recent lookups
- Hermes MCP status

### 15.6 World Intelligence Layers

Map layers:

- earthquakes
- flights
- fires
- news
- conflict zones
- satellites if endpoint exists

Use existing dependencies:

- `flutter_map`
- `latlong2`
- `http`
- `dio` if needed

### 15.7 RECON Toolkit

Tools:

- DNS lookup
- WHOIS lookup
- SSL inspect
- IP intelligence
- CVE lookup

Safety rules:

- Frame as defensive analysis.
- Avoid exploitation workflows.
- Do not provide exploit steps.
- Do not enable intrusive scanning by default.
- Do not run lookups automatically against third-party targets without user action.

### 15.8 Hermes MCP Integration

If Osiris is deployed on the VPS, configure Hermes MCP with read-only intelligence tools where possible.

Settings card should show:

- Osiris app health
- Hermes MCP wiring status if detectable
- base URL
- last successful check

---

## 16. Ambient Tab Specification

### 16.1 Purpose

Ambient supports focused use of HermesCommander as a daily-driver app.

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

### 16.2 Focus Sounds

Requirements:

- 8 scenes minimum from `assets/scenes.json`
- 10-channel mixer if available in scene data
- per-channel volume
- play/pause
- scene switching
- persists active scene/volume if currently implemented or simple later task

### 16.3 World Radio

Current code uses the unofficial Radio Garden API.

Requirements:

- search stations
- list places/cities
- show stations by place
- play/stop stream
- favorites
- now-playing metadata when available
- graceful failure if Radio Garden blocks or changes API

### 16.4 Mini Player

Keep mini-player globally above bottom nav.

It must display:

- active focus scene or active radio station
- play/pause/stop
- compact now-playing text
- tap to open Ambient tab

---

## 17. Settings Specification

Create a HermesCommander-specific settings screen or gate the existing one heavily.

### 17.1 Show These Settings

```text
Hermes REST
Hermes SSH
Hermes ACP status / diagnostics
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
Local Model
HuggingFace Token
Smart Router & Memory
Knowledge Base / RAG
Academy Mode
Life Architect
Paperclip Company
LAN Scan
Storage screen if it is mostly model cleanup
Device Info if it is mostly local model hardware
```

### 17.3 Hermes REST Settings

Use existing:

```text
lib/features/settings/hermes_settings.dart
```

Requirements:

- base URL
- API key in secure storage
- test connection
- model list / model ID if available
- no hardcoded token

### 17.4 SSH Settings

Use existing:

```text
lib/features/settings/ssh_settings.dart
```

Requirements:

- host
- port
- username
- auth method
- password or key in secure storage
- test connection
- warning: Tailscale must be active if using tailnet IP

### 17.5 Osiris Settings

Create:

```text
lib/features/settings/osiris_settings.dart
```

Fields:

- base URL
- test connection
- show enabled endpoints
- clear recent lookup cache

### 17.6 About

Text:

```text
HermesCommander
Native mobile command centre for Hermes Agent.
Nuburo.DIGITAL (PTY) LTD
```

---

## 18. Supertonic TTS Specification

### 18.1 Current State

Supertonic code exists in the ZIP:

```text
lib/core/tts/supertonic_model_manager.dart
lib/core/tts/supertonic_tts_service.dart
lib/core/tts/supertonic_chunker.dart
lib/core/tts/supertonic_text_preprocessor.dart
lib/features/settings/tts_settings_screen.dart
lib/data/providers/tts_providers.dart
```

### 18.2 Required Behavior

- system TTS fallback always works
- Supertonic model download is optional
- active voice saved in SharedPreferences
- auto-speak replies toggle
- hands-free voice loop toggle
- per-message speak button
- stop speaking button
- no API keys needed for on-device inference

### 18.3 Do Not Block MVP

If Supertonic inference has device-specific issues, keep fallback to `flutter_tts` and mark Supertonic as beta.

---

## 19. Data and Storage

### 19.1 SharedPreferences Keys

Required keys:

```text
onboarded
hermes_base_url
hermes_api_key indicator only; secret in secure storage if possible
ssh_host
ssh_port
ssh_username
ssh_auth_method
ssh_key_id
osiris_base_url
supertonic_voice_id
tts_auto_speak_replies
tts_voice_loop_mode
radio_favorites
ambient_active_scene
ambient_channel_volumes
```

### 19.2 Secure Storage Keys

```text
hermes_api_key
ssh_password
ssh_private_key_<id>
```

Never put secrets in SharedPreferences.

### 19.3 Local Database

Keep only if used by chat/session UI. Remove or avoid local-model/RAG-specific tables from HermesCommander workflows.

---

## 20. Security Requirements

### 20.1 Secrets

Before every release build:

```bash
grep -RInE "100\.78\.70\.2|hermes-pocket-claw|API_SERVER_KEY|Bearer [A-Za-z0-9_\-]{10,}|sk-[A-Za-z0-9]" lib android ios pubspec.yaml
```

Allowed:

- placeholder hints in form fields
- documentation examples if clearly fake

Not allowed:

- real tokens
- production bearer keys
- private SSH keys
- API keys
- signed URLs

### 20.2 Network Model

- Hermes REST uses bearer auth.
- SSH uses user-provided credentials or key.
- Osiris should be reachable only over the user’s private network / Tailscale.
- No public ports are assumed.

### 20.3 RECON Safety

RECON is for defensive, owned-target analysis. The app should not guide the user through exploitation, intrusive scanning, or unauthorized access.

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
lib/features/chat/chat_bubble.dart
lib/features/chat/chat_mode_selector.dart
lib/features/settings/settings_screen.dart
lib/features/hermes/hermes_management_screen.dart
```

### 21.3 Hide Then Delete Later

First hide from router/settings. Delete only after build passes.

```text
lib/features/academy/
lib/features/company/
lib/features/knowledge_base/
lib/features/life_architect/
lib/features/mission_control/
lib/features/memory/ if only local/OpenClaw remains
lib/features/onboarding/ local-model specific flows
lib/features/packs/
lib/features/skills/ ClawHub/general skill surfaces
lib/core/gateway/
lib/core/openclaw/
lib/core/llm/
lib/core/local_agent/
lib/core/rag/
lib/core/coaching/
lib/core/packs/
```

Do not delete shared widgets or models still used by Hermes chat until imports are verified.

---

## 22. Implementation Phases

### Phase 0 — Baseline Audit

Deliverables:

- branch confirmed
- current build result captured
- secret scan result captured
- source audit committed as `docs/HERMESCOMMANDER_BASELINE.md`

Commands:

```bash
flutter pub get
flutter analyze
grep -RInE "100\.78\.70\.2|hermes-pocket-claw|API_SERVER_KEY|Bearer [A-Za-z0-9_\-]{10,}|sk-[A-Za-z0-9]" lib android ios pubspec.yaml
```

### Phase 1 — Identity and Startup

Deliverables:

- package ID changed to `com.nuburo.hermescommander`
- display name `HermesCommander`
- app constants updated
- local model startup disabled
- HermesCommander icon placeholder added

Acceptance:

```bash
flutter build apk --release --dart-define=APP_FLAVOR=hermesCommander
```

### Phase 2 — Hermes-Only Providers

Deliverables:

- active server forced to Hermes
- chat mode forced to Hermes
- mode selector hidden/replaced
- capability provider Hermes-specific

Acceptance:

- no UI path can choose OpenClaw
- no UI path can choose Local
- Hermes REST still sends a message

### Phase 3 — Router and Settings Prune

Deliverables:

- five bottom tabs only
- Control is Hermes management
- Memory and Skills moved under Control
- Settings is Hermes-only
- hidden routes removed

Acceptance:

- no Academy/Life Architect/Paperclip/OpenClaw/local model entries visible
- app navigates cleanly across all five tabs

### Phase 4 — Control Completion

Deliverables:

- Control home
- Sessions
- Memory
- Cron
- Skills
- Logs
- Analytics
- Approvals
- AgentMemory placeholder
- Open-Notebook placeholder

Acceptance:

- no SSH configured: helpful cards
- SSH configured: data loads
- missing file: graceful empty state

### Phase 5 — Chat WebUI Parity

Deliverables:

- session drawer
- context ring
- composer chip row
- workspace sheet placeholder
- Mermaid fallback
- edit/resend/regenerate
- export transcript

Acceptance:

- mobile chat feels like Hermes WebUI translated to Flutter
- ACP tool timeline remains readable
- REST fallback still works

### Phase 6 — Intel / Osiris

Deliverables:

- Osiris settings
- Osiris client
- Intel tab
- World Intelligence map
- RECON panel
- Hermes MCP status card

Acceptance:

- Osiris offline state works
- DNS/WHOIS/SSL/IP/CVE lookups work against configured Osiris
- map layers can be toggled

### Phase 7 — Ambient Polish

Deliverables:

- Focus Sounds verified
- Radio Garden verified
- favorites verified
- mini-player verified
- audio session conflicts with TTS resolved

Acceptance:

- focus audio and radio do not crash when navigating tabs
- TTS can pause/duck or coexist predictably

### Phase 8 — Release Hardening

Deliverables:

- secret scan clean
- permissions reviewed
- release APK builds
- ProGuard rules still valid
- install on physical Android device
- smoke test checklist passed

---

## 23. Codex Task Breakdown

### Task 1 — Identity and Hermes Startup

Prompt:

```text
Implement HermesCommander identity and startup cleanup only.
Use package ID com.nuburo.hermescommander and display name HermesCommander.
Add app_flavor.dart.
Disable local model catalogue preload when APP_FLAVOR=hermesCommander.
Update Android namespace/applicationId/manifest label/strings.
Do not touch router yet except imports required for build.
Run flutter analyze and release APK build.
```

### Task 2 — Hermes-Only Providers and Settings

```text
Force activeServerProvider and chatModeProvider to Hermes in HermesCommander.
Hide OpenClaw/local model/Paperclip/Academy/Life Architect settings.
Replace chat mode selector with Hermes status chip.
Keep ClawCommander-only code hidden, not deleted.
Run analyze and build.
```

### Task 3 — Five-Tab Router

```text
Rework HermesCommander router to exactly five tabs: Chat, Control, Swarm, Intel, Ambient.
Control must route to Hermes management surfaces only.
Intel can be placeholder if Osiris implementation is not done.
Ambient uses existing AmbientScreen.
Run analyze and build.
```

### Task 4 — Control Completion

```text
Create Hermes Control home and add sections for Sessions, Memory, Cron, Skills, Logs, Analytics, Approvals, AgentMemory placeholder, Open-Notebook placeholder.
Move Hermes Memory and Skills under Control.
Ensure missing SSH shows capability cards.
Run analyze and build.
```

### Task 5 — Chat WebUI Parity

```text
Add mobile Hermes WebUI parity: session drawer, context ring, composer footer chips, workspace sheet placeholder, Mermaid fallback, edit/resend/regenerate, export transcript.
Do not break REST fallback or ACP streaming.
Run analyze and build.
```

### Task 6 — Intel / Osiris

```text
Implement Osiris Intel tab from existing spec: osiris_client, intelligence models, providers, world intelligence map, RECON panel, settings tile.
Keep RECON defensive and non-intrusive.
Run analyze and build.
```

### Task 7 — Ambient / Audio QA

```text
Verify and polish Ambient tab: focus sounds, Radio Garden, favorites, mini-player, audio session interaction with TTS.
Fix bugs only. No major redesign.
Run analyze and build.
```

---

## 24. Acceptance Checklist

HermesCommander is feature-complete when all are true:

### Identity

- [ ] app installs as `HermesCommander`
- [ ] package ID is `com.nuburo.hermescommander`
- [ ] no ClawCommander name appears in user-facing UI except migration notes if any
- [ ] icon/splash are HermesCommander-branded

### Navigation

- [ ] bottom nav has exactly Chat, Control, Swarm, Intel, Ambient
- [ ] no OpenClaw screen is reachable
- [ ] no Local Model screen is reachable
- [ ] no Academy screen is reachable
- [ ] no Life Architect screen is reachable
- [ ] no Paperclip screen is reachable

### Chat

- [ ] Hermes is the only chat mode
- [ ] REST works when only REST is configured
- [ ] ACP works when SSH is configured
- [ ] ACP falls back to REST if startup fails before output
- [ ] tool timeline works
- [ ] approvals appear in chat and Control
- [ ] context ring appears
- [ ] session drawer appears
- [ ] Mermaid fallback works
- [ ] edit/resend/regenerate works
- [ ] TTS read aloud works

### Control

- [ ] sessions load
- [ ] memory loads and saves without corrupting delimiters
- [ ] cron loads and toggles
- [ ] skills load
- [ ] logs load or fail gracefully
- [ ] analytics loads
- [ ] approvals panel works
- [ ] AgentMemory placeholder exists
- [ ] Open-Notebook placeholder exists

### Swarm

- [ ] swarm monitor loads
- [ ] compose screen launches mission prompt
- [ ] Office View loads
- [ ] missing SSH shows helpful state

### Intel

- [ ] Osiris settings exist
- [ ] Intel offline state works
- [ ] world map loads when Osiris reachable
- [ ] RECON panel works for allowed lookups
- [ ] no intrusive/offensive workflows are added

### Ambient

- [ ] focus sounds play
- [ ] radio search works or fails gracefully
- [ ] favorites persist
- [ ] mini-player persists across tabs
- [ ] TTS and ambient audio do not fight unpredictably

### Release

- [ ] `flutter analyze` passes
- [ ] release APK builds
- [ ] physical Android smoke test passes
- [ ] secret scan clean

---

## 25. Known Gaps For Architect

The following require architect input before full implementation:

### AgentMemory

Need:

```text
repo URL
install method
health check
API or CLI contract
auth model
storage path
Hermes integration method
expected mobile UX
```

Until then, ship placeholder.

### Open-Notebook

Need:

```text
repo URL
install method
health check
API or CLI contract
auth model
notebook storage path
Hermes integration method
expected mobile UX
```

Until then, ship placeholder.

### Hermes WebUI Exact Styling

The public WebUI reference is enough for structure. Exact iconography, spacing, and component-by-component styling should be refined after the first HermesCommander build exists.

---

## 26. Final Recommendation

Build HermesCommander in this order:

1. identity and package split
2. Hermes-only providers
3. five-tab router
4. Control completion
5. WebUI-native chat polish
6. Intel / Osiris
7. Ambient polish
8. release hardening

Do not start with Osiris, WebUI parity, or UI polish before the Hermes-only build exists. The first successful APK is the foundation.

