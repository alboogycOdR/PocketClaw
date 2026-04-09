/// Parses SKILL.md files (YAML frontmatter + Markdown body)
library;

import 'package:yaml/yaml.dart';

import '../../data/models/skill.dart';

/// Result of parsing a SKILL.md file.
class ParsedSkill {
  final Skill skill;
  final String body;

  const ParsedSkill({required this.skill, required this.body});
}

class SkillParser {
  /// Regex to extract YAML frontmatter delimited by `---`.
  static final _frontmatterPattern = RegExp(
    r'^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)',
    multiLine: true,
  );

  /// Parses raw SKILL.md content into a [ParsedSkill].
  ///
  /// [sourcePath] is the logical path used for [Skill.bodyPath].
  static ParsedSkill parse(String raw, {required String sourcePath}) {
    final match = _frontmatterPattern.firstMatch(raw.trimLeft());
    if (match == null) {
      throw FormatException(
        'SKILL.md at $sourcePath is missing YAML frontmatter (---) delimiters',
      );
    }

    final yamlString = match.group(1)!;
    final body = match.group(2)!.trim();

    final dynamic yamlDoc = loadYaml(yamlString);
    if (yamlDoc is! YamlMap && yamlDoc is! Map) {
      throw FormatException(
        'SKILL.md frontmatter at $sourcePath is not a valid YAML map',
      );
    }

    final Map<String, dynamic> front = _yamlToMap(yamlDoc as YamlMap);

    final name = front['name'] as String? ?? _inferName(sourcePath);
    final description = front['description'] as String? ?? '';
    final emoji = front['emoji'] as String?;

    // Extract metadata (may be nested)
    final metadata = front['metadata'] as Map<String, dynamic>? ?? {};

    // Resolve runtime from metadata.pocketclaw.runtime or top-level
    final pocketclaw = _nestedMap(metadata, 'pocketclaw');
    final runtime = pocketclaw['runtime'] as String? ??
        front['runtime'] as String? ??
        'server';

    // Resolve requires from metadata.pocketclaw.requires
    final requires = _nestedMap(pocketclaw, 'requires');
    final deviceApis = _stringList(requires['device_apis']);
    final env = _stringList(requires['env']);
    final bins = _stringList(requires['bins']);

    final disableModel =
        pocketclaw['disable_model_invocation'] as bool? ?? false;

    final skill = Skill(
      name: name,
      description: description,
      runtime: runtime,
      emoji: emoji,
      metadata: metadata,
      bodyPath: sourcePath,
      requiredDeviceApis: deviceApis,
      requiredEnv: env,
      requiredBins: bins,
      disableModelInvocation: disableModel,
    );

    return ParsedSkill(skill: skill, body: body);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Recursively converts a [YamlMap] into a plain [Map<String, dynamic>].
  static Map<String, dynamic> _yamlToMap(YamlMap yamlMap) {
    final result = <String, dynamic>{};
    for (final entry in yamlMap.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is YamlMap) {
        result[key] = _yamlToMap(value);
      } else if (value is YamlList) {
        result[key] = _yamlToList(value);
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  static List<dynamic> _yamlToList(YamlList yamlList) {
    return yamlList.map((item) {
      if (item is YamlMap) return _yamlToMap(item);
      if (item is YamlList) return _yamlToList(item);
      return item;
    }).toList();
  }

  /// Safely drills into a nested map returning an empty map on miss.
  static Map<String, dynamic> _nestedMap(
      Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    return {};
  }

  /// Converts a dynamic value to a `List<String>`.
  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) return [value];
    return [];
  }

  /// Infers a skill name from its file path.
  static String _inferName(String path) {
    final filename = path.split('/').last.split('\\').last;
    return filename.replaceAll(RegExp(r'\.(md|skill)$', caseSensitive: false), '');
  }
}
