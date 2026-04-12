/// Application database initialization and management
library;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _dbName = 'pocket_claw.db';
  static const _dbVersion = 2;

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

    try {
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      // Migration or open failed — log and re-throw so caller can fall back
      // to a fresh DB or in-memory mode. Does NOT delete data automatically.
      // ignore: avoid_print
      print('AppDatabase: open failed: $e');
      rethrow;
    }
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

    // v2 tables — project memory system
    await _createV2Tables(db);
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        phase TEXT NOT NULL DEFAULT 'planning',
        budget_used INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_brief_update INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_tickets (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        content TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_project_tickets_project
        ON project_tickets (project_id, created_at DESC)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_agents (
        project_id TEXT NOT NULL,
        agent_name TEXT NOT NULL,
        role TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'idle',
        PRIMARY KEY (project_id, agent_name)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS paperclip_companies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mission TEXT,
        budget_limit INTEGER,
        governance_mode TEXT,
        last_sync INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS paperclip_events (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        payload TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_paperclip_events_company
        ON paperclip_events (company_id, created_at DESC)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS model_downloads (
        model_id TEXT PRIMARY KEY,
        status TEXT NOT NULL DEFAULT 'pending',
        progress REAL NOT NULL DEFAULT 0,
        local_path TEXT,
        downloaded_at INTEGER,
        error_message TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Run each version step in isolation so a failure in one doesn't
    // abort the whole migration.
    if (oldVersion < 2) {
      try {
        await _createV2Tables(db);
      } catch (e) {
        // ignore: avoid_print
        print('AppDatabase: v2 migration failed (non-fatal): $e');
        // v2 tables use IF NOT EXISTS — safe to continue.
      }
    }
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
