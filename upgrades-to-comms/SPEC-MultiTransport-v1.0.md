# Pocket Claw — Multi-Transport Agent Integration
## Developer Specification v1.0

**Date:** 2026-05-08  
**Author:** CARMEN PTY LTD  
**Status:** Implementation-ready  
**Scope:** Hermes Agent + OpenClaw — beyond REST  

---

## 1. Executive Summary

Pocket Claw currently connects to Hermes via a single channel: the OpenAI-compatible REST API (`/v1/chat/completions`). This gives us chat but nothing else. Hermes stores sessions, memory, cron jobs, skills, and logs on the VPS filesystem — none of it is exposed via REST in v0.12. The solution, proven by the Scarf iOS app, is a second transport channel: SSH.

Similarly, OpenClaw's WebSocket is working well for chat and Mission Control, but has a critical pre-ship bug (hardcoded credentials), and deeper diagnostics (logs, raw session history) are also only accessible via SSH.

This spec defines a unified SSH transport layer that both Hermes and OpenClaw share, then builds all the management features on top of it.

**Before this sprint:**
```
Phone ──── WebSocket ──► OpenClaw :18789  (chat, mission control)
Phone ──── HTTP REST ──► Hermes   :8642   (chat only)
```

**After this sprint:**
```
Phone ──── WebSocket  ──► OpenClaw :18789  (chat, mission control — unchanged)
Phone ──── HTTP REST  ──► Hermes   :8642   (chat — unchanged)
Phone ──── SSH        ──► VPS              (sessions, memory, cron, skills, logs — NEW)
                           ├── ~/.hermes/state.db       → sessions, messages, stats
                           ├── ~/.hermes/cron/jobs.json → cron jobs
                           ├── ~/.hermes/memories/      → memory editor
                           ├── ~/.hermes/skills/        → skills browser
                           ├── ~/.hermes/logs/          → log viewer
                           ├── ~/.openclaw/logs/        → openclaw logs
                           └── hermes acp (subprocess) → rich ACP chat (Phase 3)
```

---

## 2. What SSH Unlocks

### 2.1 For Hermes

| Feature | How | Scarf reference |
|---|---|---|
| Sessions browser | `sqlite3 -json ~/.hermes/state.db` via SSH exec | `RemoteSQLiteBackend.swift` |
| Session detail + message history | SQLite query via SSH | `HermesDataService.swift` |
| Full-text search across sessions | SQLite FTS5 query via SSH | `HermesDataService.swift` |
| Cost + token stats | SQLite aggregate query | `HermesDataService.swift` |
| Memory editor | SFTP read/write `MEMORY.md`, `USER.md`, `SOUL.md` | `IOSMemoryViewModel.swift` |
| Cron manager | SFTP read/write `cron/jobs.json` | `IOSCronViewModel.swift` |
| Skills browser | SSH `find ~/.hermes/skills/` + SFTP read | `SkillsViewModel.swift` |
| Gateway status | SFTP read `gateway_state.json` | `HermesFileService` |
| Log viewer | SSH exec `tail -n 100 ~/.hermes/logs/errors.log` | `HermesLogService.swift` |
| Rich ACP chat | SSH exec `hermes acp` with JSON-RPC stdio | `ACPClient.swift` (Phase 3) |

### 2.2 For OpenClaw

| Feature | How |
|---|---|
| Remove hardcoded credentials | Prefs-based URL/token (pre-ship critical fix) |
| OpenClaw log viewer | SSH exec `journalctl -u openclaw-gateway -n 100` |
| Raw session file browser | SFTP read `~/.openclaw/sessions/` |
| Deep diagnostics | SSH exec `openclaw doctor` |

---

## 3. New pubspec Dependency

Add to `pubspec.yaml`:

```yaml
dependencies:
  dartssh2: ^4.0.0   # SSH2 client: exec, SFTP, key auth
```

`dartssh2` is the Dart equivalent of the Citadel library that Scarf uses on iOS. It supports:
- SSH2 key exchange (Ed25519, RSA, ECDSA)
- Password + publickey authentication  
- Remote command execution (`SSHClient.execute`)
- SFTP subsystem (read/write files on the remote host)

---

## 4. SSH Configuration Model

### 4.1 Settings Keys (SharedPreferences)

```dart
// New keys — add alongside existing gateway/paperclip/hermes keys
'ssh_host'        // e.g. 100.78.70.2
'ssh_port'        // e.g. 22
'ssh_username'    // e.g. clawusr
'ssh_auth_method' // 'password' | 'key'
'ssh_password'    // if auth_method == 'password'
'ssh_key_id'      // identifier into flutter_secure_storage if auth_method == 'key'
```

Sensitive fields (`ssh_password`, private key material) go into `flutter_secure_storage`, not `SharedPreferences`.

### 4.2 SSH Settings Screen

Add a new **Server SSH** section to Settings (above Hermes Agent, below Gateway Connection):

```
Server SSH
  ├─ Host          [100.78.70.2]         (SharedPrefs)
  ├─ Port          [22]                  (SharedPrefs)
  ├─ Username      [clawusr]             (SharedPrefs)
  ├─ Auth Method   [Password ▼]         (SharedPrefs: 'password' | 'key')
  ├─ Password      [••••••••]            (SecureStorage)
  └─ [Test SSH Connection]  →  ✅ Connected as clawusr@100.78.70.2
```

