/// Starter Pack picker — select and activate a company template
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/packs/starter_pack_service.dart';
import '../../data/providers/core_providers.dart';

class PackPickerScreen extends ConsumerStatefulWidget {
  /// If true, shows a "Skip" button (used during onboarding).
  final bool showSkip;
  final VoidCallback? onComplete;

  const PackPickerScreen({
    super.key,
    this.showSkip = false,
    this.onComplete,
  });

  @override
  ConsumerState<PackPickerScreen> createState() => _PackPickerScreenState();
}

class _PackPickerScreenState extends ConsumerState<PackPickerScreen> {
  bool _activating = false;
  String? _activatingId;

  Future<void> _activate(StarterPack pack) async {
    setState(() {
      _activating = true;
      _activatingId = pack.id;
    });

    final prefs = ref.read(sharedPrefsProvider);
    final service = StarterPackService(prefs: prefs);
    final result = await service.activate(pack);

    // Reload skills to include pack skills
    final skills = ref.read(skillRegistryProvider);
    await skills.loadAll();

    if (!mounted) return;

    setState(() {
      _activating = false;
      _activatingId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 4),
      ),
    );

    if (result.success) {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(sharedPrefsProvider);
    final activeId = prefs.getString('active_pack_id');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Starter Packs'),
        actions: [
          if (widget.showSkip)
            TextButton(
              onPressed: widget.onComplete,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Text(
            'Choose Your AI Company',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Each pack sets up a ready-made team of AI agents with the right '
            'skills, governance, and budget for your use case.',
            style: TextStyle(color: Colors.white54, height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Pack cards
          ...kStarterPacks.map((pack) {
            final isActive = pack.id == activeId;
            final isActivating = _activatingId == pack.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isActive
                    ? const BorderSide(
                        color: PocketClawTheme.electricTeal, width: 2)
                    : BorderSide(
                        color: PocketClawTheme.surfaceBright.withAlpha(120)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: (isActive || _activating)
                    ? null
                    : () => _activate(pack),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Text(pack.icon, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        pack.displayName,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isActive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: PocketClawTheme.electricTeal
                                              .withAlpha(30),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                PocketClawTheme.electricTeal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pack.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Agent count + governance
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.people_outline,
                            label: '${pack.agents.length} agents',
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.shield_outlined,
                            label: pack.governanceMode,
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.description_outlined,
                            label: '${pack.skillFiles.length} skills',
                          ),
                        ],
                      ),

                      // Activate button
                      if (!isActive) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: isActivating
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: _activating
                                      ? null
                                      : () => _activate(pack),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: PocketClawTheme.lobsterRed,
                                    side: const BorderSide(
                                        color: PocketClawTheme.lobsterRed),
                                  ),
                                  child: const Text('Activate'),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PocketClawTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white38),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
