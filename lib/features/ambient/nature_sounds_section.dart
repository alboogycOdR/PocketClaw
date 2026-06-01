/// Nature & Ambience section — 3-channel mixer for bundled ambient loops.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/hermes_commander_theme.dart';
import '../../core/ambient/nature_sound_engine.dart';
import '../../data/providers/ambient_providers.dart';

class NatureSoundsSection extends ConsumerWidget {
  const NatureSoundsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(natureSoundStateProvider);
    final state = stateAsync.valueOrNull;
    final isPlaying = state?.isPlaying ?? false;
    final volumes = state?.volumes ??
        List.filled(natureSoundChannels.length, 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                '🌿',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(width: 8),
              const Text(
                'Nature & Ambience',
                style: TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HCTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? HCTheme.statusGreen.withAlpha(30)
                      : HCTheme.bgSurface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isPlaying ? HCTheme.statusGreen : HCTheme.border,
                  ),
                ),
                child: Text(
                  isPlaying ? 'LIVE' : 'OFF',
                  style: TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPlaying ? HCTheme.statusGreen : HCTheme.textMuted,
                  ),
                ),
              ),
              const Spacer(),
              _PlayStopButton(isPlaying: isPlaying),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Bundled · offline',
            style: TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 11,
              color: HCTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),

          // Single column — 3 channels
          Column(
            children: List.generate(natureSoundChannels.length, (i) {
              return _ChannelSlider(
                channel: natureSoundChannels[i],
                index: i,
                volume: volumes[i],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Play / Stop button ─────────────────────────────────────────────────────────

class _PlayStopButton extends StatelessWidget {
  final bool isPlaying;

  const _PlayStopButton({required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => natureSoundEngine.toggle(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isPlaying ? HCTheme.gold : HCTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPlaying ? HCTheme.gold : HCTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 16,
              color: isPlaying ? HCTheme.bgBase : HCTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              isPlaying ? 'Stop' : 'Play',
              style: TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPlaying ? HCTheme.bgBase : HCTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Channel slider ─────────────────────────────────────────────────────────────

class _ChannelSlider extends StatelessWidget {
  final NatureSoundChannel channel;
  final int index;
  final double volume;

  const _ChannelSlider({
    required this.channel,
    required this.index,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                channel.emoji,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              Text(
                channel.label,
                style: const TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: HCTheme.textPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _StepButton(
                label: '−',
                onTap: () => natureSoundEngine.nudgeVolume(index, -0.1),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 1.5,
                    thumbShape: _SquareThumbShape(),
                    activeTrackColor: HCTheme.gold,
                    inactiveTrackColor: HCTheme.border,
                    thumbColor: HCTheme.bgPanel,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) =>
                        natureSoundEngine.setChannelVolume(index, v),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _StepButton(
                label: '+',
                onTap: () => natureSoundEngine.nudgeVolume(index, 0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StepButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 15,
              fontWeight: FontWeight.w300,
              color: HCTheme.textSecondary,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareThumbShape extends SliderComponentShape {
  static const _size = 10.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(_size, _size);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(center: center, width: _size, height: _size);
    canvas.drawRect(rect, Paint()..color = HCTheme.bgPanel);
    canvas.drawRect(
      rect.inflate(0.5),
      Paint()
        ..color = HCTheme.textSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }
}
