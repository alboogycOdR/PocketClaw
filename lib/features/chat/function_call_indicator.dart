/// Animated widget showing tool execution status
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/chat_message.dart';

class FunctionCallIndicator extends StatefulWidget {
  final FunctionCallInfo functionCall;

  const FunctionCallIndicator({super.key, required this.functionCall});

  @override
  State<FunctionCallIndicator> createState() => _FunctionCallIndicatorState();
}

class _FunctionCallIndicatorState extends State<FunctionCallIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.functionCall.isExecuting) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FunctionCallIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.functionCall.isExecuting && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.functionCall.isExecuting) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _displayName {
    final name = widget.functionCall.name;
    return switch (name) {
      'search_notes' => 'Searching notes...',
      'set_reminder' => 'Setting reminder...',
      'send_email' => 'Composing email...',
      'create_event' => 'Creating event...',
      'web_search' => 'Searching web...',
      'read_file' => 'Reading file...',
      _ => 'Running $name...',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isExecuting = widget.functionCall.isExecuting;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PocketClawTheme.electricTeal.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: PocketClawTheme.electricTeal.withAlpha(40),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isExecuting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  PocketClawTheme.electricTeal,
                ),
              ),
            )
          else
            Icon(
              widget.functionCall.result != null
                  ? Icons.check_circle
                  : Icons.error_outline,
              size: 14,
              color: widget.functionCall.result != null
                  ? PocketClawTheme.success
                  : PocketClawTheme.lobsterRed,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isExecuting
                  ? _displayName
                  : widget.functionCall.result ?? 'Done',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: PocketClawTheme.electricTeal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
