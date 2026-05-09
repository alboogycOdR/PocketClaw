/// Welcome/splash screen with logo, tagline, and Get Started button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/router.dart' as app_router;
import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';
import 'gateway_setup.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: PocketClawTheme.lobsterRed.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PocketClawTheme.lobsterRed.withAlpha(60),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '🦀',
                    style: TextStyle(fontSize: 56),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Pocket Claw',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              // Tagline
              Text(
                'Your personal AI agent,\nalways in your pocket.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Features list
              const SizedBox(height: 32),
              _FeatureRow(
                icon: Icons.flash_on,
                text: 'Local-first, private by default',
                color: PocketClawTheme.electricTeal,
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.cloud_sync,
                text: 'Sync with your OpenClaw gateway',
                color: PocketClawTheme.lobsterRed,
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.extension,
                text: 'Extensible skills system',
                color: PocketClawTheme.amber,
              ),

              const Spacer(flex: 2),

              // Get Started button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GatewaySetup(),
                      ),
                    );
                  },
                  child: const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Skip to app
              TextButton(
                onPressed: () async {
                  final prefs = ref.read(sharedPrefsProvider);
                  await prefs.setBool('onboarded', true);
                  app_router.hasOnboarded = true;
                  if (context.mounted) context.go('/');
                },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.white38),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
