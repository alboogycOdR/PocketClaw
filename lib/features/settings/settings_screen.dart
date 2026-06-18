/// Settings screen — four tabs: Connection · Models · Workspace · App.
///
/// Previously a 16-item flat ListView that scrolled ~4 600 px on a phone.
/// Now grouped semantically so each tab fits a single phone screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/app_flavor.dart';
import '../../app/hermes_commander_theme.dart';
import '../../app/theme.dart';
import '../../app/theme_provider.dart';
import '../../core/coaching/grow_state_machine.dart';
import '../../data/models/openclaw_models.dart';
import '../../data/providers/academy_providers.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/hermes_providers.dart';
import '../../data/providers/iptv_providers.dart';
import '../../data/providers/integration_providers.dart';
import '../../data/providers/intelligence_providers.dart';
import '../../data/providers/life_architect_providers.dart';
import '../../data/providers/server_providers.dart';
import '../../data/providers/ssh_providers.dart';
import '../../shared/constants.dart';
import '../../shared/widgets/agent_scope_badge.dart';
import '../../shared/widgets/connection_indicator.dart';
import 'device_identity_settings.dart';
import 'devices_screen.dart';
import 'gateway_config.dart';
import 'hermes_settings.dart';
import 'model_config.dart';
import 'models_screen.dart';
import 'agent_memory_settings.dart';
import 'open_notebook_settings.dart';
// Paperclip Company settings hidden 2026-05-08 — surface parked.
// import 'paperclip_company_settings.dart';
import 'router_memory_settings.dart';
import 'backup_restore_settings.dart';
import 'device_info_screen.dart';
import 'lan_scan_screen.dart';
import 'security_settings.dart';
import 'ssh_settings.dart';
import 'storage_settings_screen.dart';
import 'voice_settings_screen.dart';
import '../../data/providers/tts_providers.dart';
import 'osiris_settings.dart';

class SettingsScreen extends ConsumerWidget {
  final String? initialSection;

  const SettingsScreen({super.key, this.initialSection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kHermesOnlyMode) {
      return _HermesSettingsScreen(initialSection: initialSection);
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: const [AgentScopeBadge(), SizedBox(width: 8)],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: Icon(Icons.cable_outlined, size: 18),
                text: 'Connection',
              ),
              Tab(icon: Icon(Icons.memory_outlined, size: 18), text: 'Models'),
              Tab(
                icon: Icon(Icons.workspaces_outlined, size: 18),
                text: 'Workspace',
              ),
              Tab(icon: Icon(Icons.tune, size: 18), text: 'App'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ConnectionTab(),
            _ModelsTab(),
            _WorkspaceTab(),
            _AppTab(),
          ],
        ),
      ),
    );
  }
}

class _HermesSettingsScreen extends ConsumerWidget {
  final String? initialSection;

