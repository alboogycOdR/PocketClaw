/// Browse and install skills from the ClawHub registry via Gateway REST API
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/skill.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/empty_state.dart';

/// Provider that fetches available skills from the server's skill registry.
final clawHubSkillsProvider = FutureProvider<List<SkillInfo>>((ref) async {
  final rest = ref.watch(gatewayRestClientProvider);
  if (rest == null) return [];
  return rest.getInstalledSkills();
});

class ClawHubBrowser extends ConsumerWidget {
  const ClawHubBrowser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rest = ref.watch(gatewayRestClientProvider);
    final skillsAsync = ref.watch(clawHubSkillsProvider);

    if (rest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ClawHub')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Connect to a Gateway to browse skills',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ClawHub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(clawHubSkillsProvider),
          ),
        ],
      ),
      body: skillsAsync.when(
        data: (skills) {
          if (skills.isEmpty) {
            return const EmptyState(
              icon: Icons.extension_off_outlined,
              message: 'No skills available on the server',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];
              return _ClawHubSkillCard(skill: skill);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load skills\n$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(clawHubSkillsProvider),
        ),
      ),
    );
  }
}

class _ClawHubSkillCard extends ConsumerStatefulWidget {
  final SkillInfo skill;

  const _ClawHubSkillCard({required this.skill});

  @override
  ConsumerState<_ClawHubSkillCard> createState() => _ClawHubSkillCardState();
}

class _ClawHubSkillCardState extends ConsumerState<_ClawHubSkillCard> {
  bool _installing = false;
  bool _installed = false;

  Future<void> _install() async {
    final rest = ref.read(gatewayRestClientProvider);
    if (rest == null) return;

    setState(() => _installing = true);

    try {
      await rest.installSkill(widget.skill.slug);
      if (mounted) {
        setState(() {
          _installing = false;
          _installed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.skill.name} installed'),
          ),
        );
        // Refresh the local skill registry
        ref.invalidate(skillsLoadedProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _installing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Install failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    final localRegistry = ref.watch(skillRegistryProvider);
    final alreadyInstalled =
        _installed || localRegistry.skills.any((s) => s.name == skill.slug);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PocketClawTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  skill.emoji ?? '🔧',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skill.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: PocketClawTheme.electricTeal.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          skill.runtime,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: PocketClawTheme.electricTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Install button
            if (alreadyInstalled)
              const Icon(Icons.check_circle, size: 20, color: Color(0xFF4CAF50))
            else if (_installing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              OutlinedButton(
                onPressed: _install,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Install'),
              ),
          ],
        ),
      ),
    );
  }
}
