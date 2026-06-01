library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/hermes_commander_theme.dart';
import '../../data/models/chat_message.dart';
import '../../shared/extensions.dart';
import '../../shared/utils/smooth_streaming_notifier.dart';
import '../../shared/widgets/hermes_avatar.dart';
import '../../shared/widgets/message_actions_bar.dart';
import '../../shared/widgets/source_badge.dart';
import '../../shared/widgets/thinking_indicator.dart';
import '../../shared/widgets/tui_activity_card.dart';

class HermesMessageRow extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onResend;
  final VoidCallback? onRegenerate;
  final VoidCallback? onContinue;
  final void Function(String text)? onQuote;
  final VoidCallback? onSpeak;
  final bool isSpeaking;
  final bool showAvatar;

  const HermesMessageRow({
    super.key,
    required this.message,
    this.onRetry,
    this.onEdit,
    this.onResend,
    this.onRegenerate,
    this.onContinue,
    this.onQuote,
    this.onSpeak,
    this.isSpeaking = false,
    this.showAvatar = true,
  });

  @override
  State<HermesMessageRow> createState() => _HermesMessageRowState();
}

class _HermesMessageRowState extends State<HermesMessageRow> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _rowKey = GlobalKey();

  ChatMessage get message => widget.message;
  bool get _isUser => message.role == MessageRole.user;

  void _showActions() {
    _hideActions();
    final renderBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hideActions,
              child: const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: position.dx + 48,
            top: (position.dy - 48).clamp(8, double.infinity),
            child: Material(
              color: Colors.transparent,
              child: MessageActionsBar(
                text: message.content,
                showRetry: widget.onRetry != null,
                onRetry: widget.onRetry,
                onEdit: widget.onEdit,
                onResend: widget.onResend,
                onRegenerate: widget.onRegenerate,
                onContinue: widget.onContinue,
                onQuote: widget.onQuote,
                onSpeak: widget.onSpeak,
                isSpeaking: widget.isSpeaking,
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
    final hasThinking = !_isUser && (message.thinkingText?.isNotEmpty ?? false);
    final hasToolCalls = !_isUser && message.acpToolCalls.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        key: _rowKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: widget.showAvatar
                ? (_isUser
                      ? const UserAvatar(initial: 'Y', size: 28)
                      : const HermesAvatar(size: 28))
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showActions();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            _isUser ? 'You' : 'Hermes',
                            style: const TextStyle(
                              fontFamily: 'GeistSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: HCTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            message.timestamp.timeAgo,
                            style: const TextStyle(
                              fontFamily: 'GeistMono',
                              fontSize: 11,
                              color: HCTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasThinking)
                    ThinkingIndicator(
                      content: message.thinkingText!,
                      isStreaming: message.isStreaming,
                    ),
                  if (hasToolCalls)
                    TuiActivityCard(
                      toolCalls: message.acpToolCalls,
                      isStreaming: message.isStreaming,
                    ),
                  if (message.isStreaming)
                    _StreamingText(
                      text: message.content,
                      isStreaming: message.isStreaming,
                    )
                  else if (_isUser)
                    Text(
                      message.content,
                      style: const TextStyle(
                        fontFamily: 'GeistSans',
                        color: HCTheme.textPrimary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    )
                  else
                    _AssistantMarkdown(content: message.content),
                  if (message.isStreaming && message.statusText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: HCTheme.goldMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.statusText!,
                            style: const TextStyle(
                              fontFamily: 'GeistSans',
                              fontSize: 12,
                              color: HCTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (message.source != null) ...[
                        SourceBadge(source: message.source!),
                        const SizedBox(width: 8),
                      ],
                      if (!_isUser &&
                          !message.isStreaming &&
                          widget.onSpeak != null)
                        InkResponse(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onSpeak!();
                          },
                          radius: 14,
                          child: Icon(
                            widget.isSpeaking
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_outlined,
                            size: 15,
                            color: widget.isSpeaking
                                ? HCTheme.gold
                                : HCTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMarkdown extends StatelessWidget {
  final String content;

  const _AssistantMarkdown({required this.content});

  @override
  Widget build(BuildContext context) {
    final blocks = _splitMermaid(content);
    if (blocks.length > 1 || (blocks.isNotEmpty && blocks.first.isMermaid)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final block in blocks) ...[
            if (block.isMermaid)
              _MermaidFallbackCard(source: block.text)
            else if (block.text.trim().isNotEmpty)
              _MarkdownBody(content: block.text),
            if (block != blocks.last) const SizedBox(height: 10),
          ],
        ],
      );
    }
    return _MarkdownBody(content: content);
  }

  List<_MarkdownBlock> _splitMermaid(String source) {
    final regex = RegExp(r'```mermaid\s*([\s\S]*?)```', multiLine: true);
    final blocks = <_MarkdownBlock>[];
    var cursor = 0;
    for (final match in regex.allMatches(source)) {
      if (match.start > cursor) {
        blocks.add(_MarkdownBlock(source.substring(cursor, match.start)));
      }
      blocks.add(_MarkdownBlock(match.group(1)?.trim() ?? '', isMermaid: true));
      cursor = match.end;
    }
    if (cursor < source.length) {
      blocks.add(_MarkdownBlock(source.substring(cursor)));
    }
    if (blocks.isEmpty) blocks.add(_MarkdownBlock(source));
    return blocks;
  }
}

class _MarkdownBlock {
  final String text;
  final bool isMermaid;

  const _MarkdownBlock(this.text, {this.isMermaid = false});
}

class _MarkdownBody extends StatelessWidget {
  final String content;

  const _MarkdownBody({required this.content});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 14,
          color: HCTheme.textPrimary,
          height: 1.6,
        ),
        h1: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HCTheme.textPrimary,
        ),
        h2: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: HCTheme.textPrimary,
        ),
        h3: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: HCTheme.textPrimary,
        ),
        code: const TextStyle(
          fontFamily: 'GeistMono',
          fontSize: 12,
          color: HCTheme.textPrimary,
          backgroundColor: HCTheme.bgPanel,
        ),
        codeblockDecoration: BoxDecoration(
          color: HCTheme.bgPanel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: HCTheme.border),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockAlign: WrapAlignment.start,
        a: const TextStyle(color: HCTheme.gold),
        listBullet: const TextStyle(color: HCTheme.textSecondary, fontSize: 14),
        blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: HCTheme.border, width: 3)),
        ),
        tableHead: const TextStyle(
          color: HCTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        tableBody: const TextStyle(color: HCTheme.textSecondary),
      ),
    );
  }
}

