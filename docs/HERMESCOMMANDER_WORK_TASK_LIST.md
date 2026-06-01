# HermesCommander Work Task List

Last updated: 2026-06-01
Branch: `hermes-commander`
Primary product spec: `docs/HermesCommander-FullDeveloperSpec-v2.0.md`
Design spec: `docs/SPEC-HermesCommanderDesign-v1.0.md`
Intel spec: `docs/SPEC-OsirisIntegration-v1.0.md`

This file is the working tracker for the HermesCommander branch. It exists to make progress resumable and to keep implementation aligned with the current v2.0 product spec.

## Status Legend

- `DONE` = implemented and verified enough to move on
- `IN PROGRESS` = started, not yet at acceptance
- `PENDING` = not started
- `BLOCKED` = needs user, architect, or environment input
- `OUTSTANDING` = not blocking the current build, but still required before final acceptance

## Completion Snapshot

### Completed

- HermesCommander identity and Android startup baseline are in place.
- Debug and release APK builds pass for `APP_FLAVOR=hermesCommander`.
- Hermes-only provider locks are in place for active server, chat mode, and capabilities.
- Bottom navigation is reduced to Chat, Control, Swarm, Intel, Ambient.
- HermesCommander design foundation is active: Geist fonts, `HCTheme`, gold navigation state, Hermes chat rows, composer, empty state, context ring, update banner, slash command overlay, and session drawer.
- Hermes chat WebUI parity pass is implemented at feature level: grouped rows, Hermes AppBar chips, Mermaid fallback cards, edit/resend/regenerate/continue/read-aloud actions, and session export/import.
- Control now routes to real AgentMemory and Open-Notebook surfaces instead of placeholders.
- AgentMemory first-pass screen, settings, health/search/list rendering, and attach-to-session flow are implemented.
- Open-Notebook first-pass screen, settings, health/search scaffolding, chat-with-notebook handoff, and add-note-from-clipboard action are implemented.
- Intel / Osiris foundation is implemented: client, models, providers, settings, Intel screen, World Intelligence map, RECON panel, and Hermes RECON tools.
- World Intelligence has first-pass domain workspaces for Aviation, Maritime & Space, Surveillance, Natural Hazards, Conflict, and Radio.
- Targeted Intel analysis is clean: `flutter analyze lib\features\intel lib\core\intelligence lib\data\providers\intelligence_providers.dart`.
- Release hardening has a clean high-confidence secret scan and a successful release APK build.

### Outstanding

- Full repo `flutter analyze` now reports 0 warnings; pre-existing lint infos remain (~85 info-level items, no warnings).
- Physical Android smoke test is blocked from this shell because `adb` is not on PATH.
- Hermes-only cleanup still needs legacy OpenClaw/local wording and unreachable shared routes pruned from remaining shared code.
- Control home summary cards are `DONE`; broader Control hub polish (Sessions, Cron, Skills, Logs, Analytics, Approvals screen polish) remains.
- AgentMemory and Open-Notebook still need live endpoint/device verification; Open-Notebook also needs the full notebook detail flow.
- Intel still needs endpoint/schema validation for every world layer.
- Swarm tab is now `DONE`: monitor/compose/office view verified in five-tab shell; SSH capability gate added.
- Ambient/audio QA is still pending: Focus Sounds, Radio Garden, mini-player, and TTS/audio-session interaction.
- Settings cleanup still needs a final release-surface review for legacy non-Hermes screens.
- Permission review remains pending before release hardening can be marked complete.

## Current Checkpoint

- `DONE` Phase 1 identity and startup baseline:
  - Android package ID switched to `com.nuburo.hermescommander`
  - Display name switched to `HermesCommander`
  - `lib/app/app_flavor.dart` aligned to HermesCommander default
  - Hermes-only startup no longer preloads local model catalogue
  - Hermes-named launcher icon assets configured and generated
  - Flutter APK build path fixed back to repo-local `build/`
