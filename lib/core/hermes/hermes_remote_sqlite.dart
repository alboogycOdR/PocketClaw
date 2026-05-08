/// Remote SQLite query runner — invokes `sqlite3 -readonly -json` on the
/// VPS via SSH exec, parses the JSON array result.
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
  /// Returns an empty list when the statement yields no rows or sqlite3
  /// emits empty output (e.g. an UPDATE that ran fine but printed nothing).
  Future<List<Map<String, dynamic>>> query(String sql) async {
    final command =
        "sqlite3 -readonly -json '$dbPath' ${_quoteSql(sql)}";
    final raw = await _ssh.exec(command);
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Wrap the SQL string for a single-quoted shell argument; double any
  /// internal single-quotes per the standard POSIX escape pattern.
  String _quoteSql(String sql) {
    final escaped = sql.replaceAll("'", r"'\''");
    return "'$escaped'";
  }
}
