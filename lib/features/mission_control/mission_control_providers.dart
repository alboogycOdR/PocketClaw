/// Riverpod providers for Mission Control — fetch real data from Gateway REST
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent.dart';
import '../../data/models/gateway_event.dart';
import '../../data/models/task.dart';
import '../../data/models/usage_stats.dart';
import '../../data/providers/core_providers.dart';

// The Mission Control providers talk to the gateway over WebSocket JSON-RPC
// (see memory/gateway_control_surface.md for the authoritative methods).
// The legacy /__openclaw__/api/* REST paths for these surfaces return the
// SPA's index.html and can't be relied on. We catch errors and fall back to
// empty/default values so the screen degrades gracefully (tiles show "—" /
// 0) instead of blowing up when the gateway is unreachable.

// ── Agents ──
// `agents.list` returns config-only entries: no running/idle status and no
// token counts. Those would need a second call to `sessions.usage` to
// enrich from `aggregates.byAgent[]` — deferred for now.

final mcAgentsProvider = FutureProvider<List<Agent>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return [];
  try {
    final result = await client.request('agents.list', {});
    if (result is! Map) return [];
    final agents = result['agents'];
    if (agents is! List) return [];
    return [
      for (final a in agents)
        if (a is Map<String, dynamic>) Agent.fromSummary(a),
    ];
  } catch (_) {
    return [];
  }
});

// ── Tasks ──
// The gateway has no `tasks.*` RPC surface — confirmed via 2026-04-21 recon.
// We keep the provider around so existing callers (TasksScreen kanban,
// Dashboard legacy card) don't crash, but it always returns an empty list.
// The Dashboard now shows Sessions instead; see mcSessionsCountProvider.

final mcTasksProvider = FutureProvider<List<Task>>((_) async => const []);

// ── Sessions count ──
// Derived from `sessions.usage` — used on the Dashboard as a live-activity
// indicator in place of the unimplemented tasks surface.

final mcSessionsCountProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return 0;
  try {
    // Pull the full window (default ~30d) so `sessions.length` reflects the
    // real count. A small `limit` would cap the count to that limit.
    final result = await client.request('sessions.usage', {'limit': 1000});
    if (result is! Map) return 0;
    final sessions = result['sessions'];
    if (sessions is List) return sessions.length;
    final totals = result['totals'];
    if (totals is Map && totals['sessions'] is num) {
      return (totals['sessions'] as num).toInt();
    }
    return 0;
  } catch (_) {
    return 0;
  }
});

// ── Usage Stats ──
// A single `usage.cost {days:30}` call yields daily cost entries plus a
// grand-total block; we derive today/week/month client-side.

final mcUsageProvider = FutureProvider<UsageStats>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return const UsageStats();
  try {
    final result = await client.request(
      'usage.cost',
      {'days': 30, 'mode': 'utc'},
    );
    if (result is! Map<String, dynamic>) return const UsageStats();
    return UsageStats.fromCostResponse(result);
  } catch (_) {
    return const UsageStats();
  }
});

// ── System Health ──
//
// Driven by the gateway's live `event:"health"` frames rather than a REST
// round-trip. We receive one of these every ~30s on the WS already, and the
// REST `/api/health` endpoint isn't reliably present on current builds.
final mcHealthProvider = StreamProvider<SystemHealth>((ref) async* {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) {
    yield SystemHealth(lastHeartbeat: DateTime.now());
    return;
  }
  // Seed with an "unknown but not crashed" value so the widget renders
  // immediately rather than staying stuck on the loading spinner.
  yield SystemHealth(
    gatewayRunning: true,
    lastHeartbeat: DateTime.now(),
  );
  await for (final payload in client.healthStream) {
    final tsMs = payload['ts'];
    final lastHeartbeat = tsMs is int
        ? DateTime.fromMillisecondsSinceEpoch(tsMs)
        : DateTime.now();
    yield SystemHealth(
      gatewayRunning: payload['ok'] == true,
      lastHeartbeat: lastHeartbeat,
    );
  }
});

// ── Cron Jobs ──
//
// Driven by the WS `cron.list` RPC — the REST `/api/cron` path doesn't
// exist on this gateway (falls through to SPA index HTML like /api/memory
// did). Each entry we expose is the richer cron.list shape; the screen
// can ignore fields it doesn't render yet.

class CronJobEntry {
  final String id;
  final String name;
  final String? description;
  final bool enabled;
  final String scheduleLabel;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final String? lastStatus;
  final String? lastError;
  final Map<String, dynamic> raw;

