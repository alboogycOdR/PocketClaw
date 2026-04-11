/// Governance tab — reads governance drafts from governanceDraftProvider
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/governance_draft_provider.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

class GovernanceTab extends ConsumerWidget {
  const GovernanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);

    if (!state.isConnected) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Not connected to Paperclip.',
      );
    }

    final drafts = ref.watch(governanceDraftsProvider);
    if (drafts.isEmpty) {
      return const EmptyState(
        icon: Icons.gavel_outlined,
        message: 'No governance drafts yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: drafts.length,
      itemBuilder: (context, index) {
        final draft = drafts[index];
        final statusColor = _statusColor(draft.status);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        draft.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: statusColor.withAlpha(80),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        draft.status.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  draft.body,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (draft.author != null) ...[
                      Icon(Icons.person_outline,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        draft.author!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatDate(draft.createdAt),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'draft' => Colors.white54,
      'review' => const Color(0xFFFFB74D),
      'approved' => const Color(0xFF4CAF50),
      'rejected' => PocketClawTheme.lobsterRed,
      _ => Colors.white38,
    };
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
