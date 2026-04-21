/// Device Identity panel — shows the current Ed25519 identity PocketClaw
/// uses to pair with the OpenClaw gateway, with a destructive Reset button
/// to regenerate on demand (next pairing must then be approved on the VPS).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/device_identity.dart';

final _deviceIdentityProvider = FutureProvider<DeviceIdentity?>((ref) async {
  return DeviceIdentity.current();
});

class DeviceIdentitySettings extends ConsumerWidget {
  const DeviceIdentitySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_deviceIdentityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Identity')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to read identity: $e',
            style: const TextStyle(color: Colors.white60),
          ),
        ),
        data: (identity) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _IntroCard(),
            const SizedBox(height: 16),
            if (identity == null)
              Card(
                margin: EdgeInsets.zero,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white54),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No device identity yet — one will be generated the '
                          'next time the app connects to the gateway.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _IdentityCard(identity: identity),
            const SizedBox(height: 16),
            _ResetButton(onReset: () => ref.invalidate(_deviceIdentityProvider)),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: PocketClawTheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key_outlined,
                    size: 16, color: PocketClawTheme.electricTeal),
                const SizedBox(width: 8),
                Text(
                  'Ed25519 pairing identity',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PocketClawTheme.electricTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This phone signs every gateway connect with a long-lived '
              'Ed25519 key. The deviceId below is the SHA-256 hex of the '
              'public key and matches what the gateway stores as the paired '
              'device.\n\n'
              'If you reset this, the phone will generate a new keypair on '
              'the next connect and you will need to re-approve it via '
              '`openclaw devices approve <deviceId>` on the VPS.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final DeviceIdentity identity;

  const _IdentityCard({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(
              label: 'Device ID',
              value: identity.deviceId,
              monospace: true,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Public key (base64url)',
              value: identity.publicKeyBase64Url,
              monospace: true,
            ),
            if (identity.createdAt != null) ...[
              const SizedBox(height: 12),
              _Field(
                label: 'Created',
                value: identity.createdAt!.toLocal().toString().split('.').first,
                monospace: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _Field({
    required this.label,
    required this.value,
    required this.monospace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        SelectableText(
          value,
          style: monospace
              ? GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.white,
                )
              : const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}

class _ResetButton extends StatefulWidget {
  final VoidCallback onReset;

  const _ResetButton({required this.onReset});

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  bool _busy = false;

  Future<void> _confirmAndReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Reset device identity?'),
        content: const Text(
          'A new Ed25519 keypair will be generated on the next connect. '
          'The gateway will reject this device until an admin approves '
          'the new pairing request via '
          '"openclaw devices approve <deviceId>" on the VPS.\n\n'
          'The current paired entry for this phone will be orphaned — you '
          'can revoke it manually on the gateway afterwards.',
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
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await DeviceIdentity.reset();
      if (mounted) {
        widget.onReset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Identity wiped. Restart the app to generate a new keypair.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _confirmAndReset,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.delete_outline, color: PocketClawTheme.lobsterRed),
      label: Text(
        'Reset device identity',
        style: TextStyle(color: PocketClawTheme.lobsterRed),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: PocketClawTheme.lobsterRed.withAlpha(100)),
      ),
    );
  }
}
