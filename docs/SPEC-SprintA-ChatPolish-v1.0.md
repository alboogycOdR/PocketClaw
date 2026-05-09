# ClawCommander — Sprint A: Chat Polish
## Developer Specification v1.0

**Date:** 2026-05-09  
**Author:** CARMEN PTY LTD  
**Source:** Verified against `hermes-workspace-main` and `PocketClaw-source-2026-05-09`  
**Status:** Implementation-ready  
**Estimated effort:** 3 days  
**Depends on:** Nothing — fully self-contained, no Phase 2 required  

---

## Overview

Four improvements to the chat experience, in order of implementation:

1. **Smooth streaming** — progressive character reveal (replaces chunk-drop rendering)
2. **Thinking indicator** — collapsible panel for ACP `agent_thought_chunk` events
3. **TUI Activity Card** — terminal-style compound tool call panel (replaces `_AcpToolCallChip`)
4. **Message actions bar** — long-press copy + retry on any message

Each item is self-contained. If only one sprint day is available, ship items 1 and 2 — they have the highest impact per hour.

---

## Item 1 — Smooth Streaming

### The Problem

`_StreamingText` in `chat_bubble.dart` renders the full `content` string immediately when it arrives — tokens appear in large sudden chunks depending on how the model sends them. The workspace uses `requestAnimationFrame` to progressively reveal characters, creating the smooth Telegram/Discord streaming feel.

### Changes

**New file: `lib/shared/utils/smooth_streaming_notifier.dart`**

```dart
// lib/shared/utils/smooth_streaming_notifier.dart
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Progressively reveals a target string at ~60fps.
///
/// When the target updates (new tokens arrive), the notifier advances
/// toward the target using an adaptive step:
///   - far behind (>60 chars remaining): jump remaining/8 chars
///   - medium (20–60 remaining): jump 3 chars
///   - close (<20 remaining): 1 char at a time
///
/// If the target shrinks or changes non-additively (error reset, new
/// session), the notifier snaps to the new target immediately.
///
/// Ported from hermes-workspace `use-smooth-streaming-text.ts`.
class SmoothStreamingNotifier extends ChangeNotifier {
  String _target = '';
  String _rendered = '';
  Timer? _ticker;

  String get rendered => _rendered;

  bool get isCaughtUp => _rendered == _target;

  /// Update the target string. Starts ticking if not already running.
  void setTarget(String text) {
    if (text == _target) return;

    // Snap if target shrank or changed non-additively
    if (_rendered.length > text.length ||
        !text.startsWith(_rendered)) {
      _rendered = '';
    }

    _target = text;

    // Already caught up — nothing to animate
    if (_rendered == _target) {
      _ticker?.cancel();
      _ticker = null;
      notifyListeners();
      return;
    }

    // Start ticking if not already
    _ticker ??= Timer.periodic(
      const Duration(milliseconds: 16), // ~60 fps
      (_) => _tick(),
    );
  }

  /// Snap to the final value immediately (used when streaming ends).
  void snapToTarget() {
    _rendered = _target;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void _tick() {
    if (_rendered == _target) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    final remaining = _target.length - _rendered.length;
    final step = remaining > 60
        ? (remaining / 8).ceil()
        : remaining > 20
            ? 3
            : 1;

    final nextLen = (_rendered.length + step).clamp(0, _target.length);
    _rendered = _target.substring(0, nextLen);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
```

**Update `_StreamingText` in `lib/features/chat/chat_bubble.dart`:**

Find the existing `_StreamingText` class and replace it entirely:

```dart
// REPLACE the existing _StreamingText StatefulWidget and State with this:

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
    // When streaming ends, snap to full text immediately
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
        final showCursor = widget.isStreaming && !_streamNotifier.isCaughtUp;

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
                    color: Colors.white.withAlpha(
                      (_cursorController.value * 255).toInt(),
                    ),
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
```

**Update the call site** in `chat_bubble.dart` where `_StreamingText` is used. Change:

```dart
// OLD:
if (message.isStreaming)
  _StreamingText(text: message.content)

// NEW — pass isStreaming so snap-to-target fires on completion:
if (message.isStreaming)
  _StreamingText(text: message.content, isStreaming: message.isStreaming)
```

**Add import** at the top of `chat_bubble.dart`:
```dart
import '../../shared/utils/smooth_streaming_notifier.dart';
```

### Files Changed

