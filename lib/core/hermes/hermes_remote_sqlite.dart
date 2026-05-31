/// Remote SQLite query runner — invokes `sqlite3 -readonly -json` on the
/// VPS via SSH exec, parses the JSON array result. Falls back to a
/// Python-stdlib reader if the `sqlite3` CLI isn't installed on the host
/// (`exit 127`) — Python ships preinstalled on virtually every modern
/// distro, so this turns "feature dead" into "feature works" without the
/// user having to SSH and apt-install anything.
///
/// Approach copied from Scarf's RemoteSQLiteBackend. Expected latency
/// 50–100 ms per query on a warm SSH connection.
/// SPEC-MultiTransport §7.
library;

import 'dart:convert';

import '../ssh/hermes_ssh_client.dart';

class HermesRemoteSqlite {
  final HermesSshClient _ssh;
  final String dbPath;

  HermesRemoteSqlite({
    required HermesSshClient ssh,
    this.dbPath = '~/.hermes/state.db',
  }) : _ssh = ssh;

  /// Execute a single SQL statement. Returns parsed rows.
  /// Returns an empty list when the statement yields no rows or the
  /// reader emits empty output (e.g. an UPDATE that ran fine but
  /// printed nothing).
  Future<List<Map<String, dynamic>>> query(String sql) async {
    // The path needs `~` to expand. Bash doesn't expand `~` inside
    // single quotes, so swap it for `$HOME` and use double quotes
    // (which DO expand env vars) while keeping the SQL itself in
    // single quotes (so its `$` / backticks stay literal).
    final shellPath = dbPath.startsWith('~')
        ? '\$HOME${dbPath.substring(1)}'
        : dbPath;

    // Try the native sqlite3 CLI first — fastest, well-defined output.
    try {
      final command =
          'sqlite3 -readonly -json "$shellPath" ${_quoteSql(sql)}';
      final raw = await _ssh.exec(command);
      return _parse(raw);
    } on SshCommandException catch (e) {
      // Exit 127 = command not found. Fall back to Python.
      // Other non-zero exits are real query errors — re-throw so the UI
      // can surface them rather than silently masking with the fallback.
      if (e.exitCode != 127) rethrow;
    }

    // Python fallback. `sqlite3` is in the stdlib, no pip install
    // needed. Python's os.path.expanduser() handles the `~` itself
    // so we can keep the path single-quoted here without trouble.
    final pyScript = r'''
import sqlite3, json, os, sys
db = os.path.expanduser(sys.argv[1])
sql = sys.argv[2]
conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
conn.row_factory = sqlite3.Row
rows = [dict(r) for r in conn.execute(sql).fetchall()]
print(json.dumps(rows, default=str))
''';
    final command = "python3 -c ${_singleQuote(pyScript)} "
        "${_singleQuote(dbPath)} ${_singleQuote(sql)}";
    try {
      final raw = await _ssh.exec(command);
      return _parse(raw);
    } on SshCommandException catch (e) {
      if (e.exitCode == 127) {
        throw const SqliteReaderUnavailableException();
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _parse(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is List) {
        return [
          for (final r in decoded)
            if (r is Map<String, dynamic>) r,
        ];
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Wrap the SQL string for a single-quoted shell argument; double any
  /// internal single-quotes per the standard POSIX escape pattern.
  String _quoteSql(String sql) => _singleQuote(sql);

  /// POSIX single-quote escape: any embedded `'` is replaced with `'\''`.
  String _singleQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";
}

/// Thrown when neither `sqlite3` nor `python3` are available on the
/// gateway host. Surfaced to the UI so the user gets a clean instruction
/// instead of a stack trace.
class SqliteReaderUnavailableException implements Exception {
  const SqliteReaderUnavailableException();

  @override
  String toString() =>
      'Neither `sqlite3` nor `python3` is installed on the gateway host. '
      'Install one with `sudo apt install sqlite3` (or python3) and retry.';
}
