/// Persistence layer for session metadata and message history.
library;

import 'package:sqflite/sqflite.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/message_dao.dart';
import '../../data/models/chat_message.dart';

class SessionHistory {
  final AppDatabase _appDb;
  final MessageDao _messageDao;

  SessionHistory({
    AppDatabase? appDatabase,
    MessageDao? messageDao,
  })  : _appDb = appDatabase ?? AppDatabase(),
        _messageDao = messageDao ?? MessageDao();

  Future<Database> get _db => _appDb.getDatabase();

  /// Persist a session's messages and update the sessions table.
  /// [mode] identifies which chat mode this session belongs to
  /// (local / cloud / openclaw). Defaults to 'openclaw' for legacy.
  Future<void> saveSession(
    String key,
    List<ChatMessage> messages, {
    String mode = 'openclaw',
  }) async {
    final db = await _db;

    // Upsert session row
    await db.insert(
      'sessions',
      {
        'key': key,
        'started_at': messages.isNotEmpty
            ? messages.first.timestamp.toIso8601String()
            : DateTime.now().toIso8601String(),
        'message_count': messages.length,
        'token_count': _estimateTokens(messages),
        'is_active': 1,
        'mode': mode,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Batch-insert messages (replace existing)
    final rows = messages
        .map((m) => {
              'id': m.id,
              'session_key': key,
              'role': m.role.name,
              'content': m.content,
              'source': m.source?.name,
              'timestamp': m.timestamp.toIso8601String(),
              'image_url': m.imageUrl,
              'mode': mode,
            })
        .toList();
    await _messageDao.insertAll(rows);
  }

  /// Load all messages for a given session key.
  Future<List<ChatMessage>> loadSession(String key) async {
    final rows = await _messageDao.getBySessionKey(key);
    return rows.map(_rowToMessage).toList();
  }

  /// Look up the mode tag a session was stored under. Returns null if
  /// the session row doesn't exist or has no mode column populated.
  /// Used by [SessionManager.loadSession] to refuse cross-mode loads.
  Future<String?> modeOf(String key) async {
    final db = await _db;
    final rows = await db.query(
      'sessions',
      columns: ['mode'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['mode'] as String?;
  }

  /// List saved sessions, most recent first. If [mode] is provided,
  /// only sessions for that mode are returned.
  Future<List<SessionInfo>> listSessions({String? mode}) async {
    final db = await _db;
    final rows = await db.query(
      'sessions',
      where: mode != null ? 'mode = ?' : null,
      whereArgs: mode != null ? [mode] : null,
      orderBy: 'started_at DESC',
    );
    return rows.map((r) => SessionInfo.fromRow(r)).toList();
  }

  /// Delete a session and its messages.
  Future<void> deleteSession(String key) async {
    final db = await _db;
    await _messageDao.deleteBySessionKey(key);
    await db.delete('sessions', where: 'key = ?', whereArgs: [key]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ChatMessage _rowToMessage(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as String,
        role: MessageRole.values.firstWhere(
          (r) => r.name == row['role'],
          orElse: () => MessageRole.user,
        ),
        content: row['content'] as String,
        source: row['source'] != null
            ? MessageSource.values.firstWhere(
                (s) => s.name == row['source'],
                orElse: () => MessageSource.local,
              )
            : null,
        timestamp: DateTime.parse(row['timestamp'] as String),
        imageUrl: row['image_url'] as String?,
      );

  /// Rough token estimate (4 chars \u2248 1 token).
  int _estimateTokens(List<ChatMessage> messages) {
    final totalChars =
        messages.fold<int>(0, (sum, m) => sum + m.content.length);
    return (totalChars / 4).ceil();
  }
}

/// Lightweight session metadata for list views.
class SessionInfo {
  final String key;
  final DateTime startedAt;
  final int messageCount;
  final int tokenCount;
  final bool isActive;
  final String mode;

  const SessionInfo({
    required this.key,
    required this.startedAt,
    required this.messageCount,
    required this.tokenCount,
    required this.isActive,
    this.mode = 'openclaw',
  });

  factory SessionInfo.fromRow(Map<String, dynamic> row) => SessionInfo(
        key: row['key'] as String,
        startedAt: DateTime.parse(row['started_at'] as String),
        messageCount: row['message_count'] as int? ?? 0,
        tokenCount: row['token_count'] as int? ?? 0,
        isActive: (row['is_active'] as int? ?? 0) == 1,
        mode: (row['mode'] as String?) ?? 'openclaw',
      );
}
