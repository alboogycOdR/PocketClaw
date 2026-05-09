/// Animated mic button wired to the device speech-to-text engine.
///
/// Per SPEC-VoiceInput-v1.0 §7. Tap mic → SttService starts listening →
/// partial transcription streams to [onPartialResult] in real time →
/// [onFinalResult] fires on completion → [onDone] always closes the loop.
///
/// Backwards-compat: the old `onStart` / `onStop` callbacks are still
/// accepted (so call-sites that haven't migrated yet still compile),
/// but they fire purely as edge events — they no longer carry any
/// transcription. Prefer the new `on*Result` callbacks for new code.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/device/stt_service.dart';

class VoiceInputWidget extends ConsumerStatefulWidget {
  /// Called with partial transcription text as the user speaks.
  final void Function(String partialText)? onPartialResult;

  /// Called with the final transcription when the user stops speaking.
  final void Function(String text)? onFinalResult;

  /// Called when recording stops for any reason
  /// (silence, manual stop, timeout, error).
  final VoidCallback? onDone;

  /// Legacy edge callback — kept so existing call-sites keep compiling.
  /// Fires when recording starts. New code should use [onPartialResult].
  final VoidCallback? onStart;

  /// Legacy edge callback — kept so existing call-sites keep compiling.
  /// Fires when recording stops. New code should use [onDone].
  final VoidCallback? onStop;

  const VoiceInputWidget({
    super.key,
    this.onPartialResult,
    this.onFinalResult,
    this.onDone,
    this.onStart,
    this.onStop,
  });

  @override
  ConsumerState<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends ConsumerState<VoiceInputWidget>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isInitializing = false;
  String _errorMessage = '';
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

  Future<void> _toggleRecording() async {
    final stt = ref.read(sttServiceProvider);

    if (_isRecording) {
      // Stop recording — final result fires through the existing listener,
      // then onDone clears the animation.
      await stt.stopListening();
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = '';
    });

    final available = await stt.initialize();
    if (!mounted) return;

    if (!available) {
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Microphone unavailable. Check app permissions in Settings.';
      });
      // Auto-clear the error after a few seconds so the user can retry.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _errorMessage = '');
      });
      return;
    }

    setState(() {
      _isInitializing = false;
      _isRecording = true;
    });
    _startAnimation();
    widget.onStart?.call();

    await stt.startListening(
      onPartialResult: (text) {
        widget.onPartialResult?.call(text);
      },
      onFinalResult: (text) {
        widget.onFinalResult?.call(text);
      },
      onDone: () {
        if (!mounted) return;
        // SpeechToText fires `notListening` on start of session AND on
        // end — guard so we only react when we were actually recording.
        if (_isRecording) {
          _stopAnimation();
          widget.onDone?.call();
          widget.onStop?.call();
        }
      },
    );
  }

  void _startAnimation() {
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  void _stopAnimation() {
    if (!mounted) return;
    setState(() => _isRecording = false);
    _pulseController.stop();
    _pulseController.reset();
    _waveController.stop();
    _waveController.reset();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return Tooltip(
        message: _errorMessage,
        child: GestureDetector(
          onTap: () => setState(() => _errorMessage = ''),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.mic_off, color: Colors.white38, size: 22),
          ),
        ),
      );
    }

    if (_isInitializing) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _waveController]),
        builder: (context, _) => Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isRecording
                ? PocketClawTheme.lobsterRed.withAlpha(
                    (180 + 75 * _pulseController.value).toInt(),
                  )
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
                  : const Color(0xFF3A2F26),
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
              : const Icon(Icons.mic, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

// ── Waveform painter (unchanged from original) ───────────────────────────────

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
