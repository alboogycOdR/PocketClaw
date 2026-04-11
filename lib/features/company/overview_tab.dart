/// Overview tab — company summary from Paperclip provider
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/health_bar.dart';
import '../../shared/widgets/stat_card.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);

    if (!state.isConnected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_outlined,
                  size: 64, color: PocketClawTheme.electricTeal.withAlpha(80)),
              const SizedBox(height: 16),
              Text(
                'Set Up Your AI Company',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a starter pack to create your AI team, or '
                'configure Paperclip in Settings for full company features.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/packs'),
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Choose a Starter Pack'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('Configure Paperclip manually'),
              ),
            ],
          ),
        ),
      );
    }

    final overview = state.overview;
    if (overview == null) {
      return const EmptyState(
        icon: Icons.business_outlined,
        message: 'Waiting for company data...',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Company name header
        Text(
          overview.name,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (overview.description != null) ...[
          const SizedBox(height: 4),
          Text(
            overview.description!,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
        const SizedBox(height: 20),

        // Stat cards
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.people_outline,
                title: 'Employees',
                value: '${overview.employeeCount}',
                iconColor: PocketClawTheme.electricTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.rocket_launch_outlined,
                title: 'Active Projects',
                value: '${overview.activeProjects}',
                iconColor: PocketClawTheme.lobsterRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Health score
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HealthBar(
              label: 'Organisation Health',
              percentage: overview.healthScore,
              icon: Icons.favorite_outline,
            ),
          ),
        ),
      ],
    );
  }
}
