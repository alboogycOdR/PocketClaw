/// Connection status indicator dot + label
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/gateway_event.dart';

class ConnectionIndicator extends StatelessWidget {
  final GatewayState state;
  final bool compact;

  const ConnectionIndicator({
    super.key,
    required this.state,
    this.compact = false,
  });

  Color get _color => switch (state) {
        GatewayState.connected => const Color(0xFF4CAF50),
        GatewayState.connecting ||
        GatewayState.reconnecting =>
          const Color(0xFFFFB74D),
        GatewayState.disconnected => const Color(0xFF00E5CC),
        GatewayState.error => const Color(0xFFE53935),
      };

  String get _label => switch (state) {
        GatewayState.connected => 'Online',
        GatewayState.connecting => 'Connecting',
        GatewayState.reconnecting => 'Reconnecting',
        GatewayState.disconnected => 'Local Only',
        GatewayState.error => 'Error',
      };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _color.withAlpha(120),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _color.withAlpha(120),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _color,
          ),
        ),
      ],
    );
  }
}
