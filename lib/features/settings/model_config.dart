/// Local model selection and download management — multi-model, multi-runtime
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/llm/models/local_model_config.dart' as llm;
import '../../core/llm/models/model_download_state.dart';
import '../../core/llm/models/model_format.dart';
import '../../core/llm/models/model_provider.dart';
import '../../core/llm/services/device_memory_service.dart';
import '../../core/llm/services/license_service.dart';
import '../../core/llm/models/model_version_status.dart';
import '../../data/providers/core_providers.dart';

class ModelConfig extends ConsumerStatefulWidget {
  const ModelConfig({super.key});

  @override
  ConsumerState<ModelConfig> createState() => _ModelConfigState();
}

class _ModelConfigState extends ConsumerState<ModelConfig> {
  String? _downloadingId;

  Future<void> _startDownload(llm.LocalModelConfig model) async {
    // License gate: if the model requires a license and the user has not
    // yet accepted it in-app, show the acceptance dialog first. This
    // avoids the "license not accepted" error from ModelDownloadManager.
    if (model.requiresLicense) {
      final licenseService = ref.read(licenseServiceProvider);
      final alreadyAccepted = licenseService.isAccepted(model.id);
      if (!alreadyAccepted) {
        final accepted =
            await _showLicenseAcceptDialog(context, model, licenseService);
        if (accepted != true) return; // user cancelled
      }
    }

    // HuggingFace token gate: gated repos (Gemma, Llama) reject anonymous
    // downloads with HTTP 401. Surface the token dialog inline rather than
    // letting the download fail with a cryptic auth error.
    if (model.requiresLicense) {
      final tokenService = ref.read(hfTokenServiceProvider);
      final hasToken = await tokenService.hasToken();
      if (!hasToken && mounted) {
        showHfTokenDialog(context, ref);
        // The dialog runs async — bail out and let the user tap Download
        // again once their token is saved. Re-running the dialog here
        // would race with their typing.
        return;
      }
    }

    setState(() => _downloadingId = model.id);

    final manager = ref.read(modelDownloadManagerProvider);
    await manager.startDownload(model);

    if (mounted) setState(() => _downloadingId = null);
  }

  void _selectModel(llm.LocalModelConfig model) {
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setString('selected_model', model.id);
    ref.read(selectedModelIdProvider.notifier).state = model.id;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${model.displayName} selected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedModelIdProvider);
    final hasToken = ref.watch(hasHFTokenProvider);
    final tokenAvailable = hasToken.whenOrNull(data: (v) => v) ?? false;
    final catalogue = ref.watch(modelCatalogueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Models')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: PocketClawTheme.electricTeal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'On-device models — offline, private, fast. '
                      'Cloud LLMs are intentionally not supported here; '
                      'use the AI provider\'s own app for that.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // No-token banner (for HuggingFace gated local models)
          if (!tokenAvailable) ...[
            const SizedBox(height: 12),
            _NoTokenBanner(
              onTap: () => showHfTokenDialog(context, ref),
            ),
          ],

          // -- Local Models Section --
          const SizedBox(height: 20),
          Text(
            'LOCAL MODELS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Download once, run offline \u2014 private and fast',
            style: TextStyle(fontSize: 11, color: Colors.white24),
          ),
          const SizedBox(height: 10),

          ...catalogue.where((m) => m.isLocal).map((model) {
            final isSelected = model.id == selectedId;
            final downloadState = ref.watch(modelDownloadStateProvider(model.id));
            final isDownloading = _downloadingId == model.id ||
                (downloadState.whenOrNull(
                      data: (s) => s.status == DownloadStatus.downloading,
                    ) ??
                    false);
            final isDownloaded = downloadState.whenOrNull(
                  data: (s) => s.status == DownloadStatus.downloaded,
                ) ??
                false;
            final errorMsg = downloadState.whenOrNull(
              data: (s) =>
                  s.status == DownloadStatus.error ? s.errorMessage : null,
            );
            final progress = downloadState.whenOrNull(
                  data: (s) => s.progress,
                ) ??
                0.0;

            // RAM gate. While the lookup is in flight we show no warning
            // (optimistic) — the gate fires once the device value lands.
            final deviceRam = ref.watch(deviceRamProvider);
            final hasEnoughRam = deviceRam.whenOrNull(
                  data: (ram) => ram >= model.minRamBytes,
                ) ??
                true;

            // Version status: drives the "Update available" badge.
            // Default to currentVersion while loading so we don't flash a
            // false-positive badge during the async file probe.
            final versionStatus =
                ref.watch(modelVersionStatusProvider(model.id)).whenOrNull(
                      data: (s) => s,
                    ) ??
                    ModelVersionStatus.currentVersion;

            return _MultiModelCard(
              model: model,
              isSelected: isSelected,
              isDownloading: isDownloading,
              isDownloaded: isDownloaded,
              downloadProgress: progress,
              errorMessage: errorMsg,
              hasToken: tokenAvailable,
              hasEnoughRam: hasEnoughRam,
              versionStatus: versionStatus,
              onDownload: () => _startDownload(model),
              onSelect: () => _selectModel(model),
              onTokenTap: () => showHfTokenDialog(context, ref),
            );
          }),
        ],
      ),
    );
  }
}

