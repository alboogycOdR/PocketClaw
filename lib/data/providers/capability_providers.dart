/// Server capability descriptors. What features the currently active
/// server actually exposes — derived statically from
/// [activeServerProvider] + SSH configuration. Used by the Hermes
/// management tabs to render a graceful "feature unavailable" card
/// instead of an infinite spinner when SSH isn't configured.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server_providers.dart';
import 'ssh_providers.dart';

class ServerCapabilities {
  final bool hasCron;
  final bool hasSessions;
  final bool hasMemory;
  final bool hasSkills;
  final bool hasAgents;
  final bool hasChannels;
  final bool hasCost;
  final bool hasLogs;
  final bool hasSsh;

  const ServerCapabilities({
    this.hasCron = false,
    this.hasSessions = false,
    this.hasMemory = false,
    this.hasSkills = false,
    this.hasAgents = false,
    this.hasChannels = false,
    this.hasCost = false,
    this.hasLogs = false,
    this.hasSsh = false,
  });

  factory ServerCapabilities.forServer(
    ActiveServer server, {
    required bool sshConfigured,
  }) {
    return switch (server) {
      ActiveServer.openclaw => const ServerCapabilities(
          hasCron: true,
          hasSessions: true,
          hasMemory: true,
          hasSkills: true,
          hasAgents: true,
          hasChannels: true,
          hasCost: true,
          // OpenClaw logs only available via SSH today
          hasLogs: false,
        ),
      ActiveServer.hermes => ServerCapabilities(
          hasCron: sshConfigured,
          hasSessions: sshConfigured,
          hasMemory: sshConfigured,
          hasSkills: sshConfigured,
          hasAgents: false,
          hasChannels: sshConfigured,
          hasCost: sshConfigured,
          hasLogs: sshConfigured,
          hasSsh: sshConfigured,
        ),
      ActiveServer.local => const ServerCapabilities(),
    };
  }

  bool operator [](String feature) => switch (feature) {
        'cron' => hasCron,
        'sessions' => hasSessions,
        'memory' => hasMemory,
        'skills' => hasSkills,
        'agents' => hasAgents,
        'channels' => hasChannels,
        'cost' => hasCost,
        'logs' => hasLogs,
        'ssh' => hasSsh,
        _ => false,
      };
}

final serverCapabilitiesProvider = Provider<ServerCapabilities>((ref) {
  final server = ref.watch(activeServerProvider);
  final sshHost = ref.watch(sshHostProvider);
  return ServerCapabilities.forServer(
    server,
    sshConfigured: sshHost.isNotEmpty,
  );
});
