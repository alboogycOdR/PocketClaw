/// Memory browser with Local / Server tabs, search bar, file tree, card grid
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/memory_note.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/empty_state.dart';
import 'note_editor.dart';
import 'search_view.dart';

// Default agent name on single-agent OpenClaw gateways. Matches the
// sessionKey prefix we see in server traffic ("agent:main:..."). If a
// deployment uses a different agent, we'll switch to calling
// `agent.identity.get` first — for now this covers the common case.
const String _kDefaultAgentId = 'main';

/// Local notes from the on-device SQLite store.
final _localNotesProvider = FutureProvider<List<MemoryNote>>((ref) async {
  final localMemory = ref.watch(localMemoryProvider);
  return localMemory.getAllNotes();
});

/// Server-side memory files via the `agents.files.list` WS RPC. The
/// gateway's REST `/api/memory*` paths don't exist — they fall through
/// to the SPA catch-all and return HTML. Only bootstrap files + MEMORY.md
/// are returned by the server (whitelisted in `ALLOWED_FILE_NAMES`).
final _serverFilesProvider = FutureProvider<List<MemoryFile>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return [];
  final result = await client.request(
    'agents.files.list',
    {'agentId': _kDefaultAgentId},
  );
  if (result is! Map) return [];
  final rawFiles = result['files'];
  if (rawFiles is! List) return [];
  return rawFiles
      .whereType<Map>()
      .where((f) => f['missing'] != true)
      .map((f) {
        final updatedMs = f['updatedAtMs'];
        return MemoryFile(
          name: (f['name'] as String?) ?? '?',
          path: (f['path'] as String?) ?? '',
          isDirectory: false,
          modified: updatedMs is int
              ? DateTime.fromMillisecondsSinceEpoch(updatedMs)
              : null,
        );
      })
      .toList();
});

/// Health of the agent's memory subsystem (embedding provider, dreaming).
/// Surfaced as a small header card — nice to have, not required.
final _memoryStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return const {};
  try {
    final result = await client.request(
      'doctor.memory.status',
      const {},
    );
    return result is Map
        ? Map<String, dynamic>.from(result)
        : const <String, dynamic>{};
  } catch (_) {
    return const {};
  }
});

/// Body of a specific memory file. Used by the file-view screen.
final memoryFileContentProvider =
    FutureProvider.family<String, String>((ref, fileName) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return '';
  final result = await client.request(
    'agents.files.get',
    {'agentId': _kDefaultAgentId, 'name': fileName},
  );
  if (result is! Map) return '';
  final file = result['file'];
  if (file is! Map) return '';
  if (file['missing'] == true) return '';
  return (file['content'] as String?) ?? '';
});

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MemorySearchView(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, size: 16),
                  SizedBox(width: 6),
                  Text('Local'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('Server'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LocalNotesGrid(),
          _ServerFileBrowser(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const NoteEditor()),
          );
          if (saved == true) {
            ref.invalidate(_localNotesProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LocalNotesGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(_localNotesProvider);

    return notesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'Failed to load notes:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(_localNotesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (notes) {
        if (notes.isEmpty) {
          return const EmptyState(
            icon: Icons.note_outlined,
            message: 'No local notes yet',
            actionLabel: 'Create Note',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_localNotesProvider),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              return _NoteCard(note: notes[index]);
            },
          ),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final MemoryNote note;

  const _NoteCard({required this.note});

  Color get _folderColor => switch (note.folder) {
        'work' => PocketClawTheme.bronze,
        'personal' => PocketClawTheme.amber,
        'projects' => const Color(0xFF7C4DFF),
        'research' => PocketClawTheme.warning,
        _ => PocketClawTheme.onSurfaceMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NoteEditor(existingNote: note),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folder badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _folderColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  note.folder,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _folderColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Content preview
              Expanded(
                child: Text(
                  note.content,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.fade,
                ),
              ),

              // Tags and date
              const SizedBox(height: 6),
              Row(
                children: [
                  if (note.tags.isNotEmpty)
                    Expanded(
                      child: Text(
                        note.tags.map((t) => '#$t').join(' '),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: PocketClawTheme.electricTeal.withAlpha(150),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Text(
                    note.modified.timeAgo,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: Colors.white30,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerFileBrowser extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(_serverFilesProvider);
    final statusAsync = ref.watch(_memoryStatusProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_serverFilesProvider);
        ref.invalidate(_memoryStatusProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Memory-subsystem health header (embedding provider, dreaming)
          statusAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: _MemoryStatusHeader.new,
          ),

          const SizedBox(height: 12),

          // File list from agents.files.list
          filesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => _ServerErrorCard(
              error: error,
              onRetry: () => ref.invalidate(_serverFilesProvider),
            ),
            data: (files) {
              if (files.isEmpty) {
                return const EmptyState(
                  icon: Icons.cloud_off,
                  message: 'No memory files on the server yet',
                );
              }
              return Column(
                children: [
                  for (final f in files) _ServerFileTile(file: f),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MemoryStatusHeader extends StatelessWidget {
  final Map<String, dynamic> status;
  const _MemoryStatusHeader(this.status);

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final embedding = status['embedding'];
    final provider = status['provider'] as String?;
    final embOk = embedding is Map ? embedding['ok'] == true : false;
    final dreaming = status['dreaming'];
    final promotedToday =
        dreaming is Map ? dreaming['promotedToday'] as int? : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 20,
              color: embOk
                  ? PocketClawTheme.success
                  : PocketClawTheme.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Memory subsystem',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (provider != null) 'Embedding: $provider',
                      embOk ? '✓ online' : '⚠ degraded',
                      if (promotedToday != null)
                        'Promoted today: $promotedToday',
                    ].join('  ·  '),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerFileTile extends StatelessWidget {
  final MemoryFile file;
  const _ServerFileTile({required this.file});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.description_outlined, size: 18),
        title: Text(file.name,
            style: GoogleFonts.jetBrainsMono(fontSize: 13)),
        subtitle: Text(
          file.modified != null
              ? 'Modified ${file.modified!.timeAgo}'
              : file.path,
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
        trailing:
            const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _ServerFileViewer(file: file),
          ));
        },
      ),
    );
  }
}

class _ServerFileViewer extends ConsumerWidget {
  final MemoryFile file;
  const _ServerFileViewer({required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(memoryFileContentProvider(file.name));
    return Scaffold(
      appBar: AppBar(title: Text(file.name)),
      body: contentAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54)),
          ),
        ),
        data: (content) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            content.isEmpty ? '(empty file)' : content,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerErrorCard extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ServerErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 36, color: Colors.white24),
            const SizedBox(height: 10),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
