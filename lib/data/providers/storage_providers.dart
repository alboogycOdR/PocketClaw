/// Riverpod surface for the Storage settings screen — sums up bytes
/// used by each on-device subsystem (text models, whisper models, RAG
/// db, conversations) and surfaces orphaned / partial downloads via
/// [DownloadRecoveryService].
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/llm/download_recovery_service.dart';
import '../../core/rag/rag_database.dart';

class StorageStats {
  final int textModelsBytes;
  final int whisperModelsBytes;
  final int ragDatabaseBytes;
  final int conversationsBytes;
  final int embeddingModelBytes;
  final RecoveryScanResult recovery;

  const StorageStats({
    this.textModelsBytes = 0,
    this.whisperModelsBytes = 0,
    this.ragDatabaseBytes = 0,
    this.conversationsBytes = 0,
    this.embeddingModelBytes = 0,
    this.recovery = const RecoveryScanResult(),
  });

  int get totalUsedBytes =>
      textModelsBytes +
      whisperModelsBytes +
      ragDatabaseBytes +
      conversationsBytes +
      embeddingModelBytes;
}

int _dirSizeBytes(Directory dir) {
  if (!dir.existsSync()) return 0;
  var total = 0;
  for (final entry in dir.listSync(recursive: true)) {
    if (entry is File) {
      try {
        total += entry.lengthSync();
      } catch (_) {}
    }
  }
  return total;
}

final storageStatsProvider = FutureProvider<StorageStats>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  final dbsPath = await getDatabasesPath();

  final textModels = _dirSizeBytes(Directory('${docs.path}/models/gguf'));
  final whisperModels =
      _dirSizeBytes(Directory('${docs.path}/whisper-models'));
  final embedding =
      _dirSizeBytes(Directory('${docs.path}/embedding_model'));

  final ragDbSize = await ragDb.databaseSizeBytes();

  // Conversations live in the app's main sqflite database under
  // `pocket_claw.db` (legacy name — kept to avoid wiping user data).
  var conversationsSize = 0;
  for (final dbName in const ['pocket_claw.db', 'clawcommander.db']) {
    final f = File(p.join(dbsPath, dbName));
    if (f.existsSync()) {
      try {
        conversationsSize += f.lengthSync();
      } catch (_) {}
    }
  }

  // Orphan / partial scan needs the registered-paths set; we don't
  // have a global path registry yet, so we treat every file under the
  // versioned models tree as registered (orphans are then only files
  // outside that tree).
  final registeredPaths = <String>{
    for (final entry in Directory('${docs.path}/models/gguf')
        .existsSync()
        ? Directory('${docs.path}/models/gguf').listSync(recursive: true)
        : const <FileSystemEntity>[])
      if (entry is File &&
          entry.path.endsWith('.gguf') &&
          // Files in the versioned `{id}/{commit}/{file}` layout count
          // as registered; anything else (legacy flat .gguf, partials)
          // shows up as a finding.
          entry.parent.path !=
              '${docs.path}/models/gguf')
        entry.path,
  };
  final recovery = await downloadRecoveryService.scan(
    registeredPaths: registeredPaths,
  );

  return StorageStats(
    textModelsBytes: textModels,
    whisperModelsBytes: whisperModels,
    ragDatabaseBytes: ragDbSize,
    conversationsBytes: conversationsSize,
    embeddingModelBytes: embedding,
    recovery: recovery,
  );
});
