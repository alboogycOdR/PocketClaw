library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/ambient/models/tv_channel.dart';

class TvDatabase {
  static const _dbName = 'tv_channels.db';
  Database? _db;

  Future<void> ensureReady() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
        CREATE TABLE favourites (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          group_title TEXT NOT NULL,
          stream_url TEXT NOT NULL,
          logo_url TEXT,
          is_hd INTEGER DEFAULT 1,
          is_geo INTEGER DEFAULT 0,
          is_youtube INTEGER DEFAULT 0,
          is_custom INTEGER DEFAULT 0,
          added_at INTEGER NOT NULL
        )
      ''');

        await db.execute('''
        CREATE TABLE hidden_channels (
          id TEXT PRIMARY KEY,
          stream_url TEXT NOT NULL,
          name TEXT NOT NULL,
          hidden_at INTEGER NOT NULL
        )
      ''');

        await db.execute('''
        CREATE TABLE custom_channels (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          group_title TEXT NOT NULL DEFAULT 'Custom',
          stream_url TEXT NOT NULL UNIQUE,
          logo_url TEXT,
          is_hd INTEGER DEFAULT 1,
          created_at INTEGER NOT NULL
        )
      ''');
      },
    );
  }

  Database get _database {
    final database = _db;
    if (database == null) {
      throw StateError('TvDatabase not ready. Call ensureReady() first.');
    }
    return database;
  }

  Future<void> addFavourite(TvChannel channel) async {
    await _database.insert('favourites', {
      ...channel.toMap(),
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavourite(String channelId) async {
    await _database.delete(
      'favourites',
      where: 'id = ?',
      whereArgs: [channelId],
    );
  }

  Future<List<TvChannel>> getFavourites() async {
    final rows = await _database.query('favourites', orderBy: 'added_at DESC');
    return rows.map(TvChannel.fromMap).toList();
  }

  Future<Set<String>> getFavouriteIds() async {
    final rows = await _database.query('favourites', columns: ['id']);
    return rows.map((row) => row['id'] as String).toSet();
  }

  Future<void> hideChannel(TvChannel channel) async {
    await _database.insert('hidden_channels', {
      'id': channel.id,
      'stream_url': channel.streamUrl,
      'name': channel.name,
      'hidden_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unhideChannel(String channelId) async {
    await _database.delete(
      'hidden_channels',
      where: 'id = ?',
      whereArgs: [channelId],
    );
  }

  Future<Set<String>> getHiddenIds() async {
    final rows = await _database.query('hidden_channels', columns: ['id']);
    return rows.map((row) => row['id'] as String).toSet();
  }

  Future<List<Map<String, dynamic>>> getHiddenChannels() {
    return _database.query('hidden_channels', orderBy: 'hidden_at DESC');
  }

  Future<void> clearAllHidden() async {
    await _database.delete('hidden_channels');
  }

  Future<void> addCustomChannel(TvChannel channel) async {
    await _database.insert('custom_channels', {
      'id': channel.id,
      'name': channel.name,
      'group_title': channel.groupTitle,
      'stream_url': channel.streamUrl,
      'logo_url': channel.logoUrl,
      'is_hd': channel.isHD ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> addCustomChannels(List<TvChannel> channels) async {
    if (channels.isEmpty) return 0;
    final existingRows = await _database.query(
      'custom_channels',
      columns: ['stream_url'],
    );
    final existingUrls = existingRows
        .map((row) => (row['stream_url'] as String).trim())
        .toSet();
    var inserted = 0;
    await _database.transaction((txn) async {
      for (final channel in channels) {
        final normalizedUrl = channel.streamUrl.trim();
        if (existingUrls.contains(normalizedUrl)) continue;
        final id = channel.id.startsWith('custom_')
            ? channel.id
            : 'custom_${channel.id}';
        await txn.insert('custom_channels', {
          'id': id,
          'name': channel.name,
          'group_title': channel.groupTitle,
          'stream_url': normalizedUrl,
          'logo_url': channel.logoUrl,
          'is_hd': channel.isHD ? 1 : 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        existingUrls.add(normalizedUrl);
        inserted++;
      }
    });
    return inserted;
  }

  Future<void> deleteCustomChannel(String channelId) async {
    await _database.delete(
      'custom_channels',
      where: 'id = ?',
      whereArgs: [channelId],
    );
  }

  Future<List<TvChannel>> getCustomChannels() async {
    final rows = await _database.query(
      'custom_channels',
      orderBy: 'created_at ASC',
    );
    return rows.map(TvChannel.fromMap).toList();
  }

  Future<bool> customChannelExists(String streamUrl) async {
    final rows = await _database.query(
      'custom_channels',
      where: 'stream_url = ?',
      whereArgs: [streamUrl],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}

final tvDatabase = TvDatabase();
