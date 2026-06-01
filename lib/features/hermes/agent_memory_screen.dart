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

class AgentMemoryScreen extends ConsumerStatefulWidget {
  const AgentMemoryScreen({super.key});

  @override
  ConsumerState<AgentMemoryScreen> createState() => _AgentMemoryScreenState();
}

class _AgentMemoryScreenState extends ConsumerState<AgentMemoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<_AgentMemoryState>? _stateFuture;

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

  Future<_AgentMemoryState> _load({String query = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = (prefs.getString('agentmemory_base_url') ?? '').trim();
    if (baseUrl.isEmpty) {
      return const _AgentMemoryState.notConfigured();
    }

    try {
      final healthResponse = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 6));
      final statsResponse = await http
          .get(Uri.parse('$baseUrl/api/stats'))
          .timeout(const Duration(seconds: 6));
      final memoriesResponse = await http
          .get(
            Uri.parse(
              '$baseUrl/api/memories',
            ).replace(queryParameters: query.isEmpty ? null : {'q': query}),
          )
          .timeout(const Duration(seconds: 8));

      final health = _decodeMap(healthResponse.body);
      final stats = _decodeMap(statsResponse.body);
      final memories = _decodeList(memoriesResponse.body);

      return _AgentMemoryState(
        baseUrl: baseUrl,
        configured: true,
        reachable: healthResponse.statusCode == 200,
        health: health,
        stats: stats,
        memories: memories,
      );
    } catch (e) {
      return _AgentMemoryState(
        baseUrl: baseUrl,
        configured: true,
        reachable: false,
        error: e.toString(),
      );
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    if (decoded is Map<String, dynamic>) {
      final items =
          decoded['items'] as List? ?? decoded['memories'] as List? ?? const [];
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  void _refresh({String query = ''}) {
    setState(() {
      _stateFuture = _load(query: query);
    });
  }

  void _attachToSession(BuildContext context, String content) {
    final prefill = '[Memory context]\n$content\n\n';
    ref.read(pendingChatContextProvider.notifier).state = prefill;
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memory attached — navigate to Chat to use it'),
        duration: Duration(seconds: 3),
      ),
    );
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AgentMemory')),
      body: FutureBuilder<_AgentMemoryState>(
        future: _stateFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final state = snapshot.data!;
          if (!state.configured) {
            return _ConfigRequired(
              title: 'AgentMemory not configured',
              body:
                  'Set agentmemory_base_url in settings or preferences before using this screen.',
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
                        label: 'Memories',
                        value:
                            '${state.stats['totalMemories'] ?? state.stats['memoryCount'] ?? 0}',
                      ),
                      _StatBlock(
                        label: 'Sessions',
                        value:
                            '${state.stats['totalSessions'] ?? state.stats['sessionCount'] ?? 0}',
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
                  hintText: 'Search memories',
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
                        'Search Results',
                        style: TextStyle(
                          fontFamily: 'GeistSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (state.memories.isEmpty)
                        const Text(
                          'No memories found.',
                          style: TextStyle(color: HCTheme.textSecondary),
                        )
                      else
                        ...state.memories.take(20).map((memory) {
                          final content =
                              (memory['content'] ?? memory['text'] ?? '')
                                  .toString();
                          final tags = memory['tags'];
                          final session =
                              (memory['session'] ??
                                      memory['sessionId'] ??
                                      'unknown')
                                  .toString();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              content.isEmpty ? '(empty memory)' : content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'session: $session'
                              '${tags is List && tags.isNotEmpty ? ' · tags: ${tags.join(", ")}' : ''}',
                              style: const TextStyle(
                                fontFamily: 'GeistMono',
                                fontSize: 11,
                                color: HCTheme.textSecondary,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.send_outlined,
                                size: 18,
                                color: HCTheme.gold,
                              ),
                              tooltip: 'Attach to next Hermes message',
                              onPressed: content.isEmpty
                                  ? null
                                  : () => _attachToSession(context, content),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AgentMemoryState {
  final String baseUrl;
  final bool configured;
  final bool reachable;
  final Map<String, dynamic> health;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> memories;
  final String? error;

  const _AgentMemoryState({
    required this.baseUrl,
    required this.configured,
    required this.reachable,
    this.health = const {},
    this.stats = const {},
    this.memories = const [],
    this.error,
  });

  const _AgentMemoryState.notConfigured()
    : baseUrl = '',
      configured = false,
      reachable = false,
      health = const {},
      stats = const {},
      memories = const [],
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
