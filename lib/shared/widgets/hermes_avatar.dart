library;

import 'package:flutter/material.dart';

import '../../app/hermes_commander_theme.dart';

class HermesAvatar extends StatelessWidget {
  final double size;

  const HermesAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1509),
        border: Border.all(color: HCTheme.goldMuted, width: 1),
        boxShadow: [
          BoxShadow(
            color: HCTheme.gold.withAlpha(38),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.psychology_alt_outlined,
          size: size * 0.55,
          color: HCTheme.gold,
        ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String initial;
  final double size;

  const UserAvatar({super.key, required this.initial, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF388BFD),
      const Color(0xFF3FB950),
      const Color(0xFFF0883E),
      const Color(0xFF9E6ADE),
    ];
    final color = colors[initial.codeUnitAt(0) % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'GeistSans',
            fontWeight: FontWeight.w600,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}
