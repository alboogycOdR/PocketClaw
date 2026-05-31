/// Floor + chat-connection painters for the office view.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'agent_behaviors.dart';

/// 20×14 checkered floor. Tile colours match the workspace SVG.
class FloorPainter extends CustomPainter {
  const FloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 20;
    const rows = 14;
    final tileW = size.width / cols;
    final tileH = size.height / rows;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        paint.color = (r + c).isEven
            ? const Color(0xFF1A1A2E)
            : const Color(0xFF16213E);
        canvas.drawRect(
          Rect.fromLTWH(c * tileW, r * tileH, tileW, tileH),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FloorPainter _) => false;
}

class ChatLine {
  final OfficePoint from;
  final OfficePoint to;
  const ChatLine({required this.from, required this.to});
}

/// Dashed yellow lines connecting agents that are chatting.
class ChatLinesPainter extends CustomPainter {
  final List<ChatLine> lines;
  const ChatLinesPainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFBBF24).withAlpha(80)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final line in lines) {
      final p1 = Offset(
        line.from.x / 100 * size.width,
        line.from.y / 100 * size.height,
      );
      final p2 = Offset(
        line.to.x / 100 * size.width,
        line.to.y / 100 * size.height,
      );
      _drawDashed(canvas, p1, p2, paint);
    }
  }

  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 6.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final end = math.min(t + dash, total);
      canvas.drawLine(a + dir * t, a + dir * end, p);
      t = end + gap;
    }
  }

  @override
  bool shouldRepaint(covariant ChatLinesPainter old) =>
      !_listsEqual(old.lines, lines);

  bool _listsEqual(List<ChatLine> a, List<ChatLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].from != b[i].from || a[i].to != b[i].to) return false;
    }
    return true;
  }
}
