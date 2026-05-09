/// Cron tab: list scheduled jobs with enable toggle, run-now, and delete.
///
/// Backed by the `cron.*` WS methods (core-implemented, independent of
/// plugins). See memory/gateway_protocol_reference.md for the full spec
/// extracted from the live gateway.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/empty_state.dart';
import 'mission_control_providers.dart';

class CronScreen extends ConsumerWidget {
  const CronScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(gatewayClientProvider);
    final jobsAsync = ref.watch(mcCronJobsProvider);

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cron Jobs')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Not connected to Gateway',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cron Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Reload',
            onPressed: () => ref.invalidate(mcCronJobsProvider),
          ),
        ],
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load cron jobs:\n$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(mcCronJobsProvider),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(mcCronJobsProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: EmptyState(
                      icon: Icons.schedule,
                      message: 'No cron jobs configured',
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mcCronJobsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (_, i) => _CronTile(
                job: jobs[i],
                onToggle: (enabled) async {
                  await _toggle(context, ref, jobs[i].id, enabled);
                },
                onRunNow: () async {
                  await _runNow(context, ref, jobs[i].id);
                },
                onDelete: () async {
                  await _delete(context, ref, jobs[i]);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggle(
    BuildContext ctx,
    WidgetRef ref,
    String id,
    bool enabled,
  ) async {
    try {
      await setCronEnabled(ref, id, enabled);
      ref.invalidate(mcCronJobsProvider);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Toggle failed: $e')),
        );
      }
    }
  }

  Future<void> _runNow(
    BuildContext ctx,
    WidgetRef ref,
    String id,
  ) async {
    try {
      await runCronNow(ref, id);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Run triggered')),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Run failed: $e')),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext ctx,
    WidgetRef ref,
    CronJobEntry job,
  ) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete cron job?'),
        content: Text('"${job.name}" will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await removeCronJob(ref, job.id);
      ref.invalidate(mcCronJobsProvider);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }
}

class _CronTile extends StatelessWidget {
  final CronJobEntry job;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRunNow;
  final VoidCallback onDelete;

  const _CronTile({
    required this.job,
    required this.onToggle,
    required this.onRunNow,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (job.lastStatus) {
      'ok' => PocketClawTheme.success,
      'error' => PocketClawTheme.lobsterRed,
      _ => Colors.white38,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: job.enabled
                      ? PocketClawTheme.electricTeal
                      : Colors.white38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              job.enabled ? Colors.white : Colors.white54,
                        ),
                      ),
                      if (job.description != null &&
                          job.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            job.description!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(value: job.enabled, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PocketClawTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                job.scheduleLabel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: PocketClawTheme.electricTeal,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  label: 'Last',
                  value:
                      job.lastRunAt?.timeAgo ?? 'Never',
                  valueColor: statusColor,
                ),
                const SizedBox(width: 16),
                _InfoChip(
                  label: 'Next',
                  value: job.nextRunAt?.timeAgo ?? '—',
                ),
              ],
            ),
            if (job.lastError != null && job.lastError!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                job.lastError!,
                style: TextStyle(
                  fontSize: 11,
                  color: PocketClawTheme.lobsterRed,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onRunNow,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Run now'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: PocketClawTheme.lobsterRed),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: PocketClawTheme.lobsterRed),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoChip({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: valueColor ?? Colors.white60,
          ),
        ),
      ],
    );
  }
}
