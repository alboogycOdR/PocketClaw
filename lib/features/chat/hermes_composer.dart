library;

import 'package:flutter/material.dart';

import '../../app/hermes_commander_theme.dart';
import '../../shared/widgets/context_ring.dart';

class HermesComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isProcessing;
  final bool isVoiceRecording;
  final int tokenCount;
  final double contextFill;
  final String transportLabel;
  final String modelLabel;
  final String? sessionId;
  final VoidCallback onAttach;
  final VoidCallback onOpenCommands;
  final Widget voiceButton;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const HermesComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isProcessing,
    required this.isVoiceRecording,
    required this.tokenCount,
    required this.contextFill,
    required this.transportLabel,
    required this.modelLabel,
    this.sessionId,
    required this.onAttach,
    required this.onOpenCommands,
    required this.voiceButton,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HCTheme.bgPanel,
        border: Border(top: BorderSide(color: HCTheme.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: onAttach,
                    icon: const Icon(Icons.attach_file, size: 18),
                    color: HCTheme.textMuted,
                    tooltip: 'Attach file',
                  ),
                  IconButton(
                    onPressed: onOpenCommands,
                    icon: const Icon(Icons.terminal, size: 18),
                    color: HCTheme.textMuted,
                    tooltip: 'Slash commands',
                  ),
                  voiceButton,
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontFamily: 'GeistSans',
                        fontSize: 14,
                        color: HCTheme.textPrimary,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: isVoiceRecording
                            ? 'Speak or type, then tap mic to send...'
                            : 'Message Hermes...',
                        hintStyle: const TextStyle(
                          fontFamily: 'GeistSans',
                          fontSize: 14,
                          color: HCTheme.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        filled: false,
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      if (isProcessing) {
                        return _StopButton(onTap: onStop);
                      }
                      return _SendButton(enabled: hasText, onTap: onSend);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  _FooterChip(icon: Icons.psychology_outlined, label: 'Hermes'),
                  const SizedBox(width: 6),
                  _FooterChip(
                    icon: Icons.settings_ethernet,
                    label: transportLabel,
                  ),
                  const SizedBox(width: 6),
                  _FooterChip(
                    icon: Icons.auto_awesome_outlined,
                    label: modelLabel,
                  ),
                  const Spacer(),
                  ContextRing(
                    fill: contextFill,
                    tokenCount: tokenCount,
                    size: 28,
                    model: modelLabel,
                    transport: transportLabel,
                    sessionId: sessionId,
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

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? HCTheme.gold : HCTheme.bgActive,
        ),
        child: Icon(
          Icons.arrow_upward,
          size: 16,
          color: enabled ? HCTheme.bgBase : HCTheme.textMuted,
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HCTheme.bgActive,
          border: Border.all(color: HCTheme.border),
        ),
        child: const Icon(Icons.stop, size: 14, color: HCTheme.textSecondary),
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FooterChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HCTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HCTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: HCTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 11,
              color: HCTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
