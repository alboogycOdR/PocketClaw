/// Persistent mini-player rendered above the bottom navigation bar.
/// Shows Office Sounds, Nature & Ambience, and Radio when active.
/// Returns SizedBox.shrink() when all are silent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/hermes_commander_theme.dart';
import '../../core/ambient/nature_sound_engine.dart';
import '../../core/ambient/office_sound_engine.dart';
import '../../data/providers/ambient_providers.dart';

class AmbientMiniPlayer extends ConsumerWidget {
  const AmbientMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officeState = ref.watch(officeSoundStateProvider).valueOrNull;
    final natureState = ref.watch(natureSoundStateProvider).valueOrNull;
    final radio = ref.watch(activeRadioChannelProvider);
    final radioPlayer = ref.watch(radioPlayerProvider);

    final officeActive = officeState?.isPlaying ?? false;
    final natureActive = natureState?.isPlaying ?? false;
    final radioActive = radio != null;

    if (!officeActive && !natureActive && !radioActive) return const SizedBox.shrink();

    return Material(
      color: PocketClawTheme.surfaceContainer,
      child: InkWell(
        onTap: () => context.go('/ambient'),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: PocketClawTheme.onSurfaceMuted.withAlpha(60),
              ),
            ),
          ),
          child: Row(
            children: [
              if (officeActive) ...[
                const Icon(Icons.business_center_outlined, size: 16, color: HCTheme.gold),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Office Sounds',
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  color: PocketClawTheme.onSurfaceMuted,
                  tooltip: 'Stop Office Sounds',
                  onPressed: officeSoundEngine.stop,
                ),
              ],
              if (natureActive) ...[
                if (officeActive)
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: PocketClawTheme.onSurfaceMuted.withAlpha(80),
                  ),
                const Text('🌿', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Nature & Ambience',
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  color: PocketClawTheme.onSurfaceMuted,
                  tooltip: 'Stop Nature Sounds',
                  onPressed: natureSoundEngine.stop,
                ),
              ],
              if ((officeActive || natureActive) && radioActive)
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: PocketClawTheme.onSurfaceMuted.withAlpha(80),
                ),
              if (radioActive) ...[
                Icon(Icons.radio, size: 16, color: PocketClawTheme.electricTeal),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    radio.title.isNotEmpty ? radio.title : 'Radio',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  color: PocketClawTheme.onSurfaceMuted,
                  tooltip: 'Stop radio',
                  onPressed: () {
                    radioPlayer.stop();
                    ref.read(activeRadioChannelProvider.notifier).state = null;
                  },
                ),
              ],
              const Spacer(),
              Icon(Icons.keyboard_arrow_up,
                  size: 16, color: PocketClawTheme.onSurfaceMuted),
            ],
          ),
        ),
      ),
    );
  }
}
