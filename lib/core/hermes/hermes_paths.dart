/// Canonical filesystem paths for a Hermes installation at ~/.hermes.
/// Translated from Scarf's HermesPathSet.swift; verified against the
/// live VPS layout. SPEC-MultiTransport §6.
library;

class HermesPaths {
  final String home;

  const HermesPaths({this.home = '~/.hermes'});

  // Core
  String get stateDB => '$home/state.db';
  String get configYAML => '$home/config.yaml';
  String get envFile => '$home/.env';
  String get gatewayStateJSON => '$home/gateway_state.json';

  // Memory
  String get memoriesDir => '$home/memories';
  String get memoryMD => '$memoriesDir/MEMORY.md';
  String get userMD => '$memoriesDir/USER.md';
  String get soulMD => '$home/SOUL.md';

  // Cron
  String get cronJobsJSON => '$home/cron/jobs.json';
  String get cronOutputDir => '$home/cron/output';

  // Skills
  String get skillsDir => '$home/skills';

  // Logs
  String get errorsLog => '$home/logs/errors.log';
  String get gatewayLog => '$home/logs/gateway.log';
  String get agentLog => '$home/logs/agent.log';
}

const kHermesPaths = HermesPaths();

/// Default character limits for Hermes memory files (from Scarf analysis;
/// matches the v0.12 config.yaml defaults). Used as fallbacks until we
/// read the live config from the VPS.
class HermesMemoryLimits {
  static const int memoryMd = 2200;
  static const int userMd = 1375;
  // SOUL has no documented hard limit; use a generous cap.
  static const int soulMd = 8000;
}