| File | Change |
|---|---|
| `lib/shared/utils/smooth_streaming_notifier.dart` | **New** |
| `lib/features/chat/chat_bubble.dart` | Replace `_StreamingText`, add import |

### Test

1. Start a Hermes or OpenClaw chat session
2. Send a message that produces a long response
3. **Before:** text appears in large chunks, visible stuttering
4. **After:** characters reveal progressively, smooth left-to-right flow
5. When the stream ends, remaining text snaps to final value immediately
6. Test error reset: send a bad request that clears the bubble — text should snap, not animate backwards

---

## Item 2 — Thinking Indicator

### The Problem

`AcpThoughtChunkEvent` in `chat_providers.dart` is currently discarded into `statusText` as a truncated 64-char snippet. The user has no way to read the agent's full reasoning. The workspace renders thought chunks in a collapsible panel: "💡 Thinking live…" while streaming, "💡 Thought process" (expandable) when done.

### Step 1 — Add `thinkingText` to `ChatMessage`

**File:** `lib/data/models/chat_message.dart`

Add one field to `ChatMessage`:

```dart
// Add to the field declarations (after statusText):
/// Accumulated agent thought text from AcpThoughtChunkEvent.
/// Non-null only for Hermes ACP messages that emit thinking.
final String? thinkingText;
```

Update `copyWith` to include the new field:

```dart
// In copyWith — add:
String? thinkingText,
bool clearThinkingText = false,

// In the returned ChatMessage:
thinkingText: clearThinkingText ? null : (thinkingText ?? this.thinkingText),
```

Update the `const ChatMessage({...})` constructor to include:
```dart
this.thinkingText,
```

Update `fromJson` and `toJson` if they exist to persist/restore `thinkingText`.

### Step 2 — Accumulate Thought Chunks in `chat_providers.dart`

Find the `AcpThoughtChunkEvent` case in `_sendViaAcp` (around line 608). Replace the current truncation logic:

```dart
// REPLACE:
case AcpThoughtChunkEvent(:final text):
  // Thought chunks aren't surfaced inline — keep them in statusText
  messages.updateById(placeholderId, (m) => m.copyWith(
        statusText: text.length > 64
            ? '${text.substring(0, 64)}…'
            : text,
      ));

// WITH — accumulate full thought text into dedicated field:
case AcpThoughtChunkEvent(:final text):
  final current = messages.byId(placeholderId)?.thinkingText ?? '';
  messages.updateById(placeholderId, (m) => m.copyWith(
        thinkingText: current + text,
        // Also keep statusText brief for the header indicator
        statusText: '💡 Thinking…',
      ));
```

Add a `byId` helper to `MessagesNotifier` if not already present:

```dart
ChatMessage? byId(String id) {
  try {
    return state.firstWhere((m) => m.id == id);
  } on StateError {
    return null;
  }
}
```

### Step 3 — New `ThinkingIndicator` Widget

**New file: `lib/shared/widgets/thinking_indicator.dart`**

```dart
// lib/shared/widgets/thinking_indicator.dart
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';

/// Collapsible panel showing Hermes agent reasoning.
///
/// - While streaming: expands automatically, shows "💡 Thinking live…"
///   with a loading spinner.
/// - After streaming ends: collapses to "💡 Thought process" header.
///   User can tap to expand and read the full reasoning.
///
/// Returns SizedBox.shrink() if content is empty — safe to always include
/// in the bubble's column without checking at the call site.
///
/// Ported from hermes-workspace `thinking-indicator.tsx`.
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
  void didUpdateWidget(ThinkingIndicator old) {
    super.didUpdateWidget(old);
    // Auto-expand while streaming; auto-collapse when done
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
        color: Colors.deepPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.deepPurple.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — always visible
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

          // Collapsible content
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
                    color: Colors.deepPurple.withOpacity(0.15),
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  SelectableText(
                    widget.content,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.7),
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
```

### Step 4 — Add to `ChatBubble`

In `lib/features/chat/chat_bubble.dart`, add the thinking indicator inside the assistant bubble's `Column`, **above the message content**:

```dart
// In ChatBubble.build(), inside the Column children list,
// BEFORE the existing message content block:

// Add import at top:
import '../../shared/widgets/thinking_indicator.dart';

// Add before "// Message content" comment:
if (!_isUser && message.thinkingText != null &&
    message.thinkingText!.isNotEmpty) ...[
  ThinkingIndicator(
    content: message.thinkingText!,
    isStreaming: message.isStreaming,
  ),
],
```

