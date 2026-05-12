/// Riverpod surface for the on-device knowledge base. The
/// `activeProjectIdProvider` (in core_providers) is the scope key for
/// the document list.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rag/rag_database.dart';
import '../../core/rag/rag_service.dart';

final ragServiceProvider = Provider<RagService>((_) => ragService);

final ragDocumentsProvider =
    FutureProvider.family<List<RagDocument>, String>((ref, projectId) async {
  return ragService.getDocumentsByProject(projectId);
});
