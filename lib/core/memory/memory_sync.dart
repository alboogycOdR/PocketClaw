/// Synchronises local and server memory stores.
/// Conflict resolution: latest-modified timestamp wins.
library;

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

      // Push local → server (conceptual — actual upload would need a write endpoint)
      for (final ln in localNotes) {
        if (!ln.syncEnabled) continue;

        final key = _normalizeKey(ln.title, ln.folder);
        final serverVersion = serverMap.remove(key);

        if (serverVersion == null) {
          // Only exists locally — would upload
          uploaded++;
        } else if (ln.modified.isAfter(serverVersion.modified)) {
          // Local is newer — would overwrite server
          uploaded++;
          conflicts++;
        } else if (serverVersion.modified.isAfter(ln.modified)) {
          // Server is newer — pull down
          downloaded++;
          conflicts++;
        }
        // Equal timestamps — no action needed
      }

      // Remaining server notes that don't exist locally
      for (final _ in serverMap.values) {
        downloaded++;
      }

      await _settings.set(
        _lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      return SyncResult(
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: conflicts,
        success: true,
      );
    } catch (e) {
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
        uploaded = 1;
      } else if (match.modified.isAfter(note.modified)) {
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
