/// Long-press action bar for chat bubbles. Always shows Copy; shows
/// Retry when the host bubble passes a non-null callback (typically
/// only on the most recent user message).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessageActionsBar extends StatefulWidget {
  final String text;
  final bool showRetry;
  final VoidCallback? onRetry;

  /// Optional "Quote" action. When provided, the bar shows a Quote
  /// button that — on tap — passes the message text up so the chat
  /// screen can prepend it to the input field as a `> quoted line`
  /// and focus the keyboard. Set this on assistant messages so the
  /// user can ask a direct follow-up.
  final void Function(String text)? onQuote;
  final VoidCallback onDismiss;

  const MessageActionsBar({
    super.key,
    required this.text,
    required this.onDismiss,
    this.showRetry = false,
    this.onRetry,
    this.onQuote,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2520),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A3028)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(102),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: _copied ? Icons.check : Icons.copy_outlined,
            label: _copied ? 'Copied!' : 'Copy',
            color: _copied ? Colors.tealAccent : Colors.white70,
            onTap: _copy,
          ),
          if (widget.onQuote != null) ...[
            const _Sep(),
            _ActionButton(
              icon: Icons.format_quote,
              label: 'Quote',
              color: Colors.white70,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onQuote!(widget.text);
                widget.onDismiss();
              },
            ),
          ],
          if (widget.showRetry && widget.onRetry != null) ...[
            const _Sep(),
            _ActionButton(
              icon: Icons.refresh,
              label: 'Retry',
              color: Colors.white70,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onRetry!();
                widget.onDismiss();
              },
            ),
          ],
        ],
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
      color: const Color(0xFF3A3028),
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
