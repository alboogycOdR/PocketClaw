/// Chat message bubble widget
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
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
                  // Message content
                  if (message.isStreaming)
                    _StreamingText(text: message.content)
                  else if (_isUser)
                    Text(
                      message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  else
                    _AssistantMarkdown(content: message.content),

                  // ACP tool calls — one mini-card per call, in the order
                  // they arrived. Stream live (pending → completed) and
                  // remain visible after the turn ends.
                  if (message.acpToolCalls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final c in message.acpToolCalls) ...[
                      _AcpToolCallChip(call: c),
                      const SizedBox(height: 4),
                    ],
                  ],

                  // Inline tool / lifecycle status while the agent is working
                  // (e.g. "Searching the web: 'ed25519 flutter'").
                  if (message.isStreaming && message.statusText != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message.statusText!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Memory citations
                  if (message.memoryCitations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: message.memoryCitations
                          .map((citation) => _CitationChip(text: citation))
                          .toList(),
                    ),
                  ],

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

// ── Markdown rendering for assistant messages ──

class _AssistantMarkdown extends StatelessWidget {
  final String content;

  const _AssistantMarkdown({required this.content});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        // Body text
        p: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.4,
        ),
        // Headers
        h1: GoogleFonts.jetBrainsMono(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        h2: GoogleFonts.jetBrainsMono(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        h3: GoogleFonts.jetBrainsMono(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        h4: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        // Inline code
        code: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: PocketClawTheme.electricTeal,
          backgroundColor: PocketClawTheme.surfaceContainer,
        ),
        // Code block
        codeblockDecoration: BoxDecoration(
          color: PocketClawTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockAlign: WrapAlignment.start,
        // Links
        a: const TextStyle(
          color: PocketClawTheme.electricTeal,
          decoration: TextDecoration.underline,
        ),
        // Lists
        listBullet: const TextStyle(color: Colors.white70, fontSize: 14),
        // Block quote
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: PocketClawTheme.electricTeal.withAlpha(120),
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        // Emphasis
        em: const TextStyle(
          color: Colors.white,
          fontStyle: FontStyle.italic,
        ),
        strong: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        // Table
        tableHead: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        tableBody: const TextStyle(color: Colors.white70),
        tableBorder: TableBorder.all(
          color: const Color(0xFF3A3A50),
          width: 0.5,
        ),
      ),
    );
  }
}

// ── Memory citation chip ──

class _CitationChip extends StatelessWidget {
  final String text;

  const _CitationChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: PocketClawTheme.electricTeal.withAlpha(38),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 10,
            color: PocketClawTheme.electricTeal,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: PocketClawTheme.electricTeal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streaming text with cursor ──

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

// ── ACP tool call chip ──────────────────────────────────────────────────
//
// Compact one-line summary of a tool call the agent fired during this
// message's turn. Renders kind-coloured + status-aware (spinner while
// pending, check when completed, X when failed). Tapping expands a tiny
// detail panel below it.

class _AcpToolCallChip extends StatefulWidget {
  final ChatAcpToolCall call;
  const _AcpToolCallChip({required this.call});

  @override
  State<_AcpToolCallChip> createState() => _AcpToolCallChipState();
}

class _AcpToolCallChipState extends State<_AcpToolCallChip> {
  bool _expanded = false;

  // Same colour map as ToolCallCard / SPEC-ACPWireProtocol — read=blue,
  // edit=amber, execute=emerald, fetch=violet, search=sky, think=pink,
  // other=gray.
  static const _kindColours = <String, Color>{
    'read': Color(0xFF60A5FA),
    'edit': Color(0xFFFBBF24),
    'execute': Color(0xFF34D399),
    'fetch': Color(0xFFA78BFA),
    'search': Color(0xFF38BDF8),
    'think': Color(0xFFF472B6),
    'other': Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.call;
    final colour = _kindColours[c.kind] ?? _kindColours['other']!;
    return GestureDetector(
      onTap: c.content.isEmpty
          ? null
          : () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colour.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colour.withAlpha(80), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusIcon(status: c.status, colour: colour),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    c.summary.isNotEmpty
                        ? '${c.functionName}: ${c.summary}'
                        : c.functionName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: colour,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.content.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 12,
                    color: colour.withAlpha(180),
                  ),
                ],
              ],
            ),
            if (_expanded && c.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(
                c.content,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  final Color colour;
  const _StatusIcon({required this.status, required this.colour});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'pending' => SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: colour),
        ),
      'completed' =>
        Icon(Icons.check_circle_outline, size: 12, color: colour),
      'failed' =>
        Icon(Icons.error_outline, size: 12, color: PocketClawTheme.lobsterRed),
      _ => Icon(Icons.bolt, size: 12, color: colour),
    };
  }
}
