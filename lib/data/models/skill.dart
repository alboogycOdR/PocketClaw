/// Skill model (parsed from SKILL.md)
library;

class Skill {
  final String name;
  final String description;
  final String runtime; // local, server, bridge
  final String? emoji;
  final Map<String, dynamic> metadata;
  final String bodyPath;
  final List<String> requiredDeviceApis;
  final List<String> requiredEnv;
  final List<String> requiredBins;
  final bool disableModelInvocation;

  String? _cachedBody;

  Skill({
    required this.name,
    required this.description,
    required this.runtime,
    this.emoji,
    this.metadata = const {},
    required this.bodyPath,
    this.requiredDeviceApis = const [],
    this.requiredEnv = const [],
    this.requiredBins = const [],
    this.disableModelInvocation = false,
  });

  bool matchesInput(String input) {
    final descWords = description.toLowerCase().split(RegExp(r'[\s,.:]+'));
    final inputWords = input.toLowerCase().split(RegExp(r'\s+'));
    final matchCount = inputWords.where((w) => descWords.contains(w)).length;
    return matchCount >= 2;
  }

  String? get cachedBody => _cachedBody;
  set cachedBody(String? body) => _cachedBody = body;

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        name: json['name'] as String,
        description: json['description'] as String,
        runtime: json['runtime'] as String? ?? 'server',
        emoji: json['emoji'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
        bodyPath: json['bodyPath'] as String? ?? '',
        requiredDeviceApis:
            (json['requiredDeviceApis'] as List?)?.cast<String>() ?? [],
        requiredEnv:
            (json['requiredEnv'] as List?)?.cast<String>() ?? [],
        requiredBins:
            (json['requiredBins'] as List?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'runtime': runtime,
        'emoji': emoji,
        'metadata': metadata,
        'bodyPath': bodyPath,
        'requiredDeviceApis': requiredDeviceApis,
        'requiredEnv': requiredEnv,
        'requiredBins': requiredBins,
      };
}

class SkillInfo {
  final String name;
  final String slug;
  final String description;
  final String? emoji;
  final String runtime;
  final bool installed;

  const SkillInfo({
    required this.name,
    required this.slug,
    required this.description,
    this.emoji,
    required this.runtime,
    this.installed = false,
  });

  factory SkillInfo.fromJson(Map<String, dynamic> json) => SkillInfo(
        name: json['name'] as String,
        slug: json['slug'] as String? ?? json['name'] as String,
        description: json['description'] as String? ?? '',
        emoji: json['emoji'] as String?,
        runtime: json['runtime'] as String? ?? 'server',
        installed: json['installed'] as bool? ?? false,
      );
}

/// A server-side skill as returned by `skills.status`. The gateway groups
/// these by origin (`openclaw-bundled`, `clawhub`, `workspace`).
class ServerSkillEntry {
  final String name;
  final String description;
  final String? emoji;
  final String source;
  final bool bundled;
  final bool disabled;
  final bool eligible;
  final bool blockedByAllowlist;
  final String? skillKey;
  final String? homepage;
  final Map<String, dynamic> raw;

  const ServerSkillEntry({
    required this.name,
    required this.description,
    required this.source,
    required this.bundled,
    required this.disabled,
    required this.eligible,
    required this.blockedByAllowlist,
    required this.raw,
    this.emoji,
    this.skillKey,
    this.homepage,
  });

  bool get enabled => !disabled;

  factory ServerSkillEntry.fromJson(Map<String, dynamic> json) =>
      ServerSkillEntry(
        name: json['name'] as String? ?? '(unnamed)',
        description: json['description'] as String? ?? '',
        emoji: json['emoji'] as String?,
        source: json['source'] as String? ?? 'unknown',
        bundled: json['bundled'] == true,
        disabled: json['disabled'] == true,
        eligible: json['eligible'] != false,
        blockedByAllowlist: json['blockedByAllowlist'] == true,
        skillKey: json['skillKey'] as String?,
        homepage: json['homepage'] as String?,
        raw: json,
      );
}

/// A Claw Hub search hit from `skills.search`.
class ClawHubSearchHit {
  final String slug;
  final String displayName;
  final String? summary;
  final String? version;
  final double? score;

  const ClawHubSearchHit({
    required this.slug,
    required this.displayName,
    this.summary,
    this.version,
    this.score,
  });

  factory ClawHubSearchHit.fromJson(Map<String, dynamic> json) =>
      ClawHubSearchHit(
        slug: json['slug'] as String? ?? '',
        displayName: json['displayName'] as String? ?? json['slug'] as String? ?? '',
        summary: json['summary'] as String?,
        version: json['version'] as String?,
        score: (json['score'] as num?)?.toDouble(),
      );
}
