/// Chat message bubble widget
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/chat_message.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/source_badge.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF1A1A2E),
              child: Text(
                '🦀',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _isUser
                    ? const Color(0xFFE53935)
                    : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(_isUser ? 16 : 4),
                  bottomRight: Radius.circular(_isUser ? 4 : 16),
                ),
                border: _isUser
                    ? null
                    : Border.all(
                        color: const Color(0xFF3A3A50).withAlpha(120),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Streaming cursor effect
                  if (message.isStreaming)
                    _StreamingText(text: message.content)
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: _isUser ? Colors.white : Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                  const SizedBox(height: 6),

                  // Footer: source badge + timestamp
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.source != null) ...[
                        SourceBadge(source: message.source!),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        message.timestamp.timeAgo,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: _isUser
                              ? Colors.white54
                              : const Color(0xFF7A7A90),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _StreamingText extends StatefulWidget {
  final String text;

  const _StreamingText({required this.text});

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cursorController,
      builder: (context, child) {
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(text: widget.text),
              TextSpan(
                text: '\u258C',
                style: TextStyle(
                  color: Colors.white
                      .withAlpha((_cursorController.value * 255).toInt()),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
