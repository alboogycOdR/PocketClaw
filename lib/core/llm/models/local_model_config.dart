/// Model configuration — supports local (task/gguf) and cloud API models.
///
/// Sizes are stored in bytes (`sizeBytes`, `minRamBytes`) so that the JSON
/// allowlist (assets/model_allowlist.json) is the single source of truth and
/// integer math stays exact. `sizeGB` / `ramMB` / `minRamGB` are display-only
/// derived getters kept for backwards compatibility with existing UI strings.
library;

import 'model_format.dart';
import 'model_provider.dart';
import 'model_variant.dart';

/// Prompt formatting dialect for local instruct models.
///
/// fllama emits raw token streams; the Dart side formats the prompt with the
/// per-model template before calling completion. Picking the wrong template
/// produces garbled output (e.g. Gemma echoing its own role headers).
enum ChatTemplate { chatml, gemma, llama3, phi3, mistral }

class LocalModelConfig {
  final String id;
  final String displayName;
  final String description;

  /// On-disk file size in bytes. 0 for cloud models.
  final int sizeBytes;

  /// Minimum device RAM required to run, in bytes. 0 for cloud models.
  final int minRamBytes;

  final ModelFormat format;
  final ModelProvider provider;
  final String? hfRepo;
  final String? hfFilename;

  /// HuggingFace commit hash (or branch name) to pin the download to.
  /// Defaults to "main". Storing this lets us detect new versions and pin
  /// downloaded files to the exact bytes we expect.
  final String hfCommitHash;

  final ChatTemplate chatTemplate;
  final bool requiresLicense;
  final String? licenseUrl;
  final List<String> capabilities;

  /// Display tags such as "recommended" / "new". Drives badge rendering.
  final List<String> tags;

  /// Alternate downloadable variants (e.g. Q4 vs Q8 of the same base model).
  /// `null` means there is only the primary variant.
  final List<ModelVariant>? variants;

  final bool isBeta;

  // -- Cloud API fields ------------------------------------------------------
  final String? cloudApiEndpoint;
  final String? cloudModelId;
  final String? cloudApiKeyPrefix;

  const LocalModelConfig({
    required this.id,
    required this.displayName,
    required this.description,
    required this.sizeBytes,
    required this.minRamBytes,
    required this.format,
    required this.provider,
    this.hfRepo,
    this.hfFilename,
    this.hfCommitHash = 'main',
    this.chatTemplate = ChatTemplate.chatml,
    this.requiresLicense = false,
    this.licenseUrl,
    this.capabilities = const [],
    this.tags = const [],
    this.variants,
    this.isBeta = false,
    this.cloudApiEndpoint,
    this.cloudModelId,
    this.cloudApiKeyPrefix,
  });

  bool get isCloud => format == ModelFormat.cloud;
  bool get isLocal => format != ModelFormat.cloud;

  /// File size in GB (display only).
  double get sizeGB => sizeBytes / (1024 * 1024 * 1024);

  /// RAM requirement in MB (display only, kept for compat with old UI).
  int get ramMB => (minRamBytes / (1024 * 1024)).round();

  /// RAM requirement in GB (display only).
  double get minRamGB => minRamBytes / (1024 * 1024 * 1024);

  /// HuggingFace download URL pinned to `hfCommitHash`. Throws for cloud
  /// models or anything missing repo/filename — only the GGUF download path
  /// should ever read this.
  String get downloadUrl {
    if (hfRepo == null || hfFilename == null) {
      throw StateError(
        'Model $id has no hfRepo/hfFilename — cannot build download URL',
      );
    }
    return 'https://huggingface.co/$hfRepo'
        '/resolve/$hfCommitHash'
        '/$hfFilename'
        '?download=true';
  }

  /// Returns a copy of this config with the given overrides.
  LocalModelConfig copyWith({
    String? cloudModelId,
    String? cloudApiEndpoint,
  }) {
    return LocalModelConfig(
      id: id,
      displayName: displayName,
      description: description,
      sizeBytes: sizeBytes,
      minRamBytes: minRamBytes,
      format: format,
      provider: provider,
      hfRepo: hfRepo,
      hfFilename: hfFilename,
      hfCommitHash: hfCommitHash,
      chatTemplate: chatTemplate,
      requiresLicense: requiresLicense,
      licenseUrl: licenseUrl,
      capabilities: capabilities,
      tags: tags,
      variants: variants,
      isBeta: isBeta,
      cloudApiEndpoint: cloudApiEndpoint ?? this.cloudApiEndpoint,
      cloudModelId: cloudModelId ?? this.cloudModelId,
      cloudApiKeyPrefix: cloudApiKeyPrefix,
    );
  }
}