### Files Changed

| File | Change |
|---|---|
| `lib/data/models/chat_message.dart` | Add `thinkingText` field + `copyWith` support |
| `lib/data/providers/chat_providers.dart` | Accumulate thought chunks into `thinkingText` |
| `lib/shared/widgets/thinking_indicator.dart` | **New** |
| `lib/features/chat/chat_bubble.dart` | Add `ThinkingIndicator` above message content |

### Test

1. Send a message via Hermes ACP that triggers reasoning
2. **During streaming:** purple "💡 Thinking live…" panel appears above the text, auto-expanded, spinner visible
3. **After streaming ends:** panel collapses to "💡 Thought process" header
4. **Tap the header:** full reasoning text expands, selectable
5. Test with empty thinking: panel does not appear at all for non-ACP messages

---

## Item 3 — TUI Activity Card

### The Problem

`_AcpToolCallChip` renders each tool call as a separate compact chip inside the message bubble. During a multi-step task with 5+ tool calls, the bubble becomes a long stack of disconnected chips. The workspace uses a compound "Activity" card above the text content that groups all tool calls into one terminal-style panel with status dots, elapsed timers, and output previews.

This does not replace the `ChatAcpToolCall` model or `acpToolCalls` list — it replaces only the rendering widget.

### New File: `lib/shared/widgets/tui_activity_card.dart`

```dart
// lib/shared/widgets/tui_activity_card.dart
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/chat_message.dart';

// ── Colour map — same as ToolCallCard and ACP wire protocol spec ──────────────

const _kindColors = <String, Color>{
  'read':    Color(0xFF60A5FA), // blue
  'edit':    Color(0xFFFBBF24), // amber
  'execute': Color(0xFF34D399), // emerald
  'fetch':   Color(0xFFA78BFA), // violet
  'search':  Color(0xFF38BDF8), // sky
  'think':   Color(0xFFF472B6), // pink
  'other':   Color(0xFF9CA3AF), // gray
};

Color _colorForKind(String kind) =>
    _kindColors[kind] ?? _kindColors['other']!;

// ── Helper formatters ─────────────────────────────────────────────────────────

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
  if (status == 'failed')    return '✗';
  if (status == 'completed') return '●';
  return isStreamingActive ? '○' : '●';
}

// ── Main card ─────────────────────────────────────────────────────────────────

/// Terminal-style activity card that groups all ACP tool calls for a
/// message into one panel above the assistant text.
///
/// Replaces the per-call `_AcpToolCallChip` stack inside the bubble.
/// Call site: ChatBubble — shown when message.acpToolCalls.isNotEmpty.
///
/// Ported from hermes-workspace `tui-activity-card.tsx`.
class TuiActivityCard extends StatelessWidget {
  final List<ChatAcpToolCall> toolCalls;
  final String? thinking;      // first line of thinkingText for the header
  final bool isStreaming;

  const TuiActivityCard({
    super.key,
    required this.toolCalls,
    this.thinking,
    required this.isStreaming,
  });

  String get _summary {
    final total  = toolCalls.length;
    final errors = toolCalls.where((c) => c.isFailed).length;
    final running = toolCalls.where((c) => c.isPending).length;
    final done   = total - errors - running;
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
    // Working stub: streaming but no events yet
    final isStub = !hasTools && isStreaming;
    if (!hasTools && !isStub) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2D2840),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF17132A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
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

          // Tool rows
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ...toolCalls.map(
                  (call) => _ToolRow(call: call, isStreamingActive: isStreaming),
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
                        Text(
                          'tool activity will appear after the run',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: Colors.white24,
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

// ── Individual tool row ───────────────────────────────────────────────────────

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
          // Main row: ● FunctionName  arg…  3s  ▸
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Status dot
                Text(
                  dot,
                  style: TextStyle(
                    fontSize: 12,
                    color: dotColor,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                // Function name
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
                // Elapsed timer
                if (isPending && widget.isStreamingActive && _elapsed > 0)
                  Text(
                    _formatElapsed(_elapsed),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: Colors.white24,
                    ),
                  ),
                // Expand chevron
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

          // ⎿ Output preview line
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 12, bottom: 4),
            child: Row(
              children: [
                Text(
                  '⎿',
                  style: TextStyle(
                    fontSize: 11,
                    color: isError
                        ? PocketClawTheme.lobsterRed.withOpacity(0.6)
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
                          ? PocketClawTheme.lobsterRed.withOpacity(0.7)
                          : Colors.white38,
                      fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Expanded detail panel
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
                            ? PocketClawTheme.lobsterRed.withOpacity(0.6)
                            : Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      c.content,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: isError
                            ? PocketClawTheme.lobsterRed.withOpacity(0.8)
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
```