Route: `/settings/ssh`

---

## 5. SSH Transport Layer

### 5.1 HermesSSHClient

```dart
// lib/core/ssh/hermes_ssh_client.dart
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

/// Shared SSH transport for both Hermes and OpenClaw diagnostics.
/// One persistent connection per app session; reconnects on demand.
///
/// Usage pattern:
///   final result = await ssh.exec('sqlite3 -readonly -json ~/.hermes/state.db "SELECT ..."');
///   final text   = await ssh.readFile('~/.hermes/memories/MEMORY.md');
///   await ssh.writeFile('~/.hermes/cron/jobs.json', updatedJson);
class HermesSSHClient {
  final String host;
  final int port;
  final String username;
  final SSHAuthMethod authMethod;

  SSHClient? _client;
  bool _connecting = false;

  HermesSSHClient({
    required this.host,
    required this.port,
    required this.username,
    required this.authMethod,
  });

  // ── Connection ────────────────────────────────────────────────────────

  Future<bool> isReachable() async {
    try {
      await _ensureConnected();
      return _client != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureConnected() async {
    if (_client != null) return;
    if (_connecting) {
      // Spin-wait max 5s for concurrent connect to finish
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (_client != null) return;
      }
      throw Exception('SSH connect timed out');
    }

    _connecting = true;
    try {
      final socket = await SSHSocket.connect(host, port,
          timeout: const Duration(seconds: 10));
      _client = SSHClient(
        socket,
        username: username,
        onAuthenticated: () {},
        identities: authMethod.identities,
        onPasswordRequest: authMethod is PasswordAuth
            ? () => (authMethod as PasswordAuth).password
            : null,
      );
      await _client!.authenticated;
    } catch (e) {
      _client = null;
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  // ── Remote exec ───────────────────────────────────────────────────────

  /// Run a command on the remote host and return combined stdout.
  /// Throws [SSHCommandException] if the exit code is non-zero.
  Future<String> exec(String command) async {
    await _ensureConnected();
    final session = await _client!.execute(command);
    final out = await session.stdout
        .transform(utf8.decoder)
        .join();
    final err = await session.stderr
        .transform(utf8.decoder)
        .join();
    final exitCode = await session.exitCode;
    if ((exitCode ?? 0) != 0 && out.isEmpty) {
      throw SSHCommandException(command: command, exitCode: exitCode ?? -1, stderr: err);
    }
    return out;
  }

  /// Stream lines from a long-running remote command (e.g. `tail -f`).
  Stream<String> execStream(String command) async* {
    await _ensureConnected();
    final session = await _client!.execute(command);
    yield* session.stdout.transform(utf8.decoder).transform(const LineSplitter());
  }

  // ── SFTP ──────────────────────────────────────────────────────────────

  Future<String> readFile(String remotePath) async {
    await _ensureConnected();
    final sftp = await _client!.sftp();
    final file = await sftp.open(_expandHome(remotePath));
    final bytes = await file.readBytes();
    await file.close();
    return utf8.decode(bytes);
  }

  Future<Uint8List> readBytes(String remotePath) async {
    await _ensureConnected();
    final sftp = await _client!.sftp();
    final file = await sftp.open(_expandHome(remotePath));
    final bytes = await file.readBytes();
    await file.close();
    return bytes;
  }

  Future<void> writeFile(String remotePath, String content) async {
    await _ensureConnected();
    final sftp = await _client!.sftp();
    final file = await sftp.open(
      _expandHome(remotePath),
      mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
    );
    await file.writeBytes(utf8.encode(content) as Uint8List);
    await file.close();
  }

  Future<List<String>> listDirectory(String remotePath) async {
    await _ensureConnected();
    final sftp = await _client!.sftp();
    final entries = await sftp.readdir(_expandHome(remotePath));
    return entries
        .map((e) => e.filename)
        .where((n) => n != '.' && n != '..')
        .toList();
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  void disconnect() {
    _client?.close();
    _client = null;
  }

  // ~ expansion — dartssh2 doesn't expand home, pass absolute path
  String _expandHome(String path) {
    if (path.startsWith('~/')) {
      // Will be resolved by remote shell in exec; for SFTP we need absolute
      // For SFTP, pass as-is and rely on server-side tilde expansion (OpenSSH supports it)
      return path;
    }
    return path;
  }
}

// ── Auth helpers ──────────────────────────────────────────────────────────

abstract class SSHAuthMethod {
  List<SSHKeyPair> get identities;
}

class PasswordAuth implements SSHAuthMethod {
  final String password;
  PasswordAuth(this.password);
  @override
  List<SSHKeyPair> get identities => [];
}

class KeyAuth implements SSHAuthMethod {
  final SSHKeyPair keyPair;
  KeyAuth(this.keyPair);
  @override
  List<SSHKeyPair> get identities => [keyPair];
}

class SSHCommandException implements Exception {
  final String command;
  final int exitCode;
  final String stderr;
  SSHCommandException({required this.command, required this.exitCode, required this.stderr});
  @override
  String toString() => 'SSHCommandException: `$command` exited $exitCode: $stderr';
}
```

### 5.2 Riverpod Provider

