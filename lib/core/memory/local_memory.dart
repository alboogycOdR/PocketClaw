/// Local memory manager — stores notes as Markdown files with YAML frontmatter,
/// indexed in sqflite for fast search.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/daos/notes_dao.dart';
import '../../data/models/memory_note.dart';
import '../local_agent/tool_executor.dart';

class LocalMemory {
  final NotesDao _notesDao;
  final _uuid = const Uuid();
  Directory? _notesDir;

  LocalMemory({NotesDao? notesDao}) : _notesDao = notesDao ?? NotesDao();

  /// Lazily resolve the notes storage directory.
  Future<Directory> get _storageDir async {
    if (_notesDir != null) return _notesDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _notesDir = Directory(p.join(appDir.path, 'pocket_claw', 'notes'));
    if (!await _notesDir!.exists()) {
      await _notesDir!.create(recursive: true);
    }
    return _notesDir!;
  }

  /// Create a new note, persisting both the Markdown file and the index row.
  Future<ToolResult> createNote({
    required String title,
    required String content,
    String folder = 'general',
  }) async {
    try {
      final now = DateTime.now();
      final id = _uuid.v4();

      final note = MemoryNote(
        id: id,
        title: title,
        content: content,
        folder: folder,
        created: now,
        modified: now,
      );

      // Write Markdown file
      final filePath = await _writeNoteFile(note);

      // Index in database
      await _notesDao.upsert(_noteToRow(note, filePath));

      return ToolResult.ok(
        'Note "$title" saved to $folder.',
        data: {'id': id, 'folder': folder},
      );
    } catch (e) {
      return ToolResult.error('Failed to create note: $e');
    }
  }

  /// Search notes by query string — returns a ToolResult with JSON payload.
  Future<ToolResult> searchNotes({
    required String query,
    int limit = 5,
  }) async {
    try {
      final notes = await search(query, limit);
      if (notes.isEmpty) {
        return ToolResult.ok('No notes found for "$query".');
      }

      final summaries = notes
          .map((n) => '• ${n.title} (${n.folder}) — ${_preview(n.content)}')
          .join('\n');

      return ToolResult.ok(
        'Found ${notes.length} note(s):\n$summaries',
        data: {
          'notes': notes.map((n) => n.toJson()).toList(),
        },
      );
    } catch (e) {
      return ToolResult.error('Search failed: $e');
    }
  }

  /// Search notes for prompt context injection.
  Future<List<MemoryNote>> search(String query, [int limit = 5]) async {
    final rows = await _notesDao.search(query, limit: limit);
    final notes = <MemoryNote>[];
    for (final row in rows) {
      final note = await _loadNoteFromRow(row);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  /// Return every note, ordered by last modified.
  Future<List<MemoryNote>> getAllNotes() async {
    final rows = await _notesDao.getAll();
    final notes = <MemoryNote>[];
    for (final row in rows) {
      final note = await _loadNoteFromRow(row);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  /// Delete a note by id — removes both the file and the index entry.
  Future<void> deleteNote(String id) async {
    final row = await _notesDao.getById(id);
    if (row != null) {
      final filePath = row['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await _notesDao.delete(id);
    }
  }

  /// Get all notes in a given folder.
  Future<List<MemoryNote>> getNotesByFolder(String folder) async {
    final rows = await _notesDao.getByFolder(folder);
    final notes = <MemoryNote>[];
    for (final row in rows) {
      final note = await _loadNoteFromRow(row);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Write the Markdown file to disk and return its absolute path.
  Future<String> _writeNoteFile(MemoryNote note) async {
    final dir = await _storageDir;
    final folderDir = Directory(p.join(dir.path, note.folder));
    if (!await folderDir.exists()) {
      await folderDir.create(recursive: true);
    }
    final safeName = note.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+$'), '');
    final filePath = p.join(folderDir.path, '${safeName}_${note.id.substring(0, 8)}.md');
    final file = File(filePath);
    await file.writeAsString(note.toMarkdown());
    return filePath;
  }

  /// Build a database row from a MemoryNote + file path.
  Map<String, dynamic> _noteToRow(MemoryNote note, String filePath) => {
        'id': note.id,
        'title': note.title,
        'folder': note.folder,
        'tags_json': jsonEncode(note.tags),
        'created': note.created.toIso8601String(),
        'modified': note.modified.toIso8601String(),
        'sync_enabled': note.syncEnabled ? 1 : 0,
        'source': note.source,
        'file_path': filePath,
      };

  /// Hydrate a MemoryNote from a database row by reading the Markdown file for content.
  Future<MemoryNote?> _loadNoteFromRow(Map<String, dynamic> row) async {
    final filePath = row['file_path'] as String;
    final file = File(filePath);

    String content = '';
    if (await file.exists()) {
      final raw = await file.readAsString();
      content = _extractContent(raw);
    }

    final tags = _decodeTags(row['tags_json'] as String);

    return MemoryNote(
      id: row['id'] as String,
      title: row['title'] as String,
      content: content,
      folder: row['folder'] as String,
      tags: tags,
      created: DateTime.parse(row['created'] as String),
      modified: DateTime.parse(row['modified'] as String),
      syncEnabled: (row['sync_enabled'] as int) == 1,
      source: row['source'] as String,
    );
  }

  /// Extract the body content after the YAML frontmatter.
  String _extractContent(String markdown) {
    final fmPattern = RegExp(r'^---\n[\s\S]*?\n---\n*', multiLine: true);
    return markdown.replaceFirst(fmPattern, '').trim();
  }

  /// Decode tags JSON safely.
  List<String> _decodeTags(String tagsJson) {
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {
      // fall through
    }
    return [];
  }

  /// Short preview of content for search results.
  String _preview(String content, [int maxLen = 80]) {
    final oneLine = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= maxLen) return oneLine;
    return '${oneLine.substring(0, maxLen)}...';
  }
}
