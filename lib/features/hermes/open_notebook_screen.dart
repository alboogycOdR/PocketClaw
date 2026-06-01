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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.content_paste_outlined,
                                    size: 18,
                                  ),
                                  tooltip: 'Add note from clipboard',
                                  onPressed: () => _addNoteFromClipboard(
                                    context,
                                    notebook,
                                    state.baseUrl,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.chat_outlined,
                                    size: 18,
                                    color: HCTheme.gold,
                                  ),
                                  tooltip: 'Chat with this notebook',
                                  onPressed: () => _chatWithNotebook(
                                    context,
                                    notebook,
                                    state.baseUrl,
                                  ),
                                ),
                              ],
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
