/// Data access object for the notes_index table
library;

import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

class NotesDao {
  final AppDatabase _appDb;

  NotesDao({AppDatabase? appDatabase})
      : _appDb = appDatabase ?? AppDatabase();

  Future<Database> get _db => _appDb.getDatabase();

  /// Insert or replace a note index row.
  Future<void> upsert(Map<String, dynamic> row) async {
    final db = await _db;
    await db.insert(
      'notes_index',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve a note index entry by id.
  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await _db;
    final results = await db.query(
      'notes_index',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  /// Get all note index entries, ordered by modified descending.
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db;
    return db.query('notes_index', orderBy: 'modified DESC');
  }

  /// Get notes in a specific folder.
  Future<List<Map<String, dynamic>>> getByFolder(String folder) async {
    final db = await _db;
    return db.query(
      'notes_index',
      where: 'folder = ?',
      whereArgs: [folder],
      orderBy: 'modified DESC',
    );
  }

  /// Full-text search across title, folder, and tags.
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 10,
  }) async {
    final db = await _db;
    final pattern = '%$query%';
    return db.query(
      'notes_index',
      where: 'title LIKE ? OR folder LIKE ? OR tags_json LIKE ?',
      whereArgs: [pattern, pattern, pattern],
      orderBy: 'modified DESC',
      limit: limit,
    );
  }

  /// Get notes that have sync enabled.
  Future<List<Map<String, dynamic>>> getSyncEnabled() async {
    final db = await _db;
    return db.query(
      'notes_index',
      where: 'sync_enabled = 1',
      orderBy: 'modified DESC',
    );
  }

  /// Delete a note index entry.
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('notes_index', where: 'id = ?', whereArgs: [id]);
  }

  /// Update specific columns on a note.
  Future<void> update(String id, Map<String, dynamic> values) async {
    final db = await _db;
    await db.update(
      'notes_index',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count all notes.
  Future<int> count() async {
    final db = await _db;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM notes_index');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
