/// Loads, deduplicates, and queries skills from multiple sources
library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../data/models/skill.dart';
import 'skill_parser.dart';

class SkillRegistry {
  /// Bundled asset skill file names (relative to assets/skills/).
  static const _bundledSkillFiles = [
    'notes.md',
    'calculator.md',
    'forex-calc.md',
    'reminder.md',
    'solo-founder.md',
    'enterprise-it.md',
    'academy-tutor.md',
    'life-architect.md',
    'forex-starter.md',
  ];

  /// All registered skills keyed by name. Later sources overwrite earlier ones.
  final Map<String, Skill> _skills = {};

  /// Unmodifiable view of all currently loaded skills.
  List<Skill> get skills => List.unmodifiable(_skills.values);

  /// Loads skills from all three sources in order so that later sources win:
  ///   1. Bundled assets  (assets/skills/*.md)
  ///   2. Downloaded skills directory
  ///   3. User-created skills directory
  Future<void> loadAll() async {
    _skills.clear();

    // 1. Bundled assets
    await _loadBundledSkills();

    // 2 & 3. On-device directories
    final appDir = await getApplicationDocumentsDirectory();
    final downloadedDir = Directory('${appDir.path}/skills/downloaded');
    final userDir = Directory('${appDir.path}/skills/user');

    await _loadDirectorySkills(downloadedDir);
    await _loadDirectorySkills(userDir);
  }

  // ---------------------------------------------------------------------------
  // Source loaders
  // ---------------------------------------------------------------------------

  Future<void> _loadBundledSkills() async {
    for (final filename in _bundledSkillFiles) {
      try {
        final raw = await rootBundle.loadString('assets/skills/$filename');
        final parsed =
            SkillParser.parse(raw, sourcePath: 'assets/skills/$filename');
        final skill = parsed.skill;
        skill.cachedBody = parsed.body;
        _skills[skill.name] = skill;
      } catch (e) {
        // Bundled skill failed to parse — skip but log.
        // In production replace with proper logger.
        // ignore: avoid_print
        print('[SkillRegistry] Failed to load bundled skill $filename: $e');
      }
    }
  }

  Future<void> _loadDirectorySkills(Directory dir) async {
    if (!dir.existsSync()) return;

    final entries = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'));

    for (final file in entries) {
      try {
        final raw = await file.readAsString();
        final parsed = SkillParser.parse(raw, sourcePath: file.path);
        final skill = parsed.skill;
        skill.cachedBody = parsed.body;
        _skills[skill.name] = skill; // dedup: later wins
      } catch (e) {
        print('[SkillRegistry] Failed to load ${file.path}: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Query API
  // ---------------------------------------------------------------------------

  /// Returns the best matching skill for [input], or `null` if none match.
  Skill? matchSkill(String input) {
    // Check for exact slash-command match first (e.g. "/notes")
    final slashMatch = RegExp(r'^/(\S+)').firstMatch(input.trim());
    if (slashMatch != null) {
      final command = slashMatch.group(1)!.toLowerCase();
      for (final skill in _skills.values) {
        if (skill.name.toLowerCase() == command) return skill;
      }
    }

    // Fall back to the model's own matchesInput heuristic, picking the skill
    // with the most keyword overlap.
    Skill? best;
    int bestScore = 0;
    final inputWords = input.toLowerCase().split(RegExp(r'\s+'));

    for (final skill in _skills.values) {
      final descWords =
          skill.description.toLowerCase().split(RegExp(r'[\s,.:]+'));
      final score = inputWords.where((w) => descWords.contains(w)).length;
      if (score >= 2 && score > bestScore) {
        bestScore = score;
        best = skill;
      }
    }
    return best;
  }

  /// Returns all skills matching [input] (may be empty).
  List<Skill> matchSkills(String input) {
    return _skills.values.where((s) => s.matchesInput(input)).toList();
  }

  /// Formats every registered skill into a concise prompt block that can be
  /// injected into the system prompt of the LLM.
  String formatForPrompt() {
    if (_skills.isEmpty) return '';

    final buffer = StringBuffer('Available skills:\n');
    for (final skill in _skills.values) {
      final icon = skill.emoji != null ? '${skill.emoji} ' : '';
      buffer.writeln(
          '- $icon${skill.name} [${skill.runtime}]: ${skill.description}');
    }
    return buffer.toString();
  }

  /// Retrieves a single skill by [name], or `null`.
  Skill? getSkill(String name) => _skills[name];

  /// Ensures the user-created skills directory exists and returns its path.
  Future<Directory> getUserSkillsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/skills/user');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ensures the downloaded skills directory exists and returns its path.
  Future<Directory> getDownloadedSkillsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/skills/downloaded');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
