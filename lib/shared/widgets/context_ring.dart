library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/hermes_commander_theme.dart';

class ContextRing extends StatelessWidget {
  final double fill;
  final int tokenCount;
  final double estimatedCost;
  final double size;
  final String? model;
  final String? transport;
  final String? sessionId;

  const ContextRing({
    super.key,
    required this.fill,
    required this.tokenCount,
    this.estimatedCost = 0,
    this.size = 32,
    this.model,
    this.transport,
    this.sessionId,
  });

  Color get _ringColor {
    if (fill >= 0.9) return HCTheme.statusRed;
    if (fill >= 0.75) return const Color(0xFFF0883E);
    if (fill >= 0.5) return const Color(0xFFD29922);
    return HCTheme.statusGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _tooltip,
      child: InkWell(
        onTap: () => _showDetails(context),
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(fill: fill, color: _ringColor),
            child: Center(
              child: Text(
                _compact(tokenCount),
                style: TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w500,
                  color: _ringColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final pct = (fill * 100).clamp(0, 100).toStringAsFixed(0);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HCTheme.bgPanel,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Context',
                style: TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: HCTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _DetailLine(label: 'Used tokens', value: '$tokenCount'),
              _DetailLine(label: 'Context fill', value: '$pct%'),
              if (estimatedCost > 0)
                _DetailLine(
                  label: 'Estimated cost',
                  value: '\$${estimatedCost.toStringAsFixed(4)}',
                ),
              if (model != null && model!.isNotEmpty)
                _DetailLine(label: 'Model', value: model!),
              if (transport != null && transport!.isNotEmpty)
                _DetailLine(label: 'Transport', value: transport!),
              if (sessionId != null && sessionId!.isNotEmpty)
                _DetailLine(label: 'Session', value: sessionId!),
            ],
          ),
        ),
      ),
    );
  }

  String get _tooltip {
    final pct = (fill * 100).toStringAsFixed(0);
    final cost = estimatedCost > 0
        ? '  ·  ~\$${estimatedCost.toStringAsFixed(4)}'
        : '';
    return '$tokenCount tokens ($pct% of context)$cost';
  }

  String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 12,
                color: HCTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'GeistMono',
                fontSize: 12,
                color: HCTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fill;
  final Color color;

  const _RingPainter({required this.fill, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const strokeWidth = 2.5;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = HCTheme.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final sweep = math.pi * 2 * fill.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.color != color;
  }
}
