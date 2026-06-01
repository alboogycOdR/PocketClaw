library;

import 'package:flutter/material.dart';

import '../../app/hermes_commander_theme.dart';

class HermesUpdateBanner extends StatelessWidget {
  final String webUiVersion;
  final String agentVersion;
  final VoidCallback onUpdateNow;
  final VoidCallback onDismiss;

  const HermesUpdateBanner({
    super.key,
    required this.webUiVersion,
    required this.agentVersion,
    required this.onUpdateNow,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HCTheme.goldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HCTheme.goldMuted),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.arrow_upward, size: 14, color: HCTheme.gold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WebUI: $webUiVersion updates | Agent: $agentVersion update available',
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 12,
                    color: HCTheme.gold,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Update your Hermes WebUI or VPS agent to keep the mobile shell aligned.',
                  style: TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 11,
                    color: HCTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _BannerButton(
                      label: 'Later',
                      onTap: onDismiss,
                      outlined: true,
                    ),
                    _BannerButton(label: 'Update Now', onTap: onUpdateNow),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  const _BannerButton({
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : HCTheme.gold,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: HCTheme.gold),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GeistSans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: outlined ? HCTheme.gold : HCTheme.bgBase,
          ),
        ),
      ),
    );
  }
}
