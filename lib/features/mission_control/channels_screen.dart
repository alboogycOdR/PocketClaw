/// Channels screen — list configured messaging channels (WhatsApp,
/// Telegram, Discord, etc.) with status indicators and a logout action.
///
/// Backed by `channels.status` (read) + `channels.logout` (mutation). Adding
/// a new channel still requires `openclaw channels add ...` on the gateway
/// host until the per-type configure RPCs are recon'd and wired here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/channel.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/empty_state.dart';

/// Pull `channels.status` from the gateway. Result shape (per ClawX recon
/// of OpenClaw): `{channels: [{channelType, status, accounts:[...]}, ...]}`
/// or a flat list of groups. We tolerate both.
final channelsStatusProvider =
    FutureProvider<List<ChannelGroup>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return const [];
  try {
    final result = await client.request('channels.status', const {});
    if (result is! Map) return const [];
    final raw = (result['channels'] ?? result['groups'] ?? result['data']);
    final list = raw is List ? raw : <dynamic>[];
    return [
      for (final entry in list)
        if (entry is Map<String, dynamic>) ChannelGroup.fromJson(entry),
    ];
  } catch (_) {
    return const [];
  }
});

Future<void> logoutChannelAccount(
  WidgetRef ref,
  String channelType,
  String accountId,
) async {
  final client = ref.read(gatewayClientProvider);
  if (client == null) return;
  await client.request('channels.logout', {
    'channelType': channelType,
    'accountId': accountId,
  });
}

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(gatewayClientProvider);
    final async = ref.watch(channelsStatusProvider);

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Channels')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Not connected to Gateway',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(channelsStatusProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load channels:\n$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(channelsStatusProvider),
        ),
        data: (groups) => _ChannelsList(groups: groups, ref: ref),
      ),
    );
  }
}

class _ChannelsList extends StatelessWidget {
  final List<ChannelGroup> groups;
  final WidgetRef ref;

  const _ChannelsList({required this.groups, required this.ref});

  @override
  Widget build(BuildContext context) {
    // Index live groups by type so we can render a complete catalog with
    // configured/unconfigured states side-by-side.
    final byType = <ChannelType, ChannelGroup>{
      for (final g in groups) g.type: g,
    };
    final configured = ChannelType.values
        .where((t) => byType.containsKey(t) && byType[t]!.isConfigured)
        .toList();
    final available =
        ChannelType.values.where((t) => !configured.contains(t)).toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(channelsStatusProvider),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (configured.isNotEmpty) ...[
            const _SectionHeader(label: 'Connected', count: 0, hideCount: true),
            for (final t in configured)
              _ConfiguredChannelCard(group: byType[t]!),
            const SizedBox(height: 16),
          ],
          _SectionHeader(label: 'Available', count: available.length),
          for (final t in available) _AvailableChannelCard(type: t),
          const SizedBox(height: 24),
          const _AddChannelHelpCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool hideCount;

  const _SectionHeader({
    required this.label,
    required this.count,
    this.hideCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: PocketClawTheme.electricTeal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white70,
            ),
          ),
          if (!hideCount) ...[
            const SizedBox(width: 6),
            Text('· $count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.white38,
                )),
          ],
        ],
      ),
    );
  }
}

class _ConfiguredChannelCard extends ConsumerStatefulWidget {
  final ChannelGroup group;

  const _ConfiguredChannelCard({required this.group});

  @override
  ConsumerState<_ConfiguredChannelCard> createState() =>
      _ConfiguredChannelCardState();
}

class _ConfiguredChannelCardState
    extends ConsumerState<_ConfiguredChannelCard> {
  String? _busyAccountId;

  Color _statusColor(ChannelStatus s) => switch (s) {
        ChannelStatus.connected => PocketClawTheme.success,
        ChannelStatus.connecting => PocketClawTheme.warning,
        ChannelStatus.degraded => PocketClawTheme.amber,
        ChannelStatus.error => PocketClawTheme.lobsterRed,
        ChannelStatus.disconnected => Colors.white38,
      };

  Future<void> _logout(ChannelAccount account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Disconnect ${widget.group.type.displayName}?'),
        content: Text(
          'Account "${account.name}" will be logged out. Re-connecting requires running the channel setup again on the gateway host.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyAccountId = account.accountId);
    try {
      await logoutChannelAccount(
        ref,
        widget.group.type.name,
        account.accountId,
      );
      ref.invalidate(channelsStatusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disconnect failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAccountId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final color = _statusColor(g.status);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PocketClawTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(g.type.emoji,
                      style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    g.type.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    g.status.name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (g.statusReason != null && g.statusReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                g.statusReason!,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
            if (g.accounts.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final a in g.accounts)
                _AccountRow(
                  account: a,
                  busy: _busyAccountId == a.accountId,
                  statusColor: _statusColor(a.status),
                  onLogout: () => _logout(a),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final ChannelAccount account;
  final bool busy;
  final Color statusColor;
  final VoidCallback onLogout;

  const _AccountRow({
    required this.account,
    required this.busy,
    required this.statusColor,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (account.isDefault) ...[
                      const SizedBox(width: 6),
                      Text(
                        'default',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: PocketClawTheme.electricTeal,
                        ),
                      ),
                    ],
                  ],
                ),
                if (account.lastError != null && account.lastError!.isNotEmpty)
                  Text(
                    account.lastError!,
                    style: TextStyle(
                      fontSize: 10,
                      color: PocketClawTheme.lobsterRed,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton.icon(
              onPressed: onLogout,
              icon: Icon(Icons.logout,
                  size: 14, color: PocketClawTheme.lobsterRed),
              label: Text(
                'Disconnect',
                style: TextStyle(
                  fontSize: 11,
                  color: PocketClawTheme.lobsterRed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvailableChannelCard extends StatelessWidget {
  final ChannelType type;

  const _AvailableChannelCard({required this.type});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      color: PocketClawTheme.surfaceContainerLow,
      child: ListTile(
        dense: true,
        leading: Text(type.emoji, style: const TextStyle(fontSize: 20)),
        title: Text(
          type.displayName,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        subtitle: Text(
          'via ${type.connection.name.toUpperCase()}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            color: Colors.white38,
          ),
        ),
        trailing: Text(
          'Not connected',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: Colors.white38,
          ),
        ),
      ),
    );
  }
}

class _AddChannelHelpCard extends StatelessWidget {
  const _AddChannelHelpCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Colors.white60),
                const SizedBox(width: 8),
                Text(
                  'Adding a new channel',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Per-channel configuration (tokens, QR codes, OAuth flows) currently '
              'runs on the gateway host. SSH the VPS and use:',
              style: TextStyle(
                  fontSize: 12, color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                'openclaw channels add <type> --account <name>',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: PocketClawTheme.electricTeal,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'In-app configure flows (QR scan, OAuth, token paste) are coming once '
              'the per-type setup RPCs are wired.',
              style: TextStyle(
                  fontSize: 11, color: Colors.white38, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
