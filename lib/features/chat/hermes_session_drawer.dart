library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/hermes_commander_theme.dart';
import '../../core/session/session_history.dart';
import '../../core/session/session_title_store.dart';
import '../../data/models/chat_message.dart';
import '../../data/providers/chat_providers.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/hermes_providers.dart';
import '../../shared/extensions.dart';

class HermesSessionDrawer extends ConsumerStatefulWidget {
  final Future<void> Function(String key) onSessionSelected;
  final Future<void> Function() onNewSession;

  const HermesSessionDrawer({
    super.key,
    required this.onSessionSelected,
    required this.onNewSession,
  });

  @override
  ConsumerState<HermesSessionDrawer> createState() =>
      _HermesSessionDrawerState();
}

class _HermesSessionDrawerState extends ConsumerState<HermesSessionDrawer> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportTranscript() async {
    final messages = ref.read(messagesProvider);
    if (messages.isEmpty) {
      _showToast('No messages to export.');
      return;
    }
    final transcript = messages
        .map(
          (message) =>
              '[${message.timestamp.toIso8601String()}] '
              '${message.role.name.toUpperCase()}: ${message.content}',
        )
        .join('\n\n');
    await Clipboard.setData(ClipboardData(text: transcript));
    _showToast('Transcript copied to clipboard.');
  }

  Future<void> _exportJson() async {
    final messages = ref.read(messagesProvider);
    if (messages.isEmpty) {
      _showToast('No messages to export.');
      return;
    }
    final payload = jsonEncode(
      messages.map((message) => message.toJson()).toList(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    _showToast('Session JSON copied to clipboard.');
  }

  Future<void> _importSession() async {
    final data = await Clipboard.getData('text/plain');
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) {
      _showToast('Clipboard is empty.');
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Expected a JSON array.');
      }
      final imported = decoded
          .whereType<Map>()
          .map(
            (entry) => ChatMessage.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();
      if (imported.isEmpty) {
        throw const FormatException('No chat messages found.');
      }

      final session = ref.read(sessionManagerProvider);
      final messagesNotifier = ref.read(messagesProvider.notifier);
      await session.startNewSession();
      messagesNotifier.clear();
      for (final message in imported) {
        await session.addMessage(message);
        messagesNotifier.add(message);
      }

      final firstUser = imported.firstWhere(
        (message) => message.role == MessageRole.user,
        orElse: () => imported.first,
      );
      final prefs = ref.read(sharedPrefsProvider);
      final titleStore = SessionTitleStore(prefs);
      await titleStore.setTitle(
        session.currentSessionKey,
        firstUser.content
            .replaceAll(RegExp(r'\s+'), ' ')
            .truncate(42, ellipsis: '…'),
      );

      ref.read(currentSessionKeyProvider.notifier).state =
          session.currentSessionKey;
      ref.invalidate(sessionListAutoProvider);
      if (!mounted) return;
      _showToast('Session imported from clipboard.');
      Navigator.of(context).pop();
    } catch (_) {
      _showToast('Clipboard does not contain a valid session export.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionListAutoProvider);
    final currentKey = ref.watch(currentSessionKeyProvider);
    final prefs = ref.watch(sharedPrefsProvider);
    final titleStore = SessionTitleStore(prefs);
    final modelLabel = ref.watch(hermesModelIdProvider).valueOrNull ?? 'Hermes';

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(320.0, 420.0),
          decoration: const BoxDecoration(
            color: HCTheme.bgPanel,
            border: Border(right: BorderSide(color: HCTheme.border)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Sessions',
                          style: TextStyle(
                            fontFamily: 'GeistSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: HCTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: 'New session',
                        onPressed: () async {
                          await widget.onNewSession();
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontFamily: 'GeistSans',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search sessions',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: HCTheme.bgSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: HCTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: HCTheme.border),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: sessionsAsync.when(
                    data: (sessions) {
                      final filtered = sessions.where((session) {
                        final title =
                            titleStore.getTitle(session.key) ??
                            'Session ${session.startedAt.shortDate}';
                        final query = _searchController.text
                            .trim()
                            .toLowerCase();
                        if (query.isEmpty) return true;
                        return title.toLowerCase().contains(query) ||
                            session.key.toLowerCase().contains(query);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text(
                            'No saved sessions.',
                            style: TextStyle(
                              fontFamily: 'GeistSans',
                              fontSize: 13,
                              color: HCTheme.textSecondary,
                            ),
                          ),
                        );
                      }

                      final pinned = <SessionInfo>[];
                      final today = <SessionInfo>[];
                      final yesterday = <SessionInfo>[];
                      final thisWeek = <SessionInfo>[];
                      final older = <SessionInfo>[];
                      final now = DateTime.now();
                      for (final session in filtered) {
                        final diff = now.difference(session.startedAt);
                        if (session.isActive) {
                          pinned.add(session);
                        } else if (session.startedAt.year == now.year &&
                            session.startedAt.month == now.month &&
                            session.startedAt.day == now.day) {
                          today.add(session);
                        } else if (diff.inDays < 2) {
                          yesterday.add(session);
                        } else if (diff.inDays < 7) {
                          thisWeek.add(session);
                        } else {
                          older.add(session);
                        }
                      }

                      return ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          if (pinned.isNotEmpty)
                            _SessionSection(
                              label: 'PINNED',
                              sessions: pinned,
                              currentKey: currentKey,
                              titleStore: titleStore,
                              onTap: (key) async {
                                await widget.onSessionSelected(key);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                            ),
                          if (today.isNotEmpty)
                            _SessionSection(
                              label: 'TODAY',
                              sessions: today,
                              currentKey: currentKey,
                              titleStore: titleStore,
                              onTap: (key) async {
                                await widget.onSessionSelected(key);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                            ),
                          if (yesterday.isNotEmpty)
                            _SessionSection(
                              label: 'YESTERDAY',
                              sessions: yesterday,
                              currentKey: currentKey,
                              titleStore: titleStore,
                              onTap: (key) async {
                                await widget.onSessionSelected(key);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                            ),
                          if (thisWeek.isNotEmpty)
                            _SessionSection(
                              label: 'THIS WEEK',
                              sessions: thisWeek,
                              currentKey: currentKey,
                              titleStore: titleStore,
                              onTap: (key) async {
                                await widget.onSessionSelected(key);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                            ),
                          if (older.isNotEmpty)
                            _SessionSection(
                              label: 'OLDER',
                              sessions: older,
                              currentKey: currentKey,
                              titleStore: titleStore,
                              onTap: (key) async {
                                await widget.onSessionSelected(key);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                            ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          '$error',
                          style: const TextStyle(
                            fontFamily: 'GeistMono',
                            fontSize: 11,
                            color: HCTheme.statusRed,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: HCTheme.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MODEL',
                        style: TextStyle(
                          fontFamily: 'GeistSans',
                          fontSize: 10,
                          color: HCTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: HCTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HCTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_outlined,
                              size: 14,
                              color: HCTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                modelLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'GeistSans',
                                  fontSize: 12,
                                  color: HCTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(
                            Icons.folder_outlined,
                            size: 14,
                            color: HCTheme.textMuted,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'HermesCommander / default workspace',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'GeistMono',
                                fontSize: 10,
                                color: HCTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _DrawerAction(
                            label: 'Transcript',
                            onTap: _exportTranscript,
                          ),
                          const SizedBox(width: 8),
                          _DrawerAction(label: 'JSON', onTap: _exportJson),
                          const SizedBox(width: 8),
                          _DrawerAction(label: 'Import', onTap: _importSession),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionSection extends StatelessWidget {
  final String label;
  final List<SessionInfo> sessions;
  final String currentKey;
  final SessionTitleStore titleStore;
  final Future<void> Function(String key) onTap;

  const _SessionSection({
    required this.label,
    required this.sessions,
    required this.currentKey,
    required this.titleStore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HCTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...sessions.map((session) {
          final title =
              titleStore.getTitle(session.key) ??
              'Session ${session.startedAt.shortDate}';
          final isActive = session.key == currentKey;
          return InkWell(
            onTap: () => onTap(session.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? HCTheme.bgActive : Colors.transparent,
                border: isActive
                    ? const Border(
                        left: BorderSide(color: HCTheme.gold, width: 2),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (session.isActive) ...[
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: HCTheme.gold,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'GeistSans',
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isActive
                                      ? HCTheme.textPrimary
                                      : HCTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _SessionMetaChip(
                              label: session.mode.toUpperCase(),
                              accent: HCTheme.goldMuted,
                            ),
                            _SessionMetaText(
                              '${session.messageCount} messages',
                            ),
                            _SessionMetaText('${session.tokenCount} tok'),
                            _SessionMetaText(session.startedAt.timeAgo),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: HCTheme.statusAmber,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SessionMetaChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _SessionMetaChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withAlpha(35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent.withAlpha(90)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'GeistMono',
          fontSize: 9,
          color: HCTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SessionMetaText extends StatelessWidget {
  final String label;

  const _SessionMetaText(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'GeistMono',
        fontSize: 10,
        color: HCTheme.textMuted,
      ),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DrawerAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: HCTheme.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: HCTheme.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'GeistSans',
            fontSize: 11,
            color: HCTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
