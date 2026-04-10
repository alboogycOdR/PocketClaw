/// Local memory manager — stores notes as Markdown files with YAML frontmatter,
/// indexed in sqflite for fast search. Supports vector-based semantic search
/// via flutter_gemma embeddings with cosine similarity ranking.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/daos/notes_dao.dart';
import '../../data/models/memory_note.dart';
import '../local_agent/llm_engine.dart';
import '../local_agent/tool_executor.dart';

/// Result pairing a note with its similarity score (1.0 = identical).
class ScoredNote {
  final MemoryNote note;
  final double score;

  const ScoredNote({required this.note, required this.score});
}

class LocalMemory {
  final NotesDao _notesDao;
  final LlmEngine? _llmEngine;
  final _uuid = const Uuid();
  Directory? _notesDir;
  Directory? _embeddingsDir;

  /// In-memory cache of note embeddings keyed by note id.
  final Map<String, List<double>> _embeddingCache = {};

  /// Whether the embedding cache has been populated from disk.
  bool _cacheLoaded = false;

  LocalMemory({NotesDao? notesDao, LlmEngine? llmEngine})
      : _notesDao = notesDao ?? NotesDao(),
        _llmEngine = llmEngine;

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

  /// Lazily resolve the embeddings storage directory.
  Future<Directory> get _embeddingDir async {
    if (_embeddingsDir != null) return _embeddingsDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _embeddingsDir =
        Directory(p.join(appDir.path, 'pocket_claw', 'embeddings'));
    if (!await _embeddingsDir!.exists()) {
      await _embeddingsDir!.create(recursive: true);
    }
    return _embeddingsDir!;
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

      // Generate and store embedding (best-effort, non-blocking)
      _generateAndStoreEmbedding(id, '$title\n$content');

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
  ///
  /// Uses a hybrid strategy: attempts vector (semantic) search first, then
  /// falls back to text-based LIKE search if embeddings are unavailable.
  Future<List<MemoryNote>> search(String query, [int limit = 5]) async {
    // Try vector search first
    final vectorResults = await vectorSearch(query, limit: limit);
    if (vectorResults.isNotEmpty) {
      return vectorResults.map((s) => s.note).toList();
    }

    // Fall back to text search
    return _textSearch(query, limit);
  }

  /// Pure text-based search (LIKE matching) — the original search path.
  Future<List<MemoryNote>> _textSearch(String query, int limit) async {
    final rows = await _notesDao.search(query, limit: limit);
    final notes = <MemoryNote>[];
    for (final row in rows) {
      final note = await _loadNoteFromRow(row);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  /// Semantic vector search using cosine similarity against stored embeddings.
  ///
  /// Returns an empty list if the embedding model is unavailable or no
  /// embeddings have been generated yet. A minimum similarity threshold of
  /// 0.3 is applied to filter irrelevant matches.
  Future<List<ScoredNote>> vectorSearch(
    String query, {
    int limit = 5,
    double threshold = 0.3,
  }) async {
    if (_llmEngine == null) return [];

    try {
      // Generate query embedding
      final queryEmbedding = await _llmEngine.generateEmbedding(query);

      // Check for zero-vector (embedding model not available)
      if (_isZeroVector(queryEmbedding)) return [];

      // Ensure cache is populated
      await _loadEmbeddingCache();

      if (_embeddingCache.isEmpty) return [];

      // Score every cached note
      final scored = <ScoredNote>[];
      for (final entry in _embeddingCache.entries) {
        final similarity = _cosineSimilarity(queryEmbedding, entry.value);
        if (similarity >= threshold) {
          final row = await _notesDao.getById(entry.key);
          if (row != null) {
            final note = await _loadNoteFromRow(row);
            if (note != null) {
              scored.add(ScoredNote(note: note, score: similarity));
            }
          }
        }
      }

      // Sort by descending similarity
      scored.sort((a, b) => b.score.compareTo(a.score));

      if (scored.length > limit) return scored.sublist(0, limit);
      return scored;
    } catch (e) {
      debugPrint('LocalMemory: vector search failed: $e');
      return [];
    }
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

  /// Delete a note by id — removes the file, embedding, and the index entry.
  Future<void> deleteNote(String id) async {
    final row = await _notesDao.getById(id);
    if (row != null) {
      final filePath = row['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await _notesDao.delete(id);
      await _deleteEmbedding(id);
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

  // ---------------------------------------------------------------------------
  // Embedding helpers
  // ---------------------------------------------------------------------------

  /// Fire-and-forget: generate an embedding and persist it to disk + cache.
  void _generateAndStoreEmbedding(String noteId, String text) {
    if (_llmEngine == null) return;

    // Run async without awaiting — note creation should not block on embedding.
    Future<void>(() async {
      try {
        final embedding = await _llmEngine.generateEmbedding(text);
        if (_isZeroVector(embedding)) return; // model not available

        await _saveEmbedding(noteId, embedding);
        _embeddingCache[noteId] = embedding;
      } catch (e) {
        debugPrint('LocalMemory: embedding generation failed for $noteId: $e');
      }
    });
  }

  /// Persist an embedding vector as a JSON file.
  Future<void> _saveEmbedding(String noteId, List<double> embedding) async {
    final dir = await _embeddingDir;
    final file = File(p.join(dir.path, '$noteId.json'));
    await file.writeAsString(jsonEncode(embedding));
  }

  /// Populate [_embeddingCache] from disk (once).
  Future<void> _loadEmbeddingCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;

    try {
      final dir = await _embeddingDir;
      if (!await dir.exists()) return;

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final noteId =
              p.basenameWithoutExtension(entity.path);
          try {
            final raw = await entity.readAsString();
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              _embeddingCache[noteId] = decoded.cast<double>();
            }
          } catch (_) {
            // Skip malformed files
          }
        }
      }
    } catch (e) {
      debugPrint('LocalMemory: failed to load embedding cache: $e');
    }
  }

  /// Delete the embedding file for a note.
  Future<void> _deleteEmbedding(String noteId) async {
    _embeddingCache.remove(noteId);
    final dir = await _embeddingDir;
    final file = File(p.join(dir.path, '$noteId.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Cosine similarity between two vectors. Returns a value in [-1, 1].
  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    var dotProduct = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = math.sqrt(normA) * math.sqrt(normB);
    if (denominator == 0.0) return 0.0;

    return dotProduct / denominator;
  }

  /// Check if a vector is all zeroes (indicates embedding model failure).
  static bool _isZeroVector(List<double> v) {
    return v.every((x) => x == 0.0);
  }
}
