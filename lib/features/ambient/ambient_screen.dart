/// Ambient tab — three sub-features each in their own tab so only one
/// feature is in view at a time:
///   • Focus   — Office + Nature focus-sound mixers
///   • Radio   — Radio Garden world radio
///   • TV      — IPTV / Free TV
/// Each tab body scrolls independently. Settings gear stays in the
/// AppBar (Ambient took the 5th bottom-nav slot in v2.8.0).
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ambient'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.spa_outlined, size: 18), text: 'Focus'),
              Tab(icon: Icon(Icons.radio_outlined, size: 18), text: 'Radio'),
              Tab(icon: Icon(Icons.live_tv_outlined, size: 18), text: 'TV'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OfficeSoundsSection(),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  NatureSoundsSection(),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 32),
              child: WorldRadioSection(),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 32),
              child: FreeTvSection(),
            ),
          ],
        ),
      ),
    );
  }
}
