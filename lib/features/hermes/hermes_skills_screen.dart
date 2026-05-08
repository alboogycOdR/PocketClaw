/// Hermes skills browser — list directories under ~/.hermes/skills/
/// and render the inner SKILL.md when tapped. SPEC-MultiTransport §11.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';

class HermesSkillsTab extends ConsumerWidget {
  const HermesSkillsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNames = ref.watch(hermesSkillNamesProvider);
    return asyncNames.when(
      data: (names) {
        if (names.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(hermesSkillNamesProvider),
            child: ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.extension_outlined,
                  message: 'No skills installed in ~/.hermes/skills/',
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(hermesSkillNamesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: names.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _SkillTile(name: names[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        message: 'Failed to list skills: $e',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(hermesSkillNamesProvider),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  final String name;
  const _SkillTile({required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(
          Icons.extension_outlined,
          color: PocketClawTheme.electricTeal,
        ),
        title: Text(
          name,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _SkillDetailScreen(name: name),
            ),
          );
        },
      ),
    );
  }
}

class _SkillDetailScreen extends ConsumerWidget {
  final String name;
  const _SkillDetailScreen({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mdAsync = ref.watch(hermesSkillMdProvider(name));
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: GoogleFonts.jetBrainsMono(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(hermesSkillMdProvider(name)),
          ),
        ],
      ),
      body: mdAsync.when(
        data: (md) {
          if (md == null || md.isEmpty) {
            return const EmptyState(
              icon: Icons.description_outlined,
              message: 'No SKILL.md in this directory',
            );
          }
          return Markdown(
            data: md,
            padding: const EdgeInsets.all(16),
            selectable: true,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to read SKILL.md: $e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(hermesSkillMdProvider(name)),
        ),
      ),
    );
  }
}
