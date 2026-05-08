/// Hermes session detail — full message thread for one session,
/// with tool-call cards and the user/assistant role split.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_message.dart';
import '../../core/hermes/models/hermes_session.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/tool_call_card.dart';

class HermesSessionDetailScreen extends ConsumerWidget {
  final HermesSession session;
  const HermesSessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync =
        ref.watch(hermesSessionMessagesProvider(session.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.displayTitle,
              style: GoogleFonts.jetBrainsMono(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${session.sourceIcon} ${session.source}'
              '${session.model != null ? ' · ${session.model}' : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () =>
                ref.invalidate(hermesSessionMessagesProvider(session.id)),
          ),
        ],
      ),
      body: messagesAsync.when(
        data: (messages) {
          if (messages.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_outlined,
              message: 'No messages in this session',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _MessageBubble(message: messages[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load messages: $e',
          actionLabel: 'Retry',
          onAction: () =>
              ref.invalidate(hermesSessionMessagesProvider(session.id)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final HermesMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final color = isUser
        ? PocketClawTheme.lobsterRed.withAlpha(50)
        : PocketClawTheme.surfaceContainer;

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) const Text('🦞 ', style: TextStyle(fontSize: 14)),
            Text(
              message.role.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: Colors.white38,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.92,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.content.isNotEmpty)
                  SelectableText(
                    message.content,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                if (message.hasToolCalls) ...[
                  if (message.content.isNotEmpty)
                    const SizedBox(height: 10),
                  for (final call in message.toolCalls) ...[
                    ToolCallCard(toolCall: call),
                    const SizedBox(height: 6),
                  ],
                ],
                if (message.toolName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'tool: ${message.toolName}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
