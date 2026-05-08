/// Settings screen with Gateway, Local Model, Security, and About sections
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/llm/model_registry.dart';
import '../../data/models/openclaw_models.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/hermes_providers.dart';
import '../../data/providers/ssh_providers.dart';
import '../../shared/constants.dart';
import '../../shared/widgets/connection_indicator.dart';
import 'device_identity_settings.dart';
import 'devices_screen.dart';
import 'gateway_config.dart';
import 'hermes_settings.dart';
import 'model_config.dart';
import 'models_screen.dart';
import 'paperclip_company_settings.dart';
import 'router_memory_settings.dart';
import 'security_settings.dart';
import 'ssh_settings.dart';

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
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.psychology_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text('Hermes Agent'),
                  subtitle: Consumer(
                    builder: (_, ref, __) {
                      final reachable = ref.watch(hermesReachableProvider);
                      final url = ref.watch(hermesBaseUrlProvider);
                      final configured = url.isNotEmpty;
                      return reachable.when(
                        data: (ok) {
                          final label = !configured
                              ? 'Not configured'
                              : ok
                                  ? 'Connected'
                                  : 'Unreachable';
                          final color = ok
                              ? Colors.tealAccent
                              : Colors.white54;
                          return Text(
                            label,
                            style: TextStyle(fontSize: 12, color: color),
                          );
                        },
                        loading: () => const Text(
                          'Checking…',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        error: (_, __) => const Text(
                          'Unreachable',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    },
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HermesSettings(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('Device Identity'),
                  subtitle: const Text(
                    'Ed25519 pairing key · view / reset',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DeviceIdentitySettings(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.devices_other),
                  title: const Text('Paired Devices'),
                  subtitle: Consumer(
                    builder: (_, ref, __) {
                      final devicesAsync =
                          ref.watch(openClawDevicesProvider);
                      return devicesAsync.when(
                        data: (devices) {
                          final pending =
                              devices.where((d) => d.isPending).length;
                          if (pending > 0) {
                            return Text(
                              '$pending pending approval',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            );
                          }
                          final paired =
                              devices.where((d) => d.isPaired).length;
                          return Text(
                            paired == 0
                                ? 'Manage paired devices'
                                : '$paired paired',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          );
                        },
                        loading: () => const Text(
                          'Loading…',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        error: (_, __) => const Text(
                          'Manage paired devices',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    },
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DevicesScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.memory_outlined),
                  title: const Text('OpenClaw Models'),
                  subtitle: Consumer(
                    builder: (_, ref, __) {
                      final modelsAsync =
                          ref.watch(openClawModelsProvider);
                      return modelsAsync.when(
                        data: (status) {
                          if (status.isEmpty) {
                            return const Text(
                              'No data — gateway offline?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            );
                          }
                          final defaultEntry =
                              status.configured.firstWhere(
                            (m) => m.id == status.defaultModel,
                            orElse: () => OpenClawModelEntry(
                              id: status.defaultModel ?? '',
                            ),
                          );
                          final ok = defaultEntry.isHealthy;
                          final label = status.alias?.isNotEmpty == true
                              ? status.alias!
                              : (status.defaultModel ?? 'unknown');
                          return Text(
                            ok ? '$label · healthy' : '$label · unhealthy',
                            style: TextStyle(
                              fontSize: 12,
                              color: ok
                                  ? Colors.tealAccent
                                  : const Color(0xFFFFB74D),
                            ),
                          );
                        },
                        loading: () => const Text(
                          'Loading…',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        error: (_, __) => const Text(
                          'Unavailable',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    },
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ModelsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.terminal),
                  title: const Text('Server SSH'),
                  subtitle: Consumer(
                    builder: (_, ref, __) {
                      final host = ref.watch(sshHostProvider);
                      final user = ref.watch(sshUsernameProvider);
                      if (host.isEmpty || user.isEmpty) {
                        return const Text(
                          'Not configured',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        );
                      }
                      final reachable = ref.watch(sshReachableProvider);
                      return reachable.when(
                        data: (ok) => Text(
                          ok
                              ? '$user@$host · connected'
                              : '$user@$host · unreachable',
                          style: TextStyle(
                            fontSize: 12,
                            color: ok
                                ? Colors.tealAccent
                                : const Color(0xFFFFB74D),
                          ),
                        ),
                        loading: () => Text(
                          '$user@$host · checking…',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        error: (_, __) => Text(
                          '$user@$host · error',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    },
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SshSettings(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.psychology_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text('Hermes Management'),
                  subtitle: const Text(
                    'Sessions · Memory · Cron · Skills · Logs (via SSH)',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () => context.push('/hermes'),
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
