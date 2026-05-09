# Pocket Claw — OpenClaw Integration Improvements
## Developer Specification v1.0

**Date:** 2026-05-08  
**Author:** CARMEN PTY LTD  
**Status:** Implementation-ready — verified against source code and live VPS  
**Companion to:** SPEC-MultiTransport-v1.0.md (Hermes + SSH)

---

## 1. Current State Assessment

OpenClaw is the primary agent runtime powering Pocket Claw. The integration is solid in most areas but has specific gaps, one critical pre-ship bug, and several screens that exist in the navigation but are either dead or underperforming. This spec is a gap-closure document — nothing here requires new architecture, only focused fixes and additions.

### 1.1 What's Working Well

| Feature | Implementation quality |
|---|---|
| WebSocket chat with streaming | ✅ Solid — proper handshake, delta accumulation, reconnection |
| Device pairing (Ed25519) | ✅ Solid — pairing banner, identity screen |
| Dashboard (health, cost, agents, cron) | ✅ Solid — live WebSocket health + RPC data |
| Cron jobs (list, toggle, run, remove) | ✅ Solid — full CRUD via `cron.*` RPCs |
| Channels screen | ✅ Solid — status, accounts, disconnect |
| Skills (list, search, install, toggle) | ✅ Solid — three-tier registry |
| Memory browser + editor | ✅ Solid — REST read/write |
| Activity feed | ✅ Solid — live WebSocket events |
| Command palette (49 commands) | ✅ Solid |
| Draft-confirm destructive actions | ✅ Solid |

### 1.2 Gaps — Prioritised

| Gap | Severity | Effort |
|---|---|---|
| Hardcoded VPS credentials in source | 🔴 Pre-ship blocker | 30 min |
| Tasks screen permanently empty | 🟠 UX confusion | 2 hours |
| No devices management screen | 🟠 Operational gap | 1 day |
| No model status screen | 🟡 Visibility gap | 1 day |
| No gateway diagnostics (doctor/logs) | 🟡 Debugging gap | 1 day (needs SSH) |
| No gateway restart from app | 🟡 Operational gap | 2 hours (needs SSH) |
| Session history not browsable | 🟡 Feature gap | 1 day |
| Channel setup requires SSH to add | 🟡 UX gap | Future sprint |
| WebSocket reconnect has no backoff | 🟢 Reliability | 2 hours |

---

## 2. Pre-Ship Blocker — Hardcoded Credentials

**File:** `lib/data/providers/core_providers.dart` lines 54–67

**Problem:** Your VPS Tailscale IP and full OpenClaw auth token are compiled into the APK. Anyone who decompiles the release build has immediate access to your gateway.

**Fix:**

Delete:
```dart
// DELETE THESE FOUR LINES ENTIRELY
const String _kDebugHardcodedGatewayUrl   = 'ws://100.78.70.2:18789';
const String _kDebugHardcodedGatewayToken = '<REDACTED_OLD_GATEWAY_TOKEN>';

final gatewayUrlProvider = StateProvider<String>((ref) {
  return _kDebugHardcodedGatewayUrl;    // ← DELETE
});
final gatewayTokenProvider = StateProvider<String>((ref) {
  return _kDebugHardcodedGatewayToken; // ← DELETE
});
```

Replace with:
```dart
final gatewayUrlProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('gateway_url') ?? '';
});

final gatewayTokenProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('gateway_token') ?? '';
});
```

**Testing:** After this change, launch the app on a fresh install. It should show the "Not configured" empty state on the Dashboard (because no gateway URL is saved in prefs yet). Go to Settings → Gateway Configuration, enter the URL and token, tap Save. The Dashboard should then connect and show data. This is the correct first-run flow.

---

## 3. Tasks Screen — Fix or Repurpose

**Current state:** `TasksScreen` renders a kanban board that always shows empty columns. The comment in `mission_control_providers.dart` is explicit: *"The gateway has no `tasks.*` RPC surface — confirmed via 2026-04-21 recon."*

OpenClaw does not have a task management system — it has agents, sessions, cron jobs, and skills. The Tasks concept was imported from an earlier spec that assumed a feature that doesn't exist.

**Decision:** Repurpose the Tasks screen as the **Session History** screen.

OpenClaw's `sessions.usage` RPC returns session metadata. Add a `sessions.list` call to retrieve browsable history:

