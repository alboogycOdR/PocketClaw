/// Hermes Agent REST client (OpenAI-compatible chat API).
///
/// API contract: SPEC-HermesIntegration-v1.0.md §2.
/// Endpoints exposed by Hermes v0.12: /v1/models, /v1/chat/completions.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'hermes_sse_parser.dart';

class HermesClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  static const String _modelId = 'hermes-agent';

  HermesClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  // ── Health / reachability ─────────────────────────────────────────────

  /// /v1/models is the only reliable health-check endpoint in Hermes v0.12
  /// (sessions/skills/cron/api-surface all 404 by design).
  Future<bool> isReachable() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/v1/models'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns the advertised model ID (always "hermes-agent" in v0.12).
  Future<String?> getModelId() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/v1/models'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as List?;
      if (data == null || data.isEmpty) return null;
      return (data.first as Map<String, dynamic>)['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Chat — non-streaming ──────────────────────────────────────────────

  Future<String> chat(
    String message, {
    List<Map<String, String>>? history,
    int maxTokens = 1024,
  }) async {
    final messages = [
      ...?history,
      {'role': 'user', 'content': message},
    ];

    final res = await _http
        .post(
          Uri.parse('$baseUrl/v1/chat/completions'),
          headers: _headers,
          body: jsonEncode({
            'model': _modelId,
            'messages': messages,
            'stream': false,
            'max_tokens': maxTokens,
          }),
        )
        .timeout(const Duration(seconds: 120));

    _checkStatus(res);

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = json['choices'] as List;
    return (choices.first['message']['content'] as String?) ?? '';
  }

  // ── Chat — streaming SSE ──────────────────────────────────────────────

  /// Returns a stream of token strings. Caller collects them to build the
  /// full response. Stream completes when `data: [DONE]` is received or
  /// the underlying HTTP body closes.
  Stream<String> chatStream(
    String message, {
    List<Map<String, String>>? history,
    int maxTokens = 1024,
  }) async* {
    final messages = [
      ...?history,
      {'role': 'user', 'content': message},
    ];

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/v1/chat/completions'),
    );
    request.headers.addAll(_headers);
    request.body = jsonEncode({
      'model': _modelId,
      'messages': messages,
      'stream': true,
      'max_tokens': maxTokens,
    });

    final response = await _http.send(request).timeout(
          const Duration(seconds: 120),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Drain body for the error message before throwing.
      final body = await response.stream.bytesToString();
      throw HermesApiException(
        statusCode: response.statusCode,
        message: body.isEmpty ? 'Stream request failed' : body,
      );
    }

    final parser = HermesSseParser();

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final token in parser.process(chunk)) {
        yield token;
      }
    }
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HermesApiException(
        statusCode: res.statusCode,
        message: res.body,
      );
    }
  }

  void dispose() => _http.close();
}

class HermesApiException implements Exception {
  final int statusCode;
  final String message;
  const HermesApiException({required this.statusCode, required this.message});
  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isRetryable => statusCode >= 500;
  @override
  String toString() => 'HermesApiException($statusCode): $message';
}
