/// Manages API keys for cloud LLM providers via secure storage
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Supported cloud API providers
enum CloudProvider { anthropic, openAI, googleAI, xai, moonshot }

class ApiKeyService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _keyFor(CloudProvider provider) => 'api_key_${provider.name}';

  Future<String?> getKey(CloudProvider provider) async {
    return _storage.read(key: _keyFor(provider));
  }

  Future<void> saveKey(CloudProvider provider, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }
    await _storage.write(key: _keyFor(provider), value: trimmed);
  }

  Future<void> deleteKey(CloudProvider provider) async {
    await _storage.delete(key: _keyFor(provider));
  }

  Future<bool> hasKey(CloudProvider provider) async {
    final key = await getKey(provider);
    return key != null && key.isNotEmpty;
  }

  /// Validate an Anthropic API key by calling the messages endpoint.
  Future<bool> validateAnthropic(String key) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}',
      );
      // 200 = valid, 401 = invalid key, anything else = likely valid key but other error
      return response.statusCode != 401;
    } catch (_) {
      return false;
    }
  }

  /// Validate an OpenAI API key.
  Future<bool> validateOpenAI(String key) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {'Authorization': 'Bearer $key'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Validate a Google AI (Gemini) API key.
  Future<bool> validateGoogleAI(String key) async {
    try {
      final response = await http.get(
        Uri.parse('https://generativelanguage.googleapis.com/v1/models?key=$key'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Validate an xAI (Grok) API key.
  Future<bool> validateXai(String key) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.x.ai/v1/models'),
        headers: {'Authorization': 'Bearer $key'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Validate a Moonshot (Kimi) API key.
  Future<bool> validateMoonshot(String key) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.moonshot.ai/v1/models'),
        headers: {'Authorization': 'Bearer $key'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Validate any provider's key.
  Future<bool> validate(CloudProvider provider, String key) {
    return switch (provider) {
      CloudProvider.anthropic => validateAnthropic(key),
      CloudProvider.openAI    => validateOpenAI(key),
      CloudProvider.googleAI  => validateGoogleAI(key),
      CloudProvider.xai       => validateXai(key),
      CloudProvider.moonshot  => validateMoonshot(key),
    };
  }

  /// Map ModelProvider enum to CloudProvider.
  static CloudProvider? providerFor(
    dynamic modelProvider,
  ) {
    final name = modelProvider.toString().split('.').last;
    return switch (name) {
      'anthropic' => CloudProvider.anthropic,
      'openAI'    => CloudProvider.openAI,
      'googleAI'  => CloudProvider.googleAI,
      'xai'       => CloudProvider.xai,
      'moonshot'  => CloudProvider.moonshot,
      _           => null,
    };
  }
}
