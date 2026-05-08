/// Devices management — list paired + pending devices, approve or revoke
/// from the phone instead of having to SSH into the VPS for
/// `openclaw devices …`. SPEC-OpenClaw-Improvements §4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/gateway_client.dart';
import '../../core/openclaw/openclaw_ssh_service.dart';
import '../../data/models/openclaw_device.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/ssh_providers.dart';
import '../../shared/widgets/empty_state.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(gatewayClientProvider);
    final devicesAsync = ref.watch(openClawDevicesProvider);

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paired Devices')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Gateway not configured',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paired Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(openClawDevicesProvider),
          ),
        ],
      ),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(openClawDevicesProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.devices_other,
                    message: 'No devices known to the gateway',
                  ),
                ],
              ),
            );
          }
          final pending = devices.where((d) => d.isPending).toList();
          final paired = devices.where((d) => d.isPaired).toList();
          final revoked = devices.where((d) => d.isRevoked).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(openClawDevicesProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'PENDING APPROVAL',
                    count: pending.length,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  for (final d in pending) ...[
                    _DeviceCard(
                      device: d,
                      onApprove: () => _approve(context, ref, d),
                      onRevoke: () => _revoke(context, ref, d),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                ],
                if (paired.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'PAIRED DEVICES',
                    count: paired.length,
                    color: PocketClawTheme.electricTeal,
                  ),
                  const SizedBox(height: 8),
                  for (final d in paired) ...[
                    _DeviceCard(
                      device: d,
                      onRevoke: d.isCurrentDevice
                          ? null
                          : () => _revoke(context, ref, d),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                ],
                if (revoked.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'REVOKED',
                    count: revoked.length,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 8),
                  for (final d in revoked) ...[
                    _DeviceCard(device: d),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load devices: $e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(openClawDevicesProvider),
        ),
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    OpenClawDevice device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve device?'),
        content: Text(
          'Approve "${device.name ?? device.id}" to access this gateway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _runWsThenSsh(
        ref,
        ws: (c) => c.approveDevice(device.id),
        ssh: (s) => s.approveDevice(device.id),
      );
      ref.invalidate(openClawDevicesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approved ${device.name ?? device.id}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approve failed: $e')),
        );
      }
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    OpenClawDevice device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke device?'),
        content: Text(
          'Revoke "${device.name ?? device.id}"? The device will be '
          'disconnected and must re-pair to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _runWsThenSsh(
        ref,
        ws: (c) => c.revokeDevice(device.id),
        ssh: (s) => s.revokeDevice(device.id),
      );
      ref.invalidate(openClawDevicesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoked ${device.name ?? device.id}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoke failed: $e')),
        );
      }
    }
  }

  /// Run a device mutation through WS first; if the gateway version
  /// doesn't expose `devices.*` (silent timeout) fall back to the
  /// SSH-exec'd CLI. Either path acks success the same way.
  Future<void> _runWsThenSsh(
    WidgetRef ref, {
    required Future<void> Function(GatewayClient) ws,
    required Future<void> Function(OpenClawSshService) ssh,
  }) async {
    final client = ref.read(gatewayClientProvider);
    if (client != null) {
      try {
        await ws(client).timeout(const Duration(seconds: 5));
        return;
      } catch (_) {
        // fall through to SSH
      }
    }
    final svc = await ref.read(openClawSshServiceProvider.future);
    if (svc == null) {
      throw Exception(
        'Gateway WS rejected the operation and SSH is not configured. '
        'Settings → Connection → Server SSH.',
      );
    }
    await ssh(svc);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final OpenClawDevice device;
  final VoidCallback? onApprove;
  final VoidCallback? onRevoke;
  const _DeviceCard({
    required this.device,
    this.onApprove,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = StringBuffer();
    if (device.publicKey != null && device.publicKey!.isNotEmpty) {
      final key = device.publicKey!;
      subtitle.write(key.length > 12 ? '${key.substring(0, 12)}…' : key);
    } else if (device.id.isNotEmpty) {
      final id = device.id;
      subtitle.write(id.length > 12 ? '${id.substring(0, 12)}…' : id);
    }
    final age = device.isPending
        ? _ago(device.lastSeenAt ?? device.pairedAt, prefix: 'Requested')
        : _ago(device.lastSeenAt, prefix: 'Last seen') ??
            _ago(device.pairedAt, prefix: 'Paired');
    if (age != null) {
      if (subtitle.isNotEmpty) subtitle.write('  ·  ');
      subtitle.write(age);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForDevice(device),
                  size: 18,
                  color: device.isCurrentDevice
                      ? PocketClawTheme.electricTeal
                      : Colors.white70,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    device.name ?? 'Unnamed device',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (device.isCurrentDevice)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: PocketClawTheme.electricTeal.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'current',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: PocketClawTheme.electricTeal,
                      ),
                    ),
                  ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle.toString(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ],
            if (onApprove != null || onRevoke != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onApprove != null)
                    FilledButton.tonalIcon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                    ),
                  if (onApprove != null && onRevoke != null)
                    const SizedBox(width: 8),
                  if (onRevoke != null)
                    OutlinedButton.icon(
                      onPressed: onRevoke,
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Revoke'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PocketClawTheme.lobsterRed,
                        side: const BorderSide(
                          color: PocketClawTheme.lobsterRed,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _iconForDevice(OpenClawDevice d) {
  final n = (d.name ?? '').toLowerCase();
  if (n.contains('iphone') || n.contains('android') || n.contains('phone')) {
    return Icons.phone_android;
  }
  if (n.contains('ipad') || n.contains('tablet')) return Icons.tablet_mac;
  if (n.contains('mac') ||
      n.contains('laptop') ||
      n.contains('desktop') ||
      n.contains('linux') ||
      n.contains('windows')) {
    return Icons.laptop_mac;
  }
  return Icons.devices_other;
}

String? _ago(DateTime? t, {required String prefix}) {
  if (t == null) return null;
  final diff = DateTime.now().difference(t);
  if (diff.inDays > 0) return '$prefix ${diff.inDays}d ago';
  if (diff.inHours > 0) return '$prefix ${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '$prefix ${diff.inMinutes}m ago';
  return '$prefix just now';
}
