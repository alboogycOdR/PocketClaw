/// Hermes Channels tab — lists the four inbound channels (Telegram /
/// Discord / Slack / WhatsApp) with a token-present badge and a
/// "configured / unconfigured" summary. Tap a row to edit the channel's
/// settings (token stays in .env, untouched by the app).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_channel.dart';
import '../../data/providers/channels_providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'hermes_channel_detail_screen.dart';

class HermesChannelsTab extends ConsumerWidget {
  const HermesChannelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hermesChannelsProvider);

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load channels: $e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(hermesChannelsProvider),
        ),
        data: (bundle) {
          if (bundle.channels.isEmpty) {
            return const EmptyState(
              icon: Icons.podcasts_outlined,
              message:
                  'No channels in config.yaml.\nAdd `telegram: / discord:` blocks server-side, then refresh.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(hermesChannelsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: bundle.channels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ChannelTile(channel: bundle.channels[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final HermesChannelConfig channel;
  const _ChannelTile({required this.channel});

  IconData get _icon => switch (channel.kind) {
        HermesChannelKind.telegram => Icons.send,
        HermesChannelKind.discord => Icons.chat_bubble_outline,
        HermesChannelKind.slack => Icons.tag,
        HermesChannelKind.whatsapp => Icons.phone_in_talk_outlined,
      };

  Color get _color => switch (channel.kind) {
        HermesChannelKind.telegram => const Color(0xFF26A5E4),
        HermesChannelKind.discord => const Color(0xFF5865F2),
        HermesChannelKind.slack => const Color(0xFF4A154B),
        HermesChannelKind.whatsapp => const Color(0xFF25D366),
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HermesChannelDetailScreen(kind: channel.kind),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(_icon, color: _color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.kind.displayName,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.isConfigured
                          ? '${channel.settings.length} setting'
                              '${channel.settings.length == 1 ? "" : "s"} · configured'
                          : 'Scaffold present · no settings filled',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              _TokenBadge(present: channel.tokenPresent),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenBadge extends StatelessWidget {
  final bool present;
  const _TokenBadge({required this.present});

  @override
  Widget build(BuildContext context) {
    final color = present
        ? PocketClawTheme.success
        : PocketClawTheme.onSurfaceMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            present ? Icons.vpn_key : Icons.vpn_key_off_outlined,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            present ? 'token' : 'no token',
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
