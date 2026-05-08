/// Smart Router - classifies and routes every request
library;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/models/skill.dart';
import '../skills/skill_registry.dart';

enum RouteTarget { local, server, bridge, device, missionControl, hermes }

/// Consolidated context passed to the router for each routing decision.
class SmartRouterContext {
  final String? activeProjectId;
  final bool isNearBudgetLimit;
  final int tokenBudgetThreshold;
  final RouteTarget? overridePath;
  final int? estimatedTokens;
  final bool isLocalModelAvailable;

  /// If set, the user has chosen this path as their default. The router
  /// will honour it whenever the corresponding endpoint is reachable.
  /// Mirrors the `default_execution_path` SharedPreferences value.
  final RouteTarget? defaultPath;

  /// Whether the Hermes Agent gateway is configured + reachable. Required
  /// when [defaultPath] is [RouteTarget.hermes] so the router can fall
  /// back instead of routing into a dead endpoint.
  final bool isHermesAvailable;

  const SmartRouterContext({
    this.activeProjectId,
    this.isNearBudgetLimit = false,
    this.tokenBudgetThreshold = 4000,
    this.overridePath,
    this.estimatedTokens,
    this.isLocalModelAvailable = false,
    this.defaultPath,
    this.isHermesAvailable = false,
  });
}

/// Result of a routing decision — includes target and human-readable reason.
class RoutingDecision {
  final RouteTarget target;
  final String reason;

  const RoutingDecision({
    required this.target,
    required this.reason,
  });

  @override
  String toString() => 'RoutingDecision($target, reason: $reason)';
}

/// Privacy-sensitive keywords that should bias routing toward local processing.
const _privacyKeywords = [
  'password',
  'secret',
  'private',
  'confidential',
  'ssn',
  'social security',
  'bank account',
  'credit card',
  'medical',
  'diagnosis',
  'salary',
  'personal',
  'nda',
  'classified',
];

class SmartRouter {
  final Connectivity _connectivity;
  final SkillRegistry _skills;

  SmartRouter({
    required Connectivity connectivity,
    required SkillRegistry skills,
  })  : _connectivity = connectivity,
        _skills = skills;

  /// Route with full context — returns a [RoutingDecision] with target and reason.
  ///
  /// The [context] parameter is optional for backward compatibility.
  Future<RoutingDecision> routeWithContext(
    String input, {
    bool hasImage = false,
    SmartRouterContext context = const SmartRouterContext(),
  }) async {
    // 0. Explicit override from context
    if (context.overridePath != null) {
      return RoutingDecision(
        target: context.overridePath!,
        reason: 'User override via context',
      );
    }

    // 0a. User-chosen default execution path (e.g. "always use Hermes").
    // Only honour it when the underlying endpoint is reachable so we don't
    // route into a dead service.
    if (context.defaultPath == RouteTarget.hermes &&
        context.isHermesAvailable) {
      return const RoutingDecision(
        target: RouteTarget.hermes,
        reason: 'User default — Hermes Agent',
      );
    }

    // 1. User override prefixes
    if (input.startsWith('/local ')) {
      return const RoutingDecision(
        target: RouteTarget.local,
        reason: 'User override — /local prefix',
      );
    }
    if (input.startsWith('/server ')) {
      return const RoutingDecision(
        target: RouteTarget.server,
        reason: 'User override — /server prefix',
      );
    }
    if (input.startsWith('/mc ')) {
      return const RoutingDecision(
        target: RouteTarget.missionControl,
        reason: 'User override — /mc prefix',
      );
    }

    // 2. Device-only patterns (no LLM needed)
    if (_isDeviceOnly(input)) {
      return const RoutingDecision(
        target: RouteTarget.device,
        reason: 'Device-only command detected',
      );
    }

    // 3. Mission Control queries
    if (_isMissionControlQuery(input)) {
      return const RoutingDecision(
        target: RouteTarget.missionControl,
        reason: 'Mission Control query detected',
      );
    }

    // 4. Privacy keyword detection — prefer local to keep sensitive data on-device
    if (context.isLocalModelAvailable && _containsPrivacyKeyword(input)) {
      return const RoutingDecision(
        target: RouteTarget.local,
        reason: 'Privacy keywords detected — routing locally',
      );
    }

    // 5. Token budget check — large context goes to server
    if (context.estimatedTokens != null &&
        context.estimatedTokens! > context.tokenBudgetThreshold) {
      return const RoutingDecision(
        target: RouteTarget.server,
        reason:
            'Token budget exceeded — server path for large context',
      );
    }

    // 6. Check connectivity
    final isOnline = await _isServerReachable();

    // 7. If offline, everything goes local
    if (!isOnline) {
      return const RoutingDecision(
        target: RouteTarget.local,
        reason: 'Offline — routing locally',
      );
    }

    // 8. Check if a skill claims this input
    final matchedSkill = _skills.matchSkill(input);
    if (matchedSkill != null) {
      return RoutingDecision(
        target: _skillRuntime(matchedSkill),
        reason: 'Skill matched: ${matchedSkill.name}',
      );
    }

    // 9. Bridge pattern: device input + complex processing
    if (hasImage && _isComplexProcessing(input)) {
      return const RoutingDecision(
        target: RouteTarget.bridge,
        reason: 'Bridge — image with complex processing',
      );
    }

    // 10. Budget near limit — soft preference for local on simple tasks
    if (context.isNearBudgetLimit &&
        context.isLocalModelAvailable &&
        _isSimpleTask(input)) {
      return const RoutingDecision(
        target: RouteTarget.local,
        reason: 'Budget near limit — preferring local path',
      );
    }

    // 11. Complexity classification
    if (_isSimpleTask(input)) {
      return const RoutingDecision(
        target: RouteTarget.local,
        reason: 'Simple task — local inference',
      );
    }

    // 12. Budget near limit — even for non-simple tasks, prefer local if available
    //     (soft: complex/agentic work still goes to server)
    if (context.isNearBudgetLimit && context.isLocalModelAvailable) {
      return const RoutingDecision(
        target: RouteTarget.local,
        reason: 'Budget near limit — preferring local path',
      );
    }

    // 13. Default: route to server for best quality
    return const RoutingDecision(
      target: RouteTarget.server,
      reason: 'Default — server for best quality',
    );
  }

