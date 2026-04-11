/// Tickets tab — simple list grouped by status (todo/in-progress/done)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/paperclip_state.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

class TicketsTab extends ConsumerWidget {
  const TicketsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);

    if (!state.isConnected) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Not connected to Paperclip.',
      );
    }

    final tickets = state.tickets;
    if (tickets.isEmpty) {
      return const EmptyState(
        icon: Icons.confirmation_number_outlined,
        message: 'No tickets found.',
      );
    }

    // Group by status
    final todo =
        tickets.where((t) => t.status == TicketStatus.todo).toList();
    final inProgress =
        tickets.where((t) => t.status == TicketStatus.inProgress).toList();
    final done =
        tickets.where((t) => t.status == TicketStatus.done).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (todo.isNotEmpty)
          _buildSection(
            'To Do',
            todo,
            const Color(0xFFFFB74D),
            Icons.radio_button_unchecked,
          ),
        if (inProgress.isNotEmpty)
          _buildSection(
            'In Progress',
            inProgress,
            PocketClawTheme.electricTeal,
            Icons.timelapse,
          ),
        if (done.isNotEmpty)
          _buildSection(
            'Done',
            done,
            const Color(0xFF4CAF50),
            Icons.check_circle_outline,
          ),
      ],
    );
  }

  Widget _buildSection(
    String title,
    List<CompanyTicket> tickets,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '$title (${tickets.length})',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...tickets.map((ticket) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: ListTile(
                dense: true,
                title: Text(
                  ticket.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                subtitle: ticket.assignee != null
                    ? Text(
                        ticket.assignee!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      )
                    : null,
                trailing: Text(
                  _formatDate(ticket.createdAt),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: Colors.white24,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}