  const _HermesSettingsScreen({this.initialSection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <_HermesSettingsTile>[
      _HermesSettingsTile(
        section: 'hermes',
        icon: Icons.psychology_outlined,
        iconColor: HCTheme.gold,
        title: 'Hermes REST',
        subtitleBuilder: (_) => const _HermesStatusLine(),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const HermesSettings())),
      ),
      _HermesSettingsTile(
        section: 'ssh',
        icon: Icons.terminal,
        title: 'Hermes SSH',
        subtitleBuilder: (_) => const _SshStatusLine(),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SshSettings())),
      ),
      // Power User Feature Pack v2.9.0 — VPS tools clustered after the
      // SSH connection tile so they're discoverable next to the
      // credentials that power them.
      _HermesSettingsTile(
        section: 'terminal',
        icon: Icons.terminal_outlined,
        title: 'SSH Terminal',
        subtitle: 'Interactive shell over your SSH connection',
        onTap: () => context.push('/terminal'),
      ),
      _HermesSettingsTile(
        section: 'vps-monitor',
        icon: Icons.monitor_heart_outlined,
        title: 'VPS Monitor',
        subtitle: 'CPU, RAM, disk, services, top processes',
        onTap: () => context.push('/vps-monitor'),
      ),
      _HermesSettingsTile(
        section: 'briefing',
        icon: Icons.wb_sunny_outlined,
        title: 'Morning Briefing',
        subtitle: 'AI-curated Hacker News briefing · daily 07:00',
        onTap: () => context.push('/briefing'),
      ),
      _HermesSettingsTile(
        section: 'osiris',
        icon: Icons.public_outlined,
        title: 'Osiris Intelligence',
        subtitleBuilder: (_) => const _OsirisStatusLine(),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const OsirisSettings())),
      ),
      _HermesSettingsTile(
        section: 'agent-memory',
        icon: Icons.psychology_alt_outlined,
        title: 'AgentMemory',
        subtitleBuilder: (_) => const _AgentMemoryStatusLine(),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AgentMemorySettings())),
      ),
      _HermesSettingsTile(
        section: 'notebook',
        icon: Icons.menu_book_outlined,
        title: 'Open-Notebook',
        subtitleBuilder: (_) => const _OpenNotebookStatusLine(),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const OpenNotebookSettings())),
      ),
      _HermesSettingsTile(
        section: 'voice',
        icon: Icons.mic_outlined,
        title: 'Voice & Transcription',
        subtitle: 'Speech input and offline transcription',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const VoiceSettingsScreen())),
      ),
      _HermesSettingsTile(
        section: 'tts',
        icon: Icons.record_voice_over_outlined,
        title: 'Voice & TTS',
        subtitleBuilder: (_) => const _TtsStatusLine(),
        onTap: () => context.push('/settings/tts'),
      ),
      _HermesSettingsTile(
        section: 'ambient',
        icon: Icons.headphones_outlined,
        title: 'Ambient Audio',
        subtitle: 'Focus sounds, world radio, and free TV',
        onTap: () => context.go('/ambient'),
      ),
      _HermesSettingsTile(
        section: 'tv',
        icon: Icons.live_tv_outlined,
        title: 'Free TV',
        subtitleBuilder: (_) => const _TvStatusLine(),
        onTap: () => context.push('/settings/tv'),
      ),
      const _HermesSettingsTile(
        section: 'theme',
        icon: Icons.palette_outlined,
        title: 'Theme',
        subtitle: 'Hermes Commander Dark',
      ),
      _HermesSettingsTile(
        section: 'security',
        icon: Icons.security,
        title: 'Security & Privacy',
        subtitle: 'Biometric lock, battery access, local data controls',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SecuritySettings())),
      ),
      _HermesSettingsTile(
        section: 'backup',
        icon: Icons.save_alt_outlined,
        title: 'Backup & Restore',
        subtitle: 'Export and restore app settings',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BackupRestoreSettings()),
        ),
      ),
      _HermesSettingsTile(
        section: 'about',
        icon: Icons.info_outline,
        title: AppConstants.appName,
        subtitle:
            'Native mobile command centre for Hermes.\n${AppConstants.orgName}',
      ),
    ];

    final filtered = initialSection == null
        ? tiles
        : tiles.where((tile) => tile.section == initialSection).toList();
    final visibleTiles = filtered.isEmpty ? tiles : filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => visibleTiles[index].build(context),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: visibleTiles.length,
      ),
    );
  }
}

class _HermesSettingsTile {
  final String section;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final WidgetBuilder? subtitleBuilder;
  final VoidCallback? onTap;

  const _HermesSettingsTile({
    required this.section,
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.subtitleBuilder,
    this.onTap,
  });

  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle:
            subtitleBuilder?.call(context) ??
            (subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HCTheme.textSecondary,
                    ),
                  )),
        trailing: onTap == null ? null : const _Chevron(),
        onTap: onTap,
      ),
    );
  }
}

// ── Tab 1: Connection ────────────────────────────────────────────────────

class _ConnectionTab extends ConsumerWidget {
  const _ConnectionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewayState = ref.watch(gatewayStateProvider);
    final gatewayUrl = ref.watch(gatewayUrlProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                    Row(children: [ConnectionIndicator(state: gatewayState)]),
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
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GatewayConfig()),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(
                  Icons.psychology_outlined,
                  color: Color(0xFF7C3AED),
                ),
                title: const Text('Hermes Agent'),
                subtitle: const _HermesStatusLine(),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HermesSettings()),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.terminal),
                title: const Text('Server SSH'),
                subtitle: const _SshStatusLine(),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SshSettings())),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.wifi_find_outlined),
                title: const Text('Scan local network'),
                subtitle: const Text(
                  'Find Ollama / LM Studio / OpenClaw / Hermes on this WiFi',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LanScanScreen()),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: const Text('Device Identity'),
                subtitle: const Text(
                  'Ed25519 pairing key · view / reset',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeviceIdentitySettings(),
                  ),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.devices_other),
                title: const Text('Paired Devices'),
                subtitle: const _PairedDevicesStatusLine(),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DevicesScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Models ────────────────────────────────────────────────────────

