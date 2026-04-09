/// Application database initialization and management
library;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _dbName = 'pocket_claw.db';
  static const _dbVersion = 1;

  Database? _database;

  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Future<Database> getDatabase() async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> initialize() async {
    _database = await _initDatabase();
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        session_key TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        source TEXT,
        timestamp TEXT NOT NULL,
        image_url TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_session ON messages (session_key)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_timestamp ON messages (timestamp)
    ''');

    await db.execute('''
      CREATE TABLE notes_index (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        folder TEXT NOT NULL DEFAULT 'general',
        tags_json TEXT NOT NULL DEFAULT '[]',
        created TEXT NOT NULL,
        modified TEXT NOT NULL,
        sync_enabled INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL DEFAULT 'local',
        file_path TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_notes_folder ON notes_index (folder)
    ''');

    await db.execute('''
      CREATE INDEX idx_notes_modified ON notes_index (modified)
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        key TEXT PRIMARY KEY,
        started_at TEXT NOT NULL,
        message_count INTEGER NOT NULL DEFAULT 0,
        token_count INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
