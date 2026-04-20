/// Warning banner shown on the chat screen when the user is on OpenClaw
/// mode but the gateway isn't connected — so they see the problem before
/// they type, not 10 seconds after they hit send.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/chat/chat_mode.dart';
import '../../data/models/gateway_event.dart';
import '../../data/providers/chat_mode_providers.dart';
import '../../data/providers/core_providers.dart';

class GatewayDownBanner extends ConsumerWidget {
  const GatewayDownBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gatewayStateProvider);
    final mode = ref.watch(chatModeProvider);

    // Only show when the user has chosen the server-routed mode and the
    // gateway is in a state that WILL drop their next message on the
    // floor. pairingRequired has its own dedicated banner; connected is
    // fine; connecting is transient — keep the noise floor low.
    final mattersHere = mode == ChatMode.openclaw &&
        (state == GatewayState.disconnected ||
            state == GatewayState.error ||
            state == GatewayState.reconnecting);
    if (!mattersHere) return const SizedBox.shrink();

    final (label, detail) = switch (state) {
      GatewayState.reconnecting => (
        'Reconnecting to OpenClaw…',
        'Messages sent now may be delayed or dropped.',
      ),
      GatewayState.error => (
        'Gateway error',
        'Can\'t reach the OpenClaw gateway. Check Tailscale / VPN.',
      ),
      _ => (
        'Gateway offline',
        'Not connected to OpenClaw. Check that Tailscale is on and the '
            'gateway is reachable.',
      ),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74D).withAlpha(25),
        border: Border.all(color: const Color(0xFFFFB74D).withAlpha(120)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Color(0xFFFFB74D)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFB74D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              final c = ref.read(gatewayClientProvider);
              // ignore: unawaited_futures
              c?.connect();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
