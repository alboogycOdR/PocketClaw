/// Synchronises local and server memory stores.
/// Conflict resolution: latest-modified timestamp wins.
library;

import 'package:flutter/foundation.dart';

import '../../data/database/daos/settings_dao.dart';
import '../../data/models/memory_note.dart';
import 'local_memory.dart';
import 'server_memory.dart';

class MemorySync {
  final LocalMemory _local;
  final ServerMemory _server;
  final SettingsDao _settings;

  static const _lastSyncKey = 'memory_last_sync';

  MemorySync({
    required LocalMemory local,
    required ServerMemory server,
    SettingsDao? settings,
  })  : _local = local,
        _server = server,
        _settings = settings ?? SettingsDao();

  /// Sync every local note that has syncEnabled with the server store.
  Future<SyncResult> syncAll() async {
    int uploaded = 0;
    int downloaded = 0;
    int conflicts = 0;

    try {
      final localNotes = await _local.getAllNotes();
      final serverNotes = await _server.search('');

      // Index server notes by a normalized key
      final serverMap = <String, MemoryNote>{};
      for (final sn in serverNotes) {
        serverMap[_normalizeKey(sn.title, sn.folder)] = sn;
      }

      // Push local → server
      for (final ln in localNotes) {
        if (!ln.syncEnabled) continue;

        final key = _normalizeKey(ln.title, ln.folder);
        final serverVersion = serverMap.remove(key);

        if (serverVersion == null) {
          // Only exists locally — upload to server
          await _uploadNote(ln);
          uploaded++;
        } else if (ln.modified.isAfter(serverVersion.modified)) {
          // Local is newer — overwrite server
          await _uploadNote(ln);
          uploaded++;
          conflicts++;
        } else if (serverVersion.modified.isAfter(ln.modified)) {
          // Server is newer — pull down and update local
          await _downloadNote(serverVersion);
          downloaded++;
          conflicts++;
        }
        // Equal timestamps — no action needed
      }

      // Remaining server notes that don't exist locally — download them
      for (final serverNote in serverMap.values) {
        await _downloadNote(serverNote);
        downloaded++;
      }

      await _settings.set(
        _lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint(
        'MemorySync: uploaded=$uploaded, downloaded=$downloaded, conflicts=$conflicts',
      );

      return SyncResult(
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: conflicts,
        success: true,
      );
    } catch (e) {
      debugPrint('MemorySync: sync failed: $e');
      return SyncResult(
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: conflicts,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sync a single note by id.
  Future<SyncResult> syncNote(String id) async {
    try {
      final localNotes = await _local.getAllNotes();
      final note = localNotes.where((n) => n.id == id).firstOrNull;
      if (note == null) {
        return SyncResult(success: false, error: 'Note $id not found locally');
      }
      if (!note.syncEnabled) {
        return SyncResult(
          success: false,
          error: 'Sync disabled for note $id',
        );
      }

      // Attempt to find a matching server note
      final serverMatches = await _server.search(note.title);
      final match = serverMatches
          .where((s) =>
              s.title.toLowerCase() == note.title.toLowerCase() &&
              s.folder.toLowerCase() == note.folder.toLowerCase())
          .firstOrNull;

      int uploaded = 0;
      int downloaded = 0;

      if (match == null || note.modified.isAfter(match.modified)) {
        await _uploadNote(note);
        uploaded = 1;
      } else if (match.modified.isAfter(note.modified)) {
        await _downloadNote(match);
        downloaded = 1;
      }

      await _settings.set(
        _lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      return SyncResult(
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: match != null ? 1 : 0,
        success: true,
      );
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Returns the DateTime of the last successful sync, or null if never synced.
  Future<DateTime?> getLastSyncTime() async {
    final raw = await _settings.get(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Upload a local note to the server memory store.
  Future<void> _uploadNote(MemoryNote note) async {
    final serverPath = '/${note.folder}/${_sanitizeFilename(note.title)}.md';
    await _server.writeFile(
      path: serverPath,
      content: note.toMarkdown(),
    );
  }

  /// Download a server note and save it locally.
  Future<void> _downloadNote(MemoryNote serverNote) async {
    await _local.createNote(
      title: serverNote.title,
      content: serverNote.content,
      folder: serverNote.folder,
    );
  }

  /// Sanitize a title into a safe filename.
  String _sanitizeFilename(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+$'), '');
  }

  /// Produce a deterministic lookup key from title + folder.
  String _normalizeKey(String title, String folder) =>
      '${folder.toLowerCase()}/${title.toLowerCase().trim()}';
}

/// Result payload for sync operations.
class SyncResult {
  final int uploaded;
  final int downloaded;
  final int conflicts;
  final bool success;
  final String? error;

  const SyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
    required this.success,
    this.error,
  });

  @override
  String toString() =>
      'SyncResult(up: $uploaded, down: $downloaded, conflicts: $conflicts, ok: $success${error != null ? ', error: $error' : ''})';
}