class _ModelsTab extends ConsumerWidget {
  const _ModelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedModelIdProvider);
    final hasToken = ref.watch(hasHFTokenProvider);
    final tokenAvailable = hasToken.whenOrNull(data: (v) => v) ?? false;

    final catalogue = ref.watch(modelCatalogueProvider);
    final selectedModel = catalogue.cast<dynamic>().firstWhere(
      (m) => m.id == selectedId,
      orElse: () => null,
    );
    final modelLabel = selectedModel?.displayName ?? selectedId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.memory_outlined),
                title: const Text('OpenClaw Models'),
                subtitle: const _OpenClawModelsStatusLine(),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ModelsScreen())),
              ),
              const _ListDivider(),
              ListTile(
                leading: Icon(
                  Icons.memory,
                  color: PocketClawTheme.electricTeal,
                ),
                title: const Text('Local Model'),
                subtitle: Text(
                  '$modelLabel  ·  ${catalogue.length} available',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: PocketClawTheme.electricTeal,
                  ),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ModelConfig())),
              ),
              const _ListDivider(),
              ListTile(
                leading: Icon(
                  Icons.key_outlined,
                  color: tokenAvailable
                      ? PocketClawTheme.success
                      : PocketClawTheme.warning,
                ),
                title: const Text('HuggingFace Token'),
                subtitle: Text(
                  tokenAvailable
                      ? 'Token configured (secure storage)'
                      : 'Required for gated model downloads',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => showHfTokenDialog(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 3: Workspace (Paperclip + Hermes Mgmt + Routing) ─────────────────

class _WorkspaceTab extends ConsumerWidget {
  const _WorkspaceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.psychology_outlined,
                  color: Color(0xFF7C3AED),
                ),
                title: const Text('Hermes Management'),
                subtitle: const Text(
                  'Switch active server → Control tab '
                  '(Sessions · Memory · Cron · Skills · Logs · Analytics)',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                // The standalone /hermes route was removed in Phase 2.
                // Hermes management is now embedded in the Control tab
                // when the active server is Hermes — flip the server
                // and route the user there.
                onTap: () async {
                  await setActiveServer(ref, ActiveServer.hermes);
                  if (context.mounted) context.go('/control');
                },
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.alt_route),
                title: const Text('Smart Router & Memory'),
                subtitle: const Text(
                  'Token budget, active project',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RouterMemorySettings(),
                  ),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Knowledge Base'),
                subtitle: const Text(
                  'Index docs the local model can cite (RAG)',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => context.push('/knowledge-base'),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.workspaces_outline),
                title: const Text('Swarm / Conductor'),
                subtitle: const Text(
                  'Launch and monitor multi-worker Hermes missions',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => context.push('/swarm'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 4: App (Modes · Security · About) ────────────────────────────────

class _AppTab extends ConsumerWidget {
  const _AppTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(themeIdProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme'),
                subtitle: Text(
                  themeId.displayName,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => _pickTheme(context, ref, themeId),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Academy Mode'),
                subtitle: const _AcademyStatusLine(),
                trailing: const _Chevron(),
                onTap: () => context.push('/settings/academy'),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.self_improvement_outlined),
                title: const Text('Life Architect'),
                subtitle: const _LifeArchitectStatusLine(),
                trailing: const _Chevron(),
                onTap: () => context.push('/settings/life-architect'),
              ),
              const _ListDivider(),
              // Commercial onboarding wizard hidden 2026-05-08 — it
              // configures Paperclip URL/WS/token alongside the gateway,
              // which is dead surface while Paperclip is parked. Restore
              // when Paperclip's tab is restored.
              //
              // ListTile(
              //   leading: const Icon(Icons.rocket_launch_outlined),
              //   title: const Text('Commercial onboarding'),
              //   subtitle: const Text(
              //     'Gateway + Paperclip wizard',
              //     style: TextStyle(fontSize: 12, color: Colors.white54),
              //   ),
              //   trailing: const _Chevron(),
              //   onTap: () => context.push('/onboarding/commercial'),
              // ),
              // const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.mic_outlined),
                title: const Text('Voice & Transcription'),
                subtitle: const Text(
                  'Whisper models for offline STT',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VoiceSettingsScreen(),
                  ),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Voice & TTS'),
                subtitle: const _TtsStatusLine(),
                trailing: const _Chevron(),
                onTap: () => context.push('/settings/tts'),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.live_tv_outlined),
                title: const Text('Free TV'),
                subtitle: const _TvStatusLine(),
                trailing: const _Chevron(),
                onTap: () => context.push('/settings/tv'),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Storage'),
                subtitle: const Text(
                  'Models · cache · orphan cleanup',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StorageSettingsScreen(),
                  ),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.smartphone_outlined),
                title: const Text('Device Info'),
                subtitle: const Text(
                  'Hardware · active model · acceleration',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeviceInfoScreen()),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('Security & Privacy'),
                subtitle: const Text(
                  'Biometric lock, battery access, clear data',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SecuritySettings()),
                ),
              ),
              const _ListDivider(),
              ListTile(
                leading: const Icon(Icons.save_alt_outlined),
                title: const Text('Backup & Restore'),
                subtitle: const Text(
                  'Save settings to a file, reload on a fresh install',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BackupRestoreSettings(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('\u{1F980}', style: TextStyle(fontSize: 40)),
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
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
                const SizedBox(height: 12),
                Text(
                  kHermesOnlyMode
                      ? 'Native mobile command centre for Hermes Agent.'
                      : 'Your personal AI agent, always in your pocket.',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeId current,
  ) async {
    final picked = await showModalBottomSheet<ThemeId>(
      context: context,
      useSafeArea: true,
      builder: (sheet) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Choose a theme',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              for (final id in ThemeId.values)
                RadioListTile<ThemeId>(
                  value: id,
                  groupValue: current,
                  title: Text(id.displayName),
                  onChanged: (v) => Navigator.of(sheet).pop(v),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      await ref.read(themeIdProvider.notifier).setTheme(picked);
    }
  }
}

// ── Reusable bits ────────────────────────────────────────────────────────

class _Chevron extends StatelessWidget {
  const _Chevron();
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.chevron_right, color: Colors.white38);
}

class _ListDivider extends StatelessWidget {
  const _ListDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 16, endIndent: 16);
}

class _HermesStatusLine extends ConsumerWidget {
  const _HermesStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachable = ref.watch(hermesReachableProvider);
    final url = ref.watch(hermesBaseUrlProvider);
    final configured = url.isNotEmpty;
    return reachable.when(
      data: (ok) {
        final label = !configured
            ? 'Not configured'
            : (ok ? 'Connected' : 'Unreachable');
        final color = ok ? Colors.tealAccent : Colors.white54;
        return Text(label, style: TextStyle(fontSize: 12, color: color));
      },
      loading: () => const Text(
        'Checking…',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
      error: (_, __) => const Text(
        'Unreachable',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

class _SshStatusLine extends ConsumerWidget {
  const _SshStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(sshHostProvider);
    final user = ref.watch(sshUsernameProvider);
    if (host.isEmpty || user.isEmpty) {
      return const Text(
        'Not configured',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }
    final reachable = ref.watch(sshReachableProvider);
    return reachable.when(
      data: (ok) => Text(
        ok ? '$user@$host · connected' : '$user@$host · unreachable',
        style: TextStyle(
          fontSize: 12,
          color: ok ? PocketClawTheme.success : PocketClawTheme.warning,
        ),
      ),
      loading: () => Text(
        '$user@$host · checking…',
        style: const TextStyle(fontSize: 12, color: Colors.white54),
      ),
      error: (_, __) => Text(
        '$user@$host · error',
        style: const TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

class _OsirisStatusLine extends ConsumerWidget {
  const _OsirisStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(osirisBaseUrlProvider);
    final reachable = ref.watch(osirisReachableProvider);
    if (baseUrl.trim().isEmpty) {
      return const Text(
        'Not configured',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }
    return reachable.when(
      data: (ok) => Text(
        ok ? 'Connected' : 'Unreachable',
        style: TextStyle(
          fontSize: 12,
          color: ok ? PocketClawTheme.success : PocketClawTheme.warning,
        ),
      ),
      loading: () => const Text(
        'Checking…',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
      error: (_, __) => const Text(
        'Error',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

class _AgentMemoryStatusLine extends ConsumerWidget {
  const _AgentMemoryStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(agentMemoryBaseUrlProvider);
    final reachable = ref.watch(agentMemoryReachableProvider);
    if (baseUrl.trim().isEmpty) {
      return const Text(
        'Not configured',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }
    return reachable.when(
      data: (ok) => Text(
        ok ? 'Connected' : 'Unreachable',
        style: TextStyle(
          fontSize: 12,
          color: ok ? PocketClawTheme.success : PocketClawTheme.warning,
        ),
      ),
      loading: () => const Text(
        'Checking…',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
      error: (_, __) => const Text(
        'Error',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

class _OpenNotebookStatusLine extends ConsumerWidget {
  const _OpenNotebookStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(openNotebookBaseUrlProvider);
    final reachable = ref.watch(openNotebookReachableProvider);
    if (baseUrl.trim().isEmpty) {
      return const Text(
        'Not configured',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }
    return reachable.when(
      data: (ok) => Text(
        ok ? 'Connected' : 'Unreachable',
        style: TextStyle(
          fontSize: 12,
          color: ok ? PocketClawTheme.success : PocketClawTheme.warning,
        ),
      ),
      loading: () => const Text(
        'Checking…',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
      error: (_, __) => const Text(
        'Error',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

class _PairedDevicesStatusLine extends ConsumerWidget {
  const _PairedDevicesStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(openClawDevicesProvider);
    return devicesAsync.when(
      data: (devices) {
        final pending = devices.where((d) => d.isPending).length;
        if (pending > 0) {
          return Text(
            '$pending pending approval',
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          );
        }
        final paired = devices.where((d) => d.isPaired).length;
        return Text(
          paired == 0 ? 'Manage paired devices' : '$paired paired',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        );
      },
      loading: () => const Text(
        'Loading…',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
      error: (_, __) => const Text(
        'Manage paired devices',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

class _OpenClawModelsStatusLine extends ConsumerWidget {
  const _OpenClawModelsStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(openClawModelsProvider);
    return modelsAsync.when(
      data: (status) {
        if (status.isEmpty) {
          return const Text(
            'No data — gateway offline?',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          );
        }
        final defaultEntry = status.configured.firstWhere(
          (m) => m.id == status.defaultModel,
          orElse: () => OpenClawModelEntry(id: status.defaultModel ?? ''),
        );
        final ok = defaultEntry.isHealthy;
        final label = status.alias?.isNotEmpty == true
            ? status.alias!
            : (status.defaultModel ?? 'unknown');
        return Text(
          ok ? '$label · healthy' : '$label · unhealthy',
          style: TextStyle(
            fontSize: 12,
            color: ok ? PocketClawTheme.success : PocketClawTheme.warning,
          ),
        );
      },
      loading: () => const Text(
        'Loading…',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
      error: (_, __) => const Text(
        'Unavailable',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

class _AcademyStatusLine extends ConsumerWidget {
  const _AcademyStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(academyProvider);
    if (!state.isActive) {
      return const Text(
        'Off',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }
    return Text(
      '${state.subject} · ${state.level}'
      '${state.streakDays > 0 ? " · ${state.streakDays}🔥" : ""}',
      style: TextStyle(fontSize: 12, color: PocketClawTheme.electricTeal),
    );
  }
}

class _TtsStatusLine extends ConsumerWidget {
  const _TtsStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readyAsync = ref.watch(supertonicModelsReadyProvider);
    final voice = ref.watch(activeVoiceIdProvider);
    final ready = readyAsync.valueOrNull ?? false;
    return Text(
      ready ? 'Supertonic · $voice · Offline' : 'System TTS · Tap to upgrade',
      style: TextStyle(
        fontSize: 12,
        color: ready ? PocketClawTheme.electricTeal : Colors.white54,
      ),
    );
  }
}

class _TvStatusLine extends ConsumerWidget {
  const _TvStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenChannelsProvider).valueOrNull ?? const [];
    final custom = ref.watch(customChannelsProvider).valueOrNull ?? const [];
    final parts = <String>[
      if (custom.isNotEmpty) '${custom.length} custom',
      if (hidden.isNotEmpty) '${hidden.length} hidden',
    ];
    return Text(
      parts.isEmpty ? 'Manage custom and hidden channels' : parts.join(' | '),
      style: const TextStyle(fontSize: 12, color: Colors.white54),
    );
  }
}

class _LifeArchitectStatusLine extends ConsumerWidget {
  const _LifeArchitectStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lifeArchitectProvider);
    if (!state.isActive) {
      return const Text(
        'Off',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }
    final grow = ref.watch(growSessionProvider);
    final facetSuffix = state.activeFacets.isNotEmpty
        ? ' · ${state.activeFacets.length} coaches'
        : '';
    return Text(
      'Active · GROW: ${grow.currentPhase.name.toUpperCase()}$facetSuffix',
      style: TextStyle(fontSize: 12, color: PocketClawTheme.electricTeal),
    );
  }
}
