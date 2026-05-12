/// Riverpod providers for SSH-backed Hermes data (sessions, messages,
/// cron, memory, gateway state, logs, skills). SPEC-MultiTransport §10.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hermes/hermes_data_service.dart';
import '../../core/hermes/models/hermes_analytics.dart';
import '../../core/hermes/models/hermes_cron_job.dart';
import '../../core/hermes/models/hermes_memory_entry.dart';
import '../../core/hermes/models/hermes_message.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../core/hermes/models/swarm_tree.dart';
import 'ssh_providers.dart';

/// Resolves the active SSH client (async because it hydrates the password
/// from secure storage) and wraps it in a HermesDataService.
final hermesDataServiceProvider =
    FutureProvider<HermesDataService?>((ref) async {
  final ssh = await ref.watch(sshClientProvider.future);
  if (ssh == null) return null;
  return HermesDataService(ssh: ssh);
});

// ── Sessions ─────────────────────────────────────────────────────────────

final hermesSessionsProvider =
    FutureProvider<List<HermesSession>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getSessions();
});

/// Swarm tree (orchestrators + workers grouped by parent_session_id).
/// Auto-refreshed by Swarm Monitor / Office View screens on a 3s timer.
final swarmSessionsProvider = FutureProvider<SwarmTree>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) {
    return const SwarmTree(orchestrators: [], orphans: []);
  }
  final sessions = await svc.getSessions(limit: 50);
  return SwarmTree.build(sessions);
});

/// Flat list of sessions that have been active in the last 5 minutes.
/// Used by the Office View + Agent Behavior Notifier to decide which
/// agents appear on the floor.
final officeSessionsProvider =
    Provider<AsyncValue<List<HermesSession>>>((ref) {
  return ref.watch(swarmSessionsProvider).whenData((tree) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    return [
      for (final node in tree.orchestrators) ...[
        node.orchestrator,
        ...node.workers,
      ],
      ...tree.orphans,
    ].where((s) {
      final last = s.endedAt ?? s.startedAt;
      if (last == null) return true;
      return last.isAfter(cutoff);
    }).toList();
  });
});

final hermesSessionMessagesProvider =
    FutureProvider.family<List<HermesMessage>, String>((ref, sessionId) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getMessages(sessionId);
});

final hermesSessionSearchProvider =
    FutureProvider.family<List<HermesSession>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.searchSessions(query);
});

final hermesCostSummaryProvider =
    FutureProvider<HermesCostSummary>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const HermesCostSummary();
  return svc.getCostSummary();
});

// ── Analytics (Sprint C) ─────────────────────────────────────────────────

final hermesDailyStatsProvider =
    FutureProvider<List<HermesDailyStats>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getDailyStats(days: 7);
});

final hermesModelStatsProvider =
    FutureProvider<List<HermesModelStats>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getCostByModel();
});

// ── Cron ─────────────────────────────────────────────────────────────────

final hermesCronJobsProvider = FutureProvider<CronJobsFile>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const CronJobsFile(jobs: []);
  return svc.getCronJobs();
});

// ── Memory ───────────────────────────────────────────────────────────────

final hermesMemoryProvider = FutureProvider<String>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return '';
  return svc.readMemory();
});

final hermesMemoryEntriesProvider =
    FutureProvider<List<HermesMemoryEntry>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getMemoryEntries();
});

final hermesUserProfileProvider = FutureProvider<String>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return '';
  return svc.readUserProfile();
});

final hermesSoulProvider = FutureProvider<String>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return '';
  return svc.readSoul();
});

// ── Skills ───────────────────────────────────────────────────────────────

final hermesSkillNamesProvider = FutureProvider<List<String>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getSkillNames();
});

final hermesSkillMdProvider =
    FutureProvider.family<String?, String>((ref, name) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return null;
  return svc.readSkillMd(name);
});

// ── Gateway state ────────────────────────────────────────────────────────

final hermesGatewayStateProvider =
    FutureProvider<HermesGatewayState?>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return null;
  return svc.getGatewayState();
});

// ── Logs ─────────────────────────────────────────────────────────────────

final hermesErrorLogProvider = FutureProvider<List<String>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getErrorLogTail();
});

final hermesGatewayLogProvider = FutureProvider<List<String>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getGatewayLogTail();
});

final hermesAgentLogProvider = FutureProvider<List<String>>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) return const [];
  return svc.getAgentLogTail();
});
