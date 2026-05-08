/// OpenClaw model status — mirrors the `openclaw models status` CLI:
/// default model, alias, fallbacks, image model, per-model health.
/// SPEC-OpenClaw-Improvements §5.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/openclaw_models.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/empty_state.dart';

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(gatewayClientProvider);
    final modelsAsync = ref.watch(openClawModelsProvider);

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Models')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Gateway not configured',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(openClawModelsProvider),
          ),
        ],
      ),
      body: modelsAsync.when(
        data: (status) {
          if (status.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(openClawModelsProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.memory,
                    message: 'No model status from the gateway',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(openClawModelsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionLabel(label: 'ACTIVE MODEL'),
                const SizedBox(height: 8),
                _ActiveModelCard(status: status),
                const SizedBox(height: 16),
                _SectionLabel(label: 'FALLBACKS'),
                const SizedBox(height: 8),
                if (status.fallbacks.isEmpty)
                  const _MutedCard(text: 'None configured'),
                for (final id in status.fallbacks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ModelRowCard(
                      id: id,
                      isDefault: false,
                      isHealthy: status.configured
                              .firstWhere(
                                (m) => m.id == id,
                                orElse: () =>
                                    const OpenClawModelEntry(id: ''),
                              )
                              .isHealthy,
                      lastError: status.configured
                          .firstWhere(
                            (m) => m.id == id,
                            orElse: () => const OpenClawModelEntry(id: ''),
                          )
                          .lastError,
                    ),
                  ),
                const SizedBox(height: 16),
                _SectionLabel(label: 'IMAGE MODEL'),
                const SizedBox(height: 8),
                if (status.imageModel == null || status.imageModel!.isEmpty)
                  const _MutedCard(text: 'None configured')
                else
                  _ModelRowCard(
                    id: status.imageModel!,
                    isDefault: false,
                    isHealthy: true,
                  ),
                if (_extraConfigured(status).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'OTHER CONFIGURED'),
                  const SizedBox(height: 8),
                  for (final m in _extraConfigured(status))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ModelRowCard(
                        id: m.id,
                        isDefault: m.isDefault,
                        isHealthy: m.isHealthy,
                        lastError: m.lastError,
                      ),
                    ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load models: $e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(openClawModelsProvider),
        ),
      ),
    );
  }

  /// Models that aren't the default and aren't already in the fallback list.
  List<OpenClawModelEntry> _extraConfigured(OpenClawModelsStatus s) {
    final shown = {s.defaultModel, ...s.fallbacks, s.imageModel}
      ..removeWhere((e) => e == null || e.isEmpty);
    return [
      for (final m in s.configured)
        if (!shown.contains(m.id)) m,
    ];
  }
}

class _ActiveModelCard extends StatelessWidget {
  final OpenClawModelsStatus status;
  const _ActiveModelCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final defaultEntry = status.configured.firstWhere(
      (m) => m.id == status.defaultModel,
      orElse: () => OpenClawModelEntry(
        id: status.defaultModel ?? '',
        isDefault: true,
      ),
    );
    final healthy = defaultEntry.isHealthy;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🦞', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.defaultModel ?? 'No default set',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  healthy ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color: healthy
                      ? PocketClawTheme.electricTeal
                      : PocketClawTheme.lobsterRed,
                ),
              ],
            ),
            if (status.alias != null && status.alias!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Alias: ${status.alias!}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
            if (defaultEntry.lastError != null) ...[
              const SizedBox(height: 6),
              Text(
                defaultEntry.lastError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: PocketClawTheme.lobsterRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelRowCard extends StatelessWidget {
  final String id;
  final bool isDefault;
  final bool isHealthy;
  final String? lastError;
  const _ModelRowCard({
    required this.id,
    required this.isDefault,
    required this.isHealthy,
    this.lastError,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                id,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight:
                      isDefault ? FontWeight.w700 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lastError != null && lastError!.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: 'Last error logged',
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange,
                  ),
                ),
              ),
            Icon(
              isHealthy ? Icons.check_circle : Icons.error_outline,
              size: 14,
              color: isHealthy
                  ? PocketClawTheme.electricTeal
                  : PocketClawTheme.lobsterRed,
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  final String text;
  const _MutedCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: Colors.white60,
      ),
    );
  }
}
