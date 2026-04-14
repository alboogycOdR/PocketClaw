/// Settings screen with Gateway, Local Model, Security, and About sections
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/llm/model_registry.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/constants.dart';
import '../../shared/widgets/connection_indicator.dart';
import 'gateway_config.dart';
import 'model_config.dart';
import 'paperclip_company_settings.dart';
import 'router_memory_settings.dart';
import 'security_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewayState = ref.watch(gatewayStateProvider);
    final gatewayUrl = ref.watch(gatewayUrlProvider);
    final selectedId = ref.watch(selectedModelIdProvider);
    final hasToken = ref.watch(hasHFTokenProvider);
    final tokenAvailable = hasToken.whenOrNull(data: (v) => v) ?? false;

    // Look up model display name from the registry
    final selectedModel = kAvailableModels.cast<dynamic>().firstWhere(
          (m) => m.id == selectedId,
          orElse: () => null,
        );
    final modelLabel = selectedModel?.displayName ?? selectedId;

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
                  title: const Text('OpenClaw Gateway'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        ConnectionIndicator(state: gatewayState),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        gatewayUrl.isEmpty ? 'Not configured' : gatewayUrl,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    '$modelLabel  \u00b7  ${kAvailableModels.length} available',
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
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Paperclip & routing
          _SectionTitle(title: 'AI Company & routing'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.business_center,
                    color: PocketClawTheme.electricTeal,
                  ),
                  title: const Text('Paperclip Company'),
                  subtitle: const Text(
                    'REST + WebSocket, mission, budgets',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PaperclipCompanySettings(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.alt_route),
                  title: const Text('Smart Router & Memory'),
                  subtitle: const Text(
                    'Token budget, active project',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RouterMemorySettings(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // HuggingFace Token
          _SectionTitle(title: 'HuggingFace Token'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.key_outlined,
                color: tokenAvailable
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFFB74D),
              ),
              title: const Text('API Token'),
              subtitle: Text(
                tokenAvailable
                    ? 'Token configured (secure storage)'
                    : 'Required for gated model downloads',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.white38,
              ),
              onTap: () => showHfTokenDialog(context, ref),
            ),
          ),

          const SizedBox(height: 24),

          // Vertical modes (preview)
          _SectionTitle(title: 'Modes'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Academy Mode'),
                  subtitle: const Text(
                    'Curriculum tutoring shell',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () => context.push('/academy'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.self_improvement_outlined),
                  title: const Text('Life Architect'),
                  subtitle: const Text(
                    'GROW + safety preview',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () => context.push('/life-architect'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.rocket_launch_outlined),
                  title: const Text('Commercial onboarding'),
                  subtitle: const Text(
                    'Gateway + Paperclip wizard',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () => context.push('/onboarding/commercial'),
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
                    '\u{1F980}',
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
