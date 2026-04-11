/// Goals tab — list with progress indicators from Paperclip provider
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);

    if (!state.isConnected) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Not connected to Paperclip.',
      );
    }

    final goals = state.goals;
    if (goals.isEmpty) {
      return const EmptyState(
        icon: Icons.flag_outlined,
        message: 'No goals defined yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        final progressPct = goal.progress.clamp(0.0, 100.0);
        final color = progressPct >= 100
            ? const Color(0xFF4CAF50)
            : progressPct >= 50
                ? PocketClawTheme.electricTeal
                : PocketClawTheme.lobsterRed;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${progressPct.toStringAsFixed(0)}%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (goal.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    goal.description!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPct / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF2A2A40),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (goal.owner != null) ...[
                      Icon(Icons.person_outline,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        goal.owner!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (goal.dueDate != null)
                      Text(
                        'Due ${DateFormat.yMMMd().format(goal.dueDate!)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: Colors.white38,
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
}
