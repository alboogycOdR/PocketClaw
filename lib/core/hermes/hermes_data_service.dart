/// High-level Hermes data access over SSH — sessions, messages, search,
/// memory, cron, skills, gateway state, logs. SPEC-MultiTransport §9.
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../ssh/hermes_ssh_client.dart';
import 'hermes_paths.dart';
import 'hermes_remote_sqlite.dart';
import 'models/hermes_analytics.dart';
import 'models/hermes_channel.dart';
import 'models/hermes_cron_job.dart';
import 'models/hermes_memory_entry.dart';
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

  /// Daily token + cost rollup for the last [days] days. Powers the
  /// 7-day area chart on the Analytics tab.
  Future<List<HermesDailyStats>> getDailyStats({int days = 7}) async {
    final rows = await _db.query('''
      SELECT
        date(started_at, 'unixepoch') AS day,
        COALESCE(SUM(input_tokens), 0)  AS input_tokens,
        COALESCE(SUM(output_tokens), 0) AS output_tokens,
        COUNT(*) AS sessions,
        COALESCE(SUM(
          COALESCE(actual_cost_usd, estimated_cost_usd)
        ), 0.0) AS cost_usd
      FROM sessions
      WHERE started_at > strftime('%s', 'now', '-$days days')
      GROUP BY day
      ORDER BY day ASC
    ''');
    return rows.map(HermesDailyStats.fromRow).toList();
  }

  /// Per-model breakdown of token usage and cost. Powers the cost
  /// ledger on the Analytics tab.
  Future<List<HermesModelStats>> getCostByModel() async {
    final rows = await _db.query('''
      SELECT
        COALESCE(model, 'unknown') AS model,
        COALESCE(SUM(input_tokens + output_tokens), 0) AS total_tokens,
        COALESCE(SUM(
          COALESCE(actual_cost_usd, estimated_cost_usd)
        ), 0.0) AS cost_usd,
        COUNT(*) AS session_count
      FROM sessions
      GROUP BY model
      ORDER BY cost_usd DESC
    ''');
    return rows.map(HermesModelStats.fromRow).toList();
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

  // ── Memory entries (§-delimited) ────────────────────────────────────
  //
  // MEMORY.md is one append-only file but Hermes treats it as a list
  // of timestamped entries separated by `§` on its own line. Splitting
  // here lets the UI render each entry as a card with edit + delete
  // affordances instead of one giant textarea.

  static const String _entryDelimiter = '§';

  Future<List<HermesMemoryEntry>> getMemoryEntries() async {
    final raw = await readMemory();
    return parseMemoryEntries(raw);
  }

  /// Pure helper — exposed for testing and so the UI can preview a
  /// parsed view of any string without an SSH round-trip.
  static List<HermesMemoryEntry> parseMemoryEntries(String raw) {
    if (raw.trim().isEmpty) return const [];
    final out = <HermesMemoryEntry>[];
    final blocks = raw.split(RegExp('^\\s*$_entryDelimiter\\s*\$',
        multiLine: true));
    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;
      out.add(HermesMemoryEntry.fromBlock(trimmed));
    }
    return out;
  }

  String _serializeEntries(List<HermesMemoryEntry> entries) {
    if (entries.isEmpty) return '';
    return entries.map((e) => e.toBlock()).join('\n\n$_entryDelimiter\n\n');
  }

  Future<void> addMemoryEntry(String body) async {
    final entries = [...await getMemoryEntries()];
    entries.add(HermesMemoryEntry(
      timestamp: DateTime.now().toUtc(),
      body: body.trim(),
    ));
    await writeMemory(_serializeEntries(entries));
  }

  Future<void> updateMemoryEntry(int index, String body) async {
    final entries = [...await getMemoryEntries()];
    if (index < 0 || index >= entries.length) {
      throw RangeError('Memory entry index $index out of range');
    }
    entries[index] = entries[index].copyWith(body: body.trim());
    await writeMemory(_serializeEntries(entries));
  }

  Future<void> deleteMemoryEntry(int index) async {
    final entries = [...await getMemoryEntries()];
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    await writeMemory(_serializeEntries(entries));
  }

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

  /// Append a new cron job. Returns the saved job (with the
  /// freshly-minted id) so the UI can update its list optimistically.
  Future<HermesCronJob> createCronJob(HermesCronJob job) async {
    final file = await getCronJobs();
    final id = job.id.isEmpty
        ? 'job_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        : job.id;
    final saved = HermesCronJob(
      id: id,
      name: job.name,
      prompt: job.prompt,
      schedule: job.schedule,
      enabled: job.enabled,
      state: job.state,
      skills: job.skills,
      model: job.model,
      deliver: job.deliver,
      nextRunAt: job.nextRunAt,
      lastRunAt: job.lastRunAt,
      lastError: job.lastError,
      workdir: job.workdir,
    );
    await saveCronJobs(CronJobsFile(jobs: [...file.jobs, saved]));
    return saved;
  }

  Future<void> deleteCronJob(String jobId) async {
    final file = await getCronJobs();
    await saveCronJobs(CronJobsFile(
      jobs: file.jobs.where((j) => j.id != jobId).toList(),
    ));
  }

  // ── Channels ────────────────────────────────────────────────────────
  //
  // The four inbound channels (telegram/discord/slack/whatsapp) live
  // under top-level keys in config.yaml. Bot tokens live in .env and
  // are exposed only as presence booleans — never displayed or
  // written by the app.

  /// Read all four channels' settings + their token presence. Channels
  /// missing from the YAML are returned with an empty settings map so
  /// the UI can still offer to add them.
  Future<HermesChannelsBundle> getChannelsBundle() async {
    final yamlRaw = await _ssh.readFile(paths.configYAML);
    final envPresence = await _readEnvTokenPresence();

    Map? root;
    try {
      final parsed = loadYaml(yamlRaw);
      if (parsed is Map) root = parsed;
    } catch (_) {
      root = null;
    }

    final out = <HermesChannelConfig>[];
    for (final kind in HermesChannelKind.values) {
      final raw = root?[kind.yamlKey];
      final settings = <String, dynamic>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          settings['$k'] = _yamlToPlain(v);
        });
      }
      out.add(HermesChannelConfig(
        kind: kind,
        settings: settings,
        tokenPresent: envPresence[kind.envTokenKey] == true,
      ));
    }
    return HermesChannelsBundle(channels: out);
  }

  /// Surgically rewrite one channel's settings, preserving comments
  /// and unrelated keys via `yaml_edit`. If the channel key is
  /// missing from the file, a new one is appended at the bottom.
  Future<void> saveChannelSettings(
    HermesChannelKind kind,
    Map<String, dynamic> settings,
  ) async {
    final yamlRaw = await _ssh.readFile(paths.configYAML);
    final editor = YamlEditor(yamlRaw);

    // yaml_edit requires the top-level key to exist before nested
    // updates. If it's missing, write the whole map at the root.
    try {
      editor.update([kind.yamlKey], settings);
    } catch (_) {
      // First-time write — append the key.
      editor.update([kind.yamlKey], settings);
    }

    await _ssh.writeFile(paths.configYAML, editor.toString());
  }

  /// Parse `.env` to find which channel tokens are populated. Returns
  /// `{ENV_KEY: hasNonEmptyValue}`. Tolerates absent file (treat as
  /// no tokens). The actual values never leave this method.
  Future<Map<String, bool>> _readEnvTokenPresence() async {
    String raw;
    try {
      raw = await _ssh.readFile(paths.envFile);
    } catch (_) {
      return const {};
    }
    final out = <String, bool>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();
      // Strip surrounding quotes.
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      out[key] = value.isNotEmpty;
    }
    return out;
  }

  /// Convert a `yaml` package value (YamlMap / YamlList / scalar) into
  /// a plain Dart structure that the UI can edit. Nested maps stay
  /// nested.
  dynamic _yamlToPlain(dynamic v) {
    if (v is YamlMap) {
      return v.map((k, val) => MapEntry('$k', _yamlToPlain(val)));
    }
    if (v is YamlList) {
      return v.map(_yamlToPlain).toList();
    }
    return v;
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
