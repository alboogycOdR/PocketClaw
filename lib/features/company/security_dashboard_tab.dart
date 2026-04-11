/// Security dashboard tab — vulnerability counts, compliance, alerts
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/health_bar.dart';
import '../../shared/widgets/stat_card.dart';

class SecurityDashboardTab extends ConsumerWidget {
  const SecurityDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);

    if (!state.isConnected) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Not connected to Paperclip.',
      );
    }

    final security = state.security;
    if (security == null) {
      return const EmptyState(
        icon: Icons.shield_outlined,
        message: 'No security data available.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stat cards row
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.bug_report_outlined,
                title: 'Open Vulns',
                value: '${security.openVulnerabilities}',
                iconColor: security.openVulnerabilities > 0
                    ? PocketClawTheme.lobsterRed
                    : const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.check_circle_outline,
                title: 'Resolved (mo)',
                value: '${security.resolvedThisMonth}',
                iconColor: PocketClawTheme.electricTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Compliance score
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HealthBar(
              label: 'Compliance Score',
              percentage: security.complianceScore,
              icon: Icons.verified_user_outlined,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Recent alerts
        if (security.recentAlerts.isNotEmpty) ...[
          Text(
            'Recent Alerts',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          ...security.recentAlerts.map((alert) {
            final severityColor = _severityColor(alert.severity);
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: severityColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: severityColor.withAlpha(100),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                title: Text(
                  alert.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  alert.severity.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: severityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Color _severityColor(String severity) {
    return switch (severity) {
      'critical' => PocketClawTheme.lobsterRed,
      'high' => const Color(0xFFFF7043),
      'medium' => const Color(0xFFFFB74D),
      'low' => PocketClawTheme.electricTeal,
      _ => Colors.white54,
    };
  }
}
