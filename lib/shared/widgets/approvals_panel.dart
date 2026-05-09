/// Compact approvals queue card. Hidden when no approvals are pending;
/// otherwise shows one row per request with kind-coloured chip, age,
/// and the option buttons declared by the ACP server. Resolves
/// in-chat ACP requests via [activeAcpClientProvider]; REST-polled
/// approvals just clear locally for now (server roundtrip TBD).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/approvals_providers.dart';
import '../../data/providers/chat_providers.dart';

class ApprovalsPanel extends ConsumerWidget {
  const ApprovalsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvals = ref.watch(approvalsProvider);
    if (approvals.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      color: const Color(0xFF2A1A10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: PocketClawTheme.lobsterRed.withAlpha(102),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.pending_actions,
                    size: 16, color: PocketClawTheme.lobsterRed),
                const SizedBox(width: 8),
                Text(
                  '${approvals.length} pending approval'
                  '${approvals.length > 1 ? 's' : ''}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PocketClawTheme.lobsterRed,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.read(approvalsProvider.notifier).clearAll(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white38,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Dismiss all',
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF3A2520)),
          ...approvals.map((a) => _ApprovalRow(approval: a)),
        ],
      ),
    );
  }
}

class _ApprovalRow extends ConsumerWidget {
  final PendingApproval approval;
  const _ApprovalRow({required this.approval});

  String _timeAgo(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inSeconds < 60) return '${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    return '${delta.inHours}h ago';
  }

  Color _kindColor(String kind) => switch (kind) {
        'execute' => const Color(0xFF34D399),
        'edit' => const Color(0xFFFBBF24),
        'read' => const Color(0xFF60A5FA),
        'fetch' => const Color(0xFFA78BFA),
        _ => const Color(0xFF9CA3AF),
      };

  void _resolve(WidgetRef ref, String optionId) {
    if (approval.source == ApprovalSource.acp) {
      final client = ref.read(activeAcpClientProvider);
      final pending = ref.read(pendingAcpPermissionProvider);
      // Only respond through ACP when the parked event still matches —
      // otherwise the request has already been answered or the client
      // has gone away.
      if (client != null &&
          pending != null &&
          pending.requestId.toString() == approval.id) {
        client.respondToPermission(
          requestId: pending.requestId,
          optionId: optionId,
        );
        ref.read(pendingAcpPermissionProvider.notifier).state = null;
      }
    }
    ref.read(approvalsProvider.notifier).resolve(approval.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _kindColor(approval.toolCallKind);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withAlpha(102)),
                ),
                child: Text(
                  approval.toolCallKind,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  approval.toolCallTitle,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _timeAgo(approval.receivedAt),
                style:
                    const TextStyle(fontSize: 11, color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: approval.options.map((opt) {
              final isAllow = opt.optionId != 'deny';
              return SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: () => _resolve(ref, opt.optionId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAllow
                        ? PocketClawTheme.electricTeal.withAlpha(38)
                        : PocketClawTheme.lobsterRed.withAlpha(38),
                    foregroundColor: isAllow
                        ? PocketClawTheme.electricTeal
                        : PocketClawTheme.lobsterRed,
                    side: BorderSide(
                      color: isAllow
                          ? PocketClawTheme.electricTeal.withAlpha(102)
                          : PocketClawTheme.lobsterRed.withAlpha(102),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                  ),
                  child:
                      Text(opt.name, style: const TextStyle(fontSize: 12)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
