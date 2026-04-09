/// Usage and cost tracking models
library;

class UsageStats {
  final double costToday;
  final double costWeek;
  final double costMonth;
  final int inputTokens;
  final int outputTokens;
  final Map<String, double> costByModel;
  final Map<String, double> costByAgent;

  const UsageStats({
    this.costToday = 0,
    this.costWeek = 0,
    this.costMonth = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.costByModel = const {},
    this.costByAgent = const {},
  });

  factory UsageStats.fromJson(Map<String, dynamic> json) => UsageStats(
        costToday: (json['costToday'] as num?)?.toDouble() ?? 0,
        costWeek: (json['costWeek'] as num?)?.toDouble() ?? 0,
        costMonth: (json['costMonth'] as num?)?.toDouble() ?? 0,
        inputTokens: json['inputTokens'] as int? ?? 0,
        outputTokens: json['outputTokens'] as int? ?? 0,
        costByModel: (json['costByModel'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        costByAgent: (json['costByAgent'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
      );

  int get totalTokens => inputTokens + outputTokens;
}

class SystemHealth {
  final double cpuPercent;
  final double ramPercent;
  final double diskPercent;
  final bool gatewayRunning;
  final int activeAgents;
  final int activeSessions;
  final DateTime lastHeartbeat;

  const SystemHealth({
    this.cpuPercent = 0,
    this.ramPercent = 0,
    this.diskPercent = 0,
    this.gatewayRunning = false,
    this.activeAgents = 0,
    this.activeSessions = 0,
    required this.lastHeartbeat,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) => SystemHealth(
        cpuPercent: (json['cpuPercent'] as num?)?.toDouble() ?? 0,
        ramPercent: (json['ramPercent'] as num?)?.toDouble() ?? 0,
        diskPercent: (json['diskPercent'] as num?)?.toDouble() ?? 0,
        gatewayRunning: json['gatewayRunning'] as bool? ?? false,
        activeAgents: json['activeAgents'] as int? ?? 0,
        activeSessions: json['activeSessions'] as int? ?? 0,
        lastHeartbeat: json['lastHeartbeat'] != null
            ? DateTime.parse(json['lastHeartbeat'] as String)
            : DateTime.now(),
      );
}

class CronJob {
  final String id;
  final String name;
  final String schedule;
  final String? lastRun;
  final String? nextRun;
  final bool enabled;

  const CronJob({
    required this.id,
    required this.name,
    required this.schedule,
    this.lastRun,
    this.nextRun,
    this.enabled = true,
  });

  factory CronJob.fromJson(Map<String, dynamic> json) => CronJob(
        id: json['id'] as String,
        name: json['name'] as String,
        schedule: json['schedule'] as String,
        lastRun: json['lastRun'] as String?,
        nextRun: json['nextRun'] as String?,
        enabled: json['enabled'] as bool? ?? true,
      );
}
