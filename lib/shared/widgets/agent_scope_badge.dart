/// A small tappable chip rendered in screen AppBars. Shows the active
/// server (OpenClaw / Hermes / Local) and lets the user switch via a
/// bottom-sheet picker.
///
/// Phase 1 shipped this as a static info badge; Phase 2 makes it
/// dynamic and actionable per ADR-001 §4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/app_flavor.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/hermes_providers.dart';
import '../../data/providers/server_providers.dart';

class AgentScopeBadge extends ConsumerWidget {
  const AgentScopeBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    final (icon, color, label) = _appearance(server);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 12, color: color),
        label: Text(label, style: TextStyle(fontSize: 10, color: color)),
        backgroundColor: color.withAlpha(31),
        side: BorderSide(color: color.withAlpha(102)),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: kHermesOnlyMode ? null : () => _showPicker(context),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _ServerPickerSheet(),
    );
  }

  static (IconData, Color, String) _appearance(ActiveServer s) => switch (s) {
    ActiveServer.openclaw => (
      Icons.rss_feed,
      const Color(0xFFE53935),
      'OpenClaw',
    ),
    ActiveServer.hermes => (
      Icons.psychology_outlined,
      const Color(0xFF7C3AED),
      'Hermes',
    ),
    ActiveServer.local => (
      Icons.phone_android,
      const Color(0xFF00E5CC),
      'Local',
    ),
  };
}

class _ServerPickerSheet extends ConsumerWidget {
  const _ServerPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(activeServerProvider);
    final gatewayUrl = ref.watch(gatewayUrlProvider);
    final hermesUrl = ref.watch(hermesBaseUrlProvider);

    final entries = <_PickerEntry>[
      if (gatewayUrl.isNotEmpty)
        const _PickerEntry(
          server: ActiveServer.openclaw,
          label: 'OpenClaw',
          subtitle: 'Gateway · WebSocket',
        ),
      if (hermesUrl.isNotEmpty)
        const _PickerEntry(
          server: ActiveServer.hermes,
          label: 'Hermes Agent',
          subtitle: 'REST + SSH management',
        ),
      const _PickerEntry(
        server: ActiveServer.local,
        label: 'Local Model',
        subtitle: 'On-device GGUF inference',
      ),
    ];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Active server',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          for (final e in entries)
            ListTile(
              leading: Icon(
                AgentScopeBadge._appearance(e.server).$1,
                color: AgentScopeBadge._appearance(e.server).$2,
              ),
              title: Text(e.label),
              subtitle: Text(
                e.subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              trailing: current == e.server
                  ? const Icon(Icons.check, color: Colors.white70)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                if (current != e.server) {
                  await setActiveServer(ref, e.server);
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PickerEntry {
  final ActiveServer server;
  final String label;
  final String subtitle;
  const _PickerEntry({
    required this.server,
    required this.label,
    required this.subtitle,
  });
}