```dart
// lib/data/providers/ssh_providers.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/ssh/hermes_ssh_client.dart';
import 'core_providers.dart';

final sshHostProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('ssh_host') ?? '');

final sshPortProvider = StateProvider<int>((ref) =>
    ref.watch(sharedPrefsProvider).getInt('ssh_port') ?? 22);

final sshUsernameProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('ssh_username') ?? '');

final sshAuthMethodTypeProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('ssh_auth_method') ?? 'password');

/// The live SSH client. Null when not configured.
final sshClientProvider = Provider<HermesSSHClient?>((ref) {
  final host     = ref.watch(sshHostProvider);
  final port     = ref.watch(sshPortProvider);
  final username = ref.watch(sshUsernameProvider);
  final authType = ref.watch(sshAuthMethodTypeProvider);

  if (host.isEmpty || username.isEmpty) return null;

  // Password is loaded async — for now build with empty password;
  // actual password injected via HermesSSHClient.updateAuth() after load
  final auth = authType == 'password'
      ? PasswordAuth('')   // will be hydrated in settings screen
      : PasswordAuth('');  // key path: Phase 2

  return HermesSSHClient(
    host: host,
    port: port,
    username: username,
    authMethod: auth,
  );
});

final sshReachableProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(sshClientProvider);
  if (client == null) return false;
  return client.isReachable();
});
```

---

## 6. Hermes Filesystem Paths

These are the exact paths verified from Scarf's `HermesPathSet.swift`, matching your VPS layout:

```dart
// lib/core/hermes/hermes_paths.dart
library;

/// Canonical paths for a Hermes installation at ~/.hermes
class HermesPaths {
  final String home;

  const HermesPaths({this.home = '~/.hermes'});

  // Core
  String get stateDB        => '$home/state.db';
  String get configYAML     => '$home/config.yaml';
  String get envFile        => '$home/.env';
  String get gatewayStateJSON => '$home/gateway_state.json';

  // Memory
  String get memoriesDir    => '$home/memories';
  String get memoryMD       => '$memoriesDir/MEMORY.md';
  String get userMD         => '$memoriesDir/USER.md';
  String get soulMD         => '$home/SOUL.md';

  // Cron
  String get cronJobsJSON   => '$home/cron/jobs.json';
  String get cronOutputDir  => '$home/cron/output';

  // Skills
  String get skillsDir      => '$home/skills';

  // Logs
  String get errorsLog      => '$home/logs/errors.log';
  String get gatewayLog     => '$home/logs/gateway.log';
  String get agentLog       => '$home/logs/agent.log';
}

const kHermesPaths = HermesPaths();
```

---

## 7. Remote SQLite Service

```dart
// lib/core/hermes/hermes_remote_sqlite.dart
library;

import 'dart:convert';
import '../ssh/hermes_ssh_client.dart';

/// Runs `sqlite3 -readonly -json` queries against the remote
/// ~/.hermes/state.db via SSH exec.
///
/// Approach verified from Scarf's RemoteSQLiteBackend.swift —
/// one SSH exec per query, ControlMaster keeps connection warm.
/// Expected latency: 50–100ms per query.
class HermesRemoteSqlite {
  final HermesSSHClient _ssh;
  final String dbPath;

  HermesRemoteSqlite({
    required HermesSSHClient ssh,
    this.dbPath = '~/.hermes/state.db',
  }) : _ssh = ssh;

  /// Execute a single SQL statement. Returns parsed JSON rows.
  Future<List<Map<String, dynamic>>> query(String sql) async {
    // sqlite3 -readonly -json handles -readonly flag from SQLite 3.36+
    // Your Ubuntu 24.04 ships SQLite 3.45 — confirmed safe
    final command = "sqlite3 -readonly -json '$dbPath' ${_quoteSql(sql)}";
    final raw = await _ssh.exec(command);
    if (raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Execute multiple SQL statements in one sqlite3 invocation.
  /// Returns list of result sets, one per statement.
  /// Uses a unique marker to split result sets (Scarf pattern).
  Future<List<List<Map<String, dynamic>>>> queryBatch(List<String> statements) async {
    if (statements.isEmpty) return [];
    final markerPrefix = '__PC_RS_BEGIN__';
    final parts = <String>[];
    for (var i = 0; i < statements.length; i++) {
      parts.add(statements[i]);
      if (i < statements.length - 1) {
        parts.add("SELECT '$markerPrefix$i' AS marker;");
      }
    }
    final combined = parts.join(' ');
    final command = "sqlite3 -readonly -json '$dbPath' ${_quoteSql(combined)}";
    final raw = await _ssh.exec(command);

    // Split on marker rows and parse each result set
    // sqlite3 -json emits one JSON array per statement
    final resultSets = raw.split(RegExp(r'\n\['));
    // Re-join the split prefix and parse
    return resultSets
        .map((s) => s.startsWith('[') ? s : '[$s')
        .where((s) => s.length > 2)
        .map((s) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) {
              return decoded
                  .cast<Map<String, dynamic>>()
                  .where((row) => !row.containsKey('marker'))
                  .toList();
            }
          } catch (_) {}
          return <Map<String, dynamic>>[];
        })
        .toList();
  }

  String _quoteSql(String sql) {
    // Wrap in single quotes, escape internal quotes
    final escaped = sql.replaceAll("'", "'\\''");
    return "'$escaped'";
  }
}
```

---

## 8. Hermes Data Models

These are Dart translations of Scarf's verified Swift models:

### 8.1 HermesSession

