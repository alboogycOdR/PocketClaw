/// Governance tab — `GET /approvals?status=pending` + approve / reject.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

class GovernanceTab extends ConsumerWidget {
  const GovernanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(paperclipRestClientProvider);
    final async = ref.watch(paperclipApprovalsProvider);

    if (client == null) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Paperclip not configured.',
      );
    }

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        message: friendlyPaperclipError(e),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(paperclipApprovalsProvider),
      ),
      data: (approvals) {
        if (approvals.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(paperclipApprovalsProvider),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: EmptyState(
                    icon: Icons.gavel_outlined,
                    message: 'No pending approvals.',
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(paperclipApprovalsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: approvals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ApprovalCard(approval: approvals[i]),
          ),
        );
      },
    );
  }
}

class _ApprovalCard extends ConsumerStatefulWidget {
  final PaperclipApproval approval;

  const _ApprovalCard({required this.approval});

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final client = ref.read(paperclipRestClientProvider);
    if (client == null) return;

    final noteCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(approve ? 'Approve?' : 'Reject?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.approval.title),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtl,
              decoration: const InputDecoration(
                labelText: 'Decision note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: approve
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: PocketClawTheme.lobsterRed,
                  ),
            onPressed: () => Navigator.pop(d, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final note = noteCtl.text.trim().isEmpty ? null : noteCtl.text.trim();
      if (approve) {
        await client.approveApproval(widget.approval.id, decisionNote: note);
      } else {
        await client.rejectApproval(widget.approval.id, decisionNote: note);
      }
      ref.invalidate(paperclipApprovalsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyPaperclipError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.approval;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_outlined,
                    size: 16, color: PocketClawTheme.electricTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        PocketClawTheme.electricTeal.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    a.status,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: PocketClawTheme.electricTeal,
                    ),
                  ),
                ),
              ],
            ),
            if (a.description != null && a.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                a.description!,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
            if (a.requestedBy != null) ...[
              const SizedBox(height: 6),
              Text(
                'Requested by ${a.requestedBy}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () => _decide(false),
                    icon: Icon(Icons.close,
                        size: 14, color: PocketClawTheme.lobsterRed),
                    label: Text('Reject',
                        style: TextStyle(
                            color: PocketClawTheme.lobsterRed,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _decide(true),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Approve',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