### Update `ChatBubble` — Replace Chip Stack with TUI Card

In `lib/features/chat/chat_bubble.dart`:

```dart
// Add import:
import '../../shared/widgets/tui_activity_card.dart';

// REPLACE the existing acpToolCalls block:
// OLD:
if (message.acpToolCalls.isNotEmpty) ...[
  const SizedBox(height: 8),
  for (final c in message.acpToolCalls) ...[
    _AcpToolCallChip(call: c),
    const SizedBox(height: 4),
  ],
],

// NEW — single compound card ABOVE the message text:
// (Move this block to BEFORE the message content section)
if (!_isUser && message.acpToolCalls.isNotEmpty) ...[
  TuiActivityCard(
    toolCalls: message.acpToolCalls,
    isStreaming: message.isStreaming,
  ),
],
```

> **Important:** Place the `TuiActivityCard` ABOVE the message content in the Column, not below it. The correct order in the Column is:
> 1. `ThinkingIndicator` (if thinkingText present)
> 2. `TuiActivityCard` (if acpToolCalls present)
> 3. Message content (text)
> 4. StatusText indicator (if streaming with no content yet)
> 5. Memory citations
> 6. Footer (source badge + timestamp)

**Delete `_AcpToolCallChip` and `_StatusIcon`** from `chat_bubble.dart` — they are fully replaced by `TuiActivityCard`.

### Files Changed

| File | Change |
|---|---|
| `lib/shared/widgets/tui_activity_card.dart` | **New** |
| `lib/features/chat/chat_bubble.dart` | Replace chip stack with TUI card; delete `_AcpToolCallChip` + `_StatusIcon` |

### Test

1. Send a Hermes ACP message that triggers 3+ tool calls
2. **Before:** stack of individual coloured chips below the text
3. **After:** single "Activity" card above the text, one row per tool call
4. Verify status dots: `○` pulse while running, `●` when done, `✗` red when failed
5. Verify elapsed timers appear while a tool is running
6. Tap a row to expand — input + output shown in monospace panel
7. Verify working stub appears when streaming starts before first tool event

---

## Item 4 — Message Actions Bar

### The Problem

ClawCommander has no way to copy a message or retry a failed request. Both are standard mobile chat features. Long-pressing a message bubble should reveal a small actions bar.

### New File: `lib/shared/widgets/message_actions_bar.dart`

```dart
// lib/shared/widgets/message_actions_bar.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Appears on long-press of any chat bubble.
/// Shows [Copy] for all messages and [Retry] for the last user message.
class MessageActionsBar extends StatefulWidget {
  final String text;
  final bool showRetry;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  const MessageActionsBar({
    super.key,
    required this.text,
    required this.onDismiss,
    this.showRetry = false,
    this.onRetry,
  });

  @override
  State<MessageActionsBar> createState() => _MessageActionsBarState();
}

class _MessageActionsBarState extends State<MessageActionsBar> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _copied = false);
      widget.onDismiss();
    }
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
            color: Colors.black.withOpacity(0.4),
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
          if (widget.showRetry && widget.onRetry != null) ...[
            Container(
              width: 1,
              height: 20,
              color: const Color(0xFF3A3028),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
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
```

### Wire Long-Press in `ChatBubble`

In `lib/features/chat/chat_bubble.dart`, wrap the bubble container in a `GestureDetector` and overlay the actions bar using an `OverlayEntry`:

```dart
// Wrap the Flexible(child: Container(...)) in chat_bubble.dart:

// Add to ChatBubble class:
OverlayEntry? _overlayEntry;

void _showActions(BuildContext context, String text, bool isLastUserMsg,
    VoidCallback? onRetry) {
  _hideActions();
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox == null) return;
  final position = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;

  _overlayEntry = OverlayEntry(
    builder: (_) => Positioned(
      left: position.dx,
      top: position.dy - 48, // above the bubble
      child: Material(
        color: Colors.transparent,
        child: MessageActionsBar(
          text: text,
          showRetry: isLastUserMsg,
          onRetry: onRetry,
          onDismiss: _hideActions,
        ),
      ),
    ),
  );
  Overlay.of(context).insert(_overlayEntry!);
}

void _hideActions() {
  _overlayEntry?.remove();
  _overlayEntry = null;
}
```