```dart
// lib/core/hermes/models/hermes_session.dart
library;

class HermesSession {
  final String id;
  final String source;
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

  const HermesSession({
    required this.id,
    required this.source,
    this.model,
    this.title,
    this.parentSessionId,
    this.startedAt,
    this.endedAt,
    this.messageCount = 0,
    this.toolCallCount = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.estimatedCostUSD,
    this.actualCostUSD,
    this.billingProvider,
  });

  bool get isSubagent => parentSessionId != null;
  int get totalTokens => inputTokens + outputTokens;
  double? get displayCostUSD => actualCostUSD ?? estimatedCostUSD;
  String get displayTitle => title ?? id;

  String get sourceIcon => switch (source) {
    'telegram' => '📱',
    'discord'  => '💬',
    'slack'    => '💼',
    'cli'      => '⌨️',
    'whatsapp' => '📞',
    _          => '🤖',
  };

  factory HermesSession.fromSqliteRow(Map<String, dynamic> row) {
    return HermesSession(
      id:              row['id'] as String? ?? '',
      source:          row['source'] as String? ?? 'cli',
      model:           row['model'] as String?,
      title:           row['title'] as String?,
      parentSessionId: row['parent_session_id'] as String?,
      startedAt:       _epochToDate(row['started_at']),
      endedAt:         _epochToDate(row['ended_at']),
      messageCount:    (row['message_count'] as num?)?.toInt() ?? 0,
      toolCallCount:   (row['tool_call_count'] as num?)?.toInt() ?? 0,
      inputTokens:     (row['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens:    (row['output_tokens'] as num?)?.toInt() ?? 0,
      estimatedCostUSD: (row['estimated_cost_usd'] as num?)?.toDouble(),
      actualCostUSD:    (row['actual_cost_usd'] as num?)?.toDouble(),
      billingProvider:  row['billing_provider'] as String?,
    );
  }

  static DateTime? _epochToDate(dynamic v) {
    if (v == null) return null;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
```

### 8.2 HermesMessage

```dart
// lib/core/hermes/models/hermes_message.dart
library;

import 'dart:convert';

enum ToolKind { read, edit, execute, fetch, search, think, other }

class HermesToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const HermesToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
  });

  ToolKind get kind => switch (name) {
    'read_file' || 'list_dir' || 'search_files' || 'glob' => ToolKind.read,
    'write_file' || 'edit_file' || 'delete_file' || 'replace_in_file' => ToolKind.edit,
    'terminal' || 'execute_code' || 'run_script' => ToolKind.execute,
    'web_search' || 'browser' || 'fetch_url' || 'scrape' => ToolKind.fetch,
    'search_sessions' || 'search_memory' => ToolKind.search,
    'think' || 'analyze' => ToolKind.think,
    _ => ToolKind.other,
  };

  factory HermesToolCall.fromJson(Map<String, dynamic> json) {
    final fn = json['function'] as Map<String, dynamic>? ?? {};
    Map<String, dynamic> args = {};
    try {
      final rawArgs = fn['arguments'];
      if (rawArgs is String) args = jsonDecode(rawArgs) as Map<String, dynamic>;
      if (rawArgs is Map) args = rawArgs.cast<String, dynamic>();
    } catch (_) {}
    return HermesToolCall(
      id: json['id'] as String? ?? '',
      name: fn['name'] as String? ?? '',
      arguments: args,
    );
  }
}

class HermesMessage {
  final int id;
  final String sessionId;
  final String role;
  final String content;
  final String? toolName;
  final List<HermesToolCall> toolCalls;
  final DateTime? timestamp;

  const HermesMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.toolName,
    this.toolCalls = const [],
    this.timestamp,
  });

  factory HermesMessage.fromSqliteRow(Map<String, dynamic> row) {
    List<HermesToolCall> calls = [];
    try {
      final raw = row['tool_calls'];
      if (raw is String && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        calls = list
            .cast<Map<String, dynamic>>()
            .map(HermesToolCall.fromJson)
            .toList();
      }
    } catch (_) {}
    return HermesMessage(
      id:        (row['id'] as num?)?.toInt() ?? 0,
      sessionId: row['session_id'] as String? ?? '',
      role:      row['role'] as String? ?? 'user',
      content:   row['content'] as String? ?? '',
      toolName:  row['tool_name'] as String?,
      toolCalls: calls,
      timestamp: HermesSession._epochToDate(row['timestamp']),
    );
  }
}
```

### 8.3 HermesCronJob

