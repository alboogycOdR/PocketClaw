/// Voice & Transcription settings — Whisper model picker + download
/// manager. Transcription itself is not yet wired against the
/// installed fllama 0.0.1; the on-device STT path keeps using the
/// Android system speech recogniser. Once a Whisper backend is
/// dropped in, the active-model selection here drives it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/device/whisper_stt_service.dart';
import '../../data/providers/whisper_providers.dart';

class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(whisperActiveModelIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voice & Transcription')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PocketClawTheme.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PocketClawTheme.warning.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: PocketClawTheme.warning),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Offline transcription requires a Whisper backend the '
                    'installed fllama doesn\'t yet expose. The picker '
                    'below downloads the model; the runtime path will '
                    'use it once fllama is upgraded (or whisper_dart is '
                    'added). Today\'s on-device STT still uses Android '
                    'speech (online).',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Models',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              letterSpacing: 0.14,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          for (final model in kWhisperModels)
            _ModelTile(model: model, activeAsync: activeAsync),
        ],
      ),
    );
  }
}

class _ModelTile extends ConsumerStatefulWidget {
  final WhisperModel model;
  final AsyncValue<String?> activeAsync;
  const _ModelTile({required this.model, required this.activeAsync});

  @override
  ConsumerState<_ModelTile> createState() => _ModelTileState();
}

class _ModelTileState extends ConsumerState<_ModelTile> {
  double? _downloadProgress;
  bool _busy = false;

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _downloadProgress = 0;
    });
    try {
      await whisperSttService.downloadModel(
        widget.model.id,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      ref.invalidate(whisperModelDownloadedProvider(widget.model.id));
      ref.invalidate(whisperModelSizeProvider(widget.model.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await whisperSttService.deleteModel(widget.model.id);
      ref.invalidate(whisperModelDownloadedProvider(widget.model.id));
      ref.invalidate(whisperModelSizeProvider(widget.model.id));
      final active = await whisperSttService.activeModelId();
      if (active == widget.model.id) {
        await whisperSttService.setActiveModelId(null);
        ref.invalidate(whisperActiveModelIdProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive() async {
    await whisperSttService.setActiveModelId(widget.model.id);
    ref.invalidate(whisperActiveModelIdProvider);
  }

  @override
  Widget build(BuildContext context) {
    final downloadedAsync =
        ref.watch(whisperModelDownloadedProvider(widget.model.id));
    final isActive = widget.activeAsync.valueOrNull == widget.model.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.model.displayName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? PocketClawTheme.electricTeal
                          : Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${widget.model.sizeMb} MB',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.model.description,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: widget.model.languages
                  .map((l) => Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(l,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              color: Colors.white60,
                            )),
                      ))
                  .toList(),
            ),
            if (_downloadProgress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 4),
              Text(
                '${((_downloadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
            const SizedBox(height: 8),
            downloadedAsync.when(
              loading: () => const SizedBox(height: 28),
              error: (_, __) => const SizedBox.shrink(),
              data: (downloaded) => Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (downloaded) ...[
                    if (!isActive)
                      TextButton(
                        onPressed: _busy ? null : _setActive,
                        child: const Text('Set active'),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Delete'),
                      onPressed: _busy ? null : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: PocketClawTheme.lobsterRed,
                      ),
                    ),
                  ] else
                    FilledButton.icon(
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Download'),
                      onPressed: _busy ? null : _download,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
