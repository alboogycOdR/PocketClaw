/// Banner shown on the chat screen when the gateway reports
/// PAIRING_REQUIRED. Surfaces the device ID so an admin can approve the
/// device via `openclaw devices approve <id>` on the gateway host, and
/// provides a manual retry.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/gateway_event.dart';
import '../../data/providers/core_providers.dart';

class PairingBanner extends ConsumerWidget {
  const PairingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gatewayStateProvider);
    if (state != GatewayState.pairingRequired) return const SizedBox.shrink();

    final client = ref.watch(gatewayClientProvider);
    final deviceId = client?.deviceIdentity?.deviceId ?? '—';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PocketClawTheme.lobsterRed.withAlpha(25),
        border: Border.all(
          color: PocketClawTheme.lobsterRed.withAlpha(120),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_clock,
                  size: 18, color: PocketClawTheme.lobsterRed),
              const SizedBox(width: 8),
              Text(
                'Waiting for pairing approval',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PocketClawTheme.lobsterRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This device is registered with your OpenClaw gateway but an '
            'administrator has not approved the pairing yet.',
            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Device ID:',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  deviceId,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                color: Colors.white54,
                tooltip: 'Copy device ID',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: deviceId == '—'
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: deviceId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Device ID copied'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'On the gateway host run:',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(120),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'openclaw devices approve '
              '${deviceId == '—' ? '<device-id>' : deviceId}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Check approval'),
              onPressed: () {
                final c = ref.read(gatewayClientProvider);
                // ignore: unawaited_futures
                c?.connect();
              },
            ),
          ),
        ],
      ),
    );
  }
}
