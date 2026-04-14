/// HuggingFace token management via secure storage
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class HFTokenService {
  static const _kTokenKey = 'hf_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> getToken() async {
    final stored = await _storage.read(key: _kTokenKey);
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  Future<void> saveToken(String token) async {
    final trimmed = token.trim();
    if (!trimmed.startsWith('hf_')) {
      throw ArgumentError(
        'Invalid HuggingFace token format. Must start with hf_',
      );
    }
    await _storage.write(key: _kTokenKey, value: trimmed);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _kTokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Validate token against HuggingFace API.
  Future<bool> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://huggingface.co/api/whoami'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
