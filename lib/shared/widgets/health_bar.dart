/// Horizontal progress bar with label and percentage
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

class HealthBar extends StatelessWidget {
  final String label;
  final double percentage;
  final IconData? icon;

  const HealthBar({
    super.key,
    required this.label,
    required this.percentage,
    this.icon,
  });

  Color get _barColor {
    if (percentage >= 90) return PocketClawTheme.lobsterRed;
    if (percentage >= 70) return PocketClawTheme.warning;
    return PocketClawTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    final clampedPct = percentage.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              '${clampedPct.toStringAsFixed(1)}%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clampedPct / 100,
            minHeight: 6,
            backgroundColor: PocketClawTheme.surfaceContainerLow,
            valueColor: AlwaysStoppedAnimation<Color>(_barColor),
          ),
        ),
      ],
    );
  }
}
