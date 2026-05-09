/// Loads the local-model catalogue from JSON, with on-disk caching for
/// over-the-air catalogue updates.
///
/// Priority order:
///   1. Remote-fetched cache file (enables OTA additions of new models)
///   2. Bundled assets/model_allowlist.json (ships with each app build)
///
/// `refreshFromRemote()` runs in the background — failure is silent so the
/// bundled catalogue keeps the app working offline / on first launch.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_model_config.dart';
import '../models/model_format.dart';
import '../models/model_provider.dart';
import '../models/model_variant.dart';

class ModelAllowlistService {
  /// Public raw URL of the bundled JSON in the GitHub repo. Replacing this
  /// asset on the main branch ships an updated catalogue to all users on
  /// next launch — no app store release required.
  static const _remoteUrl =
      'https://raw.githubusercontent.com/alboogycOdR/PocketClaw/main/assets/model_allowlist.json';

  static const _cacheFileName = 'model_allowlist_cache.json';
  static const _bundledAsset = 'assets/model_allowlist.json';

  /// Load the catalogue. Cached version (if present) wins over the bundled
  /// asset. Throws if neither parses — there's no useful sane default to
  /// fall back to without a model list.
  Future<List<LocalModelConfig>> loadModels() async {
    final cached = await _loadCached();
    if (cached != null) return cached;
    return _loadBundled();
  }

  /// Try to fetch a newer catalogue and persist it for next launch.
  /// Failures are swallowed — bundled/cached version stays active.
  Future<void> refreshFromRemote() async {
    try {
      final client = HttpClient();
      try {
        final request = await client
            .getUrl(Uri.parse(_remoteUrl))
            .timeout(const Duration(seconds: 10));
        final response = await request.close();
        if (response.statusCode != 200) {
          await response.drain<void>();
          return;
        }
        final raw = await response.transform(utf8.decoder).join();
        // Parse before writing — corrupt JSON should not poison the cache.
        _parseAllowlist(raw);
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_cacheFileName');
        await file.writeAsString(raw);
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('ModelAllowlistService: remote refresh failed silently: $e');
    }
  }

  Future<List<LocalModelConfig>?> _loadCached() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      return _parseAllowlist(raw);
    } catch (e) {
      debugPrint('ModelAllowlistService: cached allowlist unreadable: $e');
      return null;
    }
  }

  Future<List<LocalModelConfig>> _loadBundled() async {
    final raw = await rootBundle.loadString(_bundledAsset);
    return _parseAllowlist(raw);
  }

  List<LocalModelConfig> _parseAllowlist(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final models = data['models'] as List<dynamic>;
    return models
        .cast<Map<String, dynamic>>()
        .map(_modelFromJson)
        .toList(growable: false);
  }

  LocalModelConfig _modelFromJson(Map<String, dynamic> json) {
    final variantsRaw = json['variants'] as List<dynamic>?;
    return LocalModelConfig(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String,
      provider: _parseProvider(json['provider'] as String?),
      hfRepo: json['hfRepo'] as String?,
      hfFilename: json['hfFilename'] as String?,
      hfCommitHash: json['hfCommitHash'] as String? ?? 'main',
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      minRamBytes: (json['minRamBytes'] as num).toInt(),
      format: _parseFormat(json['format'] as String?),
      chatTemplate: _parseChatTemplate(json['chatTemplate'] as String?),
      capabilities: (json['capabilities'] as List<dynamic>?)?.cast<String>() ??
          const [],
      requiresLicense: json['requiresLicense'] as bool? ?? false,
      licenseUrl: json['licenseUrl'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      variants: variantsRaw
          ?.cast<Map<String, dynamic>>()
          .map(_variantFromJson)
          .toList(growable: false),
    );
  }

  ModelVariant _variantFromJson(Map<String, dynamic> json) {
    return ModelVariant(
      id: json['id'] as String,
      variantLabel: json['variantLabel'] as String,
      hfFilename: json['hfFilename'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      minRamBytes: (json['minRamBytes'] as num).toInt(),
    );
  }

  ChatTemplate _parseChatTemplate(String? raw) => switch (raw) {
        'gemma' => ChatTemplate.gemma,
        'llama3' => ChatTemplate.llama3,
        'phi3' => ChatTemplate.phi3,
        'mistral' => ChatTemplate.mistral,
        _ => ChatTemplate.chatml,
      };

  ModelFormat _parseFormat(String? raw) => switch (raw) {
        'task' => ModelFormat.task,
        'cloud' => ModelFormat.cloud,
        _ => ModelFormat.gguf,
      };

  ModelProvider _parseProvider(String? raw) => switch (raw) {
        'google' => ModelProvider.google,
        'meta' => ModelProvider.meta,
        'microsoft' => ModelProvider.microsoft,
        'alibaba' => ModelProvider.alibaba,
        'apple' => ModelProvider.apple,
        'tii' => ModelProvider.tii,
        'anthropic' => ModelProvider.anthropic,
        'openAI' => ModelProvider.openAI,
        'googleAI' => ModelProvider.googleAI,
        'xai' => ModelProvider.xai,
        'moonshot' => ModelProvider.moonshot,
        _ => ModelProvider.huggingFace,
      };
}

final modelAllowlistServiceProvider = Provider<ModelAllowlistService>(
  (_) => ModelAllowlistService(),
);
