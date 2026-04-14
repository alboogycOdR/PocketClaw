/// Gateway REST API client for Mission Control data
library;

import 'package:dio/dio.dart';

import '../../data/models/agent.dart';
import '../../data/models/memory_note.dart';
import '../../data/models/session.dart';
import '../../data/models/skill.dart';
import '../../data/models/task.dart';
import '../../data/models/usage_stats.dart';

// OpenClaw exposes its HTTP API under this prefix (the bare `/api/*` paths
// return the SPA's index.html and caused silent 404s / Dio timeouts).
const String _apiPrefix = '/__openclaw__/api';

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
    final res = await _dio.get<List<dynamic>>('$_apiPrefix/agents');
    return (res.data ?? [])
        .map((a) => Agent.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  // -- Session Management --

  Future<List<Session>> getSessions({String? agentId}) async {
    final res = await _dio.get<List<dynamic>>(
      '$_apiPrefix/sessions',
      queryParameters: {'agentId': agentId},
    );
    return (res.data ?? [])
        .map((s) => Session.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  // -- Task / Mission Board --

  Future<List<Task>> getTasks({String? status}) async {
    final res = await _dio.get<List<dynamic>>(
      '$_apiPrefix/tasks',
      queryParameters: {'status': status},
    );
    return (res.data ?? [])
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Task> createTask(TaskCreate task) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_apiPrefix/tasks',
      data: task.toJson(),
    );
    return Task.fromJson(res.data!);
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await _dio.patch<void>('$_apiPrefix/tasks/$taskId', data: {'status': status});
  }

  // -- Cron Jobs --

  Future<List<CronJob>> getCronJobs() async {
    final res = await _dio.get<List<dynamic>>('$_apiPrefix/cron');
    return (res.data ?? [])
        .map((c) => CronJob.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleCronJob(String jobId, {required bool enabled}) async {
    await _dio.patch<void>(
      '$_apiPrefix/cron/$jobId',
      data: {'enabled': enabled},
    );
  }

  // -- Cost Tracking --

  Future<UsageStats> getUsageStats({String? period}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_apiPrefix/usage',
      queryParameters: {'period': period ?? 'today'},
    );
    return UsageStats.fromJson(res.data!);
  }

  // -- Memory (Server) --

  Future<List<MemoryFile>> getMemoryFiles({String? path}) async {
    final res = await _dio.get<List<dynamic>>(
      '$_apiPrefix/memory',
      queryParameters: {'path': path ?? '/'},
    );
    return (res.data ?? [])
        .map((m) => MemoryFile.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<String> getMemoryFileContent(String path) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_apiPrefix/memory/content',
      queryParameters: {'path': path},
    );
    return res.data!['content'] as String;
  }

  Future<void> writeMemoryFile({
    required String path,
    required String content,
  }) async {
    await _dio.put<void>(
      '$_apiPrefix/memory/content',
      data: {'path': path, 'content': content},
    );
  }

  Future<void> deleteMemoryFile(String path) async {
    await _dio.delete<void>(
      '$_apiPrefix/memory/content',
      queryParameters: {'path': path},
    );
  }

  // -- Skills --

  Future<List<SkillInfo>> getInstalledSkills() async {
    final res = await _dio.get<List<dynamic>>('$_apiPrefix/skills');
    return (res.data ?? [])
        .map((s) => SkillInfo.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<void> installSkill(String slug) async {
    await _dio.post<void>('$_apiPrefix/skills/install', data: {'slug': slug});
  }

  // -- System Health --

  Future<SystemHealth> getSystemHealth() async {
    final res = await _dio.get<Map<String, dynamic>>('$_apiPrefix/health');
    return SystemHealth.fromJson(res.data!);
  }

  void dispose() {
    _dio.close();
  }
}

/// Map a Dio/network failure into a short, user-facing message.
String friendlyGatewayError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Can't reach the gateway — it may be offline.";
      case DioExceptionType.connectionError:
        return 'No connection to the gateway. Check the URL or your network.';
      case DioExceptionType.badCertificate:
        return 'Gateway TLS certificate rejected.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 401 || code == 403) return 'Gateway auth token rejected.';
        if (code == 404) return 'Gateway endpoint not found — server version mismatch.';
        return 'Gateway returned HTTP $code.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.unknown:
        return 'Gateway unreachable.';
    }
  }
  return 'Gateway error.';
}
