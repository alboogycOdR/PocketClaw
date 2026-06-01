library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/hermes_commander_theme.dart';
import '../../data/providers/integration_providers.dart';

class OpenNotebookScreen extends ConsumerStatefulWidget {
  const OpenNotebookScreen({super.key});

  @override
  ConsumerState<OpenNotebookScreen> createState() =>
      _OpenNotebookScreenState();
}

class _OpenNotebookScreenState extends ConsumerState<OpenNotebookScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<_OpenNotebookState>? _stateFuture;

  @override
  void initState() {
    super.initState();
    _stateFuture = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_OpenNotebookState> _load({String query = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = (prefs.getString('opennotebook_base_url') ?? '').trim();
    if (baseUrl.isEmpty) {
      return const _OpenNotebookState.notConfigured();
    }

    try {
      final notebooksResponse = await http
          .get(Uri.parse('$baseUrl/api/notebooks'))
          .timeout(const Duration(seconds: 8));
      final searchResponse = query.isEmpty
          ? null
          : await http
                .get(
                  Uri.parse(
                    '$baseUrl/api/search',
                  ).replace(queryParameters: {'q': query}),
                )
                .timeout(const Duration(seconds: 8));

      final notebooks = _decodeList(notebooksResponse.body);
      final searchResults = searchResponse == null
          ? const <Map<String, dynamic>>[]
          : _decodeList(searchResponse.body);

      return _OpenNotebookState(
        baseUrl: baseUrl,
        configured: true,
        reachable: notebooksResponse.statusCode == 200,
        notebooks: notebooks,
        searchResults: searchResults,
      );
    } catch (e) {
      return _OpenNotebookState(
        baseUrl: baseUrl,
        configured: true,
        reachable: false,
        error: e.toString(),
      );
    }
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    if (decoded is Map<String, dynamic>) {
      final items =
          decoded['items'] as List? ??
          decoded['results'] as List? ??
          decoded['notebooks'] as List? ??
          const [];
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  void _refresh({String query = ''}) {
    setState(() {
      _stateFuture = _load(query: query);
    });
  }

  void _chatWithNotebook(
    BuildContext context,
    Map<String, dynamic> notebook,
    String baseUrl,
  ) {
    final title =
        (notebook['name'] ?? notebook['title'] ?? 'Untitled').toString();
    final id = (notebook['id'] ?? '').toString();
    final prefill =
        '[Notebook context: "$title"${id.isNotEmpty ? " (id: $id)" : ""}]\n'
        'Please use this notebook as context for our conversation.\n\n';
    ref.read(pendingChatContextProvider.notifier).state = prefill;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notebook "$title" attached — navigate to Chat'),
        duration: const Duration(seconds: 3),
      ),
    );
    context.go('/');
  }

  Future<void> _addNoteFromClipboard(
    BuildContext context,
    Map<String, dynamic> notebook,
    String baseUrl,
  ) async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }
    final id = (notebook['id'] ?? '').toString();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notebook ID not found')),
      );
      return;
    }
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/notes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'notebook_id': id, 'content': text}),
          )
          .timeout(const Duration(seconds: 10));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added from clipboard')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open-Notebook')),
      body: FutureBuilder<_OpenNotebookState>(
        future: _stateFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final state = snapshot.data!;
          if (!state.configured) {
            return const _ConfigRequired(
              title: 'Open-Notebook not configured',
              body:
                  'Set opennotebook_base_url in settings or preferences before using this screen.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    state.reachable ? Icons.check_circle : Icons.error_outline,
                    color: state.reachable
                        ? HCTheme.statusGreen
                        : HCTheme.statusRed,
                  ),
                  title: Text(
                    state.reachable ? 'Server online' : 'Server offline',
                  ),
                  subtitle: Text(
                    state.error ?? state.baseUrl,
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 11,
                      color: HCTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _StatBlock(
                        label: 'Notebooks',
                        value: '${state.notebooks.length}',
                      ),
                      _StatBlock(
                        label: 'Search Hits',
                        value: '${state.searchResults.length}',
                      ),
                      _StatBlock(
                        label: 'Status',
                        value: state.reachable ? 'Online' : 'Offline',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search notes and notebooks',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () =>
                        _refresh(query: _searchController.text.trim()),
                  ),
                ),
                onSubmitted: (value) => _refresh(query: value.trim()),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notebooks',
                        style: TextStyle(
                          fontFamily: 'GeistSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (state.notebooks.isEmpty)
                        const Text(
                          'No notebooks found.',
                          style: TextStyle(color: HCTheme.textSecondary),
                        )
                      else
                        ...state.notebooks.take(20).map((notebook) {
                          final title =
                              (notebook['name'] ??
                                      notebook['title'] ??
                                      'Untitled')
                                  .toString();
                          final sources =
                              notebook['sourceCount'] ??
                              notebook['sources_count'] ??
                              0;
                          final updated =
                              (notebook['updatedAt'] ??
                                      notebook['updated_at'] ??
                                      '')
                                  .toString();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(title),
                            subtitle: Text(
                              'sources: $sources${updated.isEmpty ? '' : ' · updated: $updated'}',
                              style: const TextStyle(
                                fontFamily: 'GeistMono',
                                fontSize: 11,
                                color: HCTheme.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: HCTheme.textSecondary,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _NotebookDetailScreen(
                                  notebook: notebook,
                                  baseUrl: state.baseUrl,
                                  onChatWith: () => _chatWithNotebook(
                                    context,
                                    notebook,
                                    state.baseUrl,
                                  ),
                                  onAddNote: () => _addNoteFromClipboard(
                                    context,
                                    notebook,
                                    state.baseUrl,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              if (_searchController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Search Results',
                          style: TextStyle(
                            fontFamily: 'GeistSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.searchResults.isEmpty)
                          const Text(
                            'No matching notes found.',
                            style: TextStyle(color: HCTheme.textSecondary),
                          )
                        else
                          ...state.searchResults.take(10).map((result) {
                            final preview =
                                (result['content'] ??
                                        result['snippet'] ??
                                        result['text'] ??
                                        '')
                                    .toString();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                preview.isEmpty ? '(empty note)' : preview,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OpenNotebookState {
  final String baseUrl;
  final bool configured;
  final bool reachable;
  final List<Map<String, dynamic>> notebooks;
  final List<Map<String, dynamic>> searchResults;
  final String? error;

  const _OpenNotebookState({
    required this.baseUrl,
    required this.configured,
    required this.reachable,
    this.notebooks = const [],
    this.searchResults = const [],
    this.error,
  });

  const _OpenNotebookState.notConfigured()
    : baseUrl = '',
      configured = false,
      reachable = false,
      notebooks = const [],
      searchResults = const [],
      error = null;
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;

  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 12,
              color: HCTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notebook detail ──────────────────────────────────────────────────────────

class _NotebookDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notebook;
  final String baseUrl;
  final VoidCallback onChatWith;
  final VoidCallback onAddNote;

  const _NotebookDetailScreen({
    required this.notebook,
    required this.baseUrl,
    required this.onChatWith,
    required this.onAddNote,
  });

  @override
  State<_NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<_NotebookDetailScreen> {
  late Future<_NotebookDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _load();
  }

  Future<_NotebookDetail> _load() async {
    final id = (widget.notebook['id'] ?? '').toString();
    if (id.isEmpty) {
      return const _NotebookDetail(sources: [], notes: []);
    }
    final baseUrl = widget.baseUrl;

    Future<List<Map<String, dynamic>>> fetch(String path) async {
      try {
        final resp = await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return const [];
        final decoded = jsonDecode(resp.body);
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
        if (decoded is Map<String, dynamic>) {
          for (final key in ['items', 'results', 'sources', 'notes', 'data']) {
            final v = decoded[key];
            if (v is List) return v.whereType<Map<String, dynamic>>().toList();
          }
        }
        return const [];
      } catch (_) {
        return const [];
      }
    }

    final results = await Future.wait([
      fetch('/api/notebooks/$id/sources'),
      fetch('/api/notes?notebook=$id'),
    ]);
    return _NotebookDetail(sources: results[0], notes: results[1]);
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.notebook['name'] ??
            widget.notebook['title'] ??
            'Untitled')
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste_outlined, size: 20),
            tooltip: 'Add note from clipboard',
            onPressed: () {
              widget.onAddNote();
              Navigator.of(context).pop();
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_outlined, size: 20, color: HCTheme.gold),
            tooltip: 'Chat with this notebook',
            onPressed: () {
              widget.onChatWith();
            },
          ),
        ],
      ),
      body: FutureBuilder<_NotebookDetail>(
        future: _detailFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snap.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _detailFuture = _load());
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _DetailSection(
                  label: 'Sources',
                  count: detail.sources.length,
                  icon: Icons.link_outlined,
                  emptyMessage: 'No sources in this notebook.',
                  children: detail.sources.map((s) {
                    final name = (s['title'] ?? s['name'] ?? s['url'] ?? 'Untitled').toString();
                    final type = (s['type'] ?? s['source_type'] ?? '').toString();
                    final url = (s['url'] ?? '').toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        type.contains('pdf')
                            ? Icons.picture_as_pdf_outlined
                            : url.isNotEmpty
                                ? Icons.language_outlined
                                : Icons.article_outlined,
                        size: 16,
                        color: HCTheme.textSecondary,
                      ),
                      title: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: url.isNotEmpty
                          ? Text(
                              url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'GeistMono',
                                fontSize: 10,
                                color: HCTheme.textSecondary,
                              ),
                            )
                          : type.isNotEmpty
                              ? Text(
                                  type,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: HCTheme.textSecondary,
                                  ),
                                )
                              : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  label: 'Notes',
                  count: detail.notes.length,
                  icon: Icons.notes_outlined,
                  emptyMessage: 'No notes yet.',
                  children: detail.notes.map((n) {
                    final content = (n['content'] ?? n['text'] ?? n['body'] ?? '').toString();
                    final created = (n['created_at'] ?? n['createdAt'] ?? '').toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: HCTheme.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: HCTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.isEmpty ? '(empty)' : content,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (created.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              created,
                              style: const TextStyle(
                                fontFamily: 'GeistMono',
                                fontSize: 10,
                                color: HCTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotebookDetail {
  final List<Map<String, dynamic>> sources;
  final List<Map<String, dynamic>> notes;
  const _NotebookDetail({required this.sources, required this.notes});
}

class _DetailSection extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final String emptyMessage;
  final List<Widget> children;

  const _DetailSection({
    required this.label,
    required this.count,
    required this.icon,
    required this.emptyMessage,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: HCTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HCTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: HCTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HCTheme.border),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  color: HCTheme.textSecondary,
                  fontFamily: 'GeistMono',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(
            emptyMessage,
            style: const TextStyle(
              fontSize: 13,
              color: HCTheme.textSecondary,
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _ConfigRequired extends StatelessWidget {
  final String title;
  final String body;

  const _ConfigRequired({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.settings_outlined,
              size: 32,
              color: HCTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 13,
                color: HCTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
