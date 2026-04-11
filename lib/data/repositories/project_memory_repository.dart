/// Project memory repository — persists project briefs as Markdown files
/// and project tickets in sqflite.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

// ── Models ──

class Project {
  final String id;
  final String name;
  final String status;
  final String phase;
  final int budgetUsed;
  final DateTime createdAt;
  final DateTime? lastBriefUpdate;

  const Project({
    required this.id,
    required this.name,
    this.status = 'active',
    this.phase = 'planning',
    this.budgetUsed = 0,
    required this.createdAt,
    this.lastBriefUpdate,
  });

  factory Project.fromRow(Map<String, dynamic> row) {
    return Project(
      id: row['id'] as String,
      name: row['name'] as String,
      status: row['status'] as String? ?? 'active',
      phase: row['phase'] as String? ?? 'planning',
      budgetUsed: row['budget_used'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      lastBriefUpdate: row['last_brief_update'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              row['last_brief_update'] as int)
          : null,
    );
  }
}

class ProjectTicket {
  final String id;
  final String projectId;
  final String content;
  final String status;
  final DateTime createdAt;

  const ProjectTicket({
    required this.id,
    required this.projectId,
    required this.content,
    this.status = 'open',
    required this.createdAt,
  });

  factory ProjectTicket.fromRow(Map<String, dynamic> row) {
    return ProjectTicket(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      content: row['content'] as String,
      status: row['status'] as String? ?? 'open',
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }
}

// ── Abstract interface ──

abstract class ProjectMemoryRepository {
  Future<String?> loadProjectBrief(String projectId);
  Future<void> updateProjectBrief(String projectId, String brief);
  Future<List<ProjectTicket>> getRecentTickets(String projectId, {int limit});
  Future<void> saveTicket(String projectId, String content);
  Future<void> createProject(String id, String name);
  Future<List<Project>> getProjects();
}

// ── Implementation ──

class ProjectMemoryRepositoryImpl implements ProjectMemoryRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();
  Directory? _projectsDir;

  ProjectMemoryRepositoryImpl({required AppDatabase db}) : _db = db;

  /// Lazily resolve the projects storage directory.
  Future<Directory> get _storageDir async {
    if (_projectsDir != null) return _projectsDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _projectsDir = Directory(p.join(appDir.path, 'projects'));
    if (!await _projectsDir!.exists()) {
      await _projectsDir!.create(recursive: true);
    }
    return _projectsDir!;
  }

  /// Return the path for a project's brief Markdown file.
  Future<File> _briefFile(String projectId) async {
    final dir = await _storageDir;
    final projectDir = Directory(p.join(dir.path, projectId));
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    return File(p.join(projectDir.path, 'brief.md'));
  }

  @override
  Future<String?> loadProjectBrief(String projectId) async {
    try {
      final file = await _briefFile(projectId);
      if (await file.exists()) {
        return file.readAsString();
      }
      return null;
    } catch (e) {
      debugPrint('ProjectMemory: failed to load brief for $projectId: $e');
      return null;
    }
  }

  @override
  Future<void> updateProjectBrief(String projectId, String brief) async {
    try {
      final file = await _briefFile(projectId);
      await file.writeAsString(brief);

      // Update timestamp in database
      final db = await _db.getDatabase();
      await db.update(
        'projects',
        {'last_brief_update': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [projectId],
      );
    } catch (e) {
      debugPrint('ProjectMemory: failed to update brief for $projectId: $e');
      rethrow;
    }
  }

  @override
  Future<List<ProjectTicket>> getRecentTickets(
    String projectId, {
    int limit = 10,
  }) async {
    try {
      final db = await _db.getDatabase();
      final rows = await db.query(
        'project_tickets',
        where: 'project_id = ?',
        whereArgs: [projectId],
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return rows.map(ProjectTicket.fromRow).toList();
    } catch (e) {
      debugPrint('ProjectMemory: failed to get tickets for $projectId: $e');
      return [];
    }
  }

  @override
  Future<void> saveTicket(String projectId, String content) async {
    final db = await _db.getDatabase();
    await db.insert('project_tickets', {
      'id': _uuid.v4(),
      'project_id': projectId,
      'content': content,
      'status': 'open',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> createProject(String id, String name) async {
    final db = await _db.getDatabase();
    await db.insert('projects', {
      'id': id,
      'name': name,
      'status': 'active',
      'phase': 'planning',
      'budget_used': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'last_brief_update': null,
    });
  }

  @override
  Future<List<Project>> getProjects() async {
    try {
      final db = await _db.getDatabase();
      final rows =
          await db.query('projects', orderBy: 'created_at DESC');
      return rows.map(Project.fromRow).toList();
    } catch (e) {
      debugPrint('ProjectMemory: failed to get projects: $e');
      return [];
    }
  }
}