```dart
// In mission_control_providers.dart

// Replace mcTasksProvider with:
final mcSessionsProvider = FutureProvider<List<OpenClawSession>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return [];
  try {
    final result = await client.request('sessions.usage', {
      'limit': 50,
      'sortBy': 'startedAt',
      'sortDir': 'desc',
    });
    if (result is! Map) return [];
    final sessions = result['sessions'];
    if (sessions is! List) return [];
    return [
      for (final s in sessions)
        if (s is Map<String, dynamic>) OpenClawSession.fromJson(s),
    ];
  } catch (_) {
    return [];
  }
});
```

```dart
// New model: lib/data/models/openclaw_session.dart
class OpenClawSession {
  final String id;
  final String? agentId;
  final String? model;
  final String? platform;  // 'telegram', 'cli', etc.
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int messageCount;
  final int inputTokens;
  final int outputTokens;
  final double? costUSD;

  const OpenClawSession({...});

  factory OpenClawSession.fromJson(Map<String, dynamic> json) => OpenClawSession(
    id:           json['id'] as String? ?? '',
    agentId:      json['agentId'] as String?,
    model:        json['model'] as String?,
    platform:     json['platform'] as String?,
    startedAt:    _parseDate(json['startedAt'] ?? json['started_at']),
    endedAt:      _parseDate(json['endedAt'] ?? json['ended_at']),
    messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
    inputTokens:  (json['inputTokens'] as num?)?.toInt() ?? 0,
    outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
    costUSD:      (json['costUsd'] as num?)?.toDouble(),
  );
}
```

**Rename `tasks_screen.dart` → `sessions_screen.dart`** and rewrite it as a session list — each row shows agent, platform icon, message count, token count, cost, and duration. This gives the Tasks navigation slot a genuine purpose.

**Update the navigation label** in `router.dart`:
- Tab label: Change "Tasks" → "Sessions"
- Tab icon: `history` instead of `task_alt`

---

## 4. Devices Management Screen

**Current state:** `device_identity_settings.dart` shows YOUR device's Ed25519 public key only. There is no way from the app to see other paired devices, approve pending devices, or revoke access.

**Why this matters:** If a new device requests pairing (e.g. a second phone), the only way to approve it is `openclaw devices approve <id>` on the VPS terminal. The app should handle this.

### 4.1 New RPC Calls

Add to `gateway_client.dart` as convenience wrappers:

```dart
/// List all known devices (paired + pending)
Future<List<OpenClawDevice>> listDevices() async {
  final result = await request('devices.list', {});
  if (result is! Map) return [];
  final devices = result['devices'];
  if (devices is! List) return [];
  return devices
      .cast<Map<String, dynamic>>()
      .map(OpenClawDevice.fromJson)
      .toList();
}

/// Approve a pending device by its device ID
Future<void> approveDevice(String deviceId) =>
    request('devices.approve', {'deviceId': deviceId});

/// Revoke a paired device
Future<void> revokeDevice(String deviceId) =>
    request('devices.revoke', {'deviceId': deviceId});
```

### 4.2 Device Model

```dart
// lib/data/models/openclaw_device.dart
class OpenClawDevice {
  final String id;
  final String? name;
  final String status;       // 'paired' | 'pending' | 'revoked'
  final String? publicKey;   // Ed25519 public key (hex)
  final DateTime? pairedAt;
  final DateTime? lastSeenAt;
  final bool isCurrentDevice; // true if matches DeviceIdentity.current()

  bool get isPending => status == 'pending';
  bool get isPaired  => status == 'paired';

  factory OpenClawDevice.fromJson(Map<String, dynamic> json) =>
      OpenClawDevice(
        id:          json['id'] as String? ?? '',
        name:        json['name'] as String?,
        status:      json['status'] as String? ?? 'unknown',
        publicKey:   json['publicKey'] as String?,
        pairedAt:    _parseDate(json['pairedAt']),
        lastSeenAt:  _parseDate(json['lastSeenAt']),
        isCurrentDevice: false, // resolved in provider
      );
}
```

### 4.3 Provider

```dart
// Add to lib/data/providers/core_providers.dart or new devices_provider.dart

final openClawDevicesProvider = FutureProvider<List<OpenClawDevice>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return [];
  final devices = await client.listDevices();
  // Mark which is the current device
  final myIdentity = await DeviceIdentity.current();
  return devices.map((d) => d.copyWith(
    isCurrentDevice: myIdentity != null &&
        (d.id == myIdentity.deviceId || d.publicKey == myIdentity.publicKeyHex),
  )).toList();
});
```

### 4.4 Devices Screen

```
lib/features/settings/devices_screen.dart
Route: /settings/devices
```

**UI layout:**

