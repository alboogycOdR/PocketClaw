library;

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/ambient/models/tv_channel.dart';
import '../../features/ambient/models/tv_epg.dart';

class TvDatabase {
  static const _dbName = 'tv_channels.db';
  static const _dbVersion = 2;
  Database? _db;

  Future<void> ensureReady() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, _) async {
        await _createCoreTables(db);
        await _createEpgTables(db);
        await _createHealthTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
      },
    );
  }

  Future<void> _createCoreTables(Database db) async {
    await db.execute('''
      CREATE TABLE favourites (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        group_title TEXT NOT NULL,
        stream_url TEXT NOT NULL,
        logo_url TEXT,
        tvg_id TEXT,
        tvg_name TEXT,
        channel_number INTEGER,
        stream_type TEXT DEFAULT 'live',
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
        tvg_id TEXT,
        tvg_name TEXT,
        channel_number INTEGER,
        stream_type TEXT DEFAULT 'live',
        is_hd INTEGER DEFAULT 1,
        is_geo INTEGER DEFAULT 0,
        is_youtube INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createEpgTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS epg_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        last_refresh INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS epg_channels (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        display_names TEXT NOT NULL,
        icon_url TEXT,
        number TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS epg_programmes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        epg_channel_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        stop_ms INTEGER NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT,
        description TEXT,
        category TEXT,
        icon_url TEXT,
        episode_num TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_epg_programmes_channel_time
      ON epg_programmes(epg_channel_id, start_ms, stop_ms)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS epg_mappings (
        channel_id TEXT PRIMARY KEY,
        epg_channel_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        confidence REAL DEFAULT 0,
        match_source TEXT DEFAULT 'auto',
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createHealthTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stream_health (
        url_key TEXT PRIMARY KEY,
        stream_url TEXT NOT NULL,
        success_count INTEGER DEFAULT 0,
        failure_count INTEGER DEFAULT 0,
        stall_count INTEGER DEFAULT 0,
        ttff_ms INTEGER DEFAULT 0,
        last_updated INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgradeToV2(Database db) async {
    for (final table in ['favourites', 'custom_channels']) {
      await _ensureColumn(db, table, 'tvg_id', 'TEXT');
      await _ensureColumn(db, table, 'tvg_name', 'TEXT');
      await _ensureColumn(db, table, 'channel_number', 'INTEGER');
      await _ensureColumn(db, table, 'stream_type', "TEXT DEFAULT 'live'");
    }
    await _ensureColumn(db, 'custom_channels', 'is_geo', 'INTEGER DEFAULT 0');
    await _ensureColumn(
      db,
      'custom_channels',
      'is_youtube',
      'INTEGER DEFAULT 0',
    );
    await _createEpgTables(db);
    await _createHealthTables(db);
  }

  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
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
    await _database.insert(
      'custom_channels',
      _customChannelMap(channel),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
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
        final safeChannel = channel.id.startsWith('custom_')
            ? channel
            : TvChannel(
                id: 'custom_${channel.id}',
                name: channel.name,
                groupTitle: channel.groupTitle,
                streamUrl: channel.streamUrl,
                logoUrl: channel.logoUrl,
                tvgId: channel.tvgId,
                tvgName: channel.tvgName,
                channelNumber: channel.channelNumber,
                streamType: channel.streamType,
                isHD: channel.isHD,
                isGeoBlocked: channel.isGeoBlocked,
                isYouTube: channel.isYouTube,
                isCustom: true,
              );
        final rowId = await txn.insert(
          'custom_channels',
          _customChannelMap(safeChannel),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        existingUrls.add(normalizedUrl);
        if (rowId != 0) inserted++;
      }
    });
    return inserted;
  }

  Map<String, Object?> _customChannelMap(TvChannel channel) => {
    'id': channel.id,
    'name': channel.name,
    'group_title': channel.groupTitle,
    'stream_url': channel.streamUrl.trim(),
    'logo_url': channel.logoUrl,
    'tvg_id': channel.tvgId,
    'tvg_name': channel.tvgName,
    'channel_number': channel.channelNumber,
    'stream_type': channel.streamType.name,
    'is_hd': channel.isHD ? 1 : 0,
    'is_geo': channel.isGeoBlocked ? 1 : 0,
    'is_youtube': channel.isYouTube ? 1 : 0,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  };

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

  Future<List<TvEpgSource>> getEpgSources() async {
    final rows = await _database.query('epg_sources', orderBy: 'name ASC');
    return rows.map(TvEpgSource.fromMap).toList();
  }

  Future<void> upsertEpgSource(TvEpgSource source) async {
    await _database.insert('epg_sources', {
      'id': source.id,
      'name': source.name,
      'url': source.url,
      'enabled': source.enabled ? 1 : 0,
      'last_refresh': source.lastRefresh?.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteEpgSource(String sourceId) async {
    await _database.transaction((txn) async {
      await txn.delete('epg_sources', where: 'id = ?', whereArgs: [sourceId]);
      await txn.delete(
        'epg_channels',
        where: 'source_id = ?',
        whereArgs: [sourceId],
      );
      await txn.delete(
        'epg_programmes',
        where: 'source_id = ?',
        whereArgs: [sourceId],
      );
      await txn.delete(
        'epg_mappings',
        where: 'source_id = ?',
        whereArgs: [sourceId],
      );
    });
  }

  Future<void> replaceEpgData({
    required TvEpgSource source,
    required List<TvEpgChannel> channels,
    required List<TvEpgProgramme> programmes,
  }) async {
    await _database.transaction((txn) async {
      await txn.insert('epg_sources', {
        'id': source.id,
        'name': source.name,
        'url': source.url,
        'enabled': source.enabled ? 1 : 0,
        'last_refresh': source.lastRefresh?.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'epg_channels',
        where: 'source_id = ?',
        whereArgs: [source.id],
      );
      await txn.delete(
        'epg_programmes',
        where: 'source_id = ?',
        whereArgs: [source.id],
      );
      await txn.delete(
        'epg_mappings',
        where: 'source_id = ?',
        whereArgs: [source.id],
      );

      final batch = txn.batch();
      for (final channel in channels) {
        batch.insert('epg_channels', {
          'id': channel.id,
          'source_id': channel.sourceId,
          'channel_id': channel.channelId,
          'display_name': channel.primaryName,
          'display_names': jsonEncode(channel.displayNames),
          'icon_url': channel.iconUrl,
          'number': channel.number,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final programme in programmes) {
        batch.insert('epg_programmes', {
          'epg_channel_id': programme.epgChannelId,
          'source_id': programme.sourceId,
          'start_ms': programme.start.millisecondsSinceEpoch,
          'stop_ms': programme.stop.millisecondsSinceEpoch,
          'title': programme.title,
          'subtitle': programme.subtitle,
          'description': programme.description,
          'category': programme.category,
          'icon_url': programme.iconUrl,
          'episode_num': programme.episodeNum,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<TvEpgChannel>> getEpgChannels() async {
    final rows = await _database.query('epg_channels');
    return rows.map((row) {
      final namesRaw = row['display_names'] as String? ?? '[]';
      final names = (jsonDecode(namesRaw) as List<dynamic>)
          .map((name) => name.toString())
          .where((name) => name.trim().isNotEmpty)
          .toList();
      return TvEpgChannel(
        id: row['id'] as String,
        sourceId: row['source_id'] as String,
        channelId: row['channel_id'] as String,
        displayNames: names.isEmpty ? [row['display_name'] as String] : names,
        iconUrl: row['icon_url'] as String?,
        number: row['number'] as String?,
      );
    }).toList();
  }

  Future<int> getEpgProgrammeCount() async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM epg_programmes',
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<void> saveEpgMappings(List<TvEpgMapping> mappings) async {
    if (mappings.isEmpty) return;
    await _database.transaction((txn) async {
      final batch = txn.batch();
      for (final mapping in mappings) {
        batch.insert('epg_mappings', {
          'channel_id': mapping.channelId,
          'epg_channel_id': mapping.epgChannelId,
          'source_id': mapping.sourceId,
          'confidence': mapping.confidence,
          'match_source': mapping.matchSource,
          'updated_at': mapping.updatedAt.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<TvEpgMapping?> getEpgMapping(String channelId) async {
    final rows = await _database.query(
      'epg_mappings',
      where: 'channel_id = ?',
      whereArgs: [channelId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TvEpgMapping.fromMap(rows.first);
  }

  Future<Map<String, TvEpgMapping>> getEpgMappings() async {
    final rows = await _database.query('epg_mappings');
    return {
      for (final row in rows)
        row['channel_id'] as String: TvEpgMapping.fromMap(row),
    };
  }

  Future<int> getEpgMappingCount() async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM epg_mappings',
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<TvNowNext?> getNowNextForChannel(String channelId) async {
    final mapping = await getEpgMapping(channelId);
    if (mapping == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _database.query(
      'epg_programmes',
      where: 'epg_channel_id = ? AND stop_ms > ?',
      whereArgs: [mapping.epgChannelId, now],
      orderBy: 'start_ms ASC',
      limit: 6,
    );
    if (rows.isEmpty) return const TvNowNext();

    TvEpgProgramme? current;
    TvEpgProgramme? next;
    for (final row in rows) {
      final programme = TvEpgProgramme.fromMap(row);
      final startMs = programme.start.millisecondsSinceEpoch;
      if (startMs <= now && programme.stop.millisecondsSinceEpoch > now) {
        current = programme;
      } else if (startMs > now && next == null) {
        next = programme;
      }
      if (current != null && next != null) break;
    }
    return TvNowNext(current: current, next: next);
  }

  Future<List<TvEpgProgramme>> getProgrammesForChannel({
    required String channelId,
    required DateTime start,
    required DateTime end,
  }) async {
    final mapping = await getEpgMapping(channelId);
    if (mapping == null) return [];
    final rows = await _database.query(
      'epg_programmes',
      where: 'epg_channel_id = ? AND stop_ms > ? AND start_ms < ?',
      whereArgs: [
        mapping.epgChannelId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'start_ms ASC',
    );
    return rows.map(TvEpgProgramme.fromMap).toList();
  }

  Future<void> recordStreamSuccess(String url, int ttffMs) async {
    await _updateStreamHealth(url, (row) {
      row['success_count'] = (row['success_count'] as int? ?? 0) + 1;
      row['ttff_ms'] = ttffMs;
    });
  }

  Future<void> recordStreamFailure(String url) async {
    await _updateStreamHealth(url, (row) {
      row['failure_count'] = (row['failure_count'] as int? ?? 0) + 1;
    });
  }

  Future<void> recordStreamStall(String url) async {
    await _updateStreamHealth(url, (row) {
      row['stall_count'] = (row['stall_count'] as int? ?? 0) + 1;
    });
  }

  Future<Map<String, double>> getStreamHealthScores(List<String> urls) async {
    if (urls.isEmpty) return {};
    final keys = urls.map(_urlKey).toList();
    final scores = <String, double>{};
    for (var i = 0; i < keys.length; i += 700) {
      final end = i + 700 > keys.length ? keys.length : i + 700;
      final chunk = keys.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _database.query(
        'stream_health',
        where: 'url_key IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        scores[row['stream_url'] as String] = _healthScore(row);
      }
    }
    return scores;
  }

  Future<void> _updateStreamHealth(
    String url,
    void Function(Map<String, Object?> row) update,
  ) async {
    final key = _urlKey(url);
    final existing = await _database.query(
      'stream_health',
      where: 'url_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    final row = <String, Object?>{
      'url_key': key,
      'stream_url': url,
      'success_count': 0,
      'failure_count': 0,
      'stall_count': 0,
      'ttff_ms': 0,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
      if (existing.isNotEmpty) ...existing.first,
    };
    update(row);
    row['last_updated'] = DateTime.now().millisecondsSinceEpoch;
    await _database.insert(
      'stream_health',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  double _healthScore(Map<String, Object?> row) {
    final successes = row['success_count'] as int? ?? 0;
    final failures = row['failure_count'] as int? ?? 0;
    final stalls = row['stall_count'] as int? ?? 0;
    final ttffMs = row['ttff_ms'] as int? ?? 0;
    final reliability = (successes + 1) / (successes + failures + stalls + 2);
    final stallPenalty = 1 / (1 + stalls * 0.35);
    final ttffScore = ttffMs <= 0 ? 0.5 : (1 - ttffMs / 12000).clamp(0.0, 1.0);
    return (reliability * 0.55 + stallPenalty * 0.25 + ttffScore * 0.20)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  String _urlKey(String url) => TvChannel.idFromUrl(url);
}

final tvDatabase = TvDatabase();
