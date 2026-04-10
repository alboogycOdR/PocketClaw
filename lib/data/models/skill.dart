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