```
Devices                              [🔄 Refresh]
────────────────────────────────────────────────
PENDING APPROVAL (1)
┌─────────────────────────────────────────────┐
│ 📱  iPhone 15 Pro                           │
│     abc123...  ·  Requested 2 min ago       │
│                              [Approve] [❌] │
└─────────────────────────────────────────────┘

PAIRED DEVICES (2)
┌─────────────────────────────────────────────┐
│ 📱  This Device  ✦ current                  │
│     def456...  ·  Paired 3 days ago         │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│ 💻  Laptop                                  │
│     789abc...  ·  Last seen 1 hour ago      │
│                                   [Revoke] │
└─────────────────────────────────────────────┘
```

**Approve action:** Shows confirm dialog → calls `client.approveDevice(id)` → invalidates provider.

**Revoke action:** Shows destructive confirm dialog → calls `client.revokeDevice(id)` → invalidates provider.

**Cannot revoke the current device** — disable the revoke button on `isCurrentDevice == true` with a tooltip: "Cannot revoke this device while connected through it."

**Add to Settings screen:**
```dart
ListTile(
  leading: const Icon(Icons.devices),
  title: const Text('Paired Devices'),
  subtitle: Consumer(builder: (_, ref, __) {
    final devices = ref.watch(openClawDevicesProvider);
    final pendingCount = devices.value
        ?.where((d) => d.isPending).length ?? 0;
    return pendingCount > 0
        ? Text('$pendingCount pending approval',
            style: const TextStyle(color: Colors.orange))
        : const Text('Manage paired devices');
  }),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/devices'),
),
```

A pending-device count badge on the Settings tab icon would also be valuable so the user notices incoming pairing requests passively.

---

## 5. Model Status Screen

**Current state:** No visibility into which model OpenClaw is using, whether it's healthy, or what fallbacks are configured. The `openclaw models status` command you ran shows `neurometric/clawpack` with a live API key — but the app shows nothing about this.

### 5.1 New RPC Call

```dart
// Add to gateway_client.dart

/// Returns model configuration and status from the gateway.
/// RPC: `models.status` — same surface as `openclaw models status`
Future<OpenClawModelsStatus> getModelsStatus() async {
  final result = await request('models.status', {});
  return OpenClawModelsStatus.fromJson(result as Map<String, dynamic>? ?? {});
}
```

### 5.2 Model Status Model

```dart
// lib/data/models/openclaw_models.dart
class OpenClawModelsStatus {
  final String? defaultModel;     // e.g. "neurometric/clawpack"
  final String? alias;            // e.g. "ClawPack"
  final String? imageModel;
  final List<String> fallbacks;
  final List<OpenClawModelEntry> configured;

  factory OpenClawModelsStatus.fromJson(Map<String, dynamic> json) =>
      OpenClawModelsStatus(
        defaultModel: json['default'] as String?,
        alias:        json['alias'] as String?,
        imageModel:   json['imageModel'] as String?,
        fallbacks:    (json['fallbacks'] as List?)?.cast<String>() ?? [],
        configured: [
          for (final m in (json['models'] as List? ?? []))
            if (m is Map<String, dynamic>) OpenClawModelEntry.fromJson(m),
        ],
      );
}

class OpenClawModelEntry {
  final String id;
  final bool isDefault;
  final bool isHealthy;
  final String? lastError;

  factory OpenClawModelEntry.fromJson(Map<String, dynamic> json) =>
      OpenClawModelEntry(
        id:        json['id'] as String? ?? '',
        isDefault: json['isDefault'] == true,
        isHealthy: json['healthy'] != false, // assume healthy unless told otherwise
        lastError: json['lastError'] as String?,
      );
}
```

### 5.3 Provider

```dart
final openClawModelsProvider = FutureProvider<OpenClawModelsStatus>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return const OpenClawModelsStatus();
  try {
    return await client.getModelsStatus();
  } catch (_) {
    return const OpenClawModelsStatus();
  }
});
```

### 5.4 Models Screen

```
lib/features/settings/models_screen.dart
Route: /settings/models
```

**UI layout:**

```
Models                               [🔄 Refresh]
───────────────────────────────────────────────
ACTIVE MODEL
┌──────────────────────────────────────────────┐
│ 🦞  neurometric/clawpack               ✅   │
│     Alias: ClawPack                         │
│     API key: ••••••YJ3ZX4nN               │
└──────────────────────────────────────────────┘

FALLBACKS
  None configured

IMAGE MODEL
  None configured
```

**Add a Models tile to Settings screen** alongside Gateway Configuration. This should also surface in the Dashboard as a status indicator: "Model: ClawPack ✅".

---

## 6. Gateway Diagnostics via SSH

