/// Server-side memory access through the Gateway REST client.
library;

import '../../data/models/memory_note.dart';
import '../gateway/gateway_rest.dart';

class ServerMemory {
  final GatewayRestClient _client;

  ServerMemory({required GatewayRestClient client}) : _client = client;

  /// List files at a given path on the server memory store.
  Future<List<MemoryFile>> getFiles([String path = '/']) async {
    try {
      return await _client.getMemoryFiles(path: path);
    } catch (e) {
      return [];
    }
  }

  /// Retrieve the raw content of a file by its server path.
  Future<String?> getContent(String path) async {
    try {
      return await _client.getMemoryFileContent(path);
    } catch (e) {
      return null;
    }
  }

  /// Search server memory for notes matching [query].
  ///
  /// Since the REST API exposes files, we list all files and filter
  /// by name/path containing the query. For richer search a dedicated
  /// server endpoint would be preferable — this is a pragmatic fallback.
  Future<List<MemoryNote>> search(String query) async {
    try {
      final files = await _client.getMemoryFiles();
      final matches = files.where(
        (f) => f.name.toLowerCase().contains(query.toLowerCase()) ||
            f.path.toLowerCase().contains(query.toLowerCase()),
      );

      final results = <MemoryNote>[];
      for (final file in matches) {
        if (file.isDirectory) continue;
        final content = await getContent(file.path);
        if (content == null) continue;
        results.add(_fileToNote(file, content));
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  /// Write or overwrite a file on the server memory store.
  Future<void> writeFile({
    required String path,
    required String content,
  }) async {
    await _client.writeMemoryFile(path: path, content: content);
  }

  /// Delete a file from the server memory store.
  Future<void> deleteFile(String path) async {
    await _client.deleteMemoryFile(path);
  }

  /// Convert a MemoryFile + fetched content into a MemoryNote.
  MemoryNote _fileToNote(MemoryFile file, String content) {
    final title = file.name.replaceAll(RegExp(r'\.\w+$'), '');
    final folder = _extractFolder(file.path);

    return MemoryNote(
      id: 'server:${file.path}',
      title: title,
      content: content,
      folder: folder,
      created: file.modified ?? DateTime.now(),
      modified: file.modified ?? DateTime.now(),
      syncEnabled: true,
      source: 'server',
    );
  }

  /// Derive a folder name from the file's path.
  String _extractFolder(String path) {
    final segments = path.split('/')..removeWhere((s) => s.isEmpty);
    if (segments.length > 1) {
      return segments[segments.length - 2];
    }
    return 'general';
  }
}