```dart
// lib/core/hermes/models/hermes_cron_job.dart
library;

import 'dart:convert';

class CronSchedule {
  final String kind;           // 'once' | 'cron'
  final String? runAt;         // ISO8601 for one-shot
  final String? display;       // Human-readable label
  final String? expression;    // Cron expression e.g. "0 9 * * 1"

  const CronSchedule({
    required this.kind,
    this.runAt,
    this.display,
    this.expression,
  });

  factory CronSchedule.fromJson(Map<String, dynamic> json) => CronSchedule(
    kind:       json['kind'] as String? ?? 'once',
    runAt:      json['run_at'] as String?,
    display:    json['display'] as String?,
    expression: json['expression'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (runAt != null)      'run_at': runAt,
    if (display != null)    'display': display,
    if (expression != null) 'expression': expression,
  };
}

class HermesCronJob {
  final String id;
  final String name;
  final String prompt;
  final List<String>? skills;
  final String? model;
  final CronSchedule schedule;
  final bool enabled;
  final String state;          // 'scheduled'|'running'|'completed'|'failed'
  final String? deliver;       // 'telegram'|'discord:channel'|null
  final String? nextRunAt;
  final String? lastRunAt;
  final String? lastError;
  final String? workdir;

  const HermesCronJob({
    required this.id,
    required this.name,
    required this.prompt,
    required this.schedule,
    required this.enabled,
    required this.state,
    this.skills,
    this.model,
    this.deliver,
    this.nextRunAt,
    this.lastRunAt,
    this.lastError,
    this.workdir,
  });

  String get stateIcon => switch (state) {
    'scheduled' => '🕐',
    'running'   => '▶️',
    'completed' => '✅',
    'failed'    => '❌',
    _           => '❓',
  };

  bool get isRunning => state == 'running';
  bool get hasFailed => state == 'failed';

  factory HermesCronJob.fromJson(Map<String, dynamic> json) => HermesCronJob(
    id:       json['id'] as String? ?? '',
    name:     json['name'] as String? ?? '',
    prompt:   json['prompt'] as String? ?? '',
    skills:   (json['skills'] as List?)?.cast<String>(),
    model:    json['model'] as String?,
    schedule: CronSchedule.fromJson(json['schedule'] as Map<String, dynamic>? ?? {}),
    enabled:  json['enabled'] as bool? ?? true,
    state:    json['state'] as String? ?? 'scheduled',
    deliver:  json['deliver'] as String?,
    nextRunAt: json['next_run_at'] as String?,
    lastRunAt: json['last_run_at'] as String?,
    lastError: json['last_error'] as String?,
    workdir:  json['workdir'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'prompt': prompt,
    if (skills != null)  'skills': skills,
    if (model != null)   'model': model,
    'schedule': schedule.toJson(),
    'enabled': enabled,
    'state': state,
    if (deliver != null)  'deliver': deliver,
    if (nextRunAt != null) 'next_run_at': nextRunAt,
    if (lastRunAt != null) 'last_run_at': lastRunAt,
    if (lastError != null) 'last_error': lastError,
    if (workdir != null) 'workdir': workdir,
  };

  HermesCronJob copyWith({bool? enabled}) => HermesCronJob(
    id: id, name: name, prompt: prompt, skills: skills,
    model: model, schedule: schedule,
    enabled: enabled ?? this.enabled,
    state: state, deliver: deliver, nextRunAt: nextRunAt,
    lastRunAt: lastRunAt, lastError: lastError, workdir: workdir,
  );
}

class CronJobsFile {
  final List<HermesCronJob> jobs;
  final String? updatedAt;

  const CronJobsFile({required this.jobs, this.updatedAt});

  factory CronJobsFile.fromJson(Map<String, dynamic> json) => CronJobsFile(
    jobs: (json['jobs'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(HermesCronJob.fromJson)
        .toList(),
    updatedAt: json['updated_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'jobs': jobs.map((j) => j.toJson()).toList(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}
```

---

## 9. Hermes Data Service

