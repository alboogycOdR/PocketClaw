/// Hermes cron manager — read jobs.json over SFTP, toggle enabled,
/// create + delete jobs, surface last-error inline.
/// SPEC-MultiTransport §11.4 + SPEC-HermesDesktopImprovements §Backlog 2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_cron_job.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'widgets/schedule_builder.dart';

class HermesCronTab extends ConsumerWidget {
  const HermesCronTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncJobs = ref.watch(hermesCronJobsProvider);

    return Stack(
      children: [
        asyncJobs.when(
          data: (file) {
            if (file.jobs.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(hermesCronJobsProvider),
                child: ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.schedule,
                      message:
                          'No cron jobs configured.\nTap + to create one.',
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(hermesCronJobsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
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
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'hermes-cron-add',
            onPressed: () => _showCreateSheet(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheet).viewInsets.bottom + 16,
        ),
        child: const _CreateCronForm(),
      ),
    );
    if (created == true) ref.invalidate(hermesCronJobsProvider);
  }
}

// ── Create form ────────────────────────────────────────────────────

class _CreateCronForm extends ConsumerStatefulWidget {
  const _CreateCronForm();

  @override
  ConsumerState<_CreateCronForm> createState() => _CreateCronFormState();
}

class _CreateCronFormState extends ConsumerState<_CreateCronForm> {
  final _name = TextEditingController();
  final _prompt = TextEditingController();
  CronSchedule? _schedule;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _prompt.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and prompt are required.')),
      );
      return;
    }
    if (_schedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a schedule.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = await ref.read(hermesDataServiceProvider.future);
      if (svc == null) throw 'SSH not configured';
      await svc.createCronJob(HermesCronJob(
        id: '',
        name: _name.text.trim(),
        prompt: _prompt.text.trim(),
        schedule: _schedule!,
        enabled: true,
        state: 'scheduled',
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New cron job',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelText: 'Name',
              hintText: 'morning-briefing',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _prompt,
            minLines: 3,
            maxLines: 6,
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelText: 'Prompt',
              hintText: 'Summarise overnight emails…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          ScheduleBuilder(
            onChanged: (s) => setState(() => _schedule = s),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_saving ? 'Saving…' : 'Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tile ───────────────────────────────────────────────────────────

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

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete cron job?'),
        content: Text(
          'This permanently removes "${widget.job.name.isEmpty ? widget.job.id : widget.job.name}" '
          'from jobs.json on the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final svc = await ref.read(hermesDataServiceProvider.future);
      if (svc == null) return;
      await svc.deleteCronJob(widget.job.id);
      ref.invalidate(hermesCronJobsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
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

    return Dismissible(
      key: ValueKey('cron-${job.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _delete();
        // Always return false — _delete handles the data update via
        // provider invalidation, and we don't want the widget removed
        // before the list rebuilds.
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: PocketClawTheme.lobsterRed.withAlpha(60),
        child: Icon(Icons.delete_outline,
            color: PocketClawTheme.lobsterRed),
      ),
      child: Card(
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
