/// Slash-command palette (bottom sheet) + inline autocomplete strip for
/// the chat input, plus a destructive-command confirm dialog.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import 'command_catalog.dart';

/// Inline autocomplete shown above the input bar while the user is typing
/// a slash command. Tapping a row inserts the command (with a trailing
/// space when the command takes args) and refocuses the text field.
class CommandAutocompleteStrip extends StatelessWidget {
  final String input;
  final void Function(CommandSpec) onPick;

  const CommandAutocompleteStrip({
    super.key,
    required this.input,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = input.trimLeft();
    if (!trimmed.startsWith('/')) return const SizedBox.shrink();
    // Only autocomplete the token-after-whitespace if it still looks like
    // the command word (no space yet — once there's a space the user is
    // writing args and autocomplete should step back out of the way).
    final firstWord = trimmed.split(RegExp(r'\s')).first;
    if (firstWord.length > 1 && trimmed.length > firstWord.length) {
      return const SizedBox.shrink();
    }
    final matches = autocompleteCommands(firstWord).take(6).toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: PocketClawTheme.surfaceDim,
        border: Border.all(color: const Color(0xFF3A3A50)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < matches.length; i++) ...[
            if (i != 0)
              const Divider(height: 1, color: Color(0xFF2A2A3A)),
            _CommandRow(spec: matches[i], onTap: () => onPick(matches[i])),
          ],
        ],
      ),
    );
  }
}

/// Full categorized palette opened from the "/" button in the input bar.
/// Returns the picked command via Navigator.pop, so the caller can
/// `await showModalBottomSheet<CommandSpec>` and then insert into the
/// text controller.
class CommandPaletteSheet extends StatefulWidget {
  const CommandPaletteSheet({super.key});

  @override
  State<CommandPaletteSheet> createState() => _CommandPaletteSheetState();
}

class _CommandPaletteSheetState extends State<CommandPaletteSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = commandsForMobile();
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.description.toLowerCase().contains(q) ||
                c.aliases.any((a) => a.toLowerCase().contains(q)))
            .toList();

    final grouped = <CommandCategory, List<CommandSpec>>{};
    for (final c in filtered) {
      grouped.putIfAbsent(c.category, () => []).add(c);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: PocketClawTheme.surfaceDim,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Slash commands',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${filtered.length}/${all.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Filter commands…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.black.withAlpha(80),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final cat in kCategoryLabels.keys)
                      if (grouped[cat]?.isNotEmpty ?? false) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Text(
                            kCategoryLabels[cat]!.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white38,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        for (final c in grouped[cat]!)
                          _CommandRow(
                            spec: c,
                            onTap: () => Navigator.of(context).pop(c),
                          ),
                      ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommandRow extends StatelessWidget {
  final CommandSpec spec;
  final VoidCallback onTap;

  const _CommandRow({required this.spec, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        spec.name,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (spec.argsHint != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            spec.argsHint!,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (spec.destructive) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.warning_amber,
                            size: 14,
                            color: PocketClawTheme.lobsterRed),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation dialog for destructive commands. Returns true if the user
/// wants to proceed.
Future<bool> confirmDestructiveCommand(
  BuildContext context,
  CommandSpec spec,
  String fullMessage,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon:
          Icon(Icons.warning_amber, color: PocketClawTheme.lobsterRed, size: 32),
      title: const Text('Confirm destructive command'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You\'re about to send:'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(100),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              fullMessage,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            spec.description,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: PocketClawTheme.lobsterRed,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Send'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Lookup a command (by /name or /alias) for a message body. Returns null
/// if the message isn't a slash command at all.
CommandSpec? lookupCommand(String message) {
  final trimmed = message.trimLeft();
  if (!trimmed.startsWith('/')) return null;
  final word = trimmed.split(RegExp(r'\s')).first.toLowerCase();
  for (final c in kCommandCatalog) {
    if (c.name.toLowerCase() == word) return c;
    for (final a in c.aliases) {
      if (a.toLowerCase() == word) return c;
    }
  }
  return null;
}
