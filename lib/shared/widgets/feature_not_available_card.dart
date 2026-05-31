/// Shown in place of a management tab when the active server doesn't
/// expose that feature (e.g. Hermes without SSH configured).
///
/// Provides a contextual action button — "Configure SSH" when the gate
/// is SSH, nothing when the feature simply doesn't exist for that
/// server (Local).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/providers/capability_providers.dart';
import '../../data/providers/server_providers.dart';
import '../../features/settings/ssh_settings.dart';

class FeatureNotAvailableCard extends ConsumerWidget {
  /// Human-readable: "Sessions", "Memory", "Cron", etc.
  final String feature;

  /// Capability key: 'sessions', 'memory', etc. Used by `_resolveContext`
  /// to determine which actionable hint to show.
  final String featureKey;

  const FeatureNotAvailableCard({
    super.key,
    required this.feature,
    required this.featureKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    final caps = ref.watch(serverCapabilitiesProvider);

    final (reason, actionLabel, action) = _resolveContext(
      server: server,
      caps: caps,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              feature,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white38,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && action != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => action(context),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(actionLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PocketClawTheme.electricTeal,
                  side: BorderSide(
                      color: PocketClawTheme.electricTeal),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String reason, String? actionLabel, void Function(BuildContext)? action)
      _resolveContext({
    required ActiveServer server,
    required ServerCapabilities caps,
  }) {
    if (server == ActiveServer.hermes && !caps.hasSsh) {
      return (
        '$feature requires SSH access to your VPS.\n'
        'Configure your SSH credentials in Settings.',
        'Configure SSH',
        (ctx) => Navigator.of(ctx).push(
              MaterialPageRoute<void>(
                builder: (_) => const SshSettings(),
              ),
            ),
      );
    }

    if (server == ActiveServer.local) {
      return (
        '$feature is not available for the Local model.\n'
        'Switch to OpenClaw or Hermes for management features.',
        null,
        null,
      );
    }

    return (
      '$feature is not available for the current server.',
      null,
      null,
    );
  }
}
