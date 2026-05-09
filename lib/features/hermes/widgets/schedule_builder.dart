/// Compact scheduling form for new cron jobs. Two modes:
///   - Once  — pick a date + time (writes `kind: once, run_at: ISO`)
///   - Cron  — type a 5-field cron expression (writes `kind: cron,
///             expression: "..."`); the builder also offers a few
///             one-tap presets (every-15-min / hourly / daily 09:00 /
///             weekdays 09:00 / Mondays 09:00).
///
/// Returns a [CronSchedule] via callback when the user picks/saves.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/hermes/models/hermes_cron_job.dart';

class ScheduleBuilder extends StatefulWidget {
  final CronSchedule? initial;
  final ValueChanged<CronSchedule> onChanged;

  const ScheduleBuilder({
    super.key,
    this.initial,
    required this.onChanged,
  });

  @override
  State<ScheduleBuilder> createState() => _ScheduleBuilderState();
}

class _ScheduleBuilderState extends State<ScheduleBuilder> {
  late String _kind; // 'once' | 'cron'
  DateTime _runAt = DateTime.now().add(const Duration(hours: 1));
  final _expressionCtl = TextEditingController();

  static const _presets = <(String label, String expr)>[
    ('Every 15 min', '*/15 * * * *'),
    ('Hourly', '0 * * * *'),
    ('Daily 09:00', '0 9 * * *'),
    ('Weekdays 09:00', '0 9 * * 1-5'),
    ('Mondays 09:00', '0 9 * * 1'),
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _kind = init?.kind ?? 'cron';
    if (init?.runAt != null) {
      final parsed = DateTime.tryParse(init!.runAt!);
      if (parsed != null) _runAt = parsed;
    }
    if (init?.expression != null) {
      _expressionCtl.text = init!.expression!;
    }
    _expressionCtl.addListener(_emit);
  }

  @override
  void dispose() {
    _expressionCtl.dispose();
    super.dispose();
  }

  void _emit() {
    if (_kind == 'once') {
      widget.onChanged(CronSchedule(
        kind: 'once',
        runAt: _runAt.toUtc().toIso8601String(),
        display: _formatRunAt(_runAt),
      ));
    } else {
      final expr = _expressionCtl.text.trim();
      widget.onChanged(CronSchedule(
        kind: 'cron',
        expression: expr,
        display: _displayFromCronExpr(expr),
      ));
    }
  }

  String _formatRunAt(DateTime t) {
    final local = t.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String? _displayFromCronExpr(String expr) {
    if (expr.isEmpty) return null;
    final preset = _presets.firstWhere(
      (p) => p.$2 == expr,
      orElse: () => ('', ''),
    );
    return preset.$1.isEmpty ? expr : preset.$1;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _runAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_runAt),
    );
    if (time == null) return;
    setState(() {
      _runAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'once',
              icon: Icon(Icons.event, size: 16),
              label: Text('Once'),
            ),
            ButtonSegment(
              value: 'cron',
              icon: Icon(Icons.repeat, size: 16),
              label: Text('Recurring'),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: (s) {
            setState(() => _kind = s.first);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        if (_kind == 'once') _buildOnce() else _buildCron(),
      ],
    );
  }

  Widget _buildOnce() {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(
          _formatRunAt(_runAt),
          style: GoogleFonts.jetBrainsMono(fontSize: 13),
        ),
        subtitle: const Text('Tap to change',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _pickDateTime,
      ),
    );
  }

  Widget _buildCron() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in _presets)
              ActionChip(
                label: Text(p.$1, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _expressionCtl.text = p.$2;
                  _emit();
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _expressionCtl,
          style: GoogleFonts.jetBrainsMono(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            labelText: 'Cron expression (5 fields)',
            hintText: '0 9 * * 1-5',
            prefixIcon: const Icon(Icons.code, size: 18),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'min hour day month dow',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: PocketClawTheme.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
