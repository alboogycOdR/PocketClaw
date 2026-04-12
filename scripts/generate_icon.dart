/// Generates the Pocket Claw source app icon programmatically and saves it
/// to assets/icon/pocket_claw_icon.png (1024x1024 PNG).
///
/// Then `flutter pub run flutter_launcher_icons` processes this source into
/// all the per-density mipmaps Android + iOS need.
///
/// Usage: `dart scripts/generate_icon.dart`
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int _size = 1024;

// Brand palette
const _charcoal = [0x1A, 0x1A, 0x2E]; // PocketClawTheme.deepCharcoal
const _lobsterRed = [0xE5, 0x39, 0x35];
const _electricTeal = [0x00, 0xE5, 0xCC];

Future<void> main() async {
  stdout.writeln('Generating Pocket Claw app icon (${_size}x$_size)...');

  final image = img.Image(width: _size, height: _size, numChannels: 4);

  // 1. Radial gradient background: deep charcoal center, slightly lighter edge
  _fillRadialGradient(
    image,
    centerColor: _charcoal,
    edgeColor: const [0x0E, 0x0E, 0x1F],
  );

  // 2. Large off-centre glowing dot (electric teal) — visual anchor
  _drawGlow(
    image,
    cx: (_size * 0.35).round(),
    cy: (_size * 0.38).round(),
    radius: (_size * 0.25).round(),
    color: _electricTeal,
    intensity: 0.6,
  );

  // 3. Lobster red accent swoop (stylised claw arc)
  _drawClaw(image);

  // 4. Bold "P" glyph centred, white
  _drawLetter(image);

  // 5. Subtle outer ring for definition
  _drawRing(
    image,
    radius: (_size * 0.48).round(),
    thickness: 4,
    color: _electricTeal,
    alpha: 120,
  );

  // Save
  final dir = Directory('assets/icon');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('assets/icon/pocket_claw_icon.png');
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote ${file.path} (${file.lengthSync()} bytes)');

  // Also generate foreground layer for adaptive icons (no background,
  // just the glyph + accent, centered within 66% safe zone)
  final fg = img.Image(width: _size, height: _size, numChannels: 4);
  _drawGlow(
    fg,
    cx: (_size * 0.5).round(),
    cy: (_size * 0.5).round(),
    radius: (_size * 0.22).round(),
    color: _electricTeal,
    intensity: 0.55,
  );
  _drawLetter(fg);
  final fgFile = File('assets/icon/pocket_claw_icon_foreground.png');
  fgFile.writeAsBytesSync(img.encodePng(fg));
  stdout.writeln('Wrote ${fgFile.path} (${fgFile.lengthSync()} bytes)');

  stdout.writeln('Done. Run: dart run flutter_launcher_icons');
}

// ── Drawing helpers ─────────────────────────────────────────────────────

void _fillRadialGradient(
  img.Image image, {
  required List<int> centerColor,
  required List<int> edgeColor,
}) {
  final cx = image.width / 2;
  final cy = image.height / 2;
  final maxDist = (cx * cx + cy * cy);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final t = (dx * dx + dy * dy) / maxDist; // 0 at centre, 1 at corner
      final r = _lerp(centerColor[0], edgeColor[0], t);
      final g = _lerp(centerColor[1], edgeColor[1], t);
      final b = _lerp(centerColor[2], edgeColor[2], t);
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }
}

void _drawGlow(
  img.Image image, {
  required int cx,
  required int cy,
  required int radius,
  required List<int> color,
  required double intensity,
}) {
  final r2 = radius * radius;
  for (int y = cy - radius; y <= cy + radius; y++) {
    for (int x = cx - radius; x <= cx + radius; x++) {
      if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
      final dx = x - cx;
      final dy = y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2) continue;
      final t = 1.0 - (d2 / r2); // 1 at centre, 0 at edge
      final falloff = (t * t) * intensity;
      final p = image.getPixel(x, y);
      final r = _lerp(p.r.toInt(), color[0], falloff);
      final g = _lerp(p.g.toInt(), color[1], falloff);
      final b = _lerp(p.b.toInt(), color[2], falloff);
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }
}

