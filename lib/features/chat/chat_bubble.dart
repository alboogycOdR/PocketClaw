/// Chat message bubble — Sprint A polish:
///   - smooth progressive streaming via [SmoothStreamingNotifier]
///   - collapsible Thinking indicator above assistant text
///   - terminal-style TUI activity card for ACP tool calls
///   - long-press → copy / retry actions bar (overlay)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/chat_message.dart';
import '../../shared/extensions.dart';
import '../../shared/utils/smooth_streaming_notifier.dart';
import '../../shared/widgets/message_actions_bar.dart';
import '../../shared/widgets/source_badge.dart';
import '../../shared/widgets/thinking_indicator.dart';
import '../../shared/widgets/tui_activity_card.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;

  /// Set this on the most recent user message to surface a Retry
  /// button in the long-press actions bar. Null hides the button.
  final VoidCallback? onRetry;

  /// Set this on assistant messages to surface a Quote button in the
  /// long-press actions bar. The callback receives the message text
  /// so the chat screen can drop a `> quoted line` into the input
  /// field and focus the keyboard for a direct follow-up.
  final void Function(String text)? onQuote;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onQuote,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _bubbleKey = GlobalKey();

  ChatMessage get message => widget.message;
  bool get _isUser => message.role == MessageRole.user;

  void _showActions() {
    _hideActions();
    final renderBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Tap-outside dismiss layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hideActions,
              child: const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy - 48,
            child: Material(
              color: Colors.transparent,
              child: MessageActionsBar(
                text: message.content,
                showRetry: widget.onRetry != null,
                onRetry: widget.onRetry,
                onQuote: widget.onQuote,
                onDismiss: _hideActions,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideActions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideActions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasThinking =
        !_isUser && (message.thinkingText?.isNotEmpty ?? false);
    final hasToolCalls = !_isUser && message.acpToolCalls.isNotEmpty;

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
              backgroundColor: PocketClawTheme.surface,
              child: Text(
                '🦀',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showActions();
              },
              child: Container(
                key: _bubbleKey,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _isUser
                      ? PocketClawTheme.bronze
                      : PocketClawTheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(_isUser ? 16 : 4),
                    bottomRight: Radius.circular(_isUser ? 4 : 16),
                  ),
                  border: _isUser
                      ? null
                      : Border.all(
                          color: const Color(0xFF3A2F26).withAlpha(120),
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thinking indicator — collapsible reasoning panel.
                    if (hasThinking)
                      ThinkingIndicator(
                        content: message.thinkingText!,
                        isStreaming: message.isStreaming,
                      ),

                    // TUI activity card — single compound panel for all
                    // ACP tool calls, replaces the old per-call chip stack.
                    if (hasToolCalls)
                      TuiActivityCard(
                        toolCalls: message.acpToolCalls,
                        isStreaming: message.isStreaming,
                      ),

                    // Message content
                    if (message.isStreaming)
                      _StreamingText(
                        text: message.content,
                        isStreaming: message.isStreaming,
                      )
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

                    // Inline tool / lifecycle status while the agent is
                    // working (e.g. "Searching the web…"). The TUI card
                    // already covers tool-state, so this falls through
                    // mainly for non-ACP statuses.
                    if (message.isStreaming &&
                        message.statusText != null) ...[
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
                            .map((citation) =>
                                _CitationChip(text: citation))
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
                                : PocketClawTheme.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
        a: TextStyle(
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
          color: const Color(0xFF3A2F26),
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

// ── Streaming text with cursor + smooth reveal ──

class _StreamingText extends StatefulWidget {
  final String text;
  final bool isStreaming;

  const _StreamingText({required this.text, required this.isStreaming});

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText>
    with SingleTickerProviderStateMixin {
  final _streamNotifier = SmoothStreamingNotifier();
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _streamNotifier.setTarget(widget.text);
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StreamingText old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text) {
      _streamNotifier.setTarget(widget.text);
    }
    if (!widget.isStreaming && old.isStreaming) {
      _streamNotifier.snapToTarget();
    }
  }

  @override
  void dispose() {
    _streamNotifier.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_streamNotifier, _cursorController]),
      builder: (context, _) {
        final displayed = _streamNotifier.rendered;
        final showCursor =
            widget.isStreaming && !_streamNotifier.isCaughtUp;

        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(text: displayed),
              if (showCursor)
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
