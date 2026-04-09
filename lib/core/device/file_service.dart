/// Wraps path_provider + dart:io for local file operations
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../local_agent/tool_executor.dart';

class FileService {
  /// Resolves a user-supplied [path] to an absolute path inside the app's
  /// documents directory if it is not already absolute. This prevents
  /// accidental reads/writes outside the sandbox.
  Future<String> _resolvePath(String path) async {
    if (p.isAbsolute(path)) return path;
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, path);
  }

  /// Reads the text content of a file at [path].
  Future<ToolResult> readFile(String path) async {
    try {
      final resolved = await _resolvePath(path);
      final file = File(resolved);

      if (!file.existsSync()) {
        return ToolResult.error('File not found: $resolved');
      }

      final content = await file.readAsString();
      final sizeKb = (await file.length() / 1024).toStringAsFixed(1);

      return ToolResult.ok(
        content,
        data: {
          'path': resolved,
          'sizeKb': sizeKb,
          'lines': content.split('\n').length,
        },
      );
    } catch (e) {
      return ToolResult.error('Failed to read file: $e');
    }
  }

  /// Writes [content] to a file at [path], creating parent directories as
  /// needed.
  Future<ToolResult> writeFile(String path, String content) async {
    try {
      final resolved = await _resolvePath(path);
      final file = File(resolved);

      await file.parent.create(recursive: true);
      await file.writeAsString(content);

      final sizeKb = (content.length / 1024).toStringAsFixed(1);

      return ToolResult.ok(
        'Written ${content.length} bytes to $resolved ($sizeKb KB).',
        data: {
          'path': resolved,
          'sizeKb': sizeKb,
          'bytes': content.length,
        },
      );
    } catch (e) {
      return ToolResult.error('Failed to write file: $e');
    }
  }

  /// Lists files in [directory], returning names and sizes.
  Future<ToolResult> listFiles(String directory) async {
    try {
      final resolved = await _resolvePath(directory);
      final dir = Directory(resolved);

      if (!dir.existsSync()) {
        return ToolResult.error('Directory not found: $resolved');
      }

      final entries = dir.listSync();
      if (entries.isEmpty) {
        return ToolResult.ok(
          'Directory is empty: $resolved',
          data: {'path': resolved, 'count': 0, 'entries': <Map>[]},
        );
      }

      final items = <Map<String, dynamic>>[];
      final buffer = StringBuffer('Contents of $resolved:\n');

      for (final entry in entries) {
        final name = p.basename(entry.path);
        final isDir = entry is Directory;
        final stat = entry.statSync();
        final sizeKb = isDir ? '-' : '${(stat.size / 1024).toStringAsFixed(1)} KB';
        final type = isDir ? 'dir' : 'file';

        buffer.writeln('  [$type] $name  $sizeKb');
        items.add({
          'name': name,
          'type': type,
          'path': entry.path,
          'sizeBytes': stat.size,
        });
      }

      return ToolResult.ok(
        buffer.toString().trim(),
        data: {'path': resolved, 'count': items.length, 'entries': items},
      );
    } catch (e) {
      return ToolResult.error('Failed to list directory: $e');
    }
  }
}
