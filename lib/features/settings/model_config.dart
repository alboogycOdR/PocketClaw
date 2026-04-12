/// Local model selection and download management — multi-model, multi-runtime
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../core/llm/model_registry.dart';
import '../../core/llm/models/local_model_config.dart' as llm;
import '../../core/llm/models/model_download_state.dart';
import '../../core/llm/models/model_format.dart';
import '../../core/llm/models/model_provider.dart';
import '../../core/llm/services/api_key_service.dart';
import '../../data/providers/core_providers.dart';

class ModelConfig extends ConsumerStatefulWidget {
  const ModelConfig({super.key});

  @override
  ConsumerState<ModelConfig> createState() => _ModelConfigState();
}

class _ModelConfigState extends ConsumerState<ModelConfig> {
  String? _downloadingId;

  Future<void> _startDownload(llm.LocalModelConfig model) async {
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
                      'Run models on-device for offline privacy, or connect '
                      'to cloud APIs with your own key for maximum power.',
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
              onTap: () => _showHfTokenDialog(context, ref),
            ),
          ],

          // -- Cloud Models Section --
          const SizedBox(height: 20),
          Text(
            'CLOUD MODELS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bring your own API key \u2014 no download required',
            style: TextStyle(fontSize: 11, color: Colors.white24),
          ),
          const SizedBox(height: 10),

          ...kAvailableModels.where((m) => m.isCloud).map((model) {
            final isSelected = model.id == selectedId;
            final cloudProvider = ApiKeyService.providerFor(model.provider);
            final hasKey = cloudProvider != null
                ? (ref.watch(hasCloudKeyProvider(cloudProvider))
                        .whenOrNull(data: (v) => v) ??
                    false)
                : false;

            return _MultiModelCard(
              model: model,
              isSelected: isSelected,
              isDownloading: false,
              isDownloaded: hasKey,
              downloadProgress: 0,
              errorMessage: null,
              hasToken: true,
              onDownload: () {
                if (cloudProvider != null) {
                  _showCloudApiKeyDialog(context, ref, cloudProvider, model);
                }
              },
              onSelect: () => _selectModel(model),
              onTokenTap: () {
                if (cloudProvider != null) {
                  _showCloudApiKeyDialog(context, ref, cloudProvider, model);
                }
              },
            );
          }),

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

          ...kAvailableModels.where((m) => m.isLocal).map((model) {
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

            return _MultiModelCard(
              model: model,
              isSelected: isSelected,
              isDownloading: isDownloading,
              isDownloaded: isDownloaded,
              downloadProgress: progress,
              errorMessage: errorMsg,
              hasToken: tokenAvailable,
              onDownload: () => _startDownload(model),
              onSelect: () => _selectModel(model),
              onTokenTap: () => _showHfTokenDialog(context, ref),
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
          color: const Color(0xFFFFD21E).withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD21E).withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 20, color: Color(0xFFFFD21E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'HuggingFace token required for model downloads. '
                'Tap here to add your token.',
                style: const TextStyle(fontSize: 12, color: Color(0xFFFFD21E)),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFFFFD21E)),
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
                      ? const Color(0xFF4CAF50)
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
                              color: const Color(0xFF4CAF50),
                            ),
                          ],
                          if (model.isBeta) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(
                              label: 'BETA',
                              color: const Color(0xFFFFB74D),
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
                const SizedBox(width: 8),
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
                  backgroundColor: const Color(0xFF2A2A40),
                  valueColor: const AlwaysStoppedAnimation<Color>(
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
      return Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 24);
    }

    // Cloud model without key
    if (model.isCloud) {
      return OutlinedButton.icon(
        onPressed: onDownload, // opens API key dialog
        icon: const Icon(Icons.key, size: 14),
        label: const Text('API Key', style: TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          side: BorderSide(color: model.provider.badgeColor),
          foregroundColor: model.provider.badgeColor,
        ),
      );
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
      ModelFormat.gguf  => ('GGUF', const Color(0xFF9C27B0)),
      ModelFormat.task  => ('.TASK', const Color(0xFF4285F4)),
      ModelFormat.cloud => ('CLOUD', const Color(0xFF10A37F)),
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
        color: const Color(0xFF2A2A40),
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

void _showHfTokenDialog(BuildContext context, WidgetRef ref) {
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
                      ? const Color(0xFF4CAF50)
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

// -- Cloud API key dialog -----------------------------------------------------

void _showCloudApiKeyDialog(
  BuildContext context,
  WidgetRef ref,
  CloudProvider cloudProvider,
  llm.LocalModelConfig model,
) {
  final keyService = ref.read(apiKeyServiceProvider);
  final controller = TextEditingController();
  var isValidating = false;
  var validationResult = '';

  final providerName = switch (cloudProvider) {
    CloudProvider.anthropic => 'Anthropic',
    CloudProvider.openAI    => 'OpenAI',
    CloudProvider.googleAI  => 'Google AI',
    CloudProvider.xai       => 'xAI',
    CloudProvider.moonshot  => 'Moonshot',
  };
  final hintText = model.cloudApiKeyPrefix ?? 'sk-...';

  // Pre-fill existing key
  keyService.getKey(cloudProvider).then((key) {
    if (key != null) controller.text = key;
  });

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('$providerName API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your $providerName API key to use ${model.displayName}. '
              'Your key is stored securely on-device only.',
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: hintText,
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
                      ? const Color(0xFF4CAF50)
                      : PocketClawTheme.lobsterRed,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await keyService.deleteKey(cloudProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ref.invalidate(hasCloudKeyProvider(cloudProvider));
                // Force the cloud engine to rebuild without the key.
                ref.invalidate(abstractLlmEngineProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$providerName key cleared')),
                );
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) return;
              setDialogState(() {
                isValidating = true;
                validationResult = '';
              });
              final valid = await keyService.validate(cloudProvider, key);
              setDialogState(() {
                isValidating = false;
                validationResult = valid ? 'Valid key' : 'Invalid key';
              });
            },
            child: const Text('Validate'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) {
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              try {
                await keyService.saveKey(cloudProvider, key);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ref.invalidate(hasCloudKeyProvider(cloudProvider));
                  // Force the cloud engine to rebuild with the new key.
                  ref.invalidate(abstractLlmEngineProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$providerName key saved')),
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
