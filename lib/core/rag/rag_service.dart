/// High-level API for the on-device knowledge base:
/// indexDocument / deleteDocument / setDocumentEnabled / search.
///
/// Only plain-text formats (.txt, .md) are extracted in this first
/// cut — PDF support waits on the `pdfx` package being added.
library;

import 'dart:io';

import 'rag_chunker.dart';
import 'rag_database.dart';
import 'rag_embedding_service.dart';
import 'rag_retrieval_service.dart';

enum RagIndexStage { extracting, chunking, indexing, embedding, done }

class RagIndexProgress {
  final RagIndexStage stage;
  final String message;
  final double? fraction;
  const RagIndexProgress({
    required this.stage,
    required this.message,
    this.fraction,
  });
}

class RagService {
  final _chunker = RagChunker();

  Future<void> ensureReady() => ragDb.ensureReady();

  Future<List<RagDocument>> getDocumentsByProject(String projectId) =>
      ragDb.getDocumentsByProject(projectId);

  Future<int> indexDocument({
    required String projectId,
    required String filePath,
    required String fileName,
    required int fileSize,
    void Function(RagIndexProgress)? onProgress,
  }) async {
    await ensureReady();

    if (await ragDb.documentExists(projectId, fileName)) {
      throw Exception('"$fileName" is already in the knowledge base');
    }

    onProgress?.call(RagIndexProgress(
      stage: RagIndexStage.extracting,
      message: 'Extracting text from $fileName…',
    ));

    const maxChars = 500000;
    final raw = await _extractText(filePath, fileName);
    final text = raw.length > maxChars ? raw.substring(0, maxChars) : raw;
    if (text.trim().isEmpty) {
      throw Exception('Could not extract text from $fileName');
    }

    onProgress?.call(const RagIndexProgress(
      stage: RagIndexStage.chunking,
      message: 'Splitting into chunks…',
    ));
    final chunks = _chunker.chunk(text);
    if (chunks.isEmpty) {
      throw Exception('Document produced no indexable content');
    }

    onProgress?.call(RagIndexProgress(
      stage: RagIndexStage.indexing,
      message: 'Indexing ${chunks.length} chunks…',
    ));
    final docId =
        await ragDb.insertDocument(projectId, fileName, filePath, fileSize);
    final rowIds = await ragDb.insertChunks(docId, chunks);

    onProgress?.call(const RagIndexProgress(
      stage: RagIndexStage.embedding,
      message: 'Generating embeddings…',
      fraction: 0,
    ));

    if (!ragEmbeddingService.isLoaded) await ragEmbeddingService.load();

    // Embedding may throw UnsupportedError on the current fllama; if
    // it does on the first chunk, bail with a friendly message and
    // delete the half-indexed doc so the user can retry once the
    // backend is in place.
    for (var i = 0; i < chunks.length; i++) {
      try {
        final vector = await ragEmbeddingService.embed(chunks[i].content);
        await ragDb.insertEmbedding(rowIds[i], docId, vector);
      } on UnsupportedError catch (e) {
        await ragDb.deleteDocument(docId);
        throw Exception(
            'Embedding backend not yet wired in this build. $e');
      }
      onProgress?.call(RagIndexProgress(
        stage: RagIndexStage.embedding,
        message: 'Embedding chunk ${i + 1}/${chunks.length}…',
        fraction: (i + 1) / chunks.length,
      ));
    }

    onProgress?.call(const RagIndexProgress(
      stage: RagIndexStage.done,
      message: 'Done',
      fraction: 1,
    ));
    return docId;
  }

  Future<void> deleteDocument(int docId) => ragDb.deleteDocument(docId);

  Future<void> setDocumentEnabled(int docId, bool enabled) =>
      ragDb.setDocumentEnabled(docId, enabled);

  Future<String> searchForPrompt(String projectId, String query) async {
    final result = await ragRetrievalService.search(projectId, query);
    return ragRetrievalService.formatForPrompt(result);
  }

  Future<String> _extractText(String filePath, String fileName) async {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      throw UnsupportedError(
        'PDF extraction requires the `pdfx` package. Add it to '
        'pubspec.yaml and wire `PdfDocument.openFile` here.',
      );
    }
    if (lower.endsWith('.txt') ||
        lower.endsWith('.md') ||
        lower.endsWith('.markdown') ||
        lower.endsWith('.text') ||
        lower.endsWith('.log') ||
        lower.endsWith('.csv')) {
      return File(filePath).readAsString();
    }
    // Best-effort UTF-8 read for unknown extensions.
    try {
      return await File(filePath).readAsString();
    } catch (_) {
      throw Exception('Unsupported file type: $fileName');
    }
  }
}

final ragService = RagService();