/// Stylised claw: a thick red arc in the lower-right quadrant.
void _drawClaw(img.Image image) {
  final cx = image.width * 0.68;
  final cy = image.height * 0.66;
  final outer = image.width * 0.28;
  final inner = outer - image.width * 0.05;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final d = _dist(dx, dy);
      if (d < inner || d > outer) continue;
      // Only draw in a 120-degree wedge facing up-left
      final angle = _atan2(dy, dx);
      if (angle < -2.8 || angle > -0.3) continue;
      final p = image.getPixel(x, y);
      final tEdge = (1.0 - ((d - inner) / (outer - inner) - 0.5).abs() * 2)
          .clamp(0.0, 1.0);
      final r = _lerp(p.r.toInt(), _lobsterRed[0], tEdge * 0.85);
      final g = _lerp(p.g.toInt(), _lobsterRed[1], tEdge * 0.85);
      final b = _lerp(p.b.toInt(), _lobsterRed[2], tEdge * 0.85);
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }
}

/// Draws a bold stylised "P" using rectangles + a semi-circle.
void _drawLetter(img.Image image) {
  final cx = image.width * 0.5;
  final cy = image.height * 0.5;
  final height = image.height * 0.45;
  final stemW = image.width * 0.08;
  final bowlW = image.width * 0.25;
  final bowlH = height * 0.55;

  final stemX1 = (cx - bowlW / 2).round();
  final stemX2 = (cx - bowlW / 2 + stemW).round();
  final stemY1 = (cy - height / 2).round();
  final stemY2 = (cy + height / 2).round();

  // Stem
  _fillRect(image, stemX1, stemY1, stemX2, stemY2,
      const [0xFF, 0xFF, 0xFF], 255);

  // Bowl (top rectangle + curved right side as half-ellipse)
  final bowlCx = stemX2 + (bowlW - stemW) / 3;
  final bowlCy = stemY1 + bowlH / 2;
  final rx = bowlW * 0.5;
  final ry = bowlH * 0.5;
  for (int y = stemY1; y <= (stemY1 + bowlH).round(); y++) {
    for (int x = stemX2; x <= (stemX2 + bowlW).round(); x++) {
      if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
      final dx = (x - bowlCx) / rx;
      final dy = (y - bowlCy) / ry;
      final d2 = dx * dx + dy * dy;
      if (d2 > 1) continue;
      // Hollow inside
      final dx2 = (x - bowlCx) / (rx * 0.6);
      final dy2 = (y - bowlCy) / (ry * 0.55);
      if (dx2 * dx2 + dy2 * dy2 < 1) continue;
      image.setPixelRgba(x, y, 0xFF, 0xFF, 0xFF, 255);
    }
  }
}

void _drawRing(
  img.Image image, {
  required int radius,
  required int thickness,
  required List<int> color,
  required int alpha,
}) {
  final cx = image.width / 2;
  final cy = image.height / 2;
  final outerSq = radius * radius;
  final innerSq = (radius - thickness) * (radius - thickness);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 < innerSq || d2 > outerSq) continue;
      final p = image.getPixel(x, y);
      final t = alpha / 255.0;
      final r = _lerp(p.r.toInt(), color[0], t);
      final g = _lerp(p.g.toInt(), color[1], t);
      final b = _lerp(p.b.toInt(), color[2], t);
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }
}

void _fillRect(
  img.Image image,
  int x1,
  int y1,
  int x2,
  int y2,
  List<int> color,
  int alpha,
) {
  for (int y = y1; y <= y2; y++) {
    for (int x = x1; x <= x2; x++) {
      if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
      image.setPixelRgba(x, y, color[0], color[1], color[2], alpha);
    }
  }
}

int _lerp(int a, int b, double t) {
  return (a + (b - a) * t).clamp(0, 255).round();
}

double _dist(double dx, double dy) {
  return _sqrtApprox(dx * dx + dy * dy);
}

double _sqrtApprox(double v) => math.sqrt(v);

double _atan2(double y, double x) => math.atan2(y, x);
