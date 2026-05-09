/// Riverpod providers for SSH-backed Hermes data (sessions, messages,
/// cron, memory, gateway state, logs, skills). SPEC-MultiTransport §10.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hermes/hermes_data_service.dart';
import '../../core/hermes/models/hermes_analytics.dart';
import '../../core/hermes/models/hermes_cron_job.dart';
import '../../core/hermes/models/hermes_message.dart';
import '../../core/hermes/models/hermes_session.dart';
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