```dart
// lib/core/hermes/hermes_data_service.dart
library;

import 'dart:convert';
import 'hermes_paths.dart';
import 'hermes_remote_sqlite.dart';
import 'models/hermes_session.dart';
import 'models/hermes_message.dart';
import 'models/hermes_cron_job.dart';
import '../ssh/hermes_ssh_client.dart';

/// High-level Hermes data access over SSH.
/// All methods require an active SSH connection.
class HermesDataService {
  final HermesSSHClient _ssh;
  final HermesRemoteSqlite _db;
  final HermesPaths paths;

  HermesDataService({
    required HermesSSHClient ssh,
    HermesPaths? hermesPaths,
  })  : _ssh = ssh,
        paths = hermesPaths ?? const HermesPaths(),
        _db = HermesRemoteSqlite(ssh: ssh);

  // ── Sessions ──────────────────────────────────────────────────────────

  Future<List<HermesSession>> getSessions({int limit = 50}) async {
    final rows = await _db.query('''
      SELECT id, source, model, title, parent_session_id,
             started_at, ended_at, message_count, tool_call_count,
             input_tokens, output_tokens, estimated_cost_usd,
             actual_cost_usd, billing_provider
      FROM sessions
      ORDER BY started_at DESC
      LIMIT $limit
    ''');
    return rows.map(HermesSession.fromSqliteRow).toList();
  }

  Future<List<HermesMessage>> getMessages(String sessionId) async {
    final rows = await _db.query('''
      SELECT id, session_id, role, content, tool_name,
             tool_calls, timestamp
      FROM messages
      WHERE session_id = '$sessionId'
      ORDER BY timestamp ASC
    ''');
    return rows.map(HermesMessage.fromSqliteRow).toList();
  }

  Future<List<HermesSession>> searchSessions(String query) async {
    // FTS5 full-text search — verified schema from HERMES_DISCOVERY.md
    final escaped = query.replaceAll("'", "''");
    final rows = await _db.query('''
      SELECT s.id, s.source, s.model, s.title, s.parent_session_id,
             s.started_at, s.ended_at, s.message_count, s.tool_call_count,
             s.input_tokens, s.output_tokens, s.estimated_cost_usd,
             s.actual_cost_usd, s.billing_provider
      FROM messages_fts fts
      JOIN messages m ON m.id = fts.rowid
      JOIN sessions s ON s.id = m.session_id
      WHERE messages_fts MATCH '$escaped'
      GROUP BY s.id
      ORDER BY s.started_at DESC
      LIMIT 20
    ''');
    return rows.map(HermesSession.fromSqliteRow).toList();
  }

  Future<HermesCostSummary> getCostSummary() async {
    final rows = await _db.query('''
      SELECT
        COALESCE(SUM(COALESCE(actual_cost_usd, estimated_cost_usd)), 0) AS total_cost,
        COALESCE(SUM(input_tokens + output_tokens), 0) AS total_tokens,
        COUNT(*) AS session_count
      FROM sessions
      WHERE started_at > strftime('%s', 'now', '-30 days')
    ''');
    if (rows.isEmpty) return const HermesCostSummary();
    final row = rows.first;
    return HermesCostSummary(
      totalCostUSD:   (row['total_cost'] as num?)?.toDouble() ?? 0,
      totalTokens:    (row['total_tokens'] as num?)?.toInt() ?? 0,
      sessionCount:   (row['session_count'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Memory ────────────────────────────────────────────────────────────

  Future<String> readMemory()  => _ssh.readFile(paths.memoryMD);
  Future<String> readUserProfile() => _ssh.readFile(paths.userMD);
  Future<String> readSoul()    => _ssh.readFile(paths.soulMD);

  Future<void> writeMemory(String content)      => _ssh.writeFile(paths.memoryMD, content);
  Future<void> writeUserProfile(String content) => _ssh.writeFile(paths.userMD, content);
  Future<void> writeSoul(String content)        => _ssh.writeFile(paths.soulMD, content);

  // ── Cron ──────────────────────────────────────────────────────────────

  Future<CronJobsFile> getCronJobs() async {
    final raw = await _ssh.readFile(paths.cronJobsJSON);
    return CronJobsFile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveCronJobs(CronJobsFile file) async {
    final json = const JsonEncoder.withIndent('  ').convert(file.toJson());
    await _ssh.writeFile(paths.cronJobsJSON, json);
  }

  Future<void> toggleCronJob(String jobId, {required bool enabled}) async {
    final file = await getCronJobs();
    final updated = CronJobsFile(
      jobs: file.jobs.map((j) =>
          j.id == jobId ? j.copyWith(enabled: enabled) : j).toList(),
    );
    await saveCronJobs(updated);
  }

  // ── Skills ────────────────────────────────────────────────────────────

  Future<List<String>> getSkillNames() async {
    final result = await _ssh.exec('ls ${paths.skillsDir}');
    return result.trim().split('\n').where((s) => s.isNotEmpty).toList();
  }

  Future<String?> readSkillMd(String skillName) async {
    try {
      return await _ssh.readFile('${paths.skillsDir}/$skillName/SKILL.md');
    } catch (_) {
      return null;
    }
  }

  // ── Gateway status ────────────────────────────────────────────────────

  Future<HermesGatewayState?> getGatewayState() async {
    try {
      final raw = await _ssh.readFile(paths.gatewayStateJSON);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return HermesGatewayState(
        pid:          json['pid'] as int?,
        state:        json['gateway_state'] as String? ?? 'unknown',
        exitReason:   json['exit_reason'] as String?,
        updatedAt:    json['updated_at'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Logs ──────────────────────────────────────────────────────────────

  Future<List<String>> getErrorLogTail({int lines = 100}) async {
    final result = await _ssh.exec('tail -n $lines ${paths.errorsLog}');
    return result.trim().split('\n').where((s) => s.isNotEmpty).toList();
  }

  Future<List<String>> getGatewayLogTail({int lines = 100}) async {
    final result = await _ssh.exec('tail -n $lines ${paths.gatewayLog}');
    return result.trim().split('\n').where((s) => s.isNotEmpty).toList();
  }

  Stream<String> followErrorLog() =>
      _ssh.execStream('tail -f ${paths.errorsLog}');
}

// Lightweight summary model
class HermesCostSummary {
  final double totalCostUSD;
  final int totalTokens;
  final int sessionCount;
  const HermesCostSummary({
    this.totalCostUSD = 0,
    this.totalTokens = 0,
    this.sessionCount = 0,
  });
}

class HermesGatewayState {
  final int? pid;
  final String state;
  final String? exitReason;
  final String? updatedAt;
  const HermesGatewayState({
    this.pid,
    required this.state,
    this.exitReason,
    this.updatedAt,
  });
  bool get isRunning => state == 'running';
}
```

---

## 10. New Providers

