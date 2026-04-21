/// System-health card driven by the gateway's live `event:"health"` pings.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/usage_stats.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/health_bar.dart';

class HealthWidget extends StatelessWidget {
  final SystemHealth health;

  const HealthWidget({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final hasResourceMetrics = health.cpuPercent > 0 ||
        health.ramPercent > 0 ||
        health.diskPercent > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  health.gatewayRunning ? Icons.dns : Icons.dns_outlined,
                  size: 16,
                  color: health.gatewayRunning
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                ),
                const SizedBox(width: 8),
                Text(
                  'System Health',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: health.gatewayRunning
                        ? const Color(0xFF4CAF50).withAlpha(25)
                        : const Color(0xFFE53935).withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    health.gatewayRunning ? 'RUNNING' : 'STOPPED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: health.gatewayRunning
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE53935),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.favorite_outline,
                    size: 12, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                  'Last heartbeat ',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white38),
                ),
                Text(
                  health.lastHeartbeat.timeAgo,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            if (hasResourceMetrics) ...[
              const SizedBox(height: 16),
              HealthBar(
                label: 'CPU',
                percentage: health.cpuPercent,
                icon: Icons.memory,
              ),
              const SizedBox(height: 12),
              HealthBar(
                label: 'RAM',
                percentage: health.ramPercent,
                icon: Icons.storage,
              ),
              const SizedBox(height: 12),
              HealthBar(
                label: 'Disk',
                percentage: health.diskPercent,
                icon: Icons.disc_full_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
