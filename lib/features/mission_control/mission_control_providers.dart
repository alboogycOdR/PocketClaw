/// Riverpod providers for Mission Control — fetch real data from Gateway REST
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent.dart';
import '../../data/models/gateway_event.dart';
import '../../data/models/task.dart';
import '../../data/models/usage_stats.dart';
import '../../data/providers/core_providers.dart';

// ── Agents ──

final mcAgentsProvider = FutureProvider<List<Agent>>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) return [];
  return client.getAgents();
});

// ── Tasks ──

final mcTasksProvider = FutureProvider<List<Task>>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) return [];
  return client.getTasks();
});

// ── Usage Stats ──

final mcUsageProvider = FutureProvider<UsageStats>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) return const UsageStats();
  return client.getUsageStats();
});

// ── System Health ──

final mcHealthProvider = FutureProvider<SystemHealth>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) {
    return SystemHealth(
      lastHeartbeat: DateTime.now(),
    );
  }
  return client.getSystemHealth();
});

// ── Cron Jobs ──

final mcCronJobsProvider = FutureProvider<List<CronJob>>((ref) async {
  final client = ref.watch(gatewayRestClientProvider);
  if (client == null) return [];
  return client.getCronJobs();
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