  const CronJobEntry({
    required this.id,
    required this.name,
    required this.enabled,
    required this.scheduleLabel,
    required this.raw,
    this.description,
    this.nextRunAt,
    this.lastRunAt,
    this.lastStatus,
    this.lastError,
  });
}

String _formatCronSchedule(dynamic schedule) {
  if (schedule is! Map) return '—';
  final kind = schedule['kind'];
  switch (kind) {
    case 'cron':
      final expr = schedule['expr'] as String? ?? '?';
      final tz = schedule['tz'];
      return tz is String ? '$expr ($tz)' : expr;
    case 'every':
      final ms = schedule['everyMs'];
      if (ms is! num) return 'every ?';
      final d = Duration(milliseconds: ms.toInt());
      if (d.inHours >= 1) return 'every ${d.inHours}h';
      if (d.inMinutes >= 1) return 'every ${d.inMinutes}m';
      return 'every ${d.inSeconds}s';
    case 'at':
      final at = schedule['at'] as String? ?? '';
      return 'once at $at';
  }
  return '—';
}

final mcCronJobsProvider = FutureProvider<List<CronJobEntry>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return [];
  try {
    final result = await client.request(
      'cron.list',
      {'includeDisabled': true, 'sortBy': 'nextRunAtMs', 'sortDir': 'asc'},
    );
    if (result is! Map) return [];
    final jobs = result['jobs'];
    if (jobs is! List) return [];
    return [
      for (final j in jobs)
        if (j is Map<String, dynamic>)
          CronJobEntry(
            id: j['id'] as String? ?? '',
            name: j['name'] as String? ?? '(unnamed)',
            description: j['description'] as String?,
            enabled: j['enabled'] == true,
            scheduleLabel: _formatCronSchedule(j['schedule']),
            nextRunAt: _msToDate((j['state'] as Map?)?['nextRunAtMs']),
            lastRunAt: _msToDate((j['state'] as Map?)?['lastRunAtMs']),
            lastStatus: (j['state'] as Map?)?['lastRunStatus'] as String?,
            lastError: (j['state'] as Map?)?['lastError'] as String?,
            raw: j,
          ),
    ];
  } catch (_) {
    return [];
  }
});

DateTime? _msToDate(dynamic ms) {
  if (ms is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms.toInt());
}

/// Toggle a cron job's `enabled` flag via `cron.update`. Admin scope.
Future<void> setCronEnabled(
  WidgetRef ref,
  String jobId,
  bool enabled,
) async {
  final client = ref.read(gatewayClientProvider);
  if (client == null) return;
  await client.request(
    'cron.update',
    {'id': jobId, 'patch': {'enabled': enabled}},
  );
}

/// Fire a cron job immediately, bypassing its schedule. Admin scope.
Future<void> runCronNow(WidgetRef ref, String jobId) async {
  final client = ref.read(gatewayClientProvider);
  if (client == null) return;
  await client.request(
    'cron.run',
    {'id': jobId, 'mode': 'force'},
  );
}

/// Delete a cron job. Admin scope, destructive.
Future<void> removeCronJob(WidgetRef ref, String jobId) async {
  final client = ref.read(gatewayClientProvider);
  if (client == null) return;
  await client.request('cron.remove', {'id': jobId});
}

// ── Activity (live WebSocket events converted to ActivityEvent list) ──

final mcActivityProvider =
    StreamProvider<List<ActivityEvent>>((ref) {
  final wsClient = ref.watch(gatewayClientProvider);
  if (wsClient == null) return Stream.value([]);

  final events = <ActivityEvent>[];
  return wsClient.agentEvents.map((agentEvent) {
    events.insert(
      0,
      ActivityEvent(
        id: '${agentEvent.agentId ?? "sys"}-${agentEvent.timestamp.millisecondsSinceEpoch}',
        message: agentEvent.message ?? _describeEvent(agentEvent),
        agentId: agentEvent.agentId,
        timestamp: agentEvent.timestamp,
      ),
    );
    // Keep at most 100 events in memory
    if (events.length > 100) events.removeLast();
    return List<ActivityEvent>.unmodifiable(events);
  });
});

String _describeEvent(AgentEvent e) {
  return switch (e.type) {
    EventType.agentStart => 'Agent "${e.agentId}" started',
    EventType.agentEnd => 'Agent "${e.agentId}" finished',
    EventType.agentError => 'Agent "${e.agentId}" error',
    EventType.taskProgress => 'Task "${e.taskId}" progress',
    EventType.heartbeat => 'Heartbeat',
  };
}
