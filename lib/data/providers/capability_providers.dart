/// HermesCommander capability descriptors.
///
/// In Hermes-only mode, the app should reason about Hermes surfaces
/// directly instead of generic multi-agent server capabilities.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hermes_providers.dart';
import 'integration_providers.dart';
import 'intelligence_providers.dart';
import 'server_providers.dart';
import 'ssh_providers.dart';
import 'tts_providers.dart';

class HermesCommanderCapabilities {
  final bool hasRest;
  final bool hasSsh;
  final bool hasAcp;
  final bool hasSessions;
  final bool hasMemory;
  final bool hasCron;
  final bool hasSkills;
  final bool hasLogs;
  final bool hasAnalytics;
  final bool hasApprovals;
  final bool hasSwarm;
  final bool hasOsiris;
  final bool hasAmbient;
  final bool hasSupertonic;
  final bool hasAgentMemory;
  final bool hasOpenNotebook;
  final bool hasAgents;
  final bool hasChannels;

  const HermesCommanderCapabilities({
    this.hasRest = false,
    this.hasSsh = false,
    this.hasAcp = false,
    this.hasSessions = false,
    this.hasMemory = false,
    this.hasCron = false,
    this.hasSkills = false,
    this.hasLogs = false,
    this.hasAnalytics = false,
    this.hasApprovals = true,
    this.hasSwarm = false,
    this.hasOsiris = false,
    this.hasAmbient = true,
    this.hasSupertonic = false,
    this.hasAgentMemory = false,
    this.hasOpenNotebook = false,
    this.hasAgents = false,
    this.hasChannels = false,
  });

  bool get hasCost => hasAnalytics;

  bool operator [](String feature) => switch (feature) {
    'rest' => hasRest,
    'ssh' => hasSsh,
    'acp' => hasAcp,
    'sessions' => hasSessions,
    'memory' => hasMemory,
    'cron' => hasCron,
    'skills' => hasSkills,
    'logs' => hasLogs,
    'analytics' => hasAnalytics,
    'cost' => hasCost,
    'approvals' => hasApprovals,
    'swarm' => hasSwarm,
    'osiris' => hasOsiris,
    'ambient' => hasAmbient,
    'supertonic' => hasSupertonic,
    'agent-memory' => hasAgentMemory,
    'notebook' => hasOpenNotebook,
    'agents' => hasAgents,
    'channels' => hasChannels,
    _ => false,
  };
}

final serverCapabilitiesProvider = Provider<HermesCommanderCapabilities>((ref) {
  final server = ref.watch(activeServerProvider);
  if (server != ActiveServer.hermes) {
    return const HermesCommanderCapabilities();
  }

  final hermesUrl = ref.watch(hermesBaseUrlProvider).trim();
  final hermesKey = ref.watch(hermesApiKeyProvider).trim();
  final sshHost = ref.watch(sshHostProvider).trim();
  final sshUser = ref.watch(sshUsernameProvider).trim();
  final supertonicReady =
      ref.watch(supertonicModelsReadyProvider).valueOrNull ?? false;
  final osirisReady = ref.watch(osirisReachableProvider).valueOrNull ?? false;
  final agentMemoryReady =
      ref.watch(agentMemoryReachableProvider).valueOrNull ?? false;
  final notebookReady =
      ref.watch(openNotebookReachableProvider).valueOrNull ?? false;

  final hasRest = hermesUrl.isNotEmpty && hermesKey.isNotEmpty;
  final hasSsh = sshHost.isNotEmpty && sshUser.isNotEmpty;
  final hasAcp = hasSsh;

  return HermesCommanderCapabilities(
    hasRest: hasRest,
    hasSsh: hasSsh,
    hasAcp: hasAcp,
    hasSessions: hasSsh,
    hasMemory: hasSsh,
    hasCron: hasSsh,
    hasSkills: hasSsh,
    hasLogs: hasSsh,
    hasAnalytics: hasSsh,
    hasApprovals: true,
    hasSwarm: hasSsh,
    hasOsiris: osirisReady,
    hasAmbient: true,
    hasSupertonic: supertonicReady,
    hasAgentMemory: agentMemoryReady,
    hasOpenNotebook: notebookReady,
  );
});
