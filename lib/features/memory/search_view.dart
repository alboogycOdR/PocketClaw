/// Full-screen search with results from both local and server
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/memory_note.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/source_badge.dart';
import '../../data/models/chat_message.dart';
import 'note_editor.dart';

class MemorySearchView extends ConsumerStatefulWidget {
  const MemorySearchView({super.key});

  @override
  ConsumerState<MemorySearchView> createState() => _MemorySearchViewState();
}

class _MemorySearchViewState extends ConsumerState<MemorySearchView> {
  final TextEditingController _searchController = TextEditingController();
  List<_SearchResult> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      try {
        final memoryManager = ref.read(memoryManagerProvider);
        final notes = await memoryManager.search(query.trim());

        if (!mounted) return;
        setState(() {
          _searching = false;
          _results = notes.map((note) {
            final source = note.source == 'server'
                ? MessageSource.server
                : MessageSource.local;
            // Build a snippet from content
            final content = note.content;
            String snippet;
            final queryLower = query.toLowerCase();
            final idx = content.toLowerCase().indexOf(queryLower);
            if (idx >= 0) {
              final start = (idx - 40).clamp(0, content.length);
              final end = (idx + query.length + 60).clamp(0, content.length);
              snippet = '...${content.substring(start, end)}...';
            } else {
              snippet = content.length > 100
                  ? '${content.substring(0, 100)}...'
                  : content;
            }
            return _SearchResult(
              title: note.title,
              snippet: snippet,
              source: source,
              path: '${note.folder}/${note.title}',
              note: note,
            );
          }).toList();
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searching = false;
          _results = [];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'Search notes and files...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _results = []);
              },
            ),
        ],
      ),
      body: _searching
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Search across all your notes'
                            : 'No results found',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return _ResultTile(result: result);
                  },
                ),
    );
  }
}

class _SearchResult {
  final String title;
  final String snippet;
  final MessageSource source;
  final String path;
  final MemoryNote? note;

  const _SearchResult({
    required this.title,
    required this.snippet,
    required this.source,
    required this.path,
    this.note,
  });
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;

  const _ResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (result.note != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NoteEditor(existingNote: result.note),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                SourceBadge(source: result.source),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.snippet,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              result.path,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: Colors.white30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
