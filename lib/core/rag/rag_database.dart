/// SQLite schema + DAO for the on-device RAG knowledge base.
/// Three tables — documents (one row per ingested file), chunks (the
/// text slices), embeddings (float vectors stored as raw bytes).
/// Stored in a separate `rag.db` so the main app database stays small.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'rag_chunker.dart';

class RagDocument {
  final int id;
  final String projectId;
  final String name;
  final String path;
  final int size;
  final DateTime createdAt;
  final bool enabled;

  const RagDocument({
    required this.id,
    required this.projectId,
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.enabled,
  });

  factory RagDocument.fromMap(Map<String, dynamic> m) => RagDocument(
        id: m['id'] as int,
        projectId: m['project_id'] as String,
        name: m['name'] as String,
        path: m['path'] as String,
        size: m['size'] as int,
        createdAt: DateTime.parse(m['created_at'] as String),
        enabled: (m['enabled'] as int) == 1,
      );
}

class RagSearchResult {
  final int docId;
  final String name;
  final String content;
  final int position;
  final double score;
  const RagSearchResult({
    required this.docId,
    required this.name,
    required this.content,
    required this.position,
    required this.score,
  });
}

class RagEmbeddingRow {
  final int chunkRowid;
  final int docId;
  final String name;
  final String content;
  final int position;
  final List<double> embedding;
  const RagEmbeddingRow({
    required this.chunkRowid,
    required this.docId,
    required this.name,
    required this.content,
    required this.position,
    required this.embedding,
  });
}

class RagDatabase {
  static const _dbName = 'rag.db';
  Database? _db;

  Future<void> ensureReady() async {
    if (_db != null) return;
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE rag_documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT NOT NULL,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            size INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE rag_chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            doc_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            FOREIGN KEY (doc_id) REFERENCES rag_documents(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE rag_embeddings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chunk_rowid INTEGER NOT NULL,
            doc_id INTEGER NOT NULL,
            embedding BLOB NOT NULL,
            FOREIGN KEY (chunk_rowid) REFERENCES rag_chunks(id),
            FOREIGN KEY (doc_id) REFERENCES rag_documents(id)
          )
        ''');
      },
    );
  }

  Database get _d {
    if (_db == null) throw StateError('RagDatabase not ready');
    return _db!;
  }

  Future<int> insertDocument(
    String projectId,
    String name,
    String filePath,
    int size,
  ) async {
    await ensureReady();
    return _d.insert('rag_documents', {
      'project_id': projectId,
      'name': name,
      'path': filePath,
      'size': size,
      'created_at': DateTime.now().toIso8601String(),
      'enabled': 1,
    });
  }

  Future<List<int>> insertChunks(int docId, List<RagChunk> chunks) async {
    await ensureReady();
    final batch = _d.batch();
    for (final c in chunks) {
      batch.insert('rag_chunks', {
        'content': c.content,
        'doc_id': docId,
        'position': c.position,
      });
    }
    final results = await batch.commit(noResult: false);
    return results.cast<int>();
  }

  Future<void> insertEmbedding(
    int chunkRowid,
    int docId,
    List<double> vector,
  ) async {
    await ensureReady();
    final bytes = Float64List.fromList(vector).buffer.asUint8List();
    await _d.insert('rag_embeddings', {
      'chunk_rowid': chunkRowid,
      'doc_id': docId,
      'embedding': bytes,
    });
  }

  Future<List<RagDocument>> getDocumentsByProject(String projectId) async {
    await ensureReady();
    final rows = await _d.query(
      'rag_documents',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return rows.map(RagDocument.fromMap).toList();
  }

  Future<List<RagEmbeddingRow>> getEmbeddingsByProject(
    String projectId,
  ) async {
    await ensureReady();
    final rows = await _d.rawQuery('''
      SELECT e.chunk_rowid, e.doc_id, d.name, c.content, c.position, e.embedding
      FROM rag_embeddings e
      JOIN rag_chunks c ON c.id = e.chunk_rowid
      JOIN rag_documents d ON d.id = e.doc_id
      WHERE d.project_id = ? AND d.enabled = 1
    ''', [projectId]);

    return rows.map((r) {
      final bytes = r['embedding'] as Uint8List;
      // BLOB length must be a multiple of 8 bytes; otherwise it was
      // written by a future / corrupted writer and we skip safely.
      final view = Float64List.view(bytes.buffer, bytes.offsetInBytes,
          bytes.lengthInBytes ~/ 8);
      return RagEmbeddingRow(
        chunkRowid: r['chunk_rowid'] as int,
        docId: r['doc_id'] as int,
        name: r['name'] as String,
        content: r['content'] as String,
        position: r['position'] as int,
        embedding: view.toList(),
      );
    }).toList();
  }

  Future<void> deleteDocument(int docId) async {
    await ensureReady();
    final batch = _d.batch();
    batch.delete('rag_embeddings', where: 'doc_id = ?', whereArgs: [docId]);
    batch.delete('rag_chunks', where: 'doc_id = ?', whereArgs: [docId]);
    batch.delete('rag_documents', where: 'id = ?', whereArgs: [docId]);
    await batch.commit();
  }

  Future<void> setDocumentEnabled(int docId, bool enabled) async {
    await ensureReady();
    await _d.update(
      'rag_documents',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [docId],
    );
  }

  Future<bool> documentExists(String projectId, String name) async {
    await ensureReady();
    final rows = await _d.query(
      'rag_documents',
      where: 'project_id = ? AND name = ?',
      whereArgs: [projectId, name],
    );
    return rows.isNotEmpty;
  }

  /// Total size (bytes) of `rag.db` on disk. Used by the Storage
  /// screen so the user can see the cost of their indexed docs.
  Future<int> databaseSizeBytes() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    final f = File(dbPath);
    if (!f.existsSync()) return 0;
    try {
      return f.lengthSync();
    } catch (_) {
      return 0;
    }
  }
}

final ragDb = RagDatabase();