// -- No-token banner ----------------------------------------------------------

class _NoTokenBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _NoTokenBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PocketClawTheme.warning.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PocketClawTheme.warning.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 20, color: PocketClawTheme.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'HuggingFace token required for model downloads. '
                'Tap here to add your token.',
                style: TextStyle(fontSize: 12, color: PocketClawTheme.warning),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: PocketClawTheme.warning),
          ],
        ),
      ),
    );
  }
}

// -- Multi-model card ---------------------------------------------------------

class _MultiModelCard extends StatelessWidget {
  final llm.LocalModelConfig model;
  final bool isSelected;
  final bool isDownloading;
  final bool isDownloaded;
  final double downloadProgress;
  final String? errorMessage;
  final bool hasToken;
  final bool hasEnoughRam;
  final ModelVersionStatus versionStatus;
  final VoidCallback onDownload;
  final VoidCallback onSelect;
  final VoidCallback onTokenTap;
  const _MultiModelCard({
    required this.model,
    required this.isSelected,
    required this.isDownloading,
    required this.isDownloaded,
    required this.downloadProgress,
    this.errorMessage,
    required this.hasToken,
    this.hasEnoughRam = true,
    this.versionStatus = ModelVersionStatus.currentVersion,
    required this.onDownload,
    required this.onSelect,
    required this.onTokenTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + name + badges
            Row(
              children: [
                Icon(
                  isSelected && isDownloaded
                      ? Icons.check_circle
                      : isDownloading
                          ? Icons.downloading
                          : isDownloaded
                              ? Icons.download_done
                              : Icons.download_outlined,
                  size: 20,
                  color: isSelected && isDownloaded
                      ? PocketClawTheme.success
                      : PocketClawTheme.electricTeal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status badges
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              model.displayName,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected && isDownloaded) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(
                              label: 'ACTIVE',
                              color: PocketClawTheme.success,
                            ),
                          ],
                          if (model.isBeta) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(
                              label: 'BETA',
                              color: PocketClawTheme.warning,
                            ),
                          ],
                          if (model.tags.contains('new')) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(
                              label: 'NEW',
                              color: PocketClawTheme.electricTeal,
                            ),
                          ],
                          if (model.tags.contains('recommended')) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(
                              label: 'RECOMMENDED',
                              color: PocketClawTheme.success,
                            ),
                          ],
                          if (versionStatus ==
                              ModelVersionStatus.updateAvailable) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(
                              label: 'UPDATE',
                              color: PocketClawTheme.warning,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Provider badge + format tag
                      Row(
                        children: [
                          _ProviderBadge(provider: model.provider),
                          const SizedBox(width: 6),
                          _FormatTag(format: model.format),
                          if (model.isLocal) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${model.sizeGB} GB  |  ${model.ramMB} MB RAM',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Description
                      Text(
                        model.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),

                      // Capability chips
                      if (model.capabilities.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: model.capabilities
                              .map((c) => _CapabilityChip(label: c))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action button
                const SizedBox(width: 4),
                _buildActionButton(context),
              ],
            ),

            // Download progress bar
            if (isDownloading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: downloadProgress > 0 ? downloadProgress : null,
                  backgroundColor: PocketClawTheme.surfaceContainerLow,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    PocketClawTheme.electricTeal,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Downloading: ${(downloadProgress * 100).toInt()}%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: PocketClawTheme.electricTeal,
                ),
              ),
            ],

            // Error message
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PocketClawTheme.lobsterRed.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 14, color: PocketClawTheme.lobsterRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: PocketClawTheme.lobsterRed,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onDownload,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Retry', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isDownloading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (isDownloaded && !isSelected) {
      return OutlinedButton(
        onPressed: onSelect,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          side: BorderSide(color: PocketClawTheme.electricTeal),
          foregroundColor: PocketClawTheme.electricTeal,
        ),
        child: const Text('Load', style: TextStyle(fontSize: 12)),
      );
    }

    if (isSelected && isDownloaded) {
      return Icon(Icons.check_circle, color: PocketClawTheme.success, size: 24);
    }

    // Local model not downloaded
    if (!hasToken && model.requiresLicense) {
      return Tooltip(
        message: 'Add HuggingFace token in Settings',
        child: IconButton(
          onPressed: onTokenTap,
          icon: const Icon(Icons.lock_outline, size: 20),
          color: Colors.white38,
        ),
      );
    }

    // Device doesn't meet the model's minimum RAM — surface a disabled
    // button with a tooltip rather than letting the user kick off a
    // multi-GB download that will OOM at load time.
    if (!hasEnoughRam) {
      return Tooltip(
        message:
            'Needs ${model.minRamGB.toStringAsFixed(0)} GB RAM — your device may not support this model',
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            backgroundColor: PocketClawTheme.surfaceContainerLow,
          ),
          child: const Text(
            'Low RAM',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onDownload,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: PocketClawTheme.lobsterRed,
      ),
      child: const Text('Download', style: TextStyle(fontSize: 12)),
    );
  }
}

