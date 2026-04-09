/// Data access object for the messages table
library;

import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

class MessageDao {
  final AppDatabase _appDb;

  MessageDao({AppDatabase? appDatabase})
      : _appDb = appDatabase ?? AppDatabase();

  Future<Database> get _db => _appDb.getDatabase();

  /// Insert a single message row.
  Future<void> insert(Map<String, dynamic> row) async {
    final db = await _db;
    await db.insert(
      'messages',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple message rows in a batch.
  Future<void> insertAll(List<Map<String, dynamic>> rows) async {
    final db = await _db;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Retrieve a message by its primary key.
  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await _db;
    final results = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  /// Get all messages for a session, ordered by timestamp ascending.
  Future<List<Map<String, dynamic>>> getBySessionKey(
    String sessionKey, {
    int? limit,
  }) async {
    final db = await _db;
    return db.query(
      'messages',
      where: 'session_key = ?',
      whereArgs: [sessionKey],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  /// Get the most recent N messages for a session (newest first).
  Future<List<Map<String, dynamic>>> getRecent(
    String sessionKey, {
    int limit = 50,
  }) async {
    final db = await _db;
    final results = await db.query(
      'messages',
      where: 'session_key = ?',
      whereArgs: [sessionKey],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    // Return in chronological order
    return results.reversed.toList();
  }

  /// Delete a single message.
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all messages for a session.
  Future<void> deleteBySessionKey(String sessionKey) async {
    final db = await _db;
    await db.delete(
      'messages',
      where: 'session_key = ?',
      whereArgs: [sessionKey],
    );
  }

  /// Count messages in a session.
  Future<int> countBySessionKey(String sessionKey) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages WHERE session_key = ?',
      [sessionKey],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Update a message row.
  Future<void> update(String id, Map<String, dynamic> values) async {
    final db = await _db;
    await db.update(
      'messages',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
