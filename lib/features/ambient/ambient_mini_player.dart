/// Persistent mini-player rendered above the bottom navigation bar in
/// `_AppShell`. Shows whatever Ambient sources are currently active:
///   - Focus Sound scene (left side)
///   - Radio station (right side)
/// When both are silent, the widget returns SizedBox.shrink() so the
/// shell doesn't reserve any vertical space.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ambient/focus_sound_engine.dart';
import '../../data/providers/ambient_providers.dart';

class AmbientMiniPlayer extends ConsumerWidget {
  const AmbientMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusState = ref.watch(focusSoundStateProvider).valueOrNull;
    final radio = ref.watch(activeRadioChannelProvider);
    final radioPlayer = ref.watch(radioPlayerProvider);

    final focusActive = (focusState?.isPlaying ?? false) &&
        focusState?.activeScene != null;
    final radioActive = radio != null;

    if (!focusActive && !radioActive) return const SizedBox.shrink();

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
              if (focusActive) ...[
                Icon(Icons.spa_outlined,
                    size: 16, color: focusState!.activeScene!.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    focusState.activeScene!.displayName,
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
                  tooltip: 'Stop Focus Sound',
                  onPressed: focusSoundEngine.stop,
                ),
              ],
              if (focusActive && radioActive)
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: PocketClawTheme.onSurfaceMuted.withAlpha(80),
                ),
              if (radioActive) ...[
                Icon(Icons.radio,
                    size: 16, color: PocketClawTheme.electricTeal),
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
