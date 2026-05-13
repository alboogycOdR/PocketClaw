/// TTS settings — Supertonic model + voice download, voice picker, test.
///
/// Renamed from the spec's `voice_settings_screen.dart` because that
/// name was already taken by the Whisper STT screen — the two live as
/// independent surfaces ("Voice & Transcription" for STT, "Voice & TTS"
/// for this one).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/tts/supertonic_model_manager.dart';
import '../../core/tts/supertonic_tts_service.dart';
import '../../data/providers/tts_providers.dart';

class TtsSettingsScreen extends ConsumerStatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  ConsumerState<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends ConsumerState<TtsSettingsScreen> {
  bool _downloading = false;
  double _progress = 0;
  String _progressLabel = '';
  String? _error;

  Future<void> _downloadModels() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await supertonicModelManager.downloadModels(
        onProgress: (label, progress) {
          if (mounted) {
            setState(() {
              _progressLabel = label;
              _progress = progress;
            });
          }
        },
      );
      await supertonicModelManager.downloadVoice('M1');
      if (mounted) {
        setState(() => _downloading = false);
        ref.invalidate(supertonicModelsReadyProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _downloadVoice(String voiceId) async {
    setState(() {
      _downloading = true;
      _error = null;
      _progressLabel = 'Downloading $voiceId…';
    });
    try {
      await supertonicModelManager.downloadVoice(
        voiceId,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) setState(() => _downloading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _testVoice(String voiceId) async {
    try {
      await supertonicTtsService.loadModel(voiceId: voiceId);
      await supertonicTtsService.speak(
          'XAUUSD at \$3,234.50. The session closed at 4:45 PM Wed Apr 3.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelsReady =
        ref.watch(supertonicModelsReadyProvider).valueOrNull ?? false;
    final activeVoice = ref.watch(activeVoiceIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Voice & TTS', style: GoogleFonts.jetBrainsMono(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      modelsReady
                          ? Icons.check_circle_outline
                          : Icons.download_outlined,
                      color: modelsReady
                          ? PocketClawTheme.electricTeal
                          : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      modelsReady ? 'Supertonic active' : 'Using system TTS',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: modelsReady
                            ? PocketClawTheme.electricTeal
                            : Colors.white70,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    modelsReady
                        ? 'On-device · Offline · Natural text handling'
                        : 'Download Supertonic for offline, natural speech.',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  if (!modelsReady && !_downloading) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _downloadModels,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download (~75 MB)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: PocketClawTheme.bronze,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.white12,
              color: PocketClawTheme.electricTeal,
            ),
            const SizedBox(height: 6),
            Text(_progressLabel,
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(
                      color: PocketClawTheme.lobsterRed, fontSize: 12)),
            ),
          if (modelsReady) ...[
            const SizedBox(height: 20),
            Text('Voices',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 8),
            ...kSupertonicVoices.map((voice) {
              final isActive = activeVoice == voice.id;
              return FutureBuilder<bool>(
                future: supertonicModelManager.isVoiceDownloaded(voice.id),
                builder: (context, snap) {
                  final downloaded = snap.data ?? false;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? PocketClawTheme.bronze.withAlpha(50)
                            : Colors.white12,
                        child: Text(
                          voice.gender == 'male' ? 'M' : 'F',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(voice.displayName),
                      subtitle: Text(
                        downloaded
                            ? (isActive ? 'Active' : 'Downloaded')
                            : 'Not downloaded',
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive
                              ? PocketClawTheme.electricTeal
                              : Colors.white38,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (downloaded)
                            IconButton(
                              icon: const Icon(Icons.play_arrow_outlined,
                                  size: 20),
                              tooltip: 'Test voice',
                              onPressed: () => _testVoice(voice.id),
                            ),
                          if (!downloaded)
                            IconButton(
                              icon: const Icon(Icons.download_outlined,
                                  size: 20),
                              tooltip: 'Download voice',
                              onPressed: _downloading
                                  ? null
                                  : () => _downloadVoice(voice.id),
                            ),
                          if (downloaded && !isActive)
                            FilledButton(
                              onPressed: () async {
                                await supertonicTtsService.loadModel(
                                    voiceId: voice.id);
                                await ref
                                    .read(activeVoiceIdProvider.notifier)
                                    .setVoice(voice.id);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    PocketClawTheme.electricTeal.withAlpha(40),
                                foregroundColor: PocketClawTheme.electricTeal,
                              ),
                              child: const Text('Use',
                                  style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: supertonicModelManager.totalSizeBytes(),
              builder: (context, snap) {
                final mb = ((snap.data ?? 0) / 1e6).toStringAsFixed(0);
                return TextButton.icon(
                  onPressed: () async {
                    await supertonicModelManager.deleteAll();
                    if (mounted) {
                      ref.invalidate(supertonicModelsReadyProvider);
                      setState(() {});
                    }
                  },
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: PocketClawTheme.lobsterRed),
                  label: Text('Remove all Supertonic files ($mb MB)',
                      style: TextStyle(
                          color: PocketClawTheme.lobsterRed, fontSize: 12)),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
