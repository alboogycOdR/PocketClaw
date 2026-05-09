/// Model configuration for on-device local models (.task / .gguf).
///
/// Cloud API model fields were dropped 2026-05-09 along with the rest
/// of the cloud chat path — PocketClaw is local + agentic only now.
///
/// Sizes are stored in bytes (`sizeBytes`, `minRamBytes`) so the JSON
/// allowlist (assets/model_allowlist.json) is the single source of
/// truth and integer math stays exact. `sizeGB` / `ramMB` / `minRamGB`
/// are display-only derived getters kept for the existing UI strings.
library;

import 'model_format.dart';
import 'model_provider.dart';
import 'model_variant.dart';

/// Prompt formatting dialect for local instruct models.
///
/// fllama emits raw token streams; the Dart side formats the prompt
/// with the per-model template before calling completion. Picking the
/// wrong template produces garbled output (e.g. Gemma echoing its own
/// role headers).
enum ChatTemplate { chatml, gemma, llama3, phi3, mistral }

class LocalModelConfig {
  final String id;
  final String displayName;
  final String description;

  /// On-disk file size in bytes.
  final int sizeBytes;

  /// Minimum device RAM required to run, in bytes.
  final int minRamBytes;

  final ModelFormat format;
  final ModelProvider provider;
  final String? hfRepo;
  final String? hfFilename;

  /// HuggingFace commit hash (or branch name) to pin the download to.
  /// Defaults to "main". Storing this lets us detect new versions and
  /// pin downloaded files to the exact bytes we expect.
  final String hfCommitHash;

  final ChatTemplate chatTemplate;
  final bool requiresLicense;
  final String? licenseUrl;
  final List<String> capabilities;

  /// Display tags such as "recommended" / "new". Drives badge rendering.
  final List<String> tags;

  /// Alternate downloadable variants (e.g. Q4 vs Q8 of the same base
  /// model). `null` means there is only the primary variant.
  final List<ModelVariant>? variants;

  final bool isBeta;

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
  });

  /// Always true now that cloud has been removed — every registered
  /// model is local. Kept as a getter so existing call sites compile.
  bool get isLocal => true;

  /// File size in GB (display only).
  double get sizeGB => sizeBytes / (1024 * 1024 * 1024);

  /// RAM requirement in MB (display only, kept for compat with old UI).
  int get ramMB => (minRamBytes / (1024 * 1024)).round();

  /// RAM requirement in GB (display only).
  double get minRamGB => minRamBytes / (1024 * 1024 * 1024);

  /// HuggingFace download URL pinned to `hfCommitHash`. Throws if the
  /// model lacks repo/filename (would only ever happen on a misshaped
  /// allowlist entry).
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

  /// Returns a copy of this config — kept for API compat. There are no
  /// override-able fields right now since the cloud-* fields were
  /// dropped, but this stays so existing call sites don't break.
  LocalModelConfig copyWith() {
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
    );
  }
}
