/// Animated waveform button for voice recording
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class VoiceInputWidget extends StatefulWidget {
  final VoidCallback? onStart;
  final VoidCallback? onStop;

  const VoiceInputWidget({super.key, this.onStart, this.onStop});

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _pulseController.repeat(reverse: true);
        _waveController.repeat();
        widget.onStart?.call();
      } else {
        _pulseController.stop();
        _pulseController.reset();
        _waveController.stop();
        _waveController.reset();
        widget.onStop?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _waveController]),
        builder: (context, child) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording
                  ? PocketClawTheme.lobsterRed
                      .withAlpha((180 + 75 * _pulseController.value).toInt())
                  : PocketClawTheme.surfaceContainer,
              boxShadow: _isRecording
                  ? [
                      BoxShadow(
                        color: PocketClawTheme.lobsterRed
                            .withAlpha((100 * _pulseController.value).toInt()),
                        blurRadius: 12 + 8 * _pulseController.value,
                        spreadRadius: 2 * _pulseController.value,
                      ),
                    ]
                  : null,
              border: Border.all(
                color: _isRecording
                    ? PocketClawTheme.lobsterRed
                    : const Color(0xFF3A3A50),
                width: 1.5,
              ),
            ),
            child: _isRecording
                ? CustomPaint(
                    painter: _WaveformPainter(
                      progress: _waveController.value,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.mic,
                    color: Colors.white70,
                    size: 20,
                  ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveformPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const barCount = 5;
    final barWidth = size.width / (barCount * 2.5);
    final startX = (size.width - barCount * barWidth * 2.5) / 2 + barWidth;

    final random = Random(42);
    for (int i = 0; i < barCount; i++) {
      final x = startX + i * barWidth * 2.5;
      final phase = (progress * 2 * pi + i * 0.8) % (2 * pi);
      final amplitude = (sin(phase).abs() * 0.3 + 0.15) *
          size.height *
          (0.5 + random.nextDouble() * 0.5);

      canvas.drawLine(
        Offset(x, centerY - amplitude / 2),
        Offset(x, centerY + amplitude / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
