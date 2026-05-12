/// Storage screen — shows how on-device bytes are spent and offers
/// cleanup actions for orphan files / stale `.part` downloads.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/llm/download_recovery_service.dart';
import '../../data/providers/storage_providers.dart';
import '../../shared/utils/storage_formatter.dart';

class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(storageStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(storageStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Failed to compute storage: $e',
                style: const TextStyle(color: Colors.white54)),
          ),
        ),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${formatBytes(stats.totalUsedBytes)} used',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _Section(
              label: 'Text models',
              bytes: stats.textModelsBytes,
              icon: Icons.memory,
            ),
            _Section(
              label: 'Whisper models',
              bytes: stats.whisperModelsBytes,
              icon: Icons.mic_outlined,
            ),
            _Section(
              label: 'Embedding model',
              bytes: stats.embeddingModelBytes,
              icon: Icons.scatter_plot_outlined,
            ),
            _Section(
              label: 'Knowledge base (rag.db)',
              bytes: stats.ragDatabaseBytes,
              icon: Icons.menu_book_outlined,
            ),
            _Section(
              label: 'Conversations',
              bytes: stats.conversationsBytes,
              icon: Icons.chat_bubble_outline,
            ),
            const SizedBox(height: 20),
            if (stats.recovery.hasFindings)
              _RecoveryCard(
                result: stats.recovery,
                onCleaned: () => ref.invalidate(storageStatsProvider),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final int bytes;
  final IconData icon;
  const _Section({
    required this.label,
    required this.bytes,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PocketClawTheme.electricTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            formatBytes(bytes),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryCard extends ConsumerStatefulWidget {
  final RecoveryScanResult result;
  final VoidCallback onCleaned;
  const _RecoveryCard({required this.result, required this.onCleaned});

  @override
  ConsumerState<_RecoveryCard> createState() => _RecoveryCardState();
}

class _RecoveryCardState extends ConsumerState<_RecoveryCard> {
  bool _busy = false;

  Future<void> _deleteAll() async {
    setState(() => _busy = true);
    try {
      for (final f in widget.result.orphaned) {
        await downloadRecoveryService.deletePath(f.path);
      }
      for (final f in widget.result.partial) {
        await downloadRecoveryService.deletePath(f.path);
      }
      widget.onCleaned();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Card(
      margin: EdgeInsets.zero,
      color: PocketClawTheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cleaning_services,
                    size: 16, color: PocketClawTheme.warning),
                const SizedBox(width: 8),
                Text(
                  'Cleanup available',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PocketClawTheme.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (r.orphaned.isNotEmpty)
              Text(
                '${r.orphaned.length} orphaned model file'
                '${r.orphaned.length == 1 ? "" : "s"} · '
                '${formatBytes(r.totalOrphanedBytes)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            if (r.partial.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${r.partial.length} incomplete download'
                  '${r.partial.length == 1 ? "" : "s"} · '
                  '${formatBytes(r.totalPartialBytes)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _deleteAll,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 16),
                label: Text(_busy ? 'Cleaning…' : 'Clean up'),
                style: FilledButton.styleFrom(
                  backgroundColor: PocketClawTheme.lobsterRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
