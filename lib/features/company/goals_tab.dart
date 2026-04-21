/// Goals tab — `GET /goals` + create/update via `POST`/`PATCH`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(paperclipRestClientProvider);
    final companyId = ref.watch(paperclipCompanyIdProvider);
    final async = ref.watch(paperclipGoalsProvider);

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
          onAction: () => ref.invalidate(paperclipGoalsProvider),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(paperclipGoalsProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: EmptyState(
                      icon: Icons.flag_outlined,
                      message: 'No goals yet.',
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(paperclipGoalsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _GoalCard(goal: goals[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'goals_fab',
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('New goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
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
          ],
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
      await client.createGoal(
        companyId,
        title: titleCtl.text.trim(),
        description:
            descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
      );
      ref.invalidate(paperclipGoalsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyPaperclipError(e))),
        );
      }
    }
  }
}

class _GoalCard extends ConsumerWidget {
  final PaperclipGoal goal;

  const _GoalCard({required this.goal});

  Color get _statusColor => switch (goal.status) {
        'achieved' => const Color(0xFF4CAF50),
        'active' => PocketClawTheme.electricTeal,
        'planned' => const Color(0xFFFFB74D),
        'cancelled' => Colors.white38,
        _ => Colors.white54,
      };

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    final client = ref.read(paperclipRestClientProvider);
    if (client == null) return;
    try {
      await client.updateGoal(goal.id, {'status': status});
      ref.invalidate(paperclipGoalsProvider);
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 16, color: _statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    goal.status,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (goal.description != null &&
                goal.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                goal.description!,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final next in _nextStatuses(goal.status))
                  ActionChip(
                    label:
                        Text(next, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _setStatus(context, ref, next),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _nextStatuses(String current) {
    switch (current) {
      case 'planned':
        return ['active', 'cancelled'];
      case 'active':
        return ['achieved', 'cancelled'];
      case 'achieved':
      case 'cancelled':
        return ['active'];
      default:
        return ['active', 'achieved', 'cancelled'];
    }
  }
}
