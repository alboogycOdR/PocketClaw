/// Hermes sessions browser — paginated list backed by the SQLite
/// `sessions` table on the VPS, with FTS5 search across messages.
/// SPEC-MultiTransport §11.2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/hermes_commander_theme.dart';
import '../../app/theme.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/utils/date_grouping.dart';
import '../../shared/widgets/empty_state.dart';
import 'hermes_session_detail_screen.dart';

class HermesSessionsTab extends ConsumerStatefulWidget {
  const HermesSessionsTab({super.key});

  @override
  ConsumerState<HermesSessionsTab> createState() => _HermesSessionsTabState();
}

class _HermesSessionsTabState extends ConsumerState<HermesSessionsTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    final asyncSessions = searching
        ? ref.watch(hermesSessionSearchProvider(_query))
        : ref.watch(hermesSessionsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search messages…',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Expanded(
          child: asyncSessions.when(
            data: (sessions) {
              if (sessions.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    if (searching) {
                      ref.invalidate(hermesSessionSearchProvider(_query));
                    } else {
                      ref.invalidate(hermesSessionsProvider);
                    }
                  },
                  child: ListView(
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: searching
                            ? Icons.search_off
                            : Icons.history_toggle_off,
                        message: searching
                            ? 'No matches for "$_query"'
                            : 'No sessions yet',
                      ),
                    ],
                  ),
                );
              }
              // Group by Today / Yesterday / This Week / Earlier so a
              // long session list stays scannable. Search results stay
              // flat — the user is already filtering by query.
              if (searching) {
                return RefreshIndicator(
                  onRefresh: () async => ref
                      .invalidate(hermesSessionSearchProvider(_query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _SessionTile(session: sessions[i]),
                  ),
                );
              }
              final grouped = groupByDate<HermesSession>(
                sessions,
                (s) => s.startedAt,
              );
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(hermesSessionsProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    for (final entry in grouped.entries) ...[
                      _GroupHeader(label: entry.key.label),
                      for (final s in entry.value) ...[
                        _SessionTile(session: s),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              message: 'Failed to load sessions: $e',
              actionLabel: 'Retry',
              onAction: () =>
                  ref.invalidate(hermesSessionsProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final HermesSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HermesSessionDetailScreen(session: session),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            session.isSubagent ? 26 : 12,
            12,
            12,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SourceChip(source: session.source),
                  if (session.isOrchestrator) ...[
                    const SizedBox(width: 6),
                    const _Badge(label: 'Conductor', color: HCTheme.gold),
                  ] else if (session.isSubagent) ...[
                    const SizedBox(width: 6),
                    const _Badge(
                      label: 'Worker',
                      color: Colors.deepPurpleAccent,
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.displayTitle,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (session.displayCostUSD != null)
                    Text(
                      '\$${session.displayCostUSD!.toStringAsFixed(4)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: PocketClawTheme.lobsterRed,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (session.model != null)
                    _Meta(icon: Icons.memory, text: session.model!),
                  _Meta(
                    icon: Icons.chat_bubble_outline,
                    text: '${session.messageCount} msg',
                  ),
                  if (session.toolCallCount > 0)
                    _Meta(
                      icon: Icons.bolt,
                      text: '${session.toolCallCount} tool',
                    ),
                  _Meta(
                    icon: Icons.token,
                    text: _fmtTokens(session.totalTokens),
                  ),
                  if (session.startedAt != null)
                    _Meta(
                      icon: Icons.schedule,
                      text: _fmtAgo(session.startedAt!),
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

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

String _fmtTokens(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M tok';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k tok';
  return '$n tok';
}

class _SourceChip extends StatelessWidget {
  final String source;
  const _SourceChip({required this.source});

  static (String label, Color color) _resolve(String src) => switch (src) {
        'rest' || 'http' || 'https' => ('REST', Color(0xFF3FB950)),
        'acp' || 'websocket' || 'ws' => ('ACP', Color(0xFF58A6FF)),
        'cron' => ('Cron', Color(0xFFF0883E)),
        'telegram' => ('Telegram', Color(0xFF58A6FF)),
        'discord' => ('Discord', Color(0xFF7C3AED)),
        'slack' => ('Slack', Color(0xFF4ECCA3)),
        'cli' => ('CLI', Color(0xFF8B949E)),
        _ => ('CLI', Color(0xFF8B949E)),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          letterSpacing: 0.14,
          fontWeight: FontWeight.w600,
          color: Colors.white38,
        ),
      ),
    );
  }
}

String _fmtAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inDays > 0) return '${d.inDays}d';
  if (d.inHours > 0) return '${d.inHours}h';
  if (d.inMinutes > 0) return '${d.inMinutes}m';
  return 'just now';
}
