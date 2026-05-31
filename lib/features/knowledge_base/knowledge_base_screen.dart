/// Per-project knowledge base — list of indexed documents with
/// enable/disable toggle and delete swipe. The "+ Add document" FAB
/// triggers the indexing sheet which walks
/// extract → chunk → index → embed.
///
/// The embedding step throws on the installed fllama 0.0.1 — the sheet
/// surfaces the error so the user knows what's blocked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/rag/rag_database.dart';
import '../../core/rag/rag_service.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/rag_providers.dart';
import '../../shared/utils/storage_formatter.dart';
import '../../shared/widgets/empty_state.dart';
import 'knowledge_base_index_sheet.dart';

class KnowledgeBaseScreen extends ConsumerWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ref.watch(activeProjectIdProvider) ?? 'default';
    final docsAsync = ref.watch(ragDocumentsProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () =>
                ref.invalidate(ragDocumentsProvider(projectId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'kb-add',
        onPressed: () => _addDocument(context, ref, projectId),
        child: const Icon(Icons.add),
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load: $e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ragDocumentsProvider(projectId)),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              message:
                  'No documents indexed yet.\nTap + to add a .txt / .md file.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _DocCard(
              doc: docs[i],
              projectId: projectId,
            ),
          );
        },
      ),
    );
  }

  Future<void> _addDocument(
    BuildContext context,
    WidgetRef ref,
    String projectId,
  ) async {
    final indexed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // useSafeArea pushes the sheet above gesture / 3-button nav
      // bars so the "Pick a file" button isn't overlapped by the
      // Android system nav.
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheet).viewInsets.bottom,
        ),
        child: KnowledgeBaseIndexSheet(projectId: projectId),
      ),
    );
    if (indexed == true) {
      ref.invalidate(ragDocumentsProvider(projectId));
    }
  }
}

/// Small status chip rendered next to the document size on the KB list.
/// Tells the user at a glance whether semantic search will actually
/// hit this doc:
///   - "Indexed"   (green)  — every chunk has an embedding
///   - "Text only" (amber)  — chunks exist, zero embeddings (no model
///                            was loaded when the doc was indexed)
///   - "Partial N/M" (amber) — embedding pass was interrupted partway
class _IndexStatusBadge extends StatelessWidget {
  final RagDocument doc;
  const _IndexStatusBadge({required this.doc});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (doc.chunkCount == 0) {
      // Document row exists but no chunks. Shouldn't happen in practice
      // — index() inserts chunks before embeddings — but handle gracefully.
      label = 'No chunks';
      color = PocketClawTheme.lobsterRed;
    } else if (doc.isFullyIndexed) {
      label = 'Indexed';
      color = PocketClawTheme.success;
    } else if (doc.isTextOnly) {
      label = 'Text only';
      color = PocketClawTheme.warning;
    } else {
      label = 'Partial ${doc.embeddingCount}/${doc.chunkCount}';
      color = PocketClawTheme.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DocCard extends ConsumerWidget {
  final RagDocument doc;
  final String projectId;
  const _DocCard({required this.doc, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('rag-${doc.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Remove document?'),
            content: Text(
                'Deletes "${doc.name}" and all its chunks + embeddings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PocketClawTheme.lobsterRed,
                ),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (ok != true) return false;
        await ragService.deleteDocument(doc.id);
        ref.invalidate(ragDocumentsProvider(projectId));
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: PocketClawTheme.lobsterRed.withAlpha(60),
        child: Icon(Icons.delete_outline, color: PocketClawTheme.lobsterRed),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                doc.enabled
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: doc.enabled
                    ? PocketClawTheme.electricTeal
                    : Colors.white38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _IndexStatusBadge(doc: doc),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${formatBytes(doc.size)} · '
                            '${doc.enabled ? "enabled" : "disabled"}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: doc.enabled,
                onChanged: (v) async {
                  await ragService.setDocumentEnabled(doc.id, v);
                  ref.invalidate(ragDocumentsProvider(projectId));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
