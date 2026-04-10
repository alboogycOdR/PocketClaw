/// Model selection with download via flutter_gemma's native installModel API
library;

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';

class _ModelOption {
  final String id;
  final String displayName;
  final String downloadUrl;
  final ModelType modelType;
  final ModelFileType fileType;
  final String size;
  final String ramNeeded;
  final String description;
  final bool supportImage;
  final bool supportAudio;

  const _ModelOption({
    required this.id,
    required this.displayName,
    required this.downloadUrl,
    required this.modelType,
    this.fileType = ModelFileType.litertlm,
    required this.size,
    required this.ramNeeded,
    required this.description,
    this.supportImage = false,
    this.supportAudio = false,
  });
}

class ModelDownload extends ConsumerStatefulWidget {
  const ModelDownload({super.key});

  @override
  ConsumerState<ModelDownload> createState() => _ModelDownloadState();
}

class _ModelDownloadState extends ConsumerState<ModelDownload> {
  static const _models = [
    _ModelOption(
      id: 'gemma-4-e2b',
      displayName: 'Gemma 4 E2B',
      downloadUrl:
          'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
      size: '1.5 GB',
      ramNeeded: '6 GB RAM',
      description: 'Best quality — text, vision, audio, function calling',
      supportImage: true,
      supportAudio: true,
    ),
    _ModelOption(
      id: 'gemma-3-1b',
      displayName: 'Gemma 3 1B',
      downloadUrl:
          'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
      size: '0.6 GB',
      ramNeeded: '4 GB RAM',
      description: 'Good balance of speed and quality',
    ),
    _ModelOption(
      id: 'gemma-3-270m',
      displayName: 'Gemma 3 270M',
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
      size: '0.3 GB',
      ramNeeded: '2 GB RAM',
      description: 'Ultra-compact — fast and lightweight',
    ),
  ];

  String? _selectedModelId;
  bool _downloading = false;
  int _progress = 0;
  String _statusText = '';
  String? _errorText;
  CancelToken? _cancelToken;

  Future<void> _startDownload() async {
    if (_selectedModelId == null) return;

    final model = _models.firstWhere((m) => m.id == _selectedModelId);

    setState(() {
      _downloading = true;
      _progress = 0;
      _statusText = 'Preparing download...';
      _errorText = null;
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
            setState(() {
              _progress = progress;
              _statusText = 'Downloading: $progress%';
            });
          })
          .withCancelToken(_cancelToken!)
          .install();

      if (!mounted) return;

      setState(() {
        _progress = 100;
        _statusText = 'Download complete!';
      });

      await _onDownloadComplete(model);
    } on DownloadCancelledException {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _statusText = '';
        _errorText = 'Download cancelled';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _errorText = 'Download failed: $e';
      });
    }
  }

  Future<void> _onDownloadComplete(_ModelOption model) async {
    // Save selected model to preferences
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('selected_model', model.id);
    ref.read(selectedModelIdProvider.notifier).state = model.id;

    // Brief delay to show completion state
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    context.go('/');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Local Model')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a Local Model',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A local model enables offline AI features. You can always change or download more models later.',
                style: TextStyle(color: Colors.white54, height: 1.5),
              ),

              const SizedBox(height: 24),

              // Model options
              if (!_downloading)
                ...(_models.map((model) {
                  final selected = _selectedModelId == model.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedModelId = model.id);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? PocketClawTheme.lobsterRed.withAlpha(15)
                              : PocketClawTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? PocketClawTheme.lobsterRed
                                : const Color(0xFF3A3A50).withAlpha(80),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: model.id,
                              groupValue: _selectedModelId,
                              onChanged: (val) {
                                setState(() => _selectedModelId = val);
                              },
                              activeColor: PocketClawTheme.lobsterRed,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    model.displayName,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    model.description,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  model.size,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: PocketClawTheme.electricTeal,
                                  ),
                                ),
                                Text(
                                  model.ramNeeded,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })),

              // Error message
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PocketClawTheme.lobsterRed.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: PocketClawTheme.lobsterRed.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 18, color: PocketClawTheme.lobsterRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: PocketClawTheme.lobsterRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Download progress
              if (_downloading) ...[
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _progress > 0 ? _progress / 100.0 : null,
                              strokeWidth: 6,
                              backgroundColor: const Color(0xFF2A2A40),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                PocketClawTheme.electricTeal,
                              ),
                            ),
                            Text(
                              '$_progress%',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: PocketClawTheme.electricTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _cancelDownload,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              if (!_downloading) ...[
                // Download button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _selectedModelId != null ? _startDownload : null,
                    child: const Text('Download & Continue'),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text(
                      'Skip - no local model',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