  /// Backward-compatible route method — returns just the [RouteTarget].
  Future<RouteTarget> route(String input, {bool hasImage = false}) async {
    final decision = await routeWithContext(input, hasImage: hasImage);
    return decision.target;
  }

  /// Strip command prefix from user input
  String stripPrefix(String input) {
    for (final prefix in ['/local ', '/server ', '/mc ']) {
      if (input.startsWith(prefix)) {
        return input.substring(prefix.length);
      }
    }
    return input;
  }

  /// Returns true if the input contains any privacy-sensitive keywords.
  bool _containsPrivacyKeyword(String input) {
    final lower = input.toLowerCase();
    return _privacyKeywords.any((kw) => lower.contains(kw));
  }

  bool _isSimpleTask(String input) {
    final simplePatterns = [
      RegExp(r'remind me', caseSensitive: false),
      RegExp(r'save.*(note|this)', caseSensitive: false),
      RegExp(r'(calculate|what.s|how much)', caseSensitive: false),
      RegExp(r'(read|show|list).*(note|memo)', caseSensitive: false),
      RegExp(r'set.*(alarm|timer)', caseSensitive: false),
      RegExp(r'(quick|simple|fast)\s', caseSensitive: false),
    ];
    return simplePatterns.any((p) => p.hasMatch(input));
  }

  bool _isDeviceOnly(String input) {
    final devicePatterns = [
      RegExp(r'^(take|snap).*(photo|picture|selfie)', caseSensitive: false),
      RegExp(r'^set alarm', caseSensitive: false),
      RegExp(r'^(start|set) timer', caseSensitive: false),
      RegExp(r'^open (camera|calendar|contacts)', caseSensitive: false),
    ];
    return devicePatterns.any((p) => p.hasMatch(input));
  }

  bool _isMissionControlQuery(String input) {
    final mcPatterns = [
      RegExp(r'(agent|agents).*(status|running|active)', caseSensitive: false),
      RegExp(r'(cost|spend|usage|tokens)', caseSensitive: false),
      RegExp(r'(cron|schedule|jobs)', caseSensitive: false),
      RegExp(r'(mission|task).*(control|board|kanban)', caseSensitive: false),
      RegExp(r'(gateway|server).*(health|status)', caseSensitive: false),
    ];
    return mcPatterns.any((p) => p.hasMatch(input));
  }

  bool _isComplexProcessing(String input) {
    final complexPatterns = [
      RegExp(r'(categoris|categoriz|classif|analys|summariz|extract)',
          caseSensitive: false),
      RegExp(r'(email|send|forward)', caseSensitive: false),
      RegExp(r'(research|report|document)', caseSensitive: false),
    ];
    return complexPatterns.any((p) => p.hasMatch(input));
  }

  RouteTarget _skillRuntime(Skill skill) {
    switch (skill.runtime) {
      case 'local':
        return RouteTarget.local;
      case 'server':
        return RouteTarget.server;
      case 'bridge':
        return RouteTarget.bridge;
      default:
        return RouteTarget.server;
    }
  }

  Future<bool> _isServerReachable() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