- `DONE` Build verification:
  - `flutter pub get`
  - `flutter pub run flutter_launcher_icons`
  - `flutter build apk --debug --target-platform android-arm64 --dart-define=APP_FLAVOR=hermesCommander`
  - `flutter build apk --release --target-platform android-arm64 --dart-define=APP_FLAVOR=hermesCommander`
- `KNOWN GAP` `flutter analyze` is not clean yet. Current state is pre-existing repo lint debt plus Hermes branch migration work still to do.
- `UPDATE` Targeted Hermes chat / Intel / tool-loop analyze is now clean after the latest pass.
- `UPDATE` `flutter build apk --debug --target-platform android-arm64 --dart-define=APP_FLAVOR=hermesCommander` passes after the latest chat drawer / Intel map / RECON tool changes.
- `UPDATE` Hermes chat parity pass is now complete enough for feature acceptance: slash overlay, Mermaid fallback, edit/resend/regenerate/continue, context ring details, and drawer metadata are in place.
- `UPDATE` Hermes chat polish moved further toward WebUI parity: grouped consecutive message rows, Hermes-only AppBar chips, Hermes session clear action, and removal of the visible chat-mode selector in HermesCommander.
- `UPDATE` Intel map depth improved: focus chips, live layer legend, tappable flight detail markers, and full radio-place station sheets with play/favorite actions are now in place.
- `UPDATE` Intel mobile architecture is now being reshaped away from a flattened all-layers dashboard toward Osiris-style domain workspaces with a central map and per-domain controls. Aviation is the first conversion target.
- `UPDATE` Intel Conflict and Radio modes now have dedicated workspace metrics and detail lists; targeted Intel analyzer is clean.
- `UPDATE` Hermes memory tab transport now treats missing memory files as empty state instead of surfacing raw SFTP missing-file errors; memory writes also ensure the remote memories directory exists first.
- `UPDATE` AgentMemory and Open-Notebook dedicated settings screens created (`agent_memory_settings.dart`, `open_notebook_settings.dart`). Settings tiles now route to config screens instead of data screens.
- `UPDATE` AgentMemory "Attach to session" action implemented — sets `pendingChatContextProvider` and navigates to Chat tab.
- `UPDATE` Open-Notebook "Chat with this notebook" and "Add note from clipboard" actions implemented.
- `UPDATE` ChatScreen now reads `pendingChatContextProvider` on initState and prefills the composer.
- `UPDATE` Secret scan clean: one real hit fixed (hardcoded VPS IP in `paperclip_company_settings.dart` → `<your-vps-ip>`).
- `UPDATE` Release APK builds: `flutter build apk --release --target-platform android-arm64 --dart-define=APP_FLAVOR=hermesCommander` → `app-release.apk` 190.4 MB.
- `UPDATE` Intel RECON-to-map handoff implemented: IP lookups now surface a "Focus on map" button that flies the World Intelligence map to the IP geolocation and drops a gold RECON pin. Pin persists across mode switches and can be cleared from the AppBar.
- `UPDATE` RECON results are now structured (DNS record groups, IP geo card, SSL validity card, WHOIS dates card, CVE severity badges with expand/collapse). Raw JSON is still available behind a toggle.
- `UPDATE` RECON panel is now collapsible in IntelScreen via the radar AppBar button. Map takes full remaining height by default. Active RECON pin shows a compact banner when RECON is collapsed.
- `UPDATE` "Send to Hermes" action added to RECON results — injects formatted result as pendingChatContextProvider prefill.
- `UPDATE` Aviation workspace now has a detail list (flight callsign/model/altitude/speed, sorted airborne-first) matching the pattern of all other domain workspaces.
- `UPDATE` CCTV decision: kept as _UnavailablePanel in Surveillance workspace — Osiris host does not expose a stable CCTV API. No placeholder button or future promise.
- `DONE` Control home summary cards — Home tab added to HermesManagementScreen with 8 live-data summary cards (REST/SSH/ACP status, model, pending approvals, today's tokens+cost, recent sessions, cron health).
- `DONE` Swarm tab verification — monitor/compose/office view confirmed in five-tab shell; SSH capability gate (FeatureNotAvailableCard) added to SwarmMonitorScreen.
- `DONE` flutter analyze warnings cleared — 5 warnings resolved (retired model-ID dead block in model_config.dart, unused import in voice_settings_screen.dart). 0 warnings remain.
- `DONE` Open-Notebook detail flow — tapping a notebook pushes _NotebookDetailScreen with parallel-fetched source list (/api/notebooks/{id}/sources) and note list (/api/notes?notebook={id}); PDF/URL/text icons, note content cards, pull-to-refresh; Chat and Add-note actions on AppBar.
- `DONE` Settings / router dead-code prune — FeatureNotAvailableCard button now uses HCTheme.gold in HermesCommander; router docstring fixed; all other OpenClaw/local references confirmed gated behind !kHermesOnlyMode.
- `NEXT PICKUP` Ambient / Audio QA — Focus Sounds, Radio Garden, mini-player, TTS+audio-session interaction.

## Spec Authority

- Product and architecture authority:
  - `HermesCommander-FullDeveloperSpec-v2.0.md`
- UI authority:
  - `SPEC-HermesCommanderDesign-v1.0.md`
- Intel / Osiris authority:
  - `SPEC-OsirisIntegration-v1.0.md`

When specs conflict:

1. `HermesCommander-FullDeveloperSpec-v2.0.md` wins
2. Design and Osiris specs fill implementation detail for their domains
3. Older v1.0 Hermes branch docs are reference only

## Work Streams

### 1. Identity and Startup

Status: `DONE`
Spec refs:
- v2.0 §4
- v2.0 §5
- v2.0 §6
- v2.0 §7
- v2.0 §22 Phase 1

Acceptance:
- App installs as `HermesCommander`
- Package ID is `com.nuburo.hermescommander`
- HermesCommander release APK builds

Notes:
- Phase 1 build foundation is done. Fonts are now wired under the Design System Migration stream.

### 2. Hermes-Only Providers

Status: `IN PROGRESS`
Spec refs:
- v2.0 §9
- v2.0 §10
- v2.0 §23 Task 2

Tasks:
- Force `activeServerProvider` to Hermes in HermesCommander
- Force `chatModeProvider` to Hermes in HermesCommander
- Replace multi-agent capability model with `HermesCommanderCapabilities`
- Replace chat mode picker with Hermes status chip
- Remove visible Local/OpenClaw mode choices

Checkpoint:
- `DONE` `activeServerProvider` hard-locks to Hermes in HermesCommander
- `DONE` `chatModeProvider` hard-locks to Hermes in HermesCommander
- `DONE` `serverCapabilitiesProvider` now returns `HermesCommanderCapabilities`
- `DONE` chat mode selector is replaced by Hermes REST/SSH status chip in HermesCommander
- `IN PROGRESS` legacy OpenClaw/local wording and dead conditionals still need pruning from remaining screens

Acceptance:
- No UI path selects OpenClaw
- No UI path selects Local
- Hermes REST still sends messages

### 3. Router and Navigation Prune

Status: `IN PROGRESS`
Spec refs:
- v2.0 §8
- v2.0 §22 Phase 3
- v2.0 §23 Task 3
- design spec §4

Tasks:
- Reduce bottom nav to exactly: Chat, Control, Swarm, Intel, Ambient
- Make Control route to Hermes-only surfaces
- Remove Academy, Life Architect, Paperclip, OpenClaw, Local Model routes from HermesCommander shell
- Keep `AmbientMiniPlayer` above bottom nav globally
- Active nav colour must be `HCTheme.gold`

Checkpoint:
- `DONE` HermesCommander bottom nav is now `Chat`, `Control`, `Swarm`, `Intel`, `Ambient`
- `DONE` `Control` routes to Hermes-only management surfaces
- `DONE` onboarding and packs are removed from HermesCommander routing
- `DONE` `AmbientMiniPlayer` remains global above the bottom nav
- `IN PROGRESS` non-Hermes routes still exist in the shared router file and need further code-surface pruning, even though they are not reachable in HermesCommander mode

Acceptance:
- Five tabs only
- No ClawCommander-only surfaces reachable from HermesCommander shell

### 4. Design System Migration

Status: `IN PROGRESS`
Spec refs:
- v2.0 §11
- v2.0 §12
- design spec all sections
- v2.0 §23 Task 5

Tasks:
- Add Geist font assets and wire `pubspec.yaml`
- Create `lib/app/hermes_commander_theme.dart`
- Apply `HCTheme` gold palette
- Add Hermes avatar assets/widgets
- Replace bubble chat layout with full-width `HermesMessageRow`
- Add `HermesEmptyState`
- Add `HermesComposer`
- Add `ContextRing`
- Add `UpdateBanner`
- Add slash command overlay

Checkpoint:
- `DONE` Geist Sans and Geist Mono assets are added and wired in `pubspec.yaml`
- `DONE` `lib/app/hermes_commander_theme.dart` exists and is active in HermesCommander
- `DONE` gold `HCTheme` palette is driving the app shell and Hermes nav state
- `DONE` first-pass Hermes avatar widget exists
- `DONE` first-pass `HermesMessageRow` is wired into HermesCommander chat
- `DONE` first-pass `HermesEmptyState` is wired into HermesCommander chat
- `DONE` first-pass `HermesComposer` is wired into HermesCommander chat
- `DONE` first-pass `ContextRing` is wired into HermesCommander composer
- `DONE` `UpdateBanner` component exists and is wired to Hermes update-info prefs when present
- `DONE` session drawer now exports transcript / JSON and imports session JSON from clipboard
- `DONE` session drawer now uses PINNED / TODAY / YESTERDAY / THIS WEEK / OLDER grouping with source/token/message metadata
- `DONE` Hermes slash command overlay exists and uses the Hermes command subset
- `DONE` Mermaid fenced blocks render as Hermes fallback diagram cards
- `DONE` long-press message actions now support user Edit/Resend and assistant Regenerate/Continue/Read aloud
- `DONE` context ring opens a token/model/transport/session detail sheet
- `DONE` Hermes-only chat surface now hides the legacy mode picker and uses Hermes-specific AppBar chips / grouped rows
- `IN PROGRESS` touched Hermes chat/settings surfaces now use Geist and HCTheme-compatible styling
- `DONE` Hermes chat WebUI parity scope from v2.0 Task 5 is implemented at feature level

Acceptance:
- No chat bubbles in HermesCommander
- Gold accent system applied
- Geist fonts active
- Chat visually matches Hermes WebUI family

### 5. Control Surface Completion

Status: `IN PROGRESS`
Spec refs:
- v2.0 §13
- v2.0 §22 Phase 4
- v2.0 §23 Task 4

Tasks:
- Create Hermes control home summary cards
- Sessions screen polish and navigation under Control
- Memory screen under Control
- Cron under Control
- Skills under Control
- Logs under Control
- Analytics under Control
- Approvals under Control
- Helpful capability cards for missing SSH or REST setup

Checkpoint:
- `DONE` Control routes now open real `AgentMemoryScreen` and `OpenNotebookScreen` instead of placeholders
- `IN PROGRESS` current AgentMemory and Open-Notebook screens provide first-pass health/search/list scaffolding
- `DONE` Hermes `MEMORY.md` tab now fails gracefully on fresh VPS installs where the file does not exist yet
- `DONE` AgentMemory and Open-Notebook context handoff flows are implemented
- `PENDING` Control home summary cards
- `PENDING` broader Control hub polish for sessions, cron, skills, logs, analytics, approvals

Acceptance:
- Control is the single Hermes management hub
- Missing infrastructure fails gracefully

### 6. AgentMemory Integration

Status: `IN PROGRESS`
Spec refs:
- v2.0 §13.10
- v2.0 §17.6

Tasks:
- Add AgentMemory settings
- Add AgentMemory client/service integration as needed
- Build `agent_memory_screen.dart`
- Health card
- Search
- Memory list
- Attach-to-session flow

Checkpoint:
- `DONE` `agent_memory_screen.dart` exists
- `DONE` first-pass server health, stats, and search/list rendering are in place
- `DONE` dedicated settings screen (`agent_memory_settings.dart`) — URL, test connection, memory count, clear all
- `DONE` attach-to-session action — sets pendingChatContextProvider and navigates to Chat
- `OUTSTANDING` live AgentMemory endpoint/device verification

Acceptance:
- Health check works
- Search works
- Results can be attached into Hermes workflow

### 7. Open-Notebook Integration

Status: `IN PROGRESS`
Spec refs:
- v2.0 §13.11
- v2.0 §17.7

Tasks:
- Add Open-Notebook settings
- Add notebook list and health checks
- Add notebook detail flow
- Add note creation and search
- Add chat-with-notebook context handoff

Checkpoint:
- `DONE` `open_notebook_screen.dart` exists
- `DONE` first-pass notebook list, health, and search scaffolding are in place
- `DONE` dedicated settings screen (`open_notebook_settings.dart`) — URL, test connection, notebook count
- `DONE` "Chat with this notebook" action — prefills Chat composer with notebook context
- `DONE` "Add note from clipboard" action — POSTs clipboard text to /api/notes
- `DONE` full notebook detail flow (source list + note list tap view)
- `OUTSTANDING` live Open-Notebook endpoint/device verification

Acceptance:
- Notebook list loads
- Search works
- Notebook context can be injected into Hermes chat

### 8. Intel / Osiris

Status: `IN PROGRESS`
Spec refs:
- v2.0 §15
- intel spec all sections
- v2.0 §23 Task 6

Tasks:
- Create `lib/core/intelligence/*`
- Create `lib/data/providers/intelligence_providers.dart`
- Add `osiris_settings.dart`
- Create `intel_screen.dart`
- Create `world_intelligence_screen.dart`
- Create `recon_panel.dart`
- Add RECON tools to tool registry/executor

Checkpoint:
- `DONE` `lib/core/intelligence/intelligence_models.dart`
- `DONE` `lib/core/intelligence/osiris_client.dart`
- `DONE` `lib/data/providers/intelligence_providers.dart`
- `DONE` `lib/features/settings/osiris_settings.dart`
- `DONE` `lib/features/intel/intel_screen.dart`
- `DONE` `lib/features/intel/world_intelligence_screen.dart`
- `DONE` `lib/features/intel/recon_panel.dart`
- `DONE` RECON tool definitions and executor wiring now exist in `tool_registry.dart` and `tool_executor.dart`
- `DONE` Intel tab now renders a real `flutter_map` layer surface with layer toggles, detail sheets, and radio-place overlay
- `DONE` Intel map now supports layer focus chips, live legend counts, flight detail taps, and radio station drill-in/play/favorite flows
- `DONE` Osiris live flight schema is now parsed from the active local/VPS fork shape, including `commercial_flights`, `private_flights`, `private_jets`, and `military_flights`
- `DONE` Conflict workspace now has conflict-specific metrics and a severity-sorted watch list
- `DONE` Radio workspace now has radio-place metrics and a tappable station drill-in list
- `DONE` Targeted Intel analyzer pass is clean
- `DONE` Intel is now Osiris WebUI-aligned: domain workspaces, RECON-to-map handoff, structured result cards, collapsible RECON, aviation detail list, and CCTV resolved as unavailable.

Acceptance:
- Osiris offline state handled cleanly
- DNS/WHOIS/SSL/IP/CVE work
- World map layers toggle

Outstanding:
- Validate every Osiris endpoint/schema shape against the live VPS fork
- Decide whether CCTV is a supported v1 capability, a disabled placeholder, or a later plugin
- Add richer source drill-down for mapped layer items
- Add RECON-to-map handoff so lookup results can focus or annotate the map

Constraint:
- No port scanning in v1 even if older Osiris example code contains it

### 9. Swarm

Status: `DONE`
Spec refs:
- v2.0 §14

Tasks:
- Confirm Swarm monitor works inside new five-tab shell
- Confirm compose flow launches Hermes mission
- Confirm Office View works
- Add capability-gated empty state for missing SSH

Acceptance:
- Swarm surfaces operate from Hermes-only shell

### 10. Ambient and Audio QA

Status: `PENDING`
Spec refs:
- v2.0 §16
- v2.0 §22 Phase 7
- v2.0 §23 Task 7

Tasks:
- Verify Focus Sounds
- Verify Radio Garden search/playback/favorites
- Verify global mini-player
- Fix audio session conflicts with TTS

Acceptance:
- Ambient remains stable across navigation
- TTS and ambient audio behave predictably

### 11. Settings Cleanup

Status: `IN PROGRESS`
Spec refs:
- v2.0 §17

Tasks:
- Keep Hermes REST, SSH, Osiris, AgentMemory, Open-Notebook, Voice, TTS, Ambient, Theme, Security, Backup, About
- Hide OpenClaw, Local Model, Knowledge Base, Academy, Life Architect, Paperclip, LAN Scan
- Ensure About screen matches HermesCommander identity

Checkpoint:
- `DONE` HermesCommander top-level settings list is Hermes-scoped
- `DONE` SSH settings no longer expose the old placeholder IP hint
- `DONE` legacy non-Hermes settings screens confirmed gated; FeatureNotAvailableCard and router docstring cleaned up

Acceptance:
- HermesCommander settings are scoped correctly

### 12. Security and Release Hardening

Status: `IN PROGRESS`
Spec refs:
- v2.0 §20
- v2.0 §24 Release

Tasks:
- `DONE` Remove placeholder IPs and old token hints from release-visible code
- `DONE` Run high-confidence masked secret scan clean; remaining hits are false positives from code variable reads, release-script env templates, and old spec image URLs
- `PENDING` Review permissions
- `DONE` Re-run `flutter analyze`; 0 warnings, ~85 pre-existing info-level lint items remain
- `DONE` Build release APK
- `BLOCKED` Physical Android smoke test from this shell; `adb` is not on PATH and the saved device screenshot is black

Acceptance:
- `DONE` Secret scan returns no forbidden matches
- `DONE` Release APK builds
- `BLOCKED` Physical smoke test passed

Known current failures:
- Full repo flutter analyze: 0 warnings; ~85 pre-existing lint infos remain (info level only)
- Physical Android smoke test still needs Android platform tools or a device test path outside this shell

## Immediate Next Tasks

1. Open-Notebook detail flow — source list + note list tap view (§7, §13.11)
2. Settings / router dead-code prune — legacy OpenClaw/local wording from remaining shared screens
3. Ambient / Audio QA — Focus Sounds, Radio Garden, mini-player, TTS+audio-session interaction
4. Permission review before release hardening complete
5. Physical Android smoke test (blocked: `adb` not on PATH)

## Resume Notes

If resuming after context compaction or usage limits, pick up from:

1. `docs/HERMESCOMMANDER_WORK_TASK_LIST.md`
2. `docs/HermesCommander-FullDeveloperSpec-v2.0.md`
3. `docs/SPEC-HermesCommanderDesign-v1.0.md`
4. `docs/SPEC-OsirisIntegration-v1.0.md`

Before the next implementation step, re-check:

- `git status --short`
- current bottom-nav/router state in `lib/app/router.dart`
- provider state in `lib/data/providers/server_providers.dart`
- provider state in `lib/data/providers/chat_mode_providers.dart`
- settings scope in `lib/features/settings/settings_screen.dart`
