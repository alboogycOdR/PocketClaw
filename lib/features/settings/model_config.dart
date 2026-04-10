/// Local model selection and download management via flutter_gemma
library;

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';

class _ModelInfo {
  final String id;
  final String displayName;
  final String downloadUrl;
  final ModelType modelType;
  final ModelFileType fileType;
  final int ramRequired;
  final String size;
  final String description;
  final bool supportImage;
  final bool supportAudio;

  const _ModelInfo({
    required this.id,
    required this.displayName,
    required this.downloadUrl,
    required this.modelType,
    this.fileType = ModelFileType.litertlm,
    required this.ramRequired,
    required this.size,
    required this.description,
    this.supportImage = false,
    this.supportAudio = false,
  });
}

const _availableModels = [
  _ModelInfo(
    id: 'gemma-4-e2b',
    displayName: 'Gemma 4 E2B',
    downloadUrl:
        'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
    modelType: ModelType.gemmaIt,
    fileType: ModelFileType.task,
    ramRequired: 6000,
    size: '1.5 GB',
    description: 'Best quality — vision, audio, function calling',
    supportImage: true,
    supportAudio: true,
  ),
  _ModelInfo(
    id: 'gemma-3-1b',
    displayName: 'Gemma 3 1B',
    downloadUrl:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
    modelType: ModelType.gemmaIt,
    fileType: ModelFileType.task,
    ramRequired: 4000,
    size: '0.6 GB',
    description: 'Good balance of speed and quality',
  ),
  _ModelInfo(
    id: 'gemma-3-270m',
    displayName: 'Gemma 3 270M',
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
    modelType: ModelType.gemmaIt,
    fileType: ModelFileType.task,
    ramRequired: 2000,
    size: '0.3 GB',
    description: 'Ultra-compact — fast and lightweight',
  ),
];

class ModelConfig extends ConsumerStatefulWidget {
  const ModelConfig({super.key});

  @override
  ConsumerState<ModelConfig> createState() => _ModelConfigState();
}

class _ModelConfigState extends ConsumerState<ModelConfig> {
  String? _downloadingId;
  int _downloadProgress = 0;
  CancelToken? _cancelToken;

  Future<void> _downloadAndActivate(_ModelInfo model) async {
    setState(() {
      _downloadingId = model.id;
      _downloadProgress = 0;
    });

    _cancelToken = CancelToken();

    try {
      // Read HuggingFace token for authenticated downloads
      final prefs = ref.read(sharedPrefsProvider);
      final hfToken = prefs.getString('huggingface_token');

      await FlutterGemma.installModel(
        modelType: model.modelType,
        fileType: model.fileType,
      )
          .fromNetwork(model.downloadUrl, token: hfToken)
          .withProgress((progress) {
            if (!mounted) return;
            setState(() => _downloadProgress = progress);
          })
          .withCancelToken(_cancelToken!)
          .install();

      if (!mounted) return;

      // Persist selection
      await prefs.setString('selected_model', model.id);
      ref.read(selectedModelIdProvider.notifier).state = model.id;

      // Load the model into the engine
      final engine = ref.read(llmEngineProvider);
      final selector = ref.read(modelSelectorProvider);
      final config = selector.getConfigById(model.id);
      if (config != null) {
        try {
          await engine.loadModel(config);
        } catch (_) {
          // Model will be loaded on next app restart
        }
      }

      setState(() => _downloadingId = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.displayName} is now active'),
          ),
        );
      }
    } on DownloadCancelledException {
      if (mounted) setState(() => _downloadingId = null);
    } catch (e) {
      if (mounted) {
        setState(() => _downloadingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('User cancelled');
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Screen disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedModelIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Local Models')),
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
                      'Local models run on-device for offline and privacy-sensitive tasks. '
                      'Tap Download to install a model, then it becomes active automatically.',
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

          const SizedBox(height: 16),

          ..._availableModels.map((model) {
            final isSelected = model.id == selectedId;
            final engine = ref.watch(llmEngineProvider);
            final isLoaded = engine.isLoaded &&
                engine.config?.id == model.id;
            final isActive = isSelected && isLoaded;
            final isDownloading = model.id == _downloadingId;
            return _ModelCard(
              model: model,
              isActive: isActive,
              isSelectedButNotLoaded: isSelected && !isLoaded && !isDownloading,
              isDownloading: isDownloading,
              downloadProgress: isDownloading ? _downloadProgress : 0,
              onDownload: (isActive || isDownloading)
                  ? null
                  : () => _downloadAndActivate(model),
              onCancel: isDownloading ? _cancelDownload : null,
            );
          }),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final _ModelInfo model;
  final bool isActive;
  final bool isSelectedButNotLoaded;
  final bool isDownloading;
  final int downloadProgress;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;

  const _ModelCard({
    required this.model,
    required this.isActive,
    this.isSelectedButNotLoaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0,
    this.onDownload,
    this.onCancel,
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
            Row(
              children: [
                Icon(
                  isActive
                      ? Icons.check_circle
                      : isSelectedButNotLoaded
                          ? Icons.warning_amber_rounded
                          : isDownloading
                              ? Icons.downloading
                              : Icons.download_outlined,
                  size: 20,
                  color: isActive
                      ? const Color(0xFF4CAF50)
                      : isSelectedButNotLoaded
                          ? const Color(0xFFFFB74D)
                          : PocketClawTheme.electricTeal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            model.displayName,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isActive || isSelectedButNotLoaded) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF4CAF50).withAlpha(25)
                                    : const Color(0xFFFFB74D).withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isActive ? 'ACTIVE' : 'NOT DOWNLOADED',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFFFB74D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${model.size}  |  ${model.ramRequired} MB RAM',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action button
                if (isDownloading)
                  IconButton(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.white38,
                  )
                else if (!isActive)
                  OutlinedButton(
                    onPressed: onDownload,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Download'),
                  ),
              ],
            ),

            // Download progress bar
            if (isDownloading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: downloadProgress > 0
                      ? downloadProgress / 100.0
                      : null,
                  backgroundColor: const Color(0xFF2A2A40),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    PocketClawTheme.electricTeal,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Downloading: $downloadProgress%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: PocketClawTheme.electricTeal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
