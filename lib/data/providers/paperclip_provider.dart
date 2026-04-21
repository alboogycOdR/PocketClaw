/// Paperclip state & per-tab data providers.
///
/// Paperclip is a standalone REST service (NOT push-based). See
/// `docs/PocketClaw-Paperclip-Architecture-v2.0.md`. This file replaces
/// the legacy WebSocket push-event notifier; every tab now pulls via
/// `PaperclipRestClient` through the AsyncNotifier below or one of the
/// per-tab FutureProviders.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gateway/paperclip_rest.dart';
import 'core_providers.dart';

/// Lightweight state: the resolved company + its dashboard snapshot.
/// Per-tab detail lists (issues, goals, approvals, activity) live in their
/// own FutureProviders so each tab can refresh independently.
class PaperclipState {
  final String? companyId;
  final PaperclipCompany? company;
  final PaperclipDashboard? dashboard;

  const PaperclipState({this.companyId, this.company, this.dashboard});

  bool get configured => companyId != null;
}

class PaperclipNotifier extends AsyncNotifier<PaperclipState> {
  @override
  Future<PaperclipState> build() async {
    final client = ref.watch(paperclipRestClientProvider);
    if (client == null) return const PaperclipState();

    final companies = await client.getCompanies();
    if (companies.isEmpty) return const PaperclipState();

    final company = companies.first;
    PaperclipDashboard? dashboard;
    try {
      dashboard = await client.getDashboard(company.id);
    } catch (_) {
      dashboard = null;
    }
    return PaperclipState(
      companyId: company.id,
      company: company,
      dashboard: dashboard,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final paperclipProvider =
    AsyncNotifierProvider<PaperclipNotifier, PaperclipState>(
  PaperclipNotifier.new,
);

/// Resolve the active company id — any tab wanting more data uses this.
final paperclipCompanyIdProvider = Provider<String?>((ref) {
  return ref.watch(paperclipProvider).value?.companyId;
});

// ── Per-tab pull providers ────────────────────────────────────────────────

final paperclipAgentsProvider =
    FutureProvider<List<PaperclipAgent>>((ref) async {
  final client = ref.watch(paperclipRestClientProvider);
  final companyId = ref.watch(paperclipCompanyIdProvider);
  if (client == null || companyId == null) return const [];
  return client.getAgents(companyId);
});

final paperclipOrgChartProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.watch(paperclipRestClientProvider);
  final companyId = ref.watch(paperclipCompanyIdProvider);
  if (client == null || companyId == null) return null;
  return client.getOrgChart(companyId);
});

final paperclipIssuesProvider =
    FutureProvider<List<PaperclipIssue>>((ref) async {
  final client = ref.watch(paperclipRestClientProvider);
  final companyId = ref.watch(paperclipCompanyIdProvider);
  if (client == null || companyId == null) return const [];
  return client.getIssues(companyId);
});

final paperclipGoalsProvider =
    FutureProvider<List<PaperclipGoal>>((ref) async {
  final client = ref.watch(paperclipRestClientProvider);
  final companyId = ref.watch(paperclipCompanyIdProvider);
  if (client == null || companyId == null) return const [];
  return client.getGoals(companyId);
});

final paperclipCostSummaryProvider =
    FutureProvider<PaperclipCostSummary?>((ref) async {
  final client = ref.watch(paperclipRestClientProvider);
  final companyId = ref.watch(paperclipCompanyIdProvider);
  if (client == null || companyId == null) return null;
  return client.getCostSummary(companyId);
});

final paperclipCostByAgentProvider =
    FutureProvider<List<PaperclipAgentCost>>((ref) async {
  final client = ref.watch(paperclipRestClientProvider);
  final companyId = ref.watch(paperclipCompanyIdProvider);
  if (client == null || companyId == null) return const [];
  return client.getCostByAgent(companyId);
});

final paperclipApprovalsProvider =
    FutureProvider<List<PaperclipApproval>>((ref) async {
  final client = ref.watch(paperclipRestClientProvider);
  final companyId = ref.watch(paperclipCompanyIdProvider);
  if (client == null || companyId == null) return const [];
  return client.getApprovals(companyId, status: 'pending');
});

final paperclipActivityProvider =
    FutureProvider<List<PaperclipActivityEntry>>((ref) async {
  final client = ref.watch(paperclipRestClientProvider);
  final companyId = ref.watch(paperclipCompanyIdProvider);
  if (client == null || companyId == null) return const [];
  return client.getActivity(companyId);
});
