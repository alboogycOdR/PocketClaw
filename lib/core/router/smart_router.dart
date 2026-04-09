/// Smart Router - classifies and routes every request
library;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/models/skill.dart';
import '../skills/skill_registry.dart';

enum RouteTarget { local, server, bridge, device, missionControl }

class SmartRouter {
  final Connectivity _connectivity;
  final SkillRegistry _skills;

  SmartRouter({
    required Connectivity connectivity,
    required SkillRegistry skills,
  })  : _connectivity = connectivity,
        _skills = skills;

  Future<RouteTarget> route(String input, {bool hasImage = false}) async {
    // 1. User override prefixes
    if (input.startsWith('/local ')) return RouteTarget.local;
    if (input.startsWith('/server ')) return RouteTarget.server;
    if (input.startsWith('/mc ')) return RouteTarget.missionControl;

    // 2. Device-only patterns (no LLM needed)
    if (_isDeviceOnly(input)) return RouteTarget.device;

    // 3. Mission Control queries
    if (_isMissionControlQuery(input)) return RouteTarget.missionControl;

    // 4. Check connectivity
    final isOnline = await _isServerReachable();

    // 5. If offline, everything goes local
    if (!isOnline) return RouteTarget.local;

    // 6. Check if a skill claims this input
    final matchedSkill = _skills.matchSkill(input);
    if (matchedSkill != null) {
      return _skillRuntime(matchedSkill);
    }

    // 7. Bridge pattern: device input + complex processing
    if (hasImage && _isComplexProcessing(input)) {
      return RouteTarget.bridge;
    }

    // 8. Complexity classification
    if (_isSimpleTask(input)) return RouteTarget.local;

    // 9. Default: route to server for best quality
    return RouteTarget.server;
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
