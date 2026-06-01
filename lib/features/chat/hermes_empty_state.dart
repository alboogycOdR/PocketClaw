library;

import 'package:flutter/material.dart';

import '../../app/hermes_commander_theme.dart';
import '../../shared/widgets/hermes_avatar.dart';

class HermesEmptyState extends StatelessWidget {
  final void Function(String text) onSuggestion;

  const HermesEmptyState({super.key, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
        final compact = keyboardOpen || constraints.maxHeight < 620;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, compact ? 20 : 24, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    HermesAvatar(size: compact ? 64 : 72),
                    SizedBox(height: compact ? 16 : 20),
                    Text(
                      'HermesCommander',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'GeistSans',
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w600,
                        color: HCTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a session with Hermes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'GeistSans',
                        fontSize: compact ? 13 : 14,
                        height: 1.5,
                        color: HCTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 18),
                    _SuggestionChip(
                      icon: Icons.tune,
                      label: 'Summarize my latest Hermes activity',
                      onTap: () =>
                          onSuggestion('Summarize my latest Hermes activity.'),
                    ),
                    const SizedBox(height: 8),
                    _SuggestionChip(
                      icon: Icons.public_outlined,
                      label: 'Run a quick DNS and WHOIS check on a domain',
                      onTap: () => onSuggestion(
                        'Run a quick DNS and WHOIS check on the domain I provide next.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SuggestionChip(
                      icon: Icons.account_tree_outlined,
                      label: 'Plan a small swarm mission',
                      onTap: () => onSuggestion('Plan a small swarm mission.'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HCTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HCTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: HCTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 13,
                  color: HCTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
