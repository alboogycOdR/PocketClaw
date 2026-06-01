library;

import 'package:flutter/material.dart';

import '../../app/hermes_commander_theme.dart';
import 'command_catalog.dart';

class SlashCommandOverlay extends StatelessWidget {
  final String input;
  final void Function(CommandSpec command) onPick;

  const SlashCommandOverlay({
    super.key,
    required this.input,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = input.trimLeft();
    if (!trimmed.startsWith('/')) return const SizedBox.shrink();
    final firstWord = trimmed.split(RegExp(r'\s')).first;
    if (firstWord.length > 1 && trimmed.length > firstWord.length) {
      return const SizedBox.shrink();
    }
    final commands = autocompleteHermesCommands(firstWord).take(7).toList();
    if (commands.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: HCTheme.bgPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HCTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(102),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: commands.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: HCTheme.borderMuted),
        itemBuilder: (context, index) {
          final command = commands[index];
          final isSelected = index == 0;
          return InkWell(
            onTap: () => onPick(command),
            child: Container(
              color: isSelected ? HCTheme.bgActive : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: HCTheme.bgSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: HCTheme.border),
                    ),
                    child: Center(
                      child: Text(
                        command.name.length >= 2
                            ? command.name.substring(0, 2)
                            : command.name,
                        style: const TextStyle(
                          fontFamily: 'GeistMono',
                          fontSize: 10,
                          color: HCTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                command.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'GeistMono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: HCTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (command.argsHint != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  command.argsHint!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'GeistMono',
                                    fontSize: 10,
                                    color: HCTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          command.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'GeistSans',
                            fontSize: 11,
                            color: HCTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        'ENTER',
                        style: TextStyle(
                          fontFamily: 'GeistMono',
                          fontSize: 9,
                          color: HCTheme.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
