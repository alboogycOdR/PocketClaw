/// Model selection with download progress, estimated size, skip option
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

class _ModelOption {
  final String name;
  final String displayName;
  final String size;
  final String ramNeeded;
  final String description;

  const _ModelOption({
    required this.name,
    required this.displayName,
    required this.size,
    required this.ramNeeded,
    required this.description,
  });
}

class ModelDownload extends StatefulWidget {
  const ModelDownload({super.key});

  @override
  State<ModelDownload> createState() => _ModelDownloadState();
}

class _ModelDownloadState extends State<ModelDownload> {
  static const _models = [
    _ModelOption(
      name: 'gemma-3-4b',
      displayName: 'Gemma 3 4B',
      size: '2.4 GB',
      ramNeeded: '6 GB RAM',
      description: 'Best quality for on-device inference',
    ),
    _ModelOption(
      name: 'qwen2.5-3b',
      displayName: 'Qwen 2.5 3B',
      size: '1.8 GB',
      ramNeeded: '4 GB RAM',
      description: 'Good balance of speed and quality',
    ),
    _ModelOption(
      name: 'gemma-3-1b',
      displayName: 'Gemma 3 1B',
      size: '0.8 GB',
      ramNeeded: '2 GB RAM',
      description: 'Fast and lightweight',
    ),
  ];

  String? _selectedModel;
  bool _downloading = false;
  double _progress = 0;

  void _startDownload() {
    if (_selectedModel == null) return;

    setState(() {
      _downloading = true;
      _progress = 0;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return false;
      setState(() => _progress += 0.01);
      return _progress < 1.0;
    }).then((_) {
      if (!mounted) return;
      context.go('/');
    });
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
                  final selected = _selectedModel == model.name;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedModel = model.name);
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
                              value: model.name,
                              groupValue: _selectedModel,
                              onChanged: (val) {
                                setState(() => _selectedModel = val);
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
                              value: _progress,
                              strokeWidth: 6,
                              backgroundColor: const Color(0xFF2A2A40),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                PocketClawTheme.electricTeal,
                              ),
                            ),
                            Text(
                              '${(_progress * 100).toStringAsFixed(0)}%',
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
                        'Downloading model...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This may take a few minutes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
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
                        _selectedModel != null ? _startDownload : null,
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
