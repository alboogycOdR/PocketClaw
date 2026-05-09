/// Collapsible panel showing Hermes ACP agent reasoning.
///
/// While streaming: auto-expanded, shows "💡 Thinking live…" with a
/// loading spinner. After streaming ends: collapses to "💡 Thought
/// process" — user can tap to read the full reasoning.
///
/// Returns SizedBox.shrink() for empty content so the call site can
/// always include this without a guard.
///
/// Ported from hermes-workspace `thinking-indicator.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThinkingIndicator extends StatefulWidget {
  final String content;
  final bool isStreaming;

  const ThinkingIndicator({
    super.key,
    required this.content,
    required this.isStreaming,
  });

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // While streaming, auto-expand so the user can watch reasoning live.
    _expanded = widget.isStreaming;
  }

  @override
  void didUpdateWidget(ThinkingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isStreaming && !old.isStreaming) {
      setState(() => _expanded = true);
    }
    if (!widget.isStreaming && old.isStreaming) {
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    widget.isStreaming ? 'Thinking live…' : 'Thought process',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurpleAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (widget.isStreaming)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.deepPurpleAccent,
                      ),
                    )
                  else
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: Colors.deepPurpleAccent,
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: Colors.deepPurple.withAlpha(38),
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  SelectableText(
                    widget.content,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.white.withAlpha(178),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