```dart
// lib/data/providers/hermes_data_providers.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/hermes/hermes_data_service.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../core/hermes/models/hermes_cron_job.dart';
import 'ssh_providers.dart';

final hermesDataServiceProvider = Provider<HermesDataService?>((ref) {
  final ssh = ref.watch(sshClientProvider);
  if (ssh == null) return null;
  return HermesDataService(ssh: ssh);
});

// Sessions
final hermesSessionsProvider = FutureProvider<List<HermesSession>>((ref) async {
  final svc = ref.watch(hermesDataServiceProvider);
  if (svc == null) return [];
  return svc.getSessions();
});

final hermesSessionMessagesProvider =
    FutureProvider.family<List<dynamic>, String>((ref, sessionId) async {
  final svc = ref.watch(hermesDataServiceProvider);
  if (svc == null) return [];
  return svc.getMessages(sessionId);
});

final hermesCostSummaryProvider = FutureProvider<HermesCostSummary>((ref) async {
  final svc = ref.watch(hermesDataServiceProvider);
  if (svc == null) return const HermesCostSummary();
  return svc.getCostSummary();
});

// Cron
final hermesCronJobsProvider = FutureProvider<CronJobsFile>((ref) async {
  final svc = ref.watch(hermesDataServiceProvider);
  if (svc == null) return const CronJobsFile(jobs: []);
  return svc.getCronJobs();
});

// Memory
final hermesMemoryProvider = FutureProvider<String>((ref) async {
  final svc = ref.watch(hermesDataServiceProvider);
  if (svc == null) return '';
  return svc.readMemory();
});

// Gateway state
final hermesGatewayStateProvider = FutureProvider<HermesGatewayState?>((ref) async {
  final svc = ref.watch(hermesDataServiceProvider);
  if (svc == null) return null;
  return svc.getGatewayState();
});

// Logs
final hermesErrorLogProvider = FutureProvider<List<String>>((ref) async {
  final svc = ref.watch(hermesDataServiceProvider);
  if (svc == null) return [];
  return svc.getErrorLogTail();
});
```

---

## 11. New UI Screens

### 11.1 Hermes Management Screen

Replace the stub `HermesStatusScreen` with a full tabbed management view:

```
/hermes  →  HermesManagementScreen
            ├── Sessions tab   (list + detail + search)
            ├── Memory tab     (MEMORY.md / USER.md / SOUL.md editor)
            ├── Cron tab       (jobs list + enable/disable)
            ├── Skills tab     (skill names + SKILL.md viewer)
            └── Logs tab       (errors.log + gateway.log tail)
```

```dart
// lib/features/hermes/hermes_management_screen.dart
// 5 tabs, each reading from their respective FutureProvider
// Pull-to-refresh on each tab invalidates the provider
```

### 11.2 Sessions Browser

Key UI elements (from Scarf):
- Session row: platform icon + title/id + message count + tool call count + cost + duration
- Tap → `SessionDetailScreen` with full message thread
- Search bar at top → calls `searchSessions()`
- Subagent sessions shown indented under their parent

### 11.3 Memory Editor

Key UI elements (from Scarf's `IOSMemoryViewModel`):
- Toggle between MEMORY / USER / SOUL files
- Plain text editor (markdown-aware but not rendered — user needs to see raw markdown)
- Character count vs limit (2,200 / 1,375 — from your live `config.yaml`)
- Save button enabled only when content has changed
- Discard confirmation on back if unsaved

### 11.4 Cron Manager

Key UI elements (from Scarf's `IOSCronViewModel`):
- Job row: name + schedule display + state icon + enabled toggle
- Last run time + next run time
- Last error (red text if present)
- Toggle switches write-through to `jobs.json` via SFTP immediately

### 11.5 Tool Call Card Widget

New shared widget for use in both Hermes session detail and future ACP chat:

```dart
// lib/shared/widgets/tool_call_card.dart
class ToolCallCard extends StatelessWidget {
  final HermesToolCall toolCall;
  final String? result;

  // Colour map from Scarf's tokens/colors-tool-kinds.html
  static Color kindColor(ToolKind kind) => switch (kind) {
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

---

## 12. OpenClaw Improvements

These are changes to the existing OpenClaw integration that are independent of SSH but must ship before public release.

### 12.1 Critical: Remove Hardcoded Credentials

In `lib/data/providers/core_providers.dart` lines 54–67:

**Delete:**
```dart
const String _kDebugHardcodedGatewayUrl = 'ws://100.78.70.2:18789';
const String _kDebugHardcodedGatewayToken = '<REDACTED_OLD_GATEWAY_TOKEN>';
```

**Replace with:**
```dart
final gatewayUrlProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('gateway_url') ?? '');

final gatewayTokenProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('gateway_token') ?? '');
```

This is a **pre-ship blocker**. Do not build the SSH sprint until this is fixed.

### 12.2 OpenClaw Log Viewer via SSH

Once SSH transport is available, add a log tab to Mission Control:

```dart
Future<List<String>> getOpenClawLogs({int lines = 100}) async {
  // OpenClaw runs as a systemd service on your VPS
  final result = await ssh.exec(
    'journalctl -u openclaw-gateway -n $lines --no-pager --output=short'
  );
  return result.trim().split('\n');
}
```

### 12.3 OpenClaw Doctor via SSH

```dart
Future<String> runOpenClawDoctor() async {
  return ssh.exec('openclaw doctor 2>&1');
}
```

This lets the app surface a "Diagnose" button in Gateway Connection settings that runs `openclaw doctor` remotely and shows the output — instead of requiring VPS terminal access.

---

## 13. ACP Protocol (Phase 3 — Future Sprint)

This is the richest Hermes integration but the most complex. Defer until SSH transport and management screens are working.

### What ACP Gives You

ACP (Agent Client Protocol) is `hermes acp` run as a subprocess via SSH exec. It streams JSON-RPC events that the REST API doesn't:

```
ToolCallStart    → Agent is running a terminal command
ToolCallProgress → "Found 3 files matching pattern"
AgentThought     → Internal reasoning step (if enabled)
AgentMessage     → Final response text
SessionUpdate    → Session ID, token count update
```

This enables **tool call cards inline in chat** — exactly what Scarf's chat screen shows and what makes the agent feel transparent.

### ACP Wire Protocol

```
stdin  → JSON-RPC requests (initialize, new_session, send_message)
stdout ← JSON-RPC responses + notification events
```

### Dart Implementation Sketch

```dart
// lib/core/hermes/hermes_acp_client.dart (Phase 3)
// Uses: ssh.execStream('hermes acp') for bidirectional stdio
// Wire: JSON-RPC over SSH exec channel
// Events: ToolCallStart, ToolCallProgress, AgentMessage, SessionUpdate
```

### When to Implement

After:
1. SSH transport is stable and tested on device
2. Sessions, memory, cron screens are working
3. REST chat via Hermes has been used by real users
4. Tool call card widget exists (from §11.5 above)

---

## 14. Complete New File List

```
lib/core/ssh/
├── hermes_ssh_client.dart          ← SSH transport (exec + SFTP)

