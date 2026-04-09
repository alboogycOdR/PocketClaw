/// Settings screen with Gateway, Local Model, Security, and About sections
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/constants.dart';
import '../../shared/widgets/connection_indicator.dart';
import 'gateway_config.dart';
import 'model_config.dart';
import 'security_settings.dart';

/// Map model IDs to user-friendly display names.
const _modelDisplayNames = <String, String>{
  'gemma-4-e2b': 'Gemma 4 E2B',
  'qwen3-0.6b': 'Qwen3 0.6B',
  'smollm-135m': 'SmolLM 135M',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewayState = ref.watch(gatewayStateProvider);
    final gatewayUrl = ref.watch(gatewayUrlProvider);
    final selectedModel = ref.watch(selectedModelIdProvider);
    final modelLabel =
        _modelDisplayNames[selectedModel] ?? selectedModel;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Gateway Connection
          _SectionTitle(title: 'Gateway Connection'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Gateway Status'),
                  subtitle: Row(
                    children: [
                      ConnectionIndicator(state: gatewayState),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GatewayConfig(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Gateway URL'),
                  subtitle: Text(
                    gatewayUrl.isEmpty ? 'Not configured' : gatewayUrl,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GatewayConfig(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Local Model
          _SectionTitle(title: 'Local Model'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.memory,
                    color: PocketClawTheme.electricTeal,
                  ),
                  title: const Text('Current Model'),
                  subtitle: Text(
                    modelLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: PocketClawTheme.electricTeal,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ModelConfig(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Manage Models'),
                  subtitle: const Text(
                    'Select or download models',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ModelConfig(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Security
          _SectionTitle(title: 'Security'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Security & Privacy'),
              subtitle: const Text(
                'Biometric lock, clear data',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.white38,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SecuritySettings(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // About
          _SectionTitle(title: 'About'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '🦀',
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConstants.appName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v${AppConstants.appVersion}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConstants.orgName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your personal AI agent, always in your pocket.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white60,
          ),
    );
  }
}
