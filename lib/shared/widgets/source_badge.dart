/// Source badge chip showing LOCAL / SERVER / BRIDGE
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/chat_message.dart';

class SourceBadge extends StatelessWidget {
  final MessageSource source;

  const SourceBadge({super.key, required this.source});

  Color get _color => switch (source) {
        MessageSource.local => PocketClawTheme.amber,
        MessageSource.server => PocketClawTheme.bronze,
        MessageSource.bridge => PocketClawTheme.warning,
        MessageSource.device => const Color(0xFF7C4DFF),
      };

  String get _label => switch (source) {
        MessageSource.local => 'LOCAL',
        MessageSource.server => 'SERVER',
        MessageSource.bridge => 'BRIDGE',
        MessageSource.device => 'DEVICE',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withAlpha(80), width: 0.5),
      ),
      child: Text(
        _label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: _color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
