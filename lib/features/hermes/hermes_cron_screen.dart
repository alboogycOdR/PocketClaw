/// Hermes cron manager — read jobs.json over SFTP, toggle enabled,
/// surface last-error inline. Write-through on toggle (mirrors Scarf's
/// IOSCronViewModel). SPEC-MultiTransport §11.4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_cron_job.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';

class HermesCronTab extends ConsumerWidget {
  const HermesCronTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncJobs = ref.watch(hermesCronJobsProvider);

    return asyncJobs.when(
      data: (file) {
        if (file.jobs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(hermesCronJobsProvider),
            child: ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.schedule,
                  message: 'No cron jobs configured',
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(hermesCronJobsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: file.jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _CronTile(job: file.jobs[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        message: 'Failed to load cron jobs: $e',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(hermesCronJobsProvider),
      ),
    );
  }
}

class _CronTile extends ConsumerStatefulWidget {
  final HermesCronJob job;
  const _CronTile({required this.job});

  @override
  ConsumerState<_CronTile> createState() => _CronTileState();
}

class _CronTileState extends ConsumerState<_CronTile> {
  bool _busy = false;

  Future<void> _toggle(bool enabled) async {
    setState(() => _busy = true);
    try {
      final svc = await ref.read(hermesDataServiceProvider.future);
      if (svc == null) return;
      await svc.toggleCronJob(widget.job.id, enabled: enabled);
      ref.invalidate(hermesCronJobsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toggle failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final scheduleLabel = job.schedule.display ??
        job.schedule.expression ??
        job.schedule.runAt ??
        job.schedule.kind;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(job.stateIcon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    job.name.isEmpty ? job.id : job.name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: job.enabled,
                    onChanged: _toggle,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              scheduleLabel,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            if (job.prompt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                job.prompt,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (job.model != null)
                  _Meta(icon: Icons.memory, text: job.model!),
                if (job.deliver != null)
                  _Meta(icon: Icons.send, text: job.deliver!),
                if (job.lastRunAt != null)
                  _Meta(
                    icon: Icons.history,
                    text: 'last ${_short(job.lastRunAt!)}',
                  ),
                if (job.nextRunAt != null)
                  _Meta(
                    icon: Icons.event,
                    text: 'next ${_short(job.nextRunAt!)}',
                  ),
              ],
            ),
            if (job.hasFailed && job.lastError != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PocketClawTheme.lobsterRed.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.lastError!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: PocketClawTheme.lobsterRed,
                  ),
                ),
              ),
            ],
          ],
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

String _short(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final d = DateTime.now().difference(t);
  if (d.isNegative) {
    final f = -d.inMinutes;
    if (f.abs() >= 60 * 24) return '${(f.abs() / 1440).floor()}d';
    if (f.abs() >= 60) return '${(f.abs() / 60).floor()}h';
    return '${f.abs()}m';
  }
  if (d.inDays > 0) return '${d.inDays}d ago';
  if (d.inHours > 0) return '${d.inHours}h ago';
  if (d.inMinutes > 0) return '${d.inMinutes}m ago';
  return 'just now';
}