Once the shared SSH transport from `SPEC-MultiTransport-v1.0.md` is implemented, add two OpenClaw diagnostic features. These reuse `HermesSSHClient` — no additional SSH work needed.

### 6.1 OpenClaw Log Viewer

```dart
// In HermesDataService or a new OpenClawSSHService:

Future<List<String>> getOpenClawLogs({int lines = 100}) async {
  // OpenClaw runs as a systemd service — journalctl is the correct source
  final result = await ssh.exec(
    'journalctl -u openclaw-gateway -n $lines --no-pager --output=short 2>&1'
  );
  return result.trim().split('\n').where((s) => s.isNotEmpty).toList();
}

Stream<String> followOpenClawLogs() =>
    ssh.execStream('journalctl -u openclaw-gateway -f --no-pager --output=short');
```

**Add a "Gateway Logs" tile** to Settings → Gateway Configuration screen that navigates to a log viewer. Same UI as the Hermes log viewer — scrollable list of log lines with level-based colour coding.

### 6.2 OpenClaw Doctor

```dart
Future<String> runOpenClawDoctor() async {
  return ssh.exec('openclaw doctor 2>&1');
}
```

**Add a "Run Diagnostics" button** to Settings → Gateway Configuration. On tap: show a loading dialog → run doctor → display the raw output in a monospace scrollable card. Replaces "check the terminal" instructions for troubleshooting connection issues.

### 6.3 Gateway Restart

```dart
Future<void> restartOpenClawGateway() async {
  await ssh.exec('sudo systemctl restart openclaw-gateway');
  // Give it 5 seconds to restart before reconnecting
  await Future<void>.delayed(const Duration(seconds: 5));
}
```

**Add a "Restart Gateway" button** to Settings → Gateway Configuration. Show destructive confirm dialog first ("This will disconnect all active sessions. Continue?") → restart → auto-reconnect WebSocket.

---

## 7. WebSocket Reconnection — Add Exponential Backoff

**Current state:** `gateway_client.dart` reconnects on disconnect but with a fixed delay. Under poor network conditions (Tailscale reconnecting after a tunnel reset) this can cause aggressive reconnect storms.

**Add to `GatewayClient`:**

```dart
// Replace the fixed-delay reconnect with exponential backoff

static const _minReconnectDelay = Duration(seconds: 2);
static const _maxReconnectDelay = Duration(seconds: 60);
int _reconnectAttemptCount = 0;

Duration get _nextReconnectDelay {
  // 2s → 4s → 8s → 16s → 32s → 60s (capped)
  final ms = _minReconnectDelay.inMilliseconds *
      (1 << _reconnectAttemptCount.clamp(0, 5));
  return Duration(milliseconds: ms.clamp(
    _minReconnectDelay.inMilliseconds,
    _maxReconnectDelay.inMilliseconds,
  ));
}

void _handleDisconnect() {
  if (_disposed || _pairingRequired) return;
  _reconnectAttemptCount++;
  final delay = _nextReconnectDelay;
  FileLogger.instance.log(_tag, 'reconnect in ${delay.inSeconds}s (attempt $_reconnectAttemptCount)');
  Future<void>.delayed(delay).then((_) {
    if (!_disposed && !_pairingRequired) connect();
  });
}

// Reset counter on successful connection
void _onConnected() {
  _reconnectAttemptCount = 0;
  _connectionState.value = GatewayState.connected;
}
```

Call `_onConnected()` when the `connect.helloOk` handshake frame is received (wherever `GatewayState.connected` is currently set).

---

## 8. Mission Control — Wiring Audit

A systematic check of what each Mission Control screen does and what it needs:

### 8.1 Dashboard ✅ Working

Shows: health, usage (today/week/month), agent count, session count, active cron jobs count.

**Minor improvement:** Add model name to the health card so it reads "neurometric/clawpack ✅" rather than just "Online". Source: `openClawModelsProvider`.

### 8.2 Agents ✅ Working

Shows: agent list from `agents.list` RPC.

**Minor improvement:** The `Agent.fromSummary` constructor may not capture all fields. Add `status` (if the RPC returns it) and `lastActive` timestamp.

### 8.3 Tasks → Rename to Sessions (§3 above)

**Required change:** Repurpose from dead kanban to live session history.

### 8.4 Cost ✅ Working

Shows: cost breakdown from `usage.cost` RPC, today/week/month split.

**No change needed.**

### 8.5 Cron ✅ Working

Shows: cron jobs with toggle, run-now, delete actions.

