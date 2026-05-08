/// High-level Hermes data access over SSH — sessions, messages, search,
/// memory, cron, skills, gateway state, logs. SPEC-MultiTransport §9.
library;

import 'dart:convert';

import '../ssh/hermes_ssh_client.dart';
import 'hermes_paths.dart';
import 'hermes_remote_sqlite.dart';
import 'models/hermes_cron_job.dart';
import 'models/hermes_message.dart';
import 'models/hermes_session.dart';

class HermesDataService {
  final HermesSshClient _ssh;
  final HermesRemoteSqlite _db;
  final HermesPaths paths;

  HermesDataService({
    required HermesSshClient ssh,
    HermesPaths? hermesPaths,
  })  : _ssh = ssh,
        paths = hermesPaths ?? const HermesPaths(),
        _db = HermesRemoteSqlite(ssh: ssh);

  // ── Sessions ────────────────────────────────────────────────────────

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
    final escaped = sessionId.replaceAll("'", "''");
    final rows = await _db.query('''
      SELECT id, session_id, role, content, tool_name,
             tool_calls, timestamp
      FROM messages
      WHERE session_id = '$escaped'
      ORDER BY timestamp ASC
    ''');
    return rows.map(HermesMessage.fromSqliteRow).toList();
  }

  Future<List<HermesSession>> searchSessions(String query) async {
    if (query.trim().isEmpty) return const [];
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
      totalCostUSD: (row['total_cost'] as num?)?.toDouble() ?? 0,
      totalTokens: (row['total_tokens'] as num?)?.toInt() ?? 0,
      sessionCount: (row['session_count'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Memory ──────────────────────────────────────────────────────────

  Future<String> readMemory() => _ssh.readFile(paths.memoryMD);
  Future<String> readUserProfile() => _ssh.readFile(paths.userMD);
  Future<String> readSoul() => _ssh.readFile(paths.soulMD);

  Future<void> writeMemory(String content) =>
      _ssh.writeFile(paths.memoryMD, content);
  Future<void> writeUserProfile(String content) =>
      _ssh.writeFile(paths.userMD, content);
  Future<void> writeSoul(String content) =>
      _ssh.writeFile(paths.soulMD, content);

  // ── Cron ────────────────────────────────────────────────────────────

  Future<CronJobsFile> getCronJobs() async {
    try {
      final raw = await _ssh.readFile(paths.cronJobsJSON);
      if (raw.trim().isEmpty) return const CronJobsFile(jobs: []);
      return CronJobsFile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // jobs.json may not exist yet on a fresh install — treat as empty.
      return const CronJobsFile(jobs: []);
    }
  }

  Future<void> saveCronJobs(CronJobsFile file) async {
    final json = const JsonEncoder.withIndent('  ').convert(file.toJson());
    await _ssh.writeFile(paths.cronJobsJSON, json);
  }

  Future<void> toggleCronJob(String jobId, {required bool enabled}) async {
    final file = await getCronJobs();
    final updated = CronJobsFile(
      jobs: [
        for (final j in file.jobs)
          if (j.id == jobId) j.copyWith(enabled: enabled) else j,
      ],
    );
    await saveCronJobs(updated);
  }

  // ── Skills ──────────────────────────────────────────────────────────

  Future<List<String>> getSkillNames() async {
    try {
      final names = await _ssh.listDirectory(paths.skillsDir);
      // Skills are subdirectories — filter out stray files like README.md.
      return names.where((n) => !n.contains('.')).toList()..sort();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> readSkillMd(String skillName) async {
    try {
      return await _ssh.readFile('${paths.skillsDir}/$skillName/SKILL.md');
    } catch (_) {
      return null;
    }
  }

  // ── Gateway status ──────────────────────────────────────────────────

  Future<HermesGatewayState?> getGatewayState() async {
    try {
      final raw = await _ssh.readFile(paths.gatewayStateJSON);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return HermesGatewayState(
        pid: (json['pid'] as num?)?.toInt(),
        state: json['gateway_state'] as String? ?? 'unknown',
        exitReason: json['exit_reason'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Logs ────────────────────────────────────────────────────────────

  Future<List<String>> getErrorLogTail({int lines = 100}) async =>
      _tailLog(paths.errorsLog, lines);

  Future<List<String>> getGatewayLogTail({int lines = 100}) async =>
      _tailLog(paths.gatewayLog, lines);

  Future<List<String>> getAgentLogTail({int lines = 100}) async =>
      _tailLog(paths.agentLog, lines);

  Future<List<String>> _tailLog(String path, int lines) async {
    try {
      final raw = await _ssh.exec('tail -n $lines $path');
      return raw.split('\n').where((l) => l.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Stream<String> followErrorLog() =>
      _ssh.execStream('tail -f ${paths.errorsLog}');
}

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