lib/core/hermes/
├── hermes_paths.dart               ← All ~/.hermes/* paths
├── hermes_remote_sqlite.dart       ← sqlite3 -json via SSH exec
├── hermes_data_service.dart        ← High-level data access
├── models/
│   ├── hermes_session.dart
│   ├── hermes_message.dart         ← Includes HermesToolCall + ToolKind
│   └── hermes_cron_job.dart        ← Includes CronSchedule + CronJobsFile

lib/data/providers/
├── ssh_providers.dart              ← SSH client + reachability providers
└── hermes_data_providers.dart      ← All SSH-based data FutureProviders

lib/features/settings/
└── ssh_settings.dart               ← SSH host/port/user/auth settings screen

lib/features/hermes/
├── hermes_management_screen.dart   ← 5-tab management container
├── hermes_sessions_screen.dart     ← Session list + search
├── hermes_session_detail_screen.dart ← Message thread + tool calls
├── hermes_memory_screen.dart       ← MEMORY/USER/SOUL editor
├── hermes_cron_screen.dart         ← Cron job manager
├── hermes_skills_screen.dart       ← Skills list
└── hermes_logs_screen.dart         ← Log tail viewer

lib/shared/widgets/
└── tool_call_card.dart             ← ToolCall card for session detail + ACP
```

---

## 15. Changes to Existing Files

| File | Change |
|---|---|
| `pubspec.yaml` | Add `dartssh2: ^4.0.0` |
| `lib/data/providers/core_providers.dart` | Remove hardcoded credentials (critical) |
| `lib/features/settings/settings_screen.dart` | Add SSH Connection tile |
| `lib/app/router.dart` | Add `/settings/ssh`, `/hermes/*` routes |
| `lib/core/router/execution_path.dart` | `hermes` already added in Sprint 1 |
| `SPEC-HermesIntegration-v1.0.md` | This spec supersedes it for Phase 2+ |

---

## 16. Implementation Order

### Pre-Sprint — Credential Fix (1 hour)
1. Remove hardcoded credentials from `core_providers.dart`
2. Test that existing Settings → Gateway Configuration → Save still connects

### Sprint 1 — REST Chat (Already specced — current sprint)
Per `SPEC-HermesIntegration-v1.0.md`

### Sprint 2 — SSH Transport + Settings (3–4 days)
3. Add `dartssh2` to pubspec
4. Create `HermesSSHClient`
5. Create `ssh_providers.dart`
6. Create `ssh_settings.dart` + route
7. Add SSH tile to Settings screen
8. Test SSH connect from physical Android device to VPS

### Sprint 3 — Hermes Management (4–5 days)
9. Create `hermes_paths.dart`
10. Create `HermesRemoteSqlite`
11. Create `HermesDataService`
12. Create `hermes_data_providers.dart`
13. Build Sessions screen (list + detail)
14. Build Memory editor
15. Build Cron manager
16. Build Skills list
17. Build Log viewer

### Sprint 4 — OpenClaw Diagnostics (1–2 days)
18. Add OpenClaw log viewer via SSH
19. Add OpenClaw doctor via SSH
20. Wire both into Mission Control / Settings

### Sprint 5 — ACP Chat (1 week)
21. Build `HermesACPClient`
22. Build `ToolCallCard` widget
23. Wire ACP into chat when Hermes path + SSH are both configured
24. Show tool call progress inline in chat bubbles

---

## 17. For Your Developer — One Paragraph

The architectural change this sprint makes is adding a second channel — SSH — alongside the existing WebSocket (OpenClaw) and REST (Hermes chat). Everything that isn't exposed via REST in Hermes v0.12 (sessions, memory, cron, skills, logs) lives on the VPS filesystem and is accessible via SSH. The `dartssh2` package handles the SSH connection; the app then runs `sqlite3 -readonly -json` commands remotely to query Hermes's SQLite database, and uses SFTP to read/write memory and cron files. This approach is verified and production-tested — it's exactly what the Scarf iOS app does using the Citadel SSH library. The data models in this spec are direct Dart translations of Scarf's Swift structs, and the SQL queries are the same ones Scarf runs against `~/.hermes/state.db`. The hardcoded credential removal in `core_providers.dart` is a pre-sprint blocker — that must be the first commit. Everything else follows in the order defined in §16.

---

*CARMEN PTY LTD — Pocket Claw Multi-Transport Integration Spec v1.0*  
*2026-05-08 — Verified against live VPS (100.78.70.2) and Scarf v2.7.1 source*
