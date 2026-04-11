/// Paperclip state provider — manages company data received via WebSocket
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paperclip_state.dart';

class PaperclipNotifier extends StateNotifier<PaperclipState> {
  PaperclipNotifier() : super(const PaperclipState());

  void updateConnection(bool connected) {
    state = state.copyWith(isConnected: connected);
  }

  void handleWebSocketEvent(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'overview':
        state = state.copyWith(
          overview: CompanyOverview.fromJson(
            data['payload'] as Map<String, dynamic>? ?? data,
          ),
        );

      case 'orgChart':
        final list = data['payload'] as List<dynamic>? ?? [];
        state = state.copyWith(
          orgChart: list
              .map((e) => OrgMember.fromJson(e as Map<String, dynamic>))
              .toList(),
        );

      case 'goals':
        final list = data['payload'] as List<dynamic>? ?? [];
        state = state.copyWith(
          goals: list
              .map((e) => CompanyGoal.fromJson(e as Map<String, dynamic>))
              .toList(),
        );

      case 'budget':
        state = state.copyWith(
          budget: BudgetInfo.fromJson(
            data['payload'] as Map<String, dynamic>? ?? data,
          ),
        );

      case 'tickets':
        final list = data['payload'] as List<dynamic>? ?? [];
        state = state.copyWith(
          tickets: list
              .map((e) => CompanyTicket.fromJson(e as Map<String, dynamic>))
              .toList(),
        );

      case 'governance':
        final list = data['payload'] as List<dynamic>? ?? [];
        state = state.copyWith(
          governanceDrafts: list
              .map(
                  (e) => GovernanceDraft.fromJson(e as Map<String, dynamic>))
              .toList(),
        );

      case 'security':
        state = state.copyWith(
          security: SecurityDashboard.fromJson(
            data['payload'] as Map<String, dynamic>? ?? data,
          ),
        );

      case 'full_sync':
        // A full state sync from the server
        final payload = data['payload'] as Map<String, dynamic>? ?? {};
        _handleFullSync(payload);
    }
  }

  void _handleFullSync(Map<String, dynamic> payload) {
    state = state.copyWith(
      overview: payload['overview'] != null
          ? CompanyOverview.fromJson(
              payload['overview'] as Map<String, dynamic>)
          : state.overview,
      orgChart: payload['orgChart'] != null
          ? (payload['orgChart'] as List<dynamic>)
              .map((e) => OrgMember.fromJson(e as Map<String, dynamic>))
              .toList()
          : state.orgChart,
      goals: payload['goals'] != null
          ? (payload['goals'] as List<dynamic>)
              .map((e) => CompanyGoal.fromJson(e as Map<String, dynamic>))
              .toList()
          : state.goals,
      budget: payload['budget'] != null
          ? BudgetInfo.fromJson(
              payload['budget'] as Map<String, dynamic>)
          : state.budget,
      tickets: payload['tickets'] != null
          ? (payload['tickets'] as List<dynamic>)
              .map(
                  (e) => CompanyTicket.fromJson(e as Map<String, dynamic>))
              .toList()
          : state.tickets,
      governanceDrafts: payload['governance'] != null
          ? (payload['governance'] as List<dynamic>)
              .map((e) =>
                  GovernanceDraft.fromJson(e as Map<String, dynamic>))
              .toList()
          : state.governanceDrafts,
      security: payload['security'] != null
          ? SecurityDashboard.fromJson(
              payload['security'] as Map<String, dynamic>)
          : state.security,
    );
  }
}

final paperclipProvider =
    StateNotifierProvider<PaperclipNotifier, PaperclipState>((ref) {
  return PaperclipNotifier();
});
