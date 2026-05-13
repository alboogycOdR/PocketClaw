/// Card shown when agent drafts an action (email, calendar, message)
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/chat_message.dart';

class DraftConfirmCard extends StatelessWidget {
  final DraftAction draft;
  final VoidCallback? onConfirm;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const DraftConfirmCard({
    super.key,
    required this.draft,
    this.onConfirm,
    this.onEdit,
    this.onCancel,
  });

  IconData get _typeIcon => switch (draft.type) {
        ActionType.email => Icons.email_outlined,
        ActionType.calendar => Icons.calendar_today,
        ActionType.message => Icons.message_outlined,
        ActionType.reminder => Icons.alarm,
        ActionType.generic => Icons.task_alt,
      };

  String get _typeLabel => switch (draft.type) {
        ActionType.email => 'Email Draft',
        ActionType.calendar => 'Calendar Event',
        ActionType.message => 'Message Draft',
        ActionType.reminder => 'Reminder',
        ActionType.generic => 'Action',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PocketClawTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PocketClawTheme.electricTeal.withAlpha(60),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: PocketClawTheme.electricTeal.withAlpha(15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _typeIcon,
                  size: 16,
                  color: PocketClawTheme.electricTeal,
                ),
                const SizedBox(width: 8),
                Text(
                  _typeLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PocketClawTheme.electricTeal,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (draft.recipient != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        draft.recipient!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PocketClawTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    draft.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Color(0xFF3A2F26)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PocketClawTheme.electricTeal,
                      side: BorderSide(
                        color: PocketClawTheme.electricTeal,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
