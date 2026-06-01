library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/hermes_commander_theme.dart';
import '../../data/providers/intelligence_providers.dart';
import 'recon_panel.dart';
import 'world_intelligence_screen.dart';

class IntelScreen extends ConsumerStatefulWidget {
  const IntelScreen({super.key});

  @override
  ConsumerState<IntelScreen> createState() => _IntelScreenState();
}

class _IntelScreenState extends ConsumerState<IntelScreen> {
  bool _reconExpanded = false;

  @override
  Widget build(BuildContext context) {
    final reconFocus = ref.watch(reconFocusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intel'),
        actions: [
          // RECON toggle button with indicator when a focus is active
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _reconExpanded ? Icons.radar : Icons.radar_outlined,
                  size: 22,
                  color: _reconExpanded ? HCTheme.gold : null,
                ),
                if (reconFocus != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: HCTheme.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: _reconExpanded ? 'Hide RECON' : 'Show RECON toolkit',
            onPressed: () => setState(() => _reconExpanded = !_reconExpanded),
          ),
          if (reconFocus != null)
            IconButton(
              icon: const Icon(Icons.location_off_outlined, size: 20),
              tooltip: 'Clear RECON pin',
              onPressed: () =>
                  ref.read(reconFocusProvider.notifier).state = null,
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Osiris settings',
            onPressed: () => context.push('/settings/osiris'),
          ),
        ],
      ),
      body: Column(
        children: [
          // RECON panel — collapsible
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _reconExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: const ReconPanel(),
                  )
                : const SizedBox.shrink(),
          ),
          // Active RECON focus banner when collapsed
          if (!_reconExpanded && reconFocus != null)
            _ReconFocusBanner(
              focus: reconFocus,
              onExpand: () => setState(() => _reconExpanded = true),
              onClear: () =>
                  ref.read(reconFocusProvider.notifier).state = null,
            ),
          // Map takes remaining space
          const Expanded(child: WorldIntelligenceScreen()),
        ],
      ),
    );
  }
}

class _ReconFocusBanner extends StatelessWidget {
  final ReconMapFocus focus;
  final VoidCallback onExpand;
  final VoidCallback onClear;

  const _ReconFocusBanner({
    required this.focus,
    required this.onExpand,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HCTheme.goldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HCTheme.gold.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.radar, size: 14, color: HCTheme.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'RECON pin: ${focus.label}',
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 12,
                color: HCTheme.gold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onExpand,
            child: const Text(
              'Open RECON',
              style: TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 12,
                color: HCTheme.gold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close,
              size: 14,
              color: HCTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
