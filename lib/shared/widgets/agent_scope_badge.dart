/// A small chip shown in screen AppBars to indicate which agent
/// owns the data on that screen. Informational only — Phase 2 will
/// make screens dynamically mode-aware (chip will then read
/// `activeServerProvider`).
///
/// See SPEC-MultiAgentFix-Phase1-v1.0.md §Fix 2.
library;

import 'package:flutter/material.dart';

class AgentScopeBadge extends StatelessWidget {
  final String agentName;
  final Color color;
  final IconData icon;

  const AgentScopeBadge.openclaw({super.key})
      : agentName = 'OpenClaw',
        color = const Color(0xFFE53935),
        icon = Icons.rss_feed;

  const AgentScopeBadge.hermes({super.key})
      : agentName = 'Hermes',
        color = const Color(0xFF7C3AED),
        icon = Icons.psychology_outlined;

  const AgentScopeBadge.local({super.key})
      : agentName = 'Local',
        color = const Color(0xFF00E5CC),
        icon = Icons.phone_android;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Chip(
        avatar: Icon(icon, size: 12, color: color),
        label: Text(
          agentName,
          style: TextStyle(fontSize: 10, color: color),
        ),
        backgroundColor: color.withAlpha(31),
        side: BorderSide(color: color.withAlpha(102)),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