class _MermaidFallbackCard extends StatelessWidget {
  final String source;

  const _MermaidFallbackCard({required this.source});

  Future<void> _open(BuildContext context) async {
    final url = Uri.parse('https://mermaid.live/edit');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    _showSource(context);
  }

  void _showSource(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HCTheme.bgPanel,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mermaid source',
                style: TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: HCTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: SelectableText(
                    source,
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 12,
                      color: HCTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: source));
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Diagram source copied')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: source));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Diagram source copied')));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HCTheme.bgPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HCTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.account_tree_outlined,
                  size: 16,
                  color: HCTheme.gold,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Diagram - tap to open in browser',
                    style: TextStyle(
                      fontFamily: 'GeistSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HCTheme.gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              source,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'GeistMono',
                fontSize: 12,
                height: 1.45,
                color: HCTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  late final AnimationController _cursorController;

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
  void didUpdateWidget(covariant _StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _streamNotifier.setTarget(widget.text);
    }
    if (!widget.isStreaming && oldWidget.isStreaming) {
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
        final showCursor = widget.isStreaming && !_streamNotifier.isCaughtUp;

        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'GeistSans',
              color: HCTheme.textPrimary,
              fontSize: 14,
              height: 1.6,
            ),
            children: [
              TextSpan(text: displayed),
              if (showCursor)
                TextSpan(
                  text: '\u258C',
                  style: TextStyle(
                    color: HCTheme.textPrimary.withAlpha(
                      (_cursorController.value * 255).toInt(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
