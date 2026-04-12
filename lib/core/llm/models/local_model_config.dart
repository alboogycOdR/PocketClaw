/// Model configuration — supports local (task/gguf) and cloud API models
library;

import 'model_format.dart';
import 'model_provider.dart';

class LocalModelConfig {
  final String id;
  final String displayName;
  final String description;
  final double sizeGB;
  final int ramMB;
  final ModelFormat format;
  final ModelProvider provider;
  final String? hfRepo;
  final String? hfFilename;
  final String? downloadUrl;
  final bool requiresLicense;
  final String? licenseUrl;
  final List<String> capabilities;
  final bool isBeta;

  // Cloud API fields
  final String? cloudApiEndpoint; // e.g. 'https://api.anthropic.com/v1/messages'
  final String? cloudModelId;     // e.g. 'claude-sonnet-4-20250514'
  final String? cloudApiKeyPrefix; // e.g. 'sk-ant-' for validation hint

  const LocalModelConfig({
    required this.id,
    required this.displayName,
    required this.description,
    required this.sizeGB,
    required this.ramMB,
    required this.format,
    required this.provider,
    this.hfRepo,
    this.hfFilename,
    this.downloadUrl,
    this.requiresLicense = false,
    this.licenseUrl,
    this.capabilities = const [],
    this.isBeta = false,
    this.cloudApiEndpoint,
    this.cloudModelId,
    this.cloudApiKeyPrefix,
  });

  bool get isCloud => format == ModelFormat.cloud;
  bool get isLocal => format != ModelFormat.cloud;

  /// Returns a copy of this config with the given overrides.
  LocalModelConfig copyWith({
    String? cloudModelId,
    String? cloudApiEndpoint,
  }) {
    return LocalModelConfig(
      id: id,
      displayName: displayName,
      description: description,
      sizeGB: sizeGB,
      ramMB: ramMB,
      format: format,
      provider: provider,
      hfRepo: hfRepo,
      hfFilename: hfFilename,
      downloadUrl: downloadUrl,
      requiresLicense: requiresLicense,
      licenseUrl: licenseUrl,
      capabilities: capabilities,
      isBeta: isBeta,
      cloudApiEndpoint: cloudApiEndpoint ?? this.cloudApiEndpoint,
      cloudModelId: cloudModelId ?? this.cloudModelId,
      cloudApiKeyPrefix: cloudApiKeyPrefix,
    );
  }
}