Update the `build` method to wrap in `GestureDetector`:

```dart
// Wrap the existing Flexible widget:
GestureDetector(
  onLongPress: () {
    HapticFeedback.mediumImpact();
    _showActions(
      context,
      message.content,
      false, // pass true for last user message
      null,  // pass retry callback for last user message
    );
  },
  child: Flexible(
    child: Container(
      // ... existing bubble container unchanged
    ),
  ),
),
```

**Note:** To enable Retry, the chat screen needs to pass a `onRetry` callback when building the last user message. This requires a small change in `chat_screen.dart` to pass the retry callback through to the last user `ChatBubble`. The simplest approach: add an optional `onLongPress` callback parameter to `ChatBubble` and handle the overlay logic in `chat_screen.dart` where message context (is this the last user message?) is available.

### Files Changed

| File | Change |
|---|---|
| `lib/shared/widgets/message_actions_bar.dart` | **New** |
| `lib/features/chat/chat_bubble.dart` | Add long-press + overlay |
| `lib/features/chat/chat_screen.dart` | Pass retry callback for last user message |

### Test

1. Long-press any assistant message → **Copy** button appears above the bubble
2. Tap Copy → tick icon shows for 1.5s → overlay dismisses automatically
3. Long-press the last user message → **Copy** + **Retry** buttons appear
4. Tap Retry → message is re-sent, overlay dismisses
5. Tap anywhere else → overlay dismisses
6. Verify haptic feedback fires on long-press and on Retry tap

---

## Implementation Order

| Step | Task | File | Time |
|---|---|---|---|
| 1 | Create `SmoothStreamingNotifier` | `shared/utils/smooth_streaming_notifier.dart` | 30 min |
| 2 | Replace `_StreamingText` | `chat_bubble.dart` | 30 min |
| 3 | Test smooth streaming on device | — | 20 min |
| 4 | Add `thinkingText` to `ChatMessage` | `chat_message.dart` | 20 min |
| 5 | Accumulate thought chunks | `chat_providers.dart` | 20 min |
| 6 | Create `ThinkingIndicator` | `shared/widgets/thinking_indicator.dart` | 1 hour |
| 7 | Add `ThinkingIndicator` to `ChatBubble` | `chat_bubble.dart` | 20 min |
| 8 | Test thinking indicator with Hermes ACP | — | 20 min |
| 9 | Create `TuiActivityCard` | `shared/widgets/tui_activity_card.dart` | 3 hours |
| 10 | Replace chip stack in `ChatBubble` | `chat_bubble.dart` | 30 min |
| 11 | Delete `_AcpToolCallChip` + `_StatusIcon` | `chat_bubble.dart` | 5 min |
| 12 | Test TUI card with multi-tool ACP session | — | 30 min |
| 13 | Create `MessageActionsBar` | `shared/widgets/message_actions_bar.dart` | 1 hour |
| 14 | Wire long-press in `ChatBubble` + `ChatScreen` | both files | 45 min |
| 15 | Test copy + retry on device | — | 20 min |

**Total: ~3 days**

---

## New Files Summary

```
lib/shared/utils/
└── smooth_streaming_notifier.dart     ← Item 1

lib/shared/widgets/
├── thinking_indicator.dart            ← Item 2
├── tui_activity_card.dart             ← Item 3
└── message_actions_bar.dart           ← Item 4
```

## Changed Files Summary

| File | Changes |
|---|---|
| `lib/data/models/chat_message.dart` | Add `thinkingText` field |
| `lib/data/providers/chat_providers.dart` | Accumulate thought chunks + `byId` helper |
| `lib/features/chat/chat_bubble.dart` | Replace `_StreamingText`, add indicators, replace chip stack, add long-press |
| `lib/features/chat/chat_screen.dart` | Pass retry callback to last user bubble |

---

*CARMEN PTY LTD — ClawCommander Sprint A: Chat Polish Spec v1.0*  
*Verified against PocketClaw-source-2026-05-09 and hermes-workspace-main*  
*2026-05-09*
