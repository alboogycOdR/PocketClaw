/// Settings backup / restore — exports and imports a JSON snapshot of
/// the user's configured preferences. Lets a user save their setup
/// after onboarding and restore it on a fresh install (or after a
/// reset) without manually re-entering every URL, key, and toggle.
///
/// Two layers of storage:
///   - SharedPreferences (most settings: URLs, IDs, flags, strings)
///   - flutter_secure_storage (the secrets: HF token, SSH password)
///
/// Credentials are opt-in: by default the export includes only the
/// non-sensitive layer. The user must explicitly tick "Include
/// credentials" to roll up auth tokens and API keys into the file.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsBackupService {
  /// Bumped whenever the export shape changes incompatibly. Importers
  /// should refuse to apply a file with a higher version than they
  /// understand and warn on a lower version that they'll convert.
  static const int currentVersion = 1;

  /// Prefs that are always safe to round-trip — URLs, IDs, choices,
  /// per-mode session keys, mode toggles, streaks, blueprints, etc.
  static const _safePrefKeys = <String>{
    // Gateway / agent endpoints
    'gateway_url',
    'paperclip_base_url',
    'paperclip_rest_url',
    'paperclip_ws_url',
    'hermes_base_url',
    // SSH connection (host/port/username/auth-method only — password is
    // a credential and lives in secure storage)
    'ssh_host',
    'ssh_port',
    'ssh_username',
    'ssh_auth_method',
    // Models + execution
    'selected_model',
    'default_execution_path',
    // Active chat mode + per-mode session keys
    'chat_mode',
    'chat_mode_session_local',
    'chat_mode_session_openclaw',
    'chat_mode_session_hermes',
    // Academy Mode state
    'academy_mode_active',
    'academy_subject',
    'academy_level',
    'academy_streak_days',
    'academy_last_active',
    // Life Architect state
    'life_architect_active',
    'life_architect_facets',
    'life_blueprint',
    'life_architect_last_session',
    'grow_chat_mode',
    // Smart Router / project context
    'token_budget_threshold',
    'active_project_id',
    // App-level
    'onboarded',
    'biometric_lock_enabled',
    'openclaw_session_key',
  };

  /// Prefs that are sensitive — only included when the user opts in
  /// to "Include credentials" on the backup screen.
  static const _credentialPrefKeys = <String>{
    'gateway_token',
    'paperclip_api_key',
    'paperclip_token',
    'hermes_api_key',
  };

  /// Secure-storage keys that are sensitive credentials. Same opt-in
  /// gate as `_credentialPrefKeys`.
  static const _credentialSecureKeys = <String>{
    'ssh_password',
    'hf_token',
  };

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Build a JSON snapshot of the current settings. Pass
  /// [includeCredentials] = true to roll up auth tokens / API keys.
  Future<String> exportSettings({
    required bool includeCredentials,
    String? appVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final safe = <String, Object>{};
    for (final key in _safePrefKeys) {
      final v = prefs.get(key);
      if (v != null) safe[key] = v;
    }

    final creds = <String, Object>{};
    final secureCreds = <String, String>{};
    if (includeCredentials) {
      for (final key in _credentialPrefKeys) {
        final v = prefs.get(key);
        if (v != null) safe[key] = v;
        if (v != null) creds[key] = v;
      }
      for (final key in _credentialSecureKeys) {
        final v = await _secureStorage.read(key: key);
        if (v != null && v.isNotEmpty) secureCreds[key] = v;
      }
    }

    final payload = <String, dynamic>{
      'version': currentVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'includedCredentials': includeCredentials,
      'prefs': safe,
      if (includeCredentials && secureCreds.isNotEmpty)
        'secureKeys': secureCreds,
      if (includeCredentials && creds.isNotEmpty)
        'credentialPrefs': creds,
    };
    if (appVersion != null) payload['appVersion'] = appVersion;

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Parse a backup file. Returns a [BackupParseResult] which the UI
  /// uses to render the diff dialog before the user confirms.
  Future<BackupParseResult> parse(String raw) async {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return BackupParseResult.error('Not a valid backup file: $e');
    }

    final version = json['version'];
    if (version is! int) {
      return BackupParseResult.error('Missing version field.');
    }
    if (version > currentVersion) {
      return BackupParseResult.error(
        'Backup is from a newer app version ($version). Update PocketClaw '
        'and try again.',
      );
    }

    final prefs = (json['prefs'] as Map?)?.cast<String, dynamic>() ?? const {};
    final secureKeys =
        (json['secureKeys'] as Map?)?.cast<String, dynamic>() ?? const {};
    final filtered = <String, Object>{};
    for (final entry in prefs.entries) {
      if (!_safePrefKeys.contains(entry.key) &&
          !_credentialPrefKeys.contains(entry.key)) {
        // Unknown key from a future build — ignore rather than apply
        // arbitrary writes.
        continue;
      }
      final v = entry.value;
      if (v is String || v is int || v is bool || v is double) {
        filtered[entry.key] = v as Object;
      }
    }
    final filteredSecure = <String, String>{};
    for (final entry in secureKeys.entries) {
      if (!_credentialSecureKeys.contains(entry.key)) continue;
      final v = entry.value;
      if (v is String && v.isNotEmpty) filteredSecure[entry.key] = v;
    }

    return BackupParseResult.ok(
      version: version,
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? ''),
      includedCredentials: json['includedCredentials'] == true,
      prefs: filtered,
      secureKeys: filteredSecure,
    );
  }

  /// Apply a parsed backup. Writes through to both stores. Caller
  /// should restart the app afterwards so providers re-read; we just
  /// flip the prefs.
  Future<void> apply(BackupParseResult parsed) async {
    if (!parsed.ok) {
      throw StateError('Cannot apply a failed parse');
    }
    final prefs = await SharedPreferences.getInstance();
    for (final entry in parsed.prefs.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      }
    }
    for (final entry in parsed.secureKeys.entries) {
      await _secureStorage.write(key: entry.key, value: entry.value);
    }
  }
}

class BackupParseResult {
  final bool ok;
  final String? errorMessage;
  final int? version;
  final DateTime? exportedAt;
  final bool includedCredentials;
  final Map<String, Object> prefs;
  final Map<String, String> secureKeys;

  const BackupParseResult.ok({
    required this.version,
    required this.exportedAt,
    required this.includedCredentials,
    required this.prefs,
    required this.secureKeys,
  })  : ok = true,
        errorMessage = null;

  const BackupParseResult.error(this.errorMessage)
      : ok = false,
        version = null,
        exportedAt = null,
        includedCredentials = false,
        prefs = const {},
        secureKeys = const {};

  int get totalKeyCount => prefs.length + secureKeys.length;
}
