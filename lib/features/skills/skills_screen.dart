/// Skills — server-aware. Top-level [SkillsScreen] switches on
/// [activeServerProvider]:
///   - OpenClaw → existing list grouped by runtime (Local/Server/Bridge)
///   - Hermes   → [HermesSkillsTab] wrapped (browses ~/.hermes/skills/)
///   - Local    → existing list, server section will simply be empty
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../shared/widgets/settings_gear_button.dart';
import '../../data/models/skill.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/server_providers.dart';
import '../../shared/widgets/agent_scope_badge.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/source_badge.dart';
import '../../data/models/chat_message.dart';
import '../hermes/hermes_skills_screen.dart';
import 'skills_providers.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    if (server == ActiveServer.hermes) {
      return const _HermesSkillsView();
    }

    // OpenClaw and Local both use the existing runtime-grouped list.
    // For Local, the "Server" section will just render empty.
    final loadState = ref.watch(skillsLoadedProvider);

    return loadState.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Skills'),
          actions: const [
            AgentScopeBadge(),
            SizedBox(width: 4),
            SettingsGearButton(),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Skills'),
          actions: const [
            AgentScopeBadge(),
            SizedBox(width: 4),
            SettingsGearButton(),
          ],
        ),
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
    final serverSkillsAsync = ref.watch(serverSkillsProvider);

    final local = skills.where((s) => s.runtime == 'local').toList();
    final server = skills.where((s) => s.runtime == 'server').toList();
    final bridge = skills.where((s) => s.runtime == 'bridge').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
        actions: [
          const AgentScopeBadge(),
          const SizedBox(width: 4),
          const SettingsGearButton(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh server skills',
            onPressed: () => ref.invalidate(serverSkillsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.store_outlined, size: 22),
            tooltip: 'Browse ClawHub',
            onPressed: () => context.push('/skills/clawhub'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(skillsLoadedProvider);
          ref.invalidate(serverSkillsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Server-side skills (from the gateway's skills.status) go first
            // so the user sees what's actually available to their agents.
            ..._buildServerSection(ref, serverSkillsAsync),

            if (local.isNotEmpty) ...[
              _RuntimeHeader(
                label: 'On device — Local',
                count: local.length,
                color: PocketClawTheme.electricTeal,
              ),
              const SizedBox(height: 8),
              ...local.map((s) => _SkillCard(skill: s)),
              const SizedBox(height: 16),
            ],
            if (server.isNotEmpty) ...[
              _RuntimeHeader(
                label: 'On device — Server-backed',
                count: server.length,
                color: PocketClawTheme.lobsterRed,
              ),
              const SizedBox(height: 8),
              ...server.map((s) => _SkillCard(skill: s)),
              const SizedBox(height: 16),
            ],
            if (bridge.isNotEmpty) ...[
              _RuntimeHeader(
                label: 'On device — Bridge',
                count: bridge.length,
                color: PocketClawTheme.warning,
              ),
              const SizedBox(height: 8),
              ...bridge.map((s) => _SkillCard(skill: s)),
            ],

            if (skills.isEmpty && serverSkillsAsync.valueOrNull?.isEmpty != false)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: EmptyState(
                  icon: Icons.extension_off_outlined,
                  message: 'No skills available',
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildServerSection(
    WidgetRef ref,
    AsyncValue<List<ServerSkillEntry>> async,
  ) {
    final items = async.valueOrNull ?? const <ServerSkillEntry>[];
    if (items.isEmpty && !async.isLoading) return const [];
    return [
      _RuntimeHeader(
        label: 'On server',
        count: items.length,
        color: const Color(0xFF9C27B0),
      ),
      const SizedBox(height: 8),
      if (async.isLoading && items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else
        ...items.map((s) => _ServerSkillCard(entry: s)),
      const SizedBox(height: 16),
    ];
  }
}

class _ServerSkillCard extends ConsumerStatefulWidget {
  final ServerSkillEntry entry;

  const _ServerSkillCard({required this.entry});

  @override
  ConsumerState<_ServerSkillCard> createState() => _ServerSkillCardState();
}

class _ServerSkillCardState extends ConsumerState<_ServerSkillCard> {
  bool _busy = false;

  Future<void> _toggle(bool enabled) async {
    final key = widget.entry.skillKey;
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skill missing skillKey — cannot toggle')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await setServerSkillEnabled(ref, key, enabled);
      ref.invalidate(serverSkillsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toggle failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PocketClawTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  e.emoji ?? '🔧',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.name,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: e.enabled ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0).withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.source,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFBA68C8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.description,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!e.eligible || e.blockedByAllowlist) ...[
                    const SizedBox(height: 4),
                    Text(
                      e.blockedByAllowlist
                          ? 'Blocked by allowlist'
                          : 'Requirements not met',
                      style: TextStyle(
                        fontSize: 11,
                        color: PocketClawTheme.lobsterRed,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(value: e.enabled, onChanged: _toggle),
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

class _HermesSkillsView extends StatelessWidget {
  const _HermesSkillsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
        actions: const [
          AgentScopeBadge(),
          SizedBox(width: 8),
        ],
      ),
      body: const HermesSkillsTab(),
    );
  }
}
