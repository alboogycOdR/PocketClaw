/// Extract and run tool calls from a model's streaming output.
///
/// Parser supports three flavours observed in the wild (verified
/// against off-grid-mobile-ai `generationToolLoop.ts`):
///
/// 1. Standard JSON body:
///      <tool_call>{"name":"calculator","arguments":{"expression":"2+2"}}</tool_call>
///
/// 2. XML-style body for small models that fail at JSON:
///      <tool_call><function=calculator><parameter=expression>2+2</parameter></function></tool_call>
///
/// 3. Unclosed `<tool_call>` at end of buffer — happens when the model
///    hits EOS without closing the tag. We still try to parse the
///    trailing fragment.
///
/// The chat send path keeps a buffer of streamed tokens; on each
/// new chunk it calls [extractToolCalls] to pull any completed calls,
/// runs them via [toolExecutor], and re-injects the `<tool_result>`
/// blocks for the next inference round.
library;

import 'dart:convert';

import 'tool_executor.dart';

const int kMaxToolCalls = 5;
const int kMaxToolLoops = 3;

class ParsedToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;
  final int startIndex;
  final int endIndex;
  const ParsedToolCall({
    required this.id,
    required this.name,
    required this.args,
    required this.startIndex,
    required this.endIndex,
  });
}

class ToolCallExtraction {
  /// Buffer with the matched `<tool_call>` ranges removed, so the
  /// rendered bubble doesn't show the raw call tags.
  final String cleanText;
  final List<ParsedToolCall> calls;
  const ToolCallExtraction({required this.cleanText, required this.calls});
}

/// Pull every fully- or partially-formed tool call out of [buffer].
/// Returns the cleaned text + list of parsed calls.
ToolCallExtraction extractToolCalls(String buffer) {
  final calls = <ParsedToolCall>[];
  final matchedRanges = <List<int>>[]; // [start, end] inclusive-exclusive

  // 1. Closed `<tool_call>...</tool_call>` blocks (preferred path).
  final closedRe = RegExp(r'<tool_call>([\s\S]*?)</tool_call>');
  for (final match in closedRe.allMatches(buffer)) {
    matchedRanges.add([match.start, match.end]);
    final body = match.group(1)!.trim();
    final call = _parseBody(body, calls.length);
    if (call != null) {
      calls.add(ParsedToolCall(
        id: call.id,
        name: call.name,
        args: call.args,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }
  }

  // 2. Unclosed `<tool_call>` fragment at the tail.
  final unclosedRe = RegExp(r'<tool_call>([\s\S]+)$');
  final unclosed = unclosedRe.firstMatch(buffer);
  if (unclosed != null) {
    final overlaps = matchedRanges.any((r) =>
        unclosed.start >= r[0] && unclosed.start < r[1]);
    if (!overlaps) {
      final body = unclosed.group(1)!.trim();
      final call = _parseBody(body, calls.length);
      if (call != null) {
        calls.add(ParsedToolCall(
          id: call.id,
          name: call.name,
          args: call.args,
          startIndex: unclosed.start,
          endIndex: buffer.length,
        ));
        matchedRanges.add([unclosed.start, buffer.length]);
      }
    }
  }

  // Strip matched ranges in reverse so indices stay valid.
  matchedRanges.sort((a, b) => b[0].compareTo(a[0]));
  var cleanText = buffer;
  for (final r in matchedRanges) {
    cleanText = cleanText.substring(0, r[0]) + cleanText.substring(r[1]);
  }

  return ToolCallExtraction(cleanText: cleanText.trim(), calls: calls);
}

/// Try JSON first, then fall back to XML-style body. Returns null
/// when the body matches neither shape.
ParsedToolCall? _parseBody(String body, int idSuffix) {
  // JSON: { "name": "...", "arguments": {...} } (or "parameters")
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final name = json['name'] as String?;
    if (name != null && name.isNotEmpty) {
      final args = (json['arguments'] as Map?)?.cast<String, dynamic>() ??
          (json['parameters'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return ParsedToolCall(
        id: 'text-tc-${DateTime.now().millisecondsSinceEpoch}-$idSuffix',
        name: name,
        args: args,
        startIndex: 0,
        endIndex: 0,
      );
    }
  } catch (_) {
    // Not JSON — try XML-style.
  }

  // XML body: <function=NAME>...<parameter=KEY>VALUE</parameter>...
  final funcMatch = RegExp(r'<function=(\w+)>').firstMatch(body);
  if (funcMatch == null) return null;
  final name = funcMatch.group(1)!;
  final args = <String, dynamic>{};
  final paramRe = RegExp(
      r'<parameter=(\w+)>([\s\S]*?)(?=<parameter=|<\/|$)');
  for (final m in paramRe.allMatches(body)) {
    args[m.group(1)!] = m.group(2)!.trim();
  }
  return ParsedToolCall(
    id: 'text-tc-${DateTime.now().millisecondsSinceEpoch}-$idSuffix',
    name: name,
    args: args,
    startIndex: 0,
    endIndex: 0,
  );
}

/// Format a tool result for re-injection into the model's context.
String formatToolResult(ToolCallResult result) {
  return '<tool_result name="${result.toolName}"'
      '${result.failed ? ' status="error"' : ''}>'
      '\n${result.output}\n'
      '</tool_result>';
}

/// Execute [call] and return its formatted `<tool_result>` block.
Future<String> runAndFormat(ParsedToolCall call) async {
  final result = await toolExecutor.execute(call.name, call.args);
  return formatToolResult(result);
}