// -- Badge / chip widgets -----------------------------------------------------

class _ProviderBadge extends StatelessWidget {
  final ModelProvider provider;

  const _ProviderBadge({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: provider.badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: provider.badgeColor.withAlpha(80)),
      ),
      child: Text(
        provider.displayName,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: provider.badgeColor,
        ),
      ),
    );
  }
}

class _FormatTag extends StatelessWidget {
  final ModelFormat format;

  const _FormatTag({required this.format});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (format) {
      ModelFormat.gguf => ('GGUF', const Color(0xFF9C27B0)),
      ModelFormat.task => ('.TASK', const Color(0xFF4285F4)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  final String label;

  const _CapabilityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final icon = switch (label) {
      'vision' => Icons.visibility_outlined,
      'audio' => Icons.mic_outlined,
      'function_calling' => Icons.build_outlined,
      'code' => Icons.code,
      'reasoning' => Icons.psychology_outlined,
      'multilingual' => Icons.translate,
      _ => Icons.star_outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: PocketClawTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white38),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// -- HuggingFace token dialog (moved here for import-free settings) -----------

void showHfTokenDialog(BuildContext context, WidgetRef ref) {
  final tokenService = ref.read(hfTokenServiceProvider);
  final controller = TextEditingController();
  var isValidating = false;
  var validationResult = '';

  // Pre-fill existing token
  tokenService.getToken().then((token) {
    if (token != null) controller.text = token;
  });

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('HuggingFace Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Required for downloading gated models (Gemma, Llama). '
              'Get your token from huggingface.co/settings/tokens',
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Token',
                hintText: 'hf_...',
                border: const OutlineInputBorder(),
                suffixIcon: isValidating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              obscureText: true,
            ),
            if (validationResult.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                validationResult,
                style: TextStyle(
                  fontSize: 12,
                  color: validationResult.contains('Valid')
                      ? PocketClawTheme.success
                      : PocketClawTheme.lobsterRed,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await tokenService.deleteToken();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                // Refresh the token state
                ref.invalidate(hasHFTokenProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token cleared')),
                );
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              final token = controller.text.trim();
              if (token.isEmpty) return;
              setDialogState(() {
                isValidating = true;
                validationResult = '';
              });
              final valid = await tokenService.validateToken(token);
              setDialogState(() {
                isValidating = false;
                validationResult = valid ? 'Valid token' : 'Invalid token';
              });
            },
            child: const Text('Validate'),
          ),
          ElevatedButton(
            onPressed: () async {
              final token = controller.text.trim();
              if (token.isEmpty) {
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              try {
                await tokenService.saveToken(token);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ref.invalidate(hasHFTokenProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token saved')),
                  );
                }
              } catch (e) {
                setDialogState(() {
                  validationResult = e.toString();
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  ).then((_) => controller.dispose());
}

// -- License acceptance dialog ------------------------------------------------

Future<bool?> _showLicenseAcceptDialog(
  BuildContext context,
  llm.LocalModelConfig model,
  LicenseService licenseService,
) {
  final licenseName = switch (model.provider) {
    ModelProvider.google => 'Gemma Terms of Use',
    ModelProvider.meta => 'Llama Community License',
    _ => '${model.provider.displayName} License',
  };

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('Accept ${licenseName}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${model.displayName} is governed by the ${licenseName}.',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PocketClawTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By accepting, you confirm that:',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\u2022 You have read the terms\n'
                    '\u2022 You will use the model in accordance with them\n'
                    '\u2022 You accept any usage restrictions the model carries',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: Colors.white54,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (model.licenseUrl != null)
              InkWell(
                onTap: () async {
                  final uri = Uri.parse(model.licenseUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.open_in_new,
                        size: 14, color: PocketClawTheme.electricTeal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Read full terms: ${model.licenseUrl}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: PocketClawTheme.electricTeal,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () async {
            await licenseService.markAccepted(model.id);
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          },
          child: const Text('I accept'),
        ),
      ],
    ),
  );
}
