/// Unified memory interface — routes queries to local or server stores
/// based on connectivity, and exposes a single API surface.
library;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/models/memory_note.dart';
import 'local_memory.dart';
import 'memory_sync.dart';
import 'server_memory.dart';

class MemoryManager {
  final LocalMemory _local;
  final ServerMemory? _server;
  final MemorySync? _sync;
  final Connectivity _connectivity;

  MemoryManager({
    required LocalMemory local,
    ServerMemory? server,
    MemorySync? sync,
    Connectivity? connectivity,
  })  : _local = local,
        _server = server,
        _sync = sync,
        _connectivity = connectivity ?? Connectivity();

  /// Search notes — queries both stores when online, local-only when offline.
  Future<List<MemoryNote>> search(String query, [int limit = 10]) async {
    final localResults = await _local.search(query, limit);

    if (_server != null && await _isOnline()) {
      try {
        final serverResults = await _server.search(query);
        return _mergeResults(localResults, serverResults, limit);
      } catch (_) {
        // Server failed — fall back to local only
      }
    }

    return localResults;
  }

  /// Save a note to local storage. If online, trigger a sync for this note.
  Future<void> save(MemoryNote note) async {
    await _local.createNote(
      title: note.title,
      content: note.content,
      folder: note.folder,
    );

    if (note.syncEnabled && _sync != null && await _isOnline()) {
      try {
        await _sync.syncNote(note.id);
      } catch (_) {
        // Will sync later
      }
    }
  }

  /// Get all notes from local storage.
  Future<List<MemoryNote>> getAll() async {
    return _local.getAllNotes();
  }

  /// Trigger a full sync between local and server stores.
  Future<SyncResult> sync() async {
    if (_sync == null) {
      return const SyncResult(success: false, error: 'Server not configured');
    }
    if (!await _isOnline()) {
      return const SyncResult(
        success: false,
        error: 'No network connectivity',
      );
    }
    return _sync.syncAll();
  }

  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  List<MemoryNote> _mergeResults(
    List<MemoryNote> local,
    List<MemoryNote> server,
    int limit,
  ) {
    final seen = <String>{};
    final merged = <MemoryNote>[];

    for (final note in [...local, ...server]) {
      final key = '${note.folder}/${note.title}'.toLowerCase();
      if (seen.add(key)) {
        merged.add(note);
      }
    }

    merged.sort((a, b) => b.modified.compareTo(a.modified));

    if (merged.length > limit) return merged.sublist(0, limit);
    return merged;
  }
}