**Minor improvement:** Add last-run status colour coding — green for success, red for error. The `lastStatus` field is already in `CronJobEntry.lastStatus`.

### 8.6 Activity ✅ Working

Shows: live WebSocket agent events.

**No change needed.**

### 8.7 Channels ✅ Working

Shows: configured channels with status/disconnect, available channels list.

**Minor improvement:** Replace the SSH instruction card with a link to the Terminal screen (once that's built) or a deep-link command that auto-pastes `openclaw channels add` into the chat. The help card currently tells users to SSH — the app should be the interface.

---

## 9. Settings Screen — Complete Tile Inventory

After all improvements above, Settings should read:

```
Settings
├── Gateway Connection          → GatewayConfig (URL, token, test, logs, doctor, restart)
├── Device Identity             → DeviceIdentitySettings (own device, public key)
├── Paired Devices       [N]   → DevicesScreen (NEW — N = pending count)
├── Models                      → ModelsScreen (NEW — active model status)
├── Server SSH                  → SshSettings (NEW — from MultiTransport spec)
├── Hermes Agent                → HermesSettings (from HermesIntegration spec)
├── ── ── ── ── ── ── ── ──
├── Execution Router            → RouterMemorySettings
├── Security                    → SecuritySettings (biometric lock)
├── ── ── ── ── ── ── ── ──
├── Model Configuration         → ModelConfig (local LLM)
```

---

## 10. OpenClaw-Specific Commands in Command Palette

The existing 49-command palette (`command_catalog.dart`) likely includes some commands that only work when connected to OpenClaw. Add a **"Gateway"** command category:

```dart
// New entries for command_catalog.dart

CommandEntry(
  trigger: '/devices',
  label: 'Manage paired devices',
  description: 'View and approve device pairing requests',
  category: CommandCategory.gateway,
  action: (context) => context.push('/settings/devices'),
),
CommandEntry(
  trigger: '/models',
  label: 'Model status',
  description: 'View active model and API key status',
  category: CommandCategory.gateway,
  action: (context) => context.push('/settings/models'),
),
CommandEntry(
  trigger: '/doctor',
  label: 'Run gateway diagnostics',
  description: 'Runs openclaw doctor and shows output',
  category: CommandCategory.gateway,
  action: (context) => /* trigger doctor inline in chat */,
),
CommandEntry(
  trigger: '/restart-gateway',
  label: 'Restart gateway',
  description: 'Restarts the OpenClaw gateway service',
  category: CommandCategory.gateway,
  requiresConfirm: true,
  action: (context) => /* trigger restart with confirm */,
),
```

---

## 11. Implementation Order

### Pre-Sprint (1 hour — must come first)
1. Remove hardcoded credentials from `core_providers.dart`
2. Verify Settings → Gateway Configuration → Save still connects

### Sprint A — Quick wins (2–3 days, no SSH needed)
3. Rename Tasks → Sessions; wire `sessions.usage` list to the screen
4. Add `OpenClawSession` model
5. Add model status RPC + `ModelsScreen` + Settings tile
6. Add `OpenClawDevice` model + devices RPC wrappers + `DevicesScreen` + Settings tile
7. Add pending device badge to Settings tab icon
8. Implement exponential backoff reconnection in `GatewayClient`
9. Add model name to Dashboard health card

### Sprint B — SSH diagnostics (after SSH transport from MultiTransport spec)
10. Add `getOpenClawLogs()` + log viewer screen
11. Add `runOpenClawDoctor()` + Diagnostics button in Gateway Config
12. Add `restartOpenClawGateway()` + Restart button with confirm dialog
13. Add gateway command palette entries (doctor, restart, devices, models)

### Sprint C — Polish (1 day)
14. Cron last-run status colour coding
15. Channel screen: replace SSH instruction card with chat deep-link
16. Complete Settings tile inventory (§9 above)

---

## 12. Summary

The OpenClaw integration is the most mature part of Pocket Claw — chat, Mission Control, skills, memory, cron, and channels are all working. What's missing is operational tooling: seeing what devices are paired, seeing what model is active, being able to diagnose and restart the gateway without opening a terminal, and a session history browser that gives the Sessions tab actual content.

Sprint A (no SSH required) delivers devices management, model status, session history, and better reconnection. Sprint B (requires SSH from the MultiTransport spec) delivers logs, doctor, and gateway restart. Together they make the OpenClaw integration operationally complete — the full VPS can be managed from the app without ever opening a terminal.

---

*CARMEN PTY LTD — Pocket Claw OpenClaw Integration Spec v1.0*  
*Verified against PocketClaw source (2026-05-08) and live VPS*
