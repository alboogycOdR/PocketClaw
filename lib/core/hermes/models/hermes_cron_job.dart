/// Hermes cron job — one element of `~/.hermes/cron/jobs.json`.
/// Translated from Scarf's HermesCronJob.swift.
/// SPEC-MultiTransport §8.3.
library;

class CronSchedule {
  final String kind; // 'once' | 'cron'
  final String? runAt; // ISO8601 for one-shot
  final String? display; // Human-readable label
  final String? expression; // Cron expression e.g. "0 9 * * 1"

  const CronSchedule({
    required this.kind,
    this.runAt,
    this.display,
    this.expression,
  });

  factory CronSchedule.fromJson(Map<String, dynamic> json) => CronSchedule(
        kind: json['kind'] as String? ?? 'once',
        runAt: json['run_at'] as String?,
        display: json['display'] as String?,
        expression: json['expression'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (runAt != null) 'run_at': runAt,
        if (display != null) 'display': display,
        if (expression != null) 'expression': expression,
      };
}

class HermesCronJob {
  final String id;
  final String name;
  final String prompt;
  final List<String>? skills;
  final String? model;
  final CronSchedule schedule;
  final bool enabled;
  final String state; // 'scheduled' | 'running' | 'completed' | 'failed'
  final String? deliver; // 'telegram' | 'discord:channel' | null
  final String? nextRunAt;
  final String? lastRunAt;
  final String? lastError;
  final String? workdir;

  const HermesCronJob({
    required this.id,
    required this.name,
    required this.prompt,
    required this.schedule,
    required this.enabled,
    required this.state,
    this.skills,
    this.model,
    this.deliver,
    this.nextRunAt,
    this.lastRunAt,
    this.lastError,
    this.workdir,
  });

  String get stateIcon => switch (state) {
        'scheduled' => '🕐',
        'running' => '▶️',
        'completed' => '✅',
        'failed' => '❌',
        _ => '❓',
      };

  bool get isRunning => state == 'running';
  bool get hasFailed => state == 'failed';

  factory HermesCronJob.fromJson(Map<String, dynamic> json) => HermesCronJob(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        skills: (json['skills'] as List?)?.cast<String>(),
        model: json['model'] as String?,
        schedule: CronSchedule.fromJson(
            json['schedule'] as Map<String, dynamic>? ?? const {}),
        enabled: json['enabled'] as bool? ?? true,
        state: json['state'] as String? ?? 'scheduled',
        deliver: json['deliver'] as String?,
        nextRunAt: json['next_run_at'] as String?,
        lastRunAt: json['last_run_at'] as String?,
        lastError: json['last_error'] as String?,
        workdir: json['workdir'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'prompt': prompt,
        if (skills != null) 'skills': skills,
        if (model != null) 'model': model,
        'schedule': schedule.toJson(),
        'enabled': enabled,
        'state': state,
        if (deliver != null) 'deliver': deliver,
        if (nextRunAt != null) 'next_run_at': nextRunAt,
        if (lastRunAt != null) 'last_run_at': lastRunAt,
        if (lastError != null) 'last_error': lastError,
        if (workdir != null) 'workdir': workdir,
      };

  HermesCronJob copyWith({bool? enabled}) => HermesCronJob(
        id: id,
        name: name,
        prompt: prompt,
        skills: skills,
        model: model,
        schedule: schedule,
        enabled: enabled ?? this.enabled,
        state: state,
        deliver: deliver,
        nextRunAt: nextRunAt,
        lastRunAt: lastRunAt,
        lastError: lastError,
        workdir: workdir,
      );
}

class CronJobsFile {
  final List<HermesCronJob> jobs;
  final String? updatedAt;

  const CronJobsFile({required this.jobs, this.updatedAt});

  factory CronJobsFile.fromJson(Map<String, dynamic> json) => CronJobsFile(
        jobs: (json['jobs'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(HermesCronJob.fromJson)
            .toList(),
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'jobs': jobs.map((j) => j.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}
