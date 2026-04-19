/// Riverpod providers for Mission Control — fetch real data from Gateway REST
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent.dart';
import '../../data/models/gateway_event.dart';
import '../../data/models/task.dart';
import '../../data/models/usage_stats.dart';
import '../../data/providers/core_providers.dart';

// All of the REST endpoints below may not be implemented on every gateway
// build — the /__openclaw__/api/* surface is partial and evolves. We catch
// fetch errors and fall back to empty/default values so the Mission Control
// screen degrades gracefully (tiles show "—" / 0) instead of blowing up
// with a type-cast error from Dio trying to parse the SPA index HTML.

// ── Agents ──

final mcAgentsProvider = FutureProvider<List<Agent>>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) return [];
  try {
    return await client.getAgents();
  } catch (_) {
    return [];
  }
});

// ── Tasks ──

final mcTasksProvider = FutureProvider<List<Task>>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) return [];
  try {
    return await client.getTasks();
  } catch (_) {
    return [];
  }
});

// ── Usage Stats ──

final mcUsageProvider = FutureProvider<UsageStats>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) return const UsageStats();
  try {
    return await client.getUsageStats();
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

final mcCronJobsProvider = FutureProvider<List<CronJob>>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) return [];
  try {
    return await client.getCronJobs();
  } catch (_) {
    return [];
  }
});

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
