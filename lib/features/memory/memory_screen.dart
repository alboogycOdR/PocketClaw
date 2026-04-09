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
import 'file_browser.dart';
import 'note_editor.dart';
import 'search_view.dart';

// Real data providers
final _localNotesProvider = FutureProvider<List<MemoryNote>>((ref) async {
  final localMemory = ref.watch(localMemoryProvider);
  return localMemory.getAllNotes();
});

final _serverFilesProvider = FutureProvider<List<MemoryFile>>((ref) async {
  final rest = ref.watch(gatewayRestClientProvider);
  if (rest == null) return [];
  return rest.getMemoryFiles();
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
        'work' => PocketClawTheme.lobsterRed,
        'personal' => PocketClawTheme.electricTeal,
        'projects' => const Color(0xFF7C4DFF),
        'research' => const Color(0xFFFFB74D),
        _ => Colors.white38,
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

    return filesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'Failed to load server files:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(_serverFilesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (files) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_serverFilesProvider),
          child: files.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off, size: 48,
                              color: Colors.white24),
                          SizedBox(height: 12),
                          Text(
                            'No server files found',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : FileBrowser(files: files),
        );
      },
    );
  }
}
