/// Gateway REST API client for Mission Control data
library;

import 'package:dio/dio.dart';

import '../../data/models/agent.dart';
import '../../data/models/memory_note.dart';
import '../../data/models/session.dart';
import '../../data/models/skill.dart';
import '../../data/models/task.dart';
import '../../data/models/usage_stats.dart';

class GatewayRestClient {
  final Dio _dio;

  GatewayRestClient({
    required String baseUrl,
    required String authToken,
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $authToken'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  // -- Agent Management --

  Future<List<Agent>> getAgents() async {
    final res = await _dio.get<List<dynamic>>('/api/agents');
    return (res.data ?? [])
        .map((a) => Agent.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  // -- Session Management --

  Future<List<Session>> getSessions({String? agentId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/sessions',
      queryParameters: {'agentId': agentId},
    );
    return (res.data ?? [])
        .map((s) => Session.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  // -- Task / Mission Board --

  Future<List<Task>> getTasks({String? status}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/tasks',
      queryParameters: {'status': status},
    );
    return (res.data ?? [])
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Task> createTask(TaskCreate task) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/tasks',
      data: task.toJson(),
    );
    return Task.fromJson(res.data!);
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await _dio.patch<void>('/api/tasks/$taskId', data: {'status': status});
  }

  // -- Cron Jobs --

  Future<List<CronJob>> getCronJobs() async {
    final res = await _dio.get<List<dynamic>>('/api/cron');
    return (res.data ?? [])
        .map((c) => CronJob.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleCronJob(String jobId, {required bool enabled}) async {
    await _dio.patch<void>(
      '/api/cron/$jobId',
      data: {'enabled': enabled},
    );
  }

  // -- Cost Tracking --

  Future<UsageStats> getUsageStats({String? period}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/usage',
      queryParameters: {'period': period ?? 'today'},
    );
    return UsageStats.fromJson(res.data!);
  }

  // -- Memory (Server) --

  Future<List<MemoryFile>> getMemoryFiles({String? path}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/memory',
      queryParameters: {'path': path ?? '/'},
    );
    return (res.data ?? [])
        .map((m) => MemoryFile.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<String> getMemoryFileContent(String path) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/memory/content',
      queryParameters: {'path': path},
    );
    return res.data!['content'] as String;
  }

  Future<void> writeMemoryFile({
    required String path,
    required String content,
  }) async {
    await _dio.put<void>(
      '/api/memory/content',
      data: {'path': path, 'content': content},
    );
  }

  Future<void> deleteMemoryFile(String path) async {
    await _dio.delete<void>(
      '/api/memory/content',
      queryParameters: {'path': path},
    );
  }

  // -- Skills --

  Future<List<SkillInfo>> getInstalledSkills() async {
    final res = await _dio.get<List<dynamic>>('/api/skills');
    return (res.data ?? [])
        .map((s) => SkillInfo.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<void> installSkill(String slug) async {
    await _dio.post<void>('/api/skills/install', data: {'slug': slug});
  }

  // -- System Health --

  Future<SystemHealth> getSystemHealth() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/health');
    return SystemHealth.fromJson(res.data!);
  }

  void dispose() {
    _dio.close();
  }
}
