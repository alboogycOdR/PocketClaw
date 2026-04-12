/// Legacy onboarding model download screen — superseded by the
/// CommercialWizardScreen (multi-step wizard at /onboarding/commercial)
/// and the Models screen (Settings > Current Model).
///
/// Kept as a no-op shell so router.dart doesn't 404 if anything still
/// links here. New flow should push directly to /packs or the Models
/// screen.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ModelDownload extends StatelessWidget {
  const ModelDownload({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Model')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.memory, size: 48, color: Colors.white38),
              const SizedBox(height: 16),
              const Text(
                'Local model setup has moved',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open Settings \u2192 Current Model to pick and download '
                'a local model.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/settings'),
                child: const Text('Go to Settings'),
              ),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
