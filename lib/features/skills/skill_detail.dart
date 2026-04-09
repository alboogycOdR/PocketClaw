/// Full skill detail view with metadata, runtime badge, and SKILL.md body
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/chat_message.dart';

import '../../data/providers/core_providers.dart';
import '../../shared/widgets/source_badge.dart';
import 'skill_editor.dart';

/// Provider that loads the SKILL.md body for a given skill name.
final _skillBodyProvider =
    FutureProvider.family<String, String>((ref, skillName) async {
  final registry = ref.watch(skillRegistryProvider);
  final skill = registry.getSkill(skillName);
  if (skill == null) return 'Skill not found.';

  // Use cached body if available (loaded during registry init)
  if (skill.cachedBody != null && skill.cachedBody!.isNotEmpty) {
    return skill.cachedBody!;
  }

  // Try loading from bodyPath
  final bodyPath = skill.bodyPath;
  if (bodyPath.isEmpty) return 'No documentation available.';

  // If it's a bundled asset path, load from assets
  if (bodyPath.startsWith('assets/')) {
    try {
      final raw = await rootBundle.loadString(bodyPath);
      // Strip YAML frontmatter
      final fmPattern = RegExp(r'^---\s*\n[\s\S]*?\n---\s*\n', multiLine: true);
      return raw.replaceFirst(fmPattern, '').trim();
    } catch (_) {
      return 'Could not load skill documentation.';
    }
  }

  // Otherwise try filesystem
  try {
    final file = File(bodyPath);
    if (await file.exists()) {
      final raw = await file.readAsString();
      final fmPattern =
          RegExp(r'^---\s*\n[\s\S]*?\n---\s*\n', multiLine: true);
      return raw.replaceFirst(fmPattern, '').trim();
    }
  } catch (_) {
    // fall through
  }

  return 'No documentation available.';
});

class SkillDetailScreen extends ConsumerWidget {
  final String skillName;

  const SkillDetailScreen({super.key, required this.skillName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(skillRegistryProvider);
    final skill = registry.getSkill(skillName);

    if (skill == null) {
      return Scaffold(
        appBar: AppBar(title: Text(skillName)),
        body: const Center(
          child: Text(
            'Skill not found',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
    }

    final bodyAsync = ref.watch(_skillBodyProvider(skillName));

    final source = switch (skill.runtime) {
      'local' => MessageSource.local,
      'server' => MessageSource.server,
      'bridge' => MessageSource.bridge,
      _ => MessageSource.server,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(skillName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SkillEditor(existingSkillName: skillName),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: PocketClawTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            skill.emoji ?? '🔧',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skill.name,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SourceBadge(source: source),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    skill.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Requirements
          if (skill.requiredDeviceApis.isNotEmpty ||
              skill.requiredEnv.isNotEmpty ||
              skill.requiredBins.isNotEmpty) ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requirements',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    if (skill.requiredDeviceApis.isNotEmpty) ...[
                      _RequirementSection(
                        icon: Icons.phone_android,
                        label: 'Device APIs',
                        items: skill.requiredDeviceApis,
                        color: PocketClawTheme.electricTeal,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (skill.requiredEnv.isNotEmpty) ...[
                      _RequirementSection(
                        icon: Icons.key,
                        label: 'Environment Variables',
                        items: skill.requiredEnv,
                        color: const Color(0xFFFFB74D),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (skill.requiredBins.isNotEmpty)
                      _RequirementSection(
                        icon: Icons.terminal,
                        label: 'Binaries',
                        items: skill.requiredBins,
                        color: const Color(0xFF7C4DFF),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Markdown body
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: bodyAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, _) => Text(
                  'Failed to load documentation: $error',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                data: (body) => MarkdownBody(
                  data: body,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      color: Colors.white70,
                      height: 1.6,
                      fontSize: 14,
                    ),
                    h1: GoogleFonts.jetBrainsMono(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    h2: GoogleFonts.jetBrainsMono(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    h3: GoogleFonts.jetBrainsMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    code: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      color: PocketClawTheme.electricTeal,
                      backgroundColor: PocketClawTheme.surfaceContainerLow,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: PocketClawTheme.surfaceDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    listBullet: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RequirementSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> items;
  final Color color;

  const _RequirementSection({
    required this.icon,
    required this.label,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: items
              .map(
                (item) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withAlpha(40)),
                  ),
                  child: Text(
                    item,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: color,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
