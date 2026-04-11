/// Overview tab — company summary from Paperclip provider
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Not connected to Paperclip.\n'
            'Configure your gateway in Settings to see company data.',
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
