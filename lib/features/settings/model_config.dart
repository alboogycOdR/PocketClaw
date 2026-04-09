/// Local model selection and download management
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';

class _ModelInfo {
  final String id;
  final String displayName;
  final int ramRequired;
  final String size;

  const _ModelInfo({
    required this.id,
    required this.displayName,
    required this.ramRequired,
    required this.size,
  });
}

const _availableModels = [
  _ModelInfo(
    id: 'gemma-4-e2b',
    displayName: 'Gemma 4 E2B',
    ramRequired: 4000,
    size: '2.4 GB',
  ),
  _ModelInfo(
    id: 'qwen3-0.6b',
    displayName: 'Qwen3 0.6B',
    ramRequired: 1500,
    size: '0.6 GB',
  ),
  _ModelInfo(
    id: 'smollm-135m',
    displayName: 'SmolLM 135M',
    ramRequired: 500,
    size: '0.3 GB',
  ),
];

class ModelConfig extends ConsumerWidget {
  const ModelConfig({super.key});

  Future<void> _selectModel(WidgetRef ref, BuildContext context, String id) async {
    // Persist to SharedPreferences
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('selected_model', id);

    // Update reactive provider
    ref.read(selectedModelIdProvider.notifier).state = id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      'Local models run on-device for offline and privacy-sensitive tasks. RAM requirements are approximate.',
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
            final isActive = model.id == selectedId;
            return _ModelCard(
              model: model,
              isActive: isActive,
              onSelect: isActive
                  ? null
                  : () => _selectModel(ref, context, model.id),
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
  final VoidCallback? onSelect;

  const _ModelCard({
    required this.model,
    required this.isActive,
    this.onSelect,
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
                  isActive ? Icons.check_circle : Icons.download_outlined,
                  size: 20,
                  color: isActive
                      ? const Color(0xFF4CAF50)
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
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF4CAF50).withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                            ),
                          ],
                        ],
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

                // Action button — only shown for non-active models
                if (!isActive)
                  OutlinedButton(
                    onPressed: onSelect,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Use'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
