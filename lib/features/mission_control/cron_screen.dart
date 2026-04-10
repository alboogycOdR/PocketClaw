/// List of cron jobs with schedule, last/next run, enabled toggle
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/usage_stats.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'mission_control_providers.dart';

class CronScreen extends ConsumerWidget {
  const CronScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restClient = ref.watch(gatewayRestClientProvider);
    final cronAsync = ref.watch(mcCronJobsProvider);

    if (restClient == null) {
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
            onPressed: () => ref.invalidate(mcCronJobsProvider),
          ),
        ],
      ),
      body: cronAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return const EmptyState(
              icon: Icons.schedule,
              message: 'No cron jobs configured',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mcCronJobsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _CronTile(
                  job: job,
                  onToggle: (enabled) async {
                    try {
                      await restClient.toggleCronJob(
                        job.id,
                        enabled: enabled,
                      );
                      ref.invalidate(mcCronJobsProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to toggle: $e'),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load cron jobs\n$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(mcCronJobsProvider),
        ),
      ),
    );
  }
}

class _CronTile extends StatelessWidget {
  final CronJob job;
  final ValueChanged<bool> onToggle;

  const _CronTile({required this.job, required this.onToggle});

  @override
  Widget build(BuildContext context) {
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
                  child: Text(
                    job.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: job.enabled ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
                Switch(
                  value: job.enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PocketClawTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                job.schedule,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: PocketClawTheme.electricTeal,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(label: 'Last', value: job.lastRun ?? 'Never'),
                const SizedBox(width: 16),
                _InfoChip(label: 'Next', value: job.nextRun ?? 'N/A'),
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

  const _InfoChip({required this.label, required this.value});

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
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}
