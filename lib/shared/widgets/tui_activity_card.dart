/// Terminal-style activity card that groups all ACP tool calls for a
/// message into one panel above the assistant text. Replaces the
/// per-call chip stack inside the bubble.
///
/// Ported from hermes-workspace `tui-activity-card.tsx`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/chat_message.dart';

const _kindColors = <String, Color>{
  'read': Color(0xFF60A5FA),
  'edit': Color(0xFFFBBF24),
  'execute': Color(0xFF34D399),
  'fetch': Color(0xFFA78BFA),
  'search': Color(0xFF38BDF8),
  'think': Color(0xFFF472B6),
  'other': Color(0xFF9CA3AF),
};

Color _colorForKind(String kind) =>
    _kindColors[kind] ?? _kindColors['other']!;

String _formatElapsed(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m}m ${s}s';
}

String _summarizeOutput(String text, {int maxLen = 120}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  final firstLine = trimmed
      .split('\n')
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final compact = firstLine.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxLen) return compact;
  return '${compact.substring(0, maxLen - 1)}…';
}

String _statusDot(String status, bool isStreamingActive) {
  if (status == 'failed') return '✗';
  if (status == 'completed') return '●';
  return isStreamingActive ? '○' : '●';
}

class TuiActivityCard extends StatelessWidget {
  final List<ChatAcpToolCall> toolCalls;
  final bool isStreaming;

  const TuiActivityCard({
    super.key,
    required this.toolCalls,
    required this.isStreaming,
  });

  String get _summary {
    final total = toolCalls.length;
    final errors = toolCalls.where((c) => c.isFailed).length;
    final running = toolCalls.where((c) => c.isPending).length;
    final done = total - errors - running;
    if (errors > 0) return '$errors failed · $done done';
    if (running > 0) return '$running running · $done done';
    return '$total ${total == 1 ? 'tool' : 'tools'} · done';
  }

  Color get _summaryColor {
    if (_summary.contains('failed')) return PocketClawTheme.lobsterRed;
    if (_summary.contains('running')) return Colors.deepPurpleAccent;
    return Colors.tealAccent;
  }

  @override
  Widget build(BuildContext context) {
    final hasTools = toolCalls.isNotEmpty;
    final isStub = !hasTools && isStreaming;
    if (!hasTools && !isStub) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2D2840)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF17132A),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2D2840)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  isStreaming ? '⚡ Working' : 'Activity',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.14,
                    color: Colors.white38,
                  ),
                ),
                const Spacer(),
                if (hasTools)
                  Text(
                    _summary,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: _summaryColor,
                    ),
                  ),
                if (isStreaming) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.deepPurpleAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ...toolCalls.map(
                  (call) =>
                      _ToolRow(call: call, isStreamingActive: isStreaming),
                ),
                if (isStub)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.deepPurpleAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'working…',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'tool activity will appear after the run',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: Colors.white24,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

class _ToolRow extends StatefulWidget {
  final ChatAcpToolCall call;
  final bool isStreamingActive;

  const _ToolRow({required this.call, required this.isStreamingActive});

  @override
  State<_ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends State<_ToolRow> {
  bool _expanded = false;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfPending();
  }

  @override
  void didUpdateWidget(_ToolRow old) {
    super.didUpdateWidget(old);
    if (widget.call.isPending && widget.isStreamingActive) {
      _startTimerIfPending();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimerIfPending() {
    if (!widget.call.isPending || !widget.isStreamingActive) return;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.call;
    final color = _colorForKind(c.kind);
    final dot = _statusDot(c.status, widget.isStreamingActive);
    final isPending = c.isPending;
    final isError = c.isFailed;
    final outputSummary = isPending
        ? (widget.isStreamingActive ? 'running…' : 'pending')
        : _summarizeOutput(c.content).isNotEmpty
            ? _summarizeOutput(c.content)
            : (c.isCompleted ? 'done' : 'failed');

    final dotColor = isError
        ? PocketClawTheme.lobsterRed
        : c.isCompleted
            ? Colors.tealAccent
            : widget.isStreamingActive
                ? Colors.deepPurpleAccent
                : Colors.white38;

    final canExpand = c.content.isNotEmpty || c.rawInput != null;

    return GestureDetector(
      onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text(
                  dot,
                  style: TextStyle(
                    fontSize: 12,
                    color: dotColor,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  c.functionName,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (c.summary.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      c.summary.length > 50
                          ? '${c.summary.substring(0, 47)}…'
                          : c.summary,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                if (isPending && widget.isStreamingActive && _elapsed > 0)
                  Text(
                    _formatElapsed(_elapsed),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: Colors.white24,
                    ),
                  ),
                if (canExpand) ...[
                  const SizedBox(width: 6),
                  Text(
                    _expanded ? '▾' : '▸',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white24,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 32, right: 12, bottom: 4),
            child: Row(
              children: [
                Text(
                  '⎿',
                  style: TextStyle(
                    fontSize: 11,
                    color: isError
                        ? PocketClawTheme.lobsterRed.withAlpha(153)
                        : Colors.white24,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    outputSummary,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: isError
                          ? PocketClawTheme.lobsterRed.withAlpha(178)
                          : Colors.white38,
                      fontStyle:
                          isPending ? FontStyle.italic : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded && canExpand)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0B1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2D2840)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.rawInput != null && c.rawInput!.isNotEmpty) ...[
                    Text(
                      'INPUT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 0.14,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      c.rawInput.toString(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                  if (c.content.isNotEmpty) ...[
                    if (c.rawInput != null) const SizedBox(height: 8),
                    Text(
                      isError ? 'ERROR' : 'OUTPUT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 0.14,
                        color: isError
                            ? PocketClawTheme.lobsterRed.withAlpha(153)
                            : Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      c.content,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: isError
                            ? PocketClawTheme.lobsterRed.withAlpha(204)
                            : Colors.white54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
