/// 16×16 pixel-art robot avatar. Direct translation of the workspace
/// `PixelAvatar.tsx` SVG path commands into Flutter `Canvas` drawRect
/// / drawCircle / drawPath calls. The grid is 0–15 on both axes; the
/// painter scales to whatever [size] it's given.
library;

import 'package:flutter/material.dart';

import '../../core/hermes/models/hermes_session.dart';
import 'agent_behaviors.dart';

class PixelAvatarPainter extends CustomPainter {
  final Color bodyColor;
  final Color accentColor;
  final AgentExpression expression;
  final SwarmStatus status;
  final bool isWalking;
  final bool flipHorizontal;
  final int walkFrame; // 0 or 1, alternated externally

  const PixelAvatarPainter({
    required this.bodyColor,
    required this.accentColor,
    required this.expression,
    required this.status,
    required this.isWalking,
    required this.flipHorizontal,
    required this.walkFrame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16.0;
    final paint = Paint()..style = PaintingStyle.fill;

    if (flipHorizontal) {
      canvas.scale(-1, 1);
      canvas.translate(-size.width, 0);
    }

    void rect(double x, double y, double w, double h, Color c,
        {double rx = 0}) {
      paint.color = c;
      paint.style = PaintingStyle.fill;
      if (rx > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale),
            Radius.circular(rx * scale),
          ),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale),
          paint,
        );
      }
    }

    void dot(double cx, double cy, double r, Color c) {
      paint.color = c;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx * scale, cy * scale), r * scale, paint);
    }

    // Head
    rect(4, 1, 8, 6, bodyColor, rx: 1);
    // Antenna
    rect(7, 0, 2, 1, accentColor);
    // Eyes / expression
    _paintExpression(canvas, scale, paint, expression);

    // Body
    rect(3, 7, 10, 5, bodyColor, rx: 1);
    // Chest detail
    rect(6, 8, 4, 3, accentColor.withAlpha(150), rx: 0.5);

    // Arms — alternate Y while walking
    final leftArmY = isWalking ? (walkFrame == 0 ? 7.0 : 9.0) : 8.0;
    final rightArmY = isWalking ? (walkFrame == 0 ? 9.0 : 7.0) : 8.0;
    rect(1, leftArmY, 2, 3, bodyColor, rx: 0.5);
    rect(13, rightArmY, 2, 3, bodyColor, rx: 0.5);

    // Legs — same alternation
    final leftLegY = isWalking ? (walkFrame == 0 ? 11.0 : 13.0) : 12.0;
    final rightLegY = isWalking ? (walkFrame == 0 ? 13.0 : 11.0) : 12.0;
    rect(5, leftLegY, 2, 3, bodyColor, rx: 0.5);
    rect(9, rightLegY, 2, 3, bodyColor, rx: 0.5);

    // Feet
    rect(4, leftLegY + 2, 3, 2, accentColor, rx: 0.5);
    rect(9, rightLegY + 2, 3, 2, accentColor, rx: 0.5);

    // Status corner indicator
    final dotColor = switch (status) {
      SwarmStatus.thinking => const Color(0xFFFBBF24),
      SwarmStatus.complete => const Color(0xFF34D399),
      SwarmStatus.failed => const Color(0xFFF87171),
      SwarmStatus.error => const Color(0xFFEF4444),
      _ => null,
    };
    if (dotColor != null) dot(14, 2, 1.5, dotColor);
  }

  void _paintExpression(
    Canvas canvas,
    double scale,
    Paint paint,
    AgentExpression expr,
  ) {
    void rect(double x, double y, double w, double h, Color c) {
      paint.color = c;
      paint.style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale),
        paint,
      );
    }

    void dot(double cx, double cy, double r, Color c) {
      paint.color = c;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx * scale, cy * scale), r * scale, paint);
    }

    const white = Colors.white;
    const dark = Color(0xFF1E293B);
    const yellow = Color(0xFFFDE047);
    const gray = Color(0xFF94A3B8);

    switch (expr) {
      case AgentExpression.happy:
        // ^ ^ eyes via stroke paths
        final eyePath1 = Path()
          ..moveTo(5 * scale, 4 * scale)
          ..lineTo(6 * scale, 3 * scale)
          ..lineTo(7 * scale, 4 * scale);
        final eyePath2 = Path()
          ..moveTo(9 * scale, 4 * scale)
          ..lineTo(10 * scale, 3 * scale)
          ..lineTo(11 * scale, 4 * scale);
        paint.color = white;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 0.8 * scale;
        canvas.drawPath(eyePath1, paint);
        canvas.drawPath(eyePath2, paint);
        // Smile
        final smile = Path()
          ..moveTo(6.5 * scale, 5.5 * scale)
          ..quadraticBezierTo(
              8 * scale, 7 * scale, 9.5 * scale, 5.5 * scale);
        paint.strokeWidth = 0.6 * scale;
        canvas.drawPath(smile, paint);
        paint.style = PaintingStyle.fill;
      case AgentExpression.focused:
        // — — narrow eyes
        rect(5, 3.5, 2, 0.8, white);
        rect(9, 3.5, 2, 0.8, white);
      case AgentExpression.confused:
        // Asymmetric eyes
        rect(5, 3, 2, 2, white);
        rect(6, 3, 1, 1, dark);
        rect(9, 4, 2, 2, white);
        rect(10, 4, 1, 1, dark);
        // ? mark surrogate — yellow dot above right eye
        dot(13.5, 1.5, 0.8, yellow);
      case AgentExpression.tired:
        // Half-closed eyes — translucent white
        const half = Color(0xB3FFFFFF);
        rect(5, 4, 2, 1, half);
        rect(9, 4, 2, 1, half);
        // z dots
        dot(12.5, 1.5, 0.6, gray);
        dot(13.5, 0.5, 0.5, gray);
      case AgentExpression.excited:
        // ★ ★ — approximate with yellow dots
        dot(6, 4, 1.5, yellow);
        dot(10, 4, 1.5, yellow);
        // Open mouth
        dot(8, 6, 0.8, white);
      case AgentExpression.neutral:
        // Round eyes with dark pupils
        rect(5, 3, 2, 2, white);
        rect(9, 3, 2, 2, white);
        rect(6, 3, 1, 1, dark);
        rect(10, 3, 1, 1, dark);
    }
  }

  @override
  bool shouldRepaint(covariant PixelAvatarPainter old) =>
      old.expression != expression ||
      old.status != status ||
      old.isWalking != isWalking ||
      old.walkFrame != walkFrame ||
      old.flipHorizontal != flipHorizontal ||
      old.bodyColor != bodyColor ||
      old.accentColor != accentColor;
}
