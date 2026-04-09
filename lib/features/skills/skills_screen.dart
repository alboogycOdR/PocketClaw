/// Skills list grouped by runtime (Local/Server/Bridge)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/skill.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/source_badge.dart';
import '../../data/models/chat_message.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadState = ref.watch(skillsLoadedProvider);

    return loadState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Skills')),
        body: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Skills')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                'Failed to load skills:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(skillsLoadedProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (_) => _SkillsList(),
    );
  }
}

class _SkillsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(skillRegistryProvider);
    final skills = registry.skills;

    if (skills.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Skills')),
        body: const EmptyState(
          icon: Icons.extension_off_outlined,
          message: 'No skills installed',
        ),
      );
    }

    final local = skills.where((s) => s.runtime == 'local').toList();
    final server = skills.where((s) => s.runtime == 'server').toList();
    final bridge = skills.where((s) => s.runtime == 'bridge').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(skillsLoadedProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (local.isNotEmpty) ...[
              _RuntimeHeader(
                label: 'Local',
                count: local.length,
                color: PocketClawTheme.electricTeal,
              ),
              const SizedBox(height: 8),
              ...local.map((s) => _SkillCard(skill: s)),
              const SizedBox(height: 16),
            ],
            if (server.isNotEmpty) ...[
              _RuntimeHeader(
                label: 'Server',
                count: server.length,
                color: PocketClawTheme.lobsterRed,
              ),
              const SizedBox(height: 8),
              ...server.map((s) => _SkillCard(skill: s)),
              const SizedBox(height: 16),
            ],
            if (bridge.isNotEmpty) ...[
              _RuntimeHeader(
                label: 'Bridge',
                count: bridge.length,
                color: const Color(0xFFFFB74D),
              ),
              const SizedBox(height: 8),
              ...bridge.map((s) => _SkillCard(skill: s)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RuntimeHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _RuntimeHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white70,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _SkillCard extends StatelessWidget {
  final Skill skill;

  const _SkillCard({required this.skill});

  MessageSource get _source => switch (skill.runtime) {
        'local' => MessageSource.local,
        'server' => MessageSource.server,
        'bridge' => MessageSource.bridge,
        _ => MessageSource.server,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.go('/skills/${skill.name}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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

              // Name & description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            skill.name,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SourceBadge(source: _source),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skill.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
                color: Colors.white24,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
