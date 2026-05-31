/// Scans the local subnet for AI server endpoints (Ollama, LM Studio,
/// OpenClaw gateway, Hermes). Uses `dart:io NetworkInterface` to find
/// the WiFi IPv4, derives the /24 subnet, batches TCP-connect probes
/// across all 254 hosts to avoid socket exhaustion.
library;

import 'dart:async';
import 'dart:io';

enum ServerType { ollama, lmstudio, openclaw, hermes }

class DiscoveredServer {
  final String endpoint;
  final String name;
  final ServerType type;
  const DiscoveredServer({
    required this.endpoint,
    required this.name,
    required this.type,
  });
}

class _Provider {
  final int port;
  final ServerType type;
  final String name;
  const _Provider(this.port, this.type, this.name);
}

const _kProviders = <_Provider>[
  _Provider(11434, ServerType.ollama, 'Ollama'),
  _Provider(1234, ServerType.lmstudio, 'LM Studio'),
  _Provider(18789, ServerType.openclaw, 'OpenClaw'),
  _Provider(8642, ServerType.hermes, 'Hermes'),
];

const _kTimeoutMs = 500;
const _kBatchSize = 50;
const _kBatchDelay = Duration(milliseconds: 50);

class LanDiscoveryService {
  /// Returns the device's first usable private IPv4 address, or null
  /// when on cellular / VPN with only public routes.
  Future<String?> localIPv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (_isPrivate(addr.address)) return addr.address;
        }
      }
    } catch (_) {
      // Some platforms restrict NetworkInterface.list — treat as offline.
    }
    return null;
  }

  Future<List<DiscoveredServer>> scan({
    void Function(double progress)? onProgress,
  }) async {
    final ip = await localIPv4();
    if (ip == null) return const [];

    final parts = ip.split('.');
    if (parts.length != 4) return const [];
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    final discovered = <DiscoveredServer>[];
    final seen = <String>{};
    var done = 0;
    final total = _kProviders.length * 254;

    for (final provider in _kProviders) {
      final tasks = List.generate(254, (i) {
        final target = '$subnet.${i + 1}';
        return () async {
          if (await _probe(target, provider.port)) {
            final endpoint = 'http://$target:${provider.port}';
            if (seen.add(endpoint)) {
              discovered.add(DiscoveredServer(
                endpoint: endpoint,
                name: '${provider.name} ($target)',
                type: provider.type,
              ));
            }
          }
          done++;
          if (total > 0) onProgress?.call(done / total);
        };
      });

      for (var i = 0; i < tasks.length; i += _kBatchSize) {
        final slice =
            tasks.skip(i).take(_kBatchSize).map((t) => t()).toList();
        await Future.wait(slice);
        if (i + _kBatchSize < tasks.length) {
          await Future<void>.delayed(_kBatchDelay);
        }
      }
    }

    return discovered;
  }

  Future<bool> _probe(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: _kTimeoutMs),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isPrivate(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final ints = parts.map(int.tryParse).toList();
    if (ints.any((p) => p == null)) return false;
    final p = ints.cast<int>();
    if (p[0] == 10) return true;
    if (p[0] == 192 && p[1] == 168) return true;
    if (p[0] == 172 && p[1] >= 16 && p[1] <= 31) return true;
    if (p[0] == 100) return true; // Tailscale CGNAT range
    return false;
  }
}

final lanDiscoveryService = LanDiscoveryService();
