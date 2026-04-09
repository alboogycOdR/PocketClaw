/// Key-value settings storage DAO
library;

import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

class SettingsDao {
  final AppDatabase _appDb;

  SettingsDao({AppDatabase? appDatabase})
      : _appDb = appDatabase ?? AppDatabase();

  Future<Database> get _db => _appDb.getDatabase();

  /// Get a setting value by key, or null if not found.
  Future<String?> get(String key) async {
    final db = await _db;
    final results = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String;
  }

  /// Set a key-value pair (insert or update).
  Future<void> set(String key, String value) async {
    final db = await _db;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete a setting.
  Future<void> delete(String key) async {
    final db = await _db;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  /// Get all settings as a map.
  Future<Map<String, String>> getAll() async {
    final db = await _db;
    final rows = await db.query('settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  /// Check if a setting key exists.
  Future<bool> exists(String key) async {
    final value = await get(key);
    return value != null;
  }

  /// Get a setting as an int, with an optional default.
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final value = await get(key);
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Get a setting as a bool (stored as "true"/"false").
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final value = await get(key);
    if (value == null) return defaultValue;
    return value == 'true';
  }

  /// Set a bool setting.
  Future<void> setBool(String key, bool value) async {
    await set(key, value.toString());
  }

  /// Set an int setting.
  Future<void> setInt(String key, int value) async {
    await set(key, value.toString());
  }
}
