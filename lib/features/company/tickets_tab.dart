/// Tickets (Issues) tab — `GET /issues` + create / status update / comment.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

const _issueStatuses = [
  'backlog',
  'todo',
  'in_progress',
  'in_review',
  'blocked',
  'done',
  'cancelled',
];

class TicketsTab extends ConsumerWidget {
  const TicketsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(paperclipRestClientProvider);
    final companyId = ref.watch(paperclipCompanyIdProvider);
    final async = ref.watch(paperclipIssuesProvider);

    if (client == null || companyId == null) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Paperclip not configured.',
      );
    }

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: friendlyPaperclipError(e),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(paperclipIssuesProvider),
        ),
        data: (issues) {
          if (issues.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(paperclipIssuesProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: EmptyState(
                      icon: Icons.confirmation_number_outlined,
                      message: 'No issues yet.',
                    ),
                  ),
                ],
              ),
            );
          }

          final groups = <String, List<PaperclipIssue>>{};
          for (final i in issues) {
            groups.putIfAbsent(i.status, () => []).add(i);
          }
          final orderedKeys = _issueStatuses
              .where((s) => groups.containsKey(s))
              .toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(paperclipIssuesProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final status in orderedKeys) ...[
                  _StatusHeader(
                    status: status,
                    count: groups[status]!.length,
                  ),
                  for (final issue in groups[status]!)
                    _IssueCard(issue: issue),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'issues_fab',
        onPressed: () => _showCreateDialog(context, ref, client, companyId),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    PaperclipRestClient client,
    String companyId,
  ) async {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    String priority = 'medium';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('New issue'),
        content: StatefulBuilder(
          builder: (ctx, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Priority: ',
                      style: TextStyle(color: Colors.white70)),
                  DropdownButton<String>(
                    value: priority,
                    items: const [
                      DropdownMenuItem(
                          value: 'critical', child: Text('critical')),
                      DropdownMenuItem(value: 'high', child: Text('high')),
                      DropdownMenuItem(
                          value: 'medium', child: Text('medium')),
                      DropdownMenuItem(value: 'low', child: Text('low')),
                    ],
                    onChanged: (v) =>
                        setInner(() => priority = v ?? 'medium'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (titleCtl.text.trim().isEmpty) return;

    try {
      await client.createIssue(
        companyId,
        title: titleCtl.text.trim(),
        description:
            descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
        priority: priority,
      );
      ref.invalidate(paperclipIssuesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyPaperclipError(e))),
        );
      }
    }
  }
}

class _StatusHeader extends StatelessWidget {
  final String status;
  final int count;

  const _StatusHeader({required this.status, required this.count});

  Color get _color => switch (status) {
        'done' => PocketClawTheme.success,
        'in_progress' => PocketClawTheme.amber,
        'in_review' => const Color(0xFF9C27B0),
        'blocked' => PocketClawTheme.lobsterRed,
        'todo' => PocketClawTheme.warning,
        'backlog' => Colors.white38,
        'cancelled' => Colors.white24,
        _ => Colors.white54,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: _color,
            ),
          ),
          const SizedBox(width: 6),
          Text('· $count',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }
}

class _IssueCard extends ConsumerWidget {
  final PaperclipIssue issue;

  const _IssueCard({required this.issue});

  Color get _priorityColor => switch (issue.priority) {
        'critical' => PocketClawTheme.lobsterRed,
        'high' => PocketClawTheme.amber,
        'medium' => PocketClawTheme.warning,
        'low' => Colors.white54,
        _ => Colors.white38,
      };

  Future<void> _moveTo(
    BuildContext context,
    WidgetRef ref,
    String next,
  ) async {
    final client = ref.read(paperclipRestClientProvider);
    if (client == null) return;
    try {
      await client.updateIssue(issue.id, {'status': next});
      ref.invalidate(paperclipIssuesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyPaperclipError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      if (issue.assigneeAgentId != null)
                        Text(
                          '→ ${issue.assigneeAgentId}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _priorityColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    issue.priority,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final next in _validNext(issue.status))
                  ActionChip(
                    label: Text(next.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 10)),
                    onPressed: () => _moveTo(context, ref, next),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Spec §5.5 lifecycle:
  //   backlog → todo → in_progress → in_review → done
  //                        └─ blocked ─┘
  //   terminal: done, cancelled
  List<String> _validNext(String current) {
    switch (current) {
      case 'backlog':
        return ['todo', 'cancelled'];
      case 'todo':
        return ['in_progress', 'cancelled'];
      case 'in_progress':
        return ['in_review', 'blocked', 'done'];
      case 'in_review':
        return ['done', 'in_progress'];
      case 'blocked':
        return ['in_progress', 'cancelled'];
      case 'done':
      case 'cancelled':
        return ['todo'];
      default:
        return ['todo', 'in_progress', 'done'];
    }
  }
}
