/// Long-press action bar for chat bubbles. Always shows Copy; shows
/// Retry when the host bubble passes a non-null callback (typically
/// only on the most recent user message).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/hermes_commander_theme.dart';

class MessageActionsBar extends StatefulWidget {
  final String text;
  final bool showRetry;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onResend;
  final VoidCallback? onRegenerate;
  final VoidCallback? onContinue;

  /// Optional "Quote" action. When provided, the bar shows a Quote
  /// button that — on tap — passes the message text up so the chat
  /// screen can prepend it to the input field as a `> quoted line`
  /// and focus the keyboard. Set this on assistant messages so the
  /// user can ask a direct follow-up.
  final void Function(String text)? onQuote;

  /// Optional "Read aloud" action. When provided, the bar shows a
  /// speaker button that pipes the message text into the active TTS
  /// engine (Supertonic if loaded, system TTS otherwise). Set this on
  /// assistant messages.
  final VoidCallback? onSpeak;
  final bool isSpeaking;

  final VoidCallback onDismiss;

  const MessageActionsBar({
    super.key,
    required this.text,
    required this.onDismiss,
    this.showRetry = false,
    this.onRetry,
    this.onEdit,
    this.onResend,
    this.onRegenerate,
    this.onContinue,
    this.onQuote,
    this.onSpeak,
    this.isSpeaking = false,
  });

  @override
  State<MessageActionsBar> createState() => _MessageActionsBarState();
}

class _MessageActionsBarState extends State<MessageActionsBar> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _copied = false);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 32,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: HCTheme.bgPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HCTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(102),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: _copied ? Icons.check : Icons.copy_outlined,
                label: _copied ? 'Copied!' : 'Copy',
                color: _copied ? HCTheme.statusGreen : HCTheme.textSecondary,
                onTap: _copy,
              ),
              if (widget.onEdit != null) ...[
                const _Sep(),
                _ActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: HCTheme.textSecondary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onEdit!();
                    widget.onDismiss();
                  },
                ),
              ],
              if (widget.onResend != null) ...[
                const _Sep(),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'Resend',
                  color: HCTheme.textSecondary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onResend!();
                    widget.onDismiss();
                  },
                ),
              ],
              if (widget.onRegenerate != null) ...[
                const _Sep(),
                _ActionButton(
                  icon: Icons.autorenew,
                  label: 'Regenerate',
                  color: HCTheme.textSecondary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onRegenerate!();
                    widget.onDismiss();
                  },
                ),
              ],
              if (widget.onContinue != null) ...[
                const _Sep(),
                _ActionButton(
                  icon: Icons.subdirectory_arrow_right,
                  label: 'Continue',
                  color: HCTheme.textSecondary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onContinue!();
                    widget.onDismiss();
                  },
                ),
              ],
              if (widget.onQuote != null) ...[
                const _Sep(),
                _ActionButton(
                  icon: Icons.format_quote,
                  label: 'Quote',
                  color: HCTheme.textSecondary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onQuote!(widget.text);
                    widget.onDismiss();
                  },
                ),
              ],
              if (widget.onSpeak != null) ...[
                const _Sep(),
                _ActionButton(
                  icon: widget.isSpeaking
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_outlined,
                  label: widget.isSpeaking ? 'Stop speaking' : 'Read aloud',
                  color: widget.isSpeaking
                      ? HCTheme.gold
                      : HCTheme.textSecondary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSpeak!();
                    widget.onDismiss();
                  },
                ),
              ],
              if (widget.showRetry && widget.onRetry != null) ...[
                const _Sep(),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'Retry',
                  color: HCTheme.textSecondary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onRetry!();
                    widget.onDismiss();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: HCTheme.border,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
