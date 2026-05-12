/// Scans the on-disk models directory for files that aren't tracked
/// in the model catalogue (orphans) and incomplete `.part` downloads.
/// The Storage settings screen surfaces both for the user to clean up.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OrphanedFile {
  final String path;
  final String filename;
  final int sizeBytes;
  const OrphanedFile({
    required this.path,
    required this.filename,
    required this.sizeBytes,
  });
}

class PartialDownload {
  final String path;
  final String filename;
  final int sizeBytes;
  const PartialDownload({
    required this.path,
    required this.filename,
    required this.sizeBytes,
  });
}

class RecoveryScanResult {
  final List<OrphanedFile> orphaned;
  final List<PartialDownload> partial;
  const RecoveryScanResult({
    this.orphaned = const [],
    this.partial = const [],
  });

  bool get hasFindings => orphaned.isNotEmpty || partial.isNotEmpty;

  int get totalOrphanedBytes =>
      orphaned.fold(0, (sum, o) => sum + o.sizeBytes);
  int get totalPartialBytes =>
      partial.fold(0, (sum, q) => sum + q.sizeBytes);
}

class DownloadRecoveryService {
  /// Walks `{docs}/models/gguf/**` collecting:
  ///   - `.part` files (partial downloads)
  ///   - `.gguf` files whose path doesn't match any [registeredPaths]
  ///     entry exactly.
  Future<RecoveryScanResult> scan({
    required Set<String> registeredPaths,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models/gguf');
    if (!modelDir.existsSync()) return const RecoveryScanResult();

    final orphaned = <OrphanedFile>[];
    final partial = <PartialDownload>[];

    for (final entry in modelDir.listSync(recursive: true)) {
      if (entry is! File) continue;
      final filename = p.basename(entry.path);
      int size;
      try {
        size = entry.lengthSync();
      } catch (_) {
        continue;
      }
      if (filename.endsWith('.part')) {
        partial.add(PartialDownload(
          path: entry.path,
          filename: filename,
          sizeBytes: size,
        ));
      } else if (filename.endsWith('.gguf') &&
          !registeredPaths.contains(entry.path)) {
        orphaned.add(OrphanedFile(
          path: entry.path,
          filename: filename,
          sizeBytes: size,
        ));
      }
    }

    return RecoveryScanResult(orphaned: orphaned, partial: partial);
  }

  Future<void> deletePath(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }
}

final downloadRecoveryService = DownloadRecoveryService();
