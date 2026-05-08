/// OpenClaw model configuration + status — shape of the `models.status`
/// RPC response (mirror of `openclaw models status` CLI).
library;

class OpenClawModelsStatus {
  final String? defaultModel; // e.g. "neurometric/clawpack"
  final String? alias; // e.g. "ClawPack"
  final String? imageModel;
  final List<String> fallbacks;
  final List<OpenClawModelEntry> configured;

  const OpenClawModelsStatus({
    this.defaultModel,
    this.alias,
    this.imageModel,
    this.fallbacks = const [],
    this.configured = const [],
  });

  bool get isEmpty => defaultModel == null && configured.isEmpty;

  factory OpenClawModelsStatus.fromJson(Map<String, dynamic> json) =>
      OpenClawModelsStatus(
        defaultModel: json['default'] as String?,
        alias: json['alias'] as String?,
        imageModel: json['imageModel'] as String?,
        fallbacks: (json['fallbacks'] as List?)?.cast<String>() ?? const [],
        configured: [
          for (final m in (json['models'] as List? ?? const []))
            if (m is Map<String, dynamic>) OpenClawModelEntry.fromJson(m),
        ],
      );
}

class OpenClawModelEntry {
  final String id;
  final bool isDefault;
  final bool isHealthy;
  final String? lastError;

  const OpenClawModelEntry({
    required this.id,
    this.isDefault = false,
    this.isHealthy = true,
    this.lastError,
  });

  factory OpenClawModelEntry.fromJson(Map<String, dynamic> json) =>
      OpenClawModelEntry(
        id: json['id'] as String? ?? '',
        isDefault: json['isDefault'] == true,
        // Assume healthy unless explicitly told otherwise.
        isHealthy: json['healthy'] != false,
        lastError: json['lastError'] as String?,
      );
}
