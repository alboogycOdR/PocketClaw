/// Ambient tab — Focus Sounds (multi-channel mixer) + World Radio
/// (Radio Garden integration). Single scrollable screen hosting both
/// sections. Settings gear moved to AppBar overflow when Ambient took
/// the 5th bottom-nav slot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'free_tv_section.dart';
import 'nature_sounds_section.dart';
import 'office_sounds_section.dart';
import 'world_radio_section.dart';

class AmbientScreen extends ConsumerWidget {
  const AmbientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambient'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OfficeSoundsSection(),
            Divider(height: 1, indent: 16, endIndent: 16),
            NatureSoundsSection(),
            Divider(height: 1, indent: 16, endIndent: 16),
            WorldRadioSection(),
            Divider(height: 1, indent: 16, endIndent: 16),
            FreeTvSection(),
          ],
        ),
      ),
    );
  }
}
