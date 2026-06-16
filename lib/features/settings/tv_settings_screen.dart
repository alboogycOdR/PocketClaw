library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/hermes_commander_theme.dart';
import '../../core/ambient/iptv_service.dart';
import '../../core/ambient/tv_database.dart';
import '../../core/device/battery_optimization_service.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/iptv_providers.dart';

class TvSettingsScreen extends ConsumerWidget {
  const TvSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenAsync = ref.watch(hiddenChannelsProvider);
    final customAsync = ref.watch(customChannelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Free TV Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SectionLabel('Playback'),
          const Card(
            margin: EdgeInsets.zero,
            child: _BatteryOptimisationTile(),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Hidden Channels'),
          Card(
            margin: EdgeInsets.zero,
            child: hiddenAsync.when(
              loading: () => const _LoadingTile(),
              error: (error, _) => _ErrorTile(error: error),
              data: (hidden) {
                if (hidden.isEmpty) {
                  return const ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('No hidden channels'),
                    subtitle: Text(
                      'Broken channels you hide will appear here.',
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final channel in hidden)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.tv_off_outlined, size: 18),
                        title: Text(channel['name'] as String? ?? 'Channel'),
                        subtitle: Text(
                          channel['stream_url'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            await tvDatabase.unhideChannel(
                              channel['id'] as String,
                            );
                            ref.invalidate(hiddenChannelsProvider);
                            ref.invalidate(iptvChannelsProvider);
                          },
                          child: const Text('Restore'),
                        ),
                      ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('Restore all hidden channels'),
                      onTap: () async {
                        final confirm = await _confirm(
                          context,
                          title: 'Restore all channels?',
                          body: 'All hidden channels will be visible again.',
                          action: 'Restore',
                        );
                        if (confirm != true) return;
                        await tvDatabase.clearAllHidden();
                        ref.invalidate(hiddenChannelsProvider);
                        ref.invalidate(iptvChannelsProvider);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Custom Channels'),
          Card(
            margin: EdgeInsets.zero,
            child: customAsync.when(
              loading: () => const _LoadingTile(),
              error: (error, _) => _ErrorTile(error: error),
              data: (channels) {
                if (channels.isEmpty) {
                  return const ListTile(
                    leading: Icon(Icons.live_tv_outlined),
                    title: Text('No custom channels'),
                    subtitle: Text(
                      'Add channels from the Ambient Free TV section.',
                    ),
                  );
                }
                return Column(
                  children: channels.map((channel) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.live_tv_outlined, size: 18),
                      title: Text(channel.name),
                      subtitle: Text(
                        channel.groupTitle,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final confirm = await _confirm(
                            context,
                            title: 'Delete channel?',
                            body: '"${channel.name}" will be removed.',
                            action: 'Delete',
                            destructive: true,
                          );
                          if (confirm != true) return;
                          await tvDatabase.deleteCustomChannel(channel.id);
                          ref.invalidate(customChannelsProvider);
                          ref.invalidate(iptvChannelsProvider);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Playlist'),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Force refresh playlist'),
              subtitle: const Text(
                'The Free-TV/IPTV playlist is cached for 12 hours.',
                style: TextStyle(fontSize: 12, color: HCTheme.textSecondary),
              ),
              onTap: () async {
                final prefs = ref.read(sharedPrefsProvider);
                await iptvService.invalidateCache(prefs);
                ref.invalidate(iptvChannelsProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Playlist refresh queued')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: HCTheme.statusRed)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _BatteryOptimisationTile extends StatefulWidget {
  const _BatteryOptimisationTile();

  @override
  State<_BatteryOptimisationTile> createState() =>
      _BatteryOptimisationTileState();
}

class _BatteryOptimisationTileState extends State<_BatteryOptimisationTile>
    with WidgetsBindingObserver {
  bool? _exempt;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _checking = true);
    final exempt =
        await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _exempt = exempt;
      _checking = false;
    });
  }

  Future<void> _openBatterySettings() async {
    await BatteryOptimizationService.requestExemption();
    await BatteryOptimizationService.markAsked();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _exempt == true;
    return ListTile(
      leading: Icon(
        enabled
            ? Icons.battery_charging_full_outlined
            : Icons.battery_saver_outlined,
        color: enabled ? HCTheme.statusGreen : HCTheme.gold,
      ),
      title: const Text('Battery optimisation'),
      subtitle: Text(
        _checking
            ? 'Checking Android battery state...'
            : enabled
            ? 'Unrestricted battery use is enabled'
            : 'Allow unrestricted battery use so TV keeps playing during sleep',
        style: const TextStyle(fontSize: 12, color: HCTheme.textSecondary),
      ),
      trailing: enabled
          ? const Icon(Icons.check_circle_outline, color: HCTheme.statusGreen)
          : const Icon(Icons.chevron_right),
      onTap: _openBatterySettings,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'GeistMono',
          fontSize: 11,
          color: HCTheme.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text('Loading...'),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final Object error;

  const _ErrorTile({required this.error});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.error_outline, color: HCTheme.statusRed),
      title: const Text('Could not load TV settings'),
      subtitle: Text('$error'),
    );
  }
}
