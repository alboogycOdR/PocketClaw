/// Pending-approvals queue. Centralises permission requests from both:
///   - active-chat ACP turns (`AcpPermissionRequestEvent`), and
///   - background runs delivered via REST poll (Hermes `/v1/approvals`)
///
/// The Control tab badge + ApprovalsPanel both watch this. The active
/// ACP responder still lives on `acpPermissionResponderProvider`; this
/// notifier just mirrors the pending list so the UI can render outside
/// of an active chat.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hermes/acp/acp_models.dart';

enum ApprovalSource { acp, rest }

class PendingApproval {
  /// requestId for ACP, server-side id for REST.
  final String id;
  final String toolCallTitle;
  final String toolCallKind;
  final List<AcpPermissionOption> options;
  final DateTime receivedAt;
  final ApprovalSource source;

  const PendingApproval({
    required this.id,
    required this.toolCallTitle,
    required this.toolCallKind,
    required this.options,
    required this.receivedAt,
    required this.source,
  });
}

class ApprovalsNotifier extends StateNotifier<List<PendingApproval>> {
  ApprovalsNotifier() : super(const []);

  /// Mirror an ACP permission event into the pending queue. Idempotent
  /// — re-emits with the same requestId are dropped.
  void addAcpApproval(AcpPermissionRequestEvent event) {
    final id = event.requestId.toString();
    if (state.any((a) => a.id == id)) return;
    state = [
      ...state,
      PendingApproval(
        id: id,
        toolCallTitle: event.toolCallTitle,
        toolCallKind: event.toolCallKind,
        options: event.options,
        receivedAt: DateTime.now(),
        source: ApprovalSource.acp,
      ),
    ];
  }

  /// Add a REST-polled approval. The server payload shape isn't pinned
  /// yet (see ADR-001 §4.1 question 2); this assumes minimal fields and
  /// falls back to allow/deny options if none are provided.
  void addRestApproval(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty || state.any((a) => a.id == id)) return;
    state = [
      ...state,
      PendingApproval(
        id: id,
        toolCallTitle: json['action'] as String? ?? 'Approval requested',
        toolCallKind: json['tool'] as String? ?? 'other',
        options: const [
          AcpPermissionOption(optionId: 'allow', name: 'Allow'),
          AcpPermissionOption(optionId: 'deny', name: 'Deny'),
        ],
        receivedAt: DateTime.now(),
        source: ApprovalSource.rest,
      ),
    ];
  }

  void resolve(String id) {
    state = state.where((a) => a.id != id).toList();
  }

  void clearAll() => state = const [];
}

final approvalsProvider =
    StateNotifierProvider<ApprovalsNotifier, List<PendingApproval>>(
  (_) => ApprovalsNotifier(),
);

final pendingApprovalCountProvider = Provider<int>(
  (ref) => ref.watch(approvalsProvider).length,
);
