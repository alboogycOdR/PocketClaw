/// Tool call card — renders a single HermesToolCall (and optional result
/// text) with kind-based colour coding. Used in the Hermes session detail
/// view and reserved for future ACP chat. Colour map per Scarf.
/// SPEC-MultiTransport §11.5.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/hermes/models/hermes_message.dart';

class ToolCallCard extends StatelessWidget {
  final HermesToolCall toolCall;
  final String? result;
  final bool initiallyExpanded;

  const ToolCallCard({
    super.key,
    required this.toolCall,
    this.result,
    this.initiallyExpanded = false,
  });

  static Color kindColor(ToolKind k) => switch (k) {
        ToolKind.read => const Color(0xFF60A5FA),
        ToolKind.edit => const Color(0xFFFBBF24),
        ToolKind.execute => const Color(0xFF34D399),
        ToolKind.fetch => const Color(0xFFA78BFA),
        ToolKind.search => const Color(0xFF38BDF8),
        ToolKind.think => const Color(0xFFF472B6),
        ToolKind.other => const Color(0xFF9CA3AF),
      };

  static IconData kindIcon(ToolKind k) => switch (k) {
        ToolKind.read => Icons.menu_book_outlined,
        ToolKind.edit => Icons.edit_outlined,
        ToolKind.execute => Icons.terminal,
        ToolKind.fetch => Icons.public,
        ToolKind.search => Icons.search,
        ToolKind.think => Icons.psychology_outlined,
        ToolKind.other => Icons.extension_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final color = kindColor(toolCall.kind);
    final icon = kindIcon(toolCall.kind);
    final args = toolCall.arguments.isEmpty
        ? null
        : const JsonEncoder.withIndent('  ').convert(toolCall.arguments);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withAlpha(80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          listTileTheme: const ListTileThemeData(dense: true),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding:
              const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(icon, size: 16, color: color),
          title: Text(
            toolCall.name.isEmpty ? '(unnamed tool)' : toolCall.name,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          subtitle: args == null
              ? null
              : Text(
                  _previewArgs(toolCall.arguments),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
          children: [
            if (args != null) ...[
              const SizedBox(height: 4),
              _CodeBlock(label: 'arguments', text: args),
            ],
            if (result != null && result!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _CodeBlock(label: 'result', text: result!),
            ],
          ],
        ),
      ),
    );
  }

  static String _previewArgs(Map<String, dynamic> args) {
    final entries = args.entries.take(2).map((e) {
      final v = e.value;
      final s = v is String && v.length > 40 ? '${v.substring(0, 40)}…' : '$v';
      return '${e.key}: $s';
    }).join(', ');
    return entries;
  }
}

class _CodeBlock extends StatelessWidget {
  final String label;
  final String text;
  const _CodeBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: Colors.white38,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
