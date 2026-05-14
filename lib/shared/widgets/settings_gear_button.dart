/// Tiny shared widget — the gear icon that appears in every top-level
/// screen's AppBar after Settings was moved out of the bottom nav in
/// v2.8.0 to make room for the Ambient tab. Centralised here so we
/// don't drift on icon size / tooltip / route across screens.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsGearButton extends StatelessWidget {
  const SettingsGearButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined, size: 20),
      tooltip: 'Settings',
      onPressed: () => context.push('/settings'),
    );
  }
}
