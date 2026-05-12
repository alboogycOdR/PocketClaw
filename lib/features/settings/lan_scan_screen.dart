/// Scans the local /24 for Ollama, LM Studio, OpenClaw and Hermes
/// endpoints and lets the user one-tap "Use" a discovered server.
///
/// Backed by [lanDiscoveryService] (dart:io NetworkInterface +
/// batched Socket.connect probes). Only runs when on a private IP
/// (10/8, 192.168/16, 172.16/12, 100/8 for Tailscale).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/network/lan_discovery_service.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/hermes_providers.dart';

class LanScanScreen extends ConsumerStatefulWidget {
  const LanScanScreen({super.key});

  @override
  ConsumerState<LanScanScreen> createState() => _LanScanScreenState();
}

class _LanScanScreenState extends ConsumerState<LanScanScreen> {
  bool _scanning = false;
  double _progress = 0;
  String? _localIp;
  String? _error;
  List<DiscoveredServer> _results = const [];

  @override
  void initState() {
    super.initState();
    lanDiscoveryService.localIPv4().then((ip) {
      if (mounted) setState(() => _localIp = ip);
    });
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _progress = 0;
      _error = null;
      _results = const [];
    });
    try {
      final found = await lanDiscoveryService.scan(onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _results = found);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _use(DiscoveredServer s) async {
    // Apply the discovered endpoint to the right config slot.
    switch (s.type) {
      case ServerType.openclaw:
        ref.read(gatewayUrlProvider.notifier).state = s.endpoint;
        await ref
            .read(sharedPrefsProvider)
            .setString('gateway_url', s.endpoint);
        break;
      case ServerType.hermes:
        ref.read(hermesBaseUrlProvider.notifier).state = s.endpoint;
        await ref
            .read(sharedPrefsProvider)
            .setString('hermes_base_url', s.endpoint);
        break;
      case ServerType.ollama:
      case ServerType.lmstudio:
        // Not wired to a typed config yet — copy to clipboard so the
        // user can paste it into a future "Remote model" surface.
        await Clipboard.setData(ClipboardData(text: s.endpoint));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${s.endpoint} copied to clipboard')),
          );
        }
        return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.name} set as ${s.type.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan local network'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: PocketClawTheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Probes Ollama (11434), LM Studio (1234), OpenClaw '
                    '(18789) and Hermes (8642) across your /24 subnet. '
                    'Only runs on private networks (10/8, 192.168/16, '
                    '172.16/12, Tailscale 100/8).',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      height: 1.5,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localIp != null
                        ? 'Local IP: $_localIp'
                        : 'Local IP: detecting…',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: PocketClawTheme.electricTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _scanning || _localIp == null ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find_outlined, size: 18),
            label: Text(_scanning ? 'Scanning…' : 'Scan now'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          if (_scanning) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 4),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PocketClawTheme.lobsterRed.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!,
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ],
          if (!_scanning && _results.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Found ${_results.length} server${_results.length == 1 ? "" : "s"}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                letterSpacing: 0.14,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            for (final s in _results) _ResultTile(server: s, onUse: _use),
          ],
          if (!_scanning && _results.isEmpty && _error == null) ...[
            const SizedBox(height: 24),
            const Text(
              'Tap "Scan now" to look for AI servers on this WiFi.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final DiscoveredServer server;
  final Future<void> Function(DiscoveredServer) onUse;
  const _ResultTile({required this.server, required this.onUse});

  IconData _icon() => switch (server.type) {
        ServerType.openclaw => Icons.rss_feed,
        ServerType.hermes => Icons.psychology_outlined,
        ServerType.ollama => Icons.memory_outlined,
        ServerType.lmstudio => Icons.developer_board_outlined,
      };

  Color _color() => switch (server.type) {
        ServerType.openclaw => const Color(0xFFE53935),
        ServerType.hermes => const Color(0xFF7C3AED),
        ServerType.ollama => const Color(0xFF00E5CC),
        ServerType.lmstudio => const Color(0xFFFBBF24),
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_icon(), color: _color()),
        title: Text(server.name),
        subtitle: Text(
          server.endpoint,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
        trailing: FilledButton(
          onPressed: () => onUse(server),
          child: const Text('Use'),
        ),
      ),
    );
  }
}
