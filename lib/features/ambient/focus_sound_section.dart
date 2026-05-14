/// Focus Sounds section of the Ambient tab. Horizontal scene picker
/// + per-channel volume mixer when a scene is active.
///
/// v2.8.0 ships without audio assets — the engine plays silence until
/// the user drops MP3 loops into `assets/sounds/<scene_id>/`. The UI
/// shows a notice so this isn't mysterious.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/ambient/focus_sound_engine.dart';
import '../../data/providers/ambient_providers.dart';
import 'models/sound_scene.dart';

class FocusSoundSection extends ConsumerWidget {
  const FocusSoundSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogueAsync = ref.watch(soundCatalogueProvider);
    final state = ref.watch(focusSoundStateProvider).valueOrNull;

    return catalogueAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Failed to load scenes: $e',
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ),
      data: (scenes) => _buildContent(context, scenes, state),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<SoundScene> scenes,
    FocusSoundState? state,
  ) {
    final active = state?.activeScene;
    final isPlaying = state?.isPlaying ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Text('Focus Sounds',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
              const Spacer(),
              if (isPlaying)
                _PillButton(
                  icon: Icons.pause,
                  label: 'Playing',
                  color: PocketClawTheme.electricTeal,
                  onTap: focusSoundEngine.pause,
                ),
            ],
          ),
        ),

        // Notice: audio assets not bundled.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: PocketClawTheme.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PocketClawTheme.warning.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: PocketClawTheme.warning),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Audio loops aren\'t bundled yet. The mixer is '
                    'wired — drop MP3 files at '
                    'assets/sounds/<scene>/<channel>.mp3 to activate.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: scenes.length,
            itemBuilder: (_, i) => _SceneChip(
              scene: scenes[i],
              isActive: active?.id == scenes[i].id && isPlaying,
              onTap: () => _onSceneTap(scenes[i], state),
            ),
          ),
        ),

        if (active != null && isPlaying) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Mixer(scene: active, state: state!),
          ),
        ],
      ],
    );
  }

  void _onSceneTap(SoundScene scene, FocusSoundState? state) {
    if (state?.activeScene?.id == scene.id && state!.isPlaying) {
      focusSoundEngine.pause();
    } else {
      focusSoundEngine.loadScene(scene);
    }
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SceneChip extends StatelessWidget {
  final SoundScene scene;
  final bool isActive;
  final VoidCallback onTap;
  const _SceneChip({
    required this.scene,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 96,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? scene.color.withAlpha(64) : PocketClawTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? scene.color : PocketClawTheme.surfaceContainerHigh,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(scene.displayName,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? scene.color : Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(
              scene.category,
              style: TextStyle(
                fontSize: 9,
                color: isActive ? scene.color : Colors.white38,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mixer extends ConsumerWidget {
  final SoundScene scene;
  final FocusSoundState state;
  const _Mixer({required this.scene, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scene.color.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 100,
              child: Row(
                children: List.generate(scene.channels.length, (i) {
                  final channel = scene.channels[i];
                  final volume = state.volumes[i];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        children: [
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 10),
                                  activeTrackColor: scene.color,
                                  inactiveTrackColor:
                                      scene.color.withAlpha(50),
                                  thumbColor: scene.color,
                                ),
                                child: Slider(
                                  value: volume,
                                  onChanged: (v) => focusSoundEngine
                                      .setChannelVolume(i, v),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            channel.label,
                            style: const TextStyle(
                                fontSize: 8, color: Colors.white60),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                _MixerAction(
                  label: 'All In',
                  icon: Icons.equalizer,
                  onTap: focusSoundEngine.allIn,
                ),
                const SizedBox(width: 12),
                _MixerAction(
                  label: 'Reset',
                  icon: Icons.refresh,
                  onTap: focusSoundEngine.resetToDefaults,
                ),
                const SizedBox(width: 12),
                _MixerAction(
                  label: 'Stop',
                  icon: Icons.stop_outlined,
                  onTap: focusSoundEngine.stop,
                  destructive: true,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bedtime_outlined, size: 18),
                  tooltip: 'Sleep timer',
                  color: state.hasSleepTimer
                      ? PocketClawTheme.electricTeal
                      : Colors.white60,
                  onPressed: () => _showSleepTimer(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSleepTimer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sleep timer',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final mins in [15, 30, 45, 60, 90])
              ListTile(
                title: Text('Stop in $mins minutes'),
                onTap: () {
                  Navigator.pop(context);
                  focusSoundEngine
                      .setSleepTimer(Duration(minutes: mins));
                },
              ),
            ListTile(
              title: Text('Cancel timer',
                  style: TextStyle(color: PocketClawTheme.lobsterRed)),
              onTap: () {
                Navigator.pop(context);
                focusSoundEngine.cancelSleepTimer();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MixerAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;
  final bool destructive;
  const _MixerAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? PocketClawTheme.lobsterRed : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
