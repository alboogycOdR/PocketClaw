library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/hermes_commander_theme.dart';
import '../../core/ambient/iptv_service.dart';
import '../../core/ambient/tv_epg_service.dart';
import '../../core/ambient/tv_database.dart';
import '../../core/device/battery_optimization_service.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/iptv_providers.dart';
import '../ambient/models/tv_epg.dart';

class TvSettingsScreen extends ConsumerWidget {
  const TvSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenAsync = ref.watch(hiddenChannelsProvider);
    final customAsync = ref.watch(customChannelsProvider);
    final epgSourcesAsync = ref.watch(epgSourcesProvider);
    final programmeCount = ref.watch(epgProgrammeCountProvider).valueOrNull;
    final mappingCount = ref.watch(epgMappingCountProvider).valueOrNull;

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
          const _SectionLabel('Programme Guide'),
          Card(
            margin: EdgeInsets.zero,
            child: epgSourcesAsync.when(
              loading: () => const _LoadingTile(),
              error: (error, _) => _ErrorTile(error: error),
              data: (sources) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_view_week_outlined),
                      title: const Text('EPG sources'),
                      subtitle: Text(
                        '${sources.length} sources | ${programmeCount ?? 0} programmes | ${mappingCount ?? 0} mapped channels',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HCTheme.textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add XMLTV source',
                        onPressed: () => _showAddEpgSourceSheet(context, ref),
                      ),
                    ),
                    for (final source in sources)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.event_note_outlined,
                          size: 18,
                        ),
                        title: Text(source.name),
                        subtitle: Text(
                          source.lastRefresh == null
                              ? source.url
                              : 'Updated ${_formatDateTime(source.lastRefresh!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: 'Refresh EPG',
                              onPressed: () =>
                                  _refreshEpgSource(context, ref, source),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Delete EPG source',
                              onPressed: () async {
                                final confirm = await _confirm(
                                  context,
                                  title: 'Delete EPG source?',
                                  body:
                                      '"${source.name}" and its programme data will be removed.',
                                  action: 'Delete',
                                  destructive: true,
                                );
                                if (confirm != true) return;
                                await tvDatabase.deleteEpgSource(source.id);
                                ref.invalidate(epgSourcesProvider);
                                ref.invalidate(epgProgrammeCountProvider);
                                ref.invalidate(epgMappingCountProvider);
                                ref.invalidate(tvNowNextProvider);
                              },
                            ),
                          ],
                        ),
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showAddEpgSourceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddEpgSourceSheet(
        onSave: (name, url) async {
          final channels = await ref.read(iptvChannelsProvider.future);
          final result = await tvEpgService.addOrRefreshSource(
            name: name,
            url: url,
            channels: channels,
          );
          ref.invalidate(epgSourcesProvider);
          ref.invalidate(epgProgrammeCountProvider);
          ref.invalidate(epgMappingCountProvider);
          ref.invalidate(tvNowNextProvider);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'EPG loaded: ${result.programmes} programmes, ${result.mappedChannels} mapped channels.',
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshEpgSource(
    BuildContext context,
    WidgetRef ref,
    TvEpgSource source,
  ) async {
    try {
      final channels = await ref.read(iptvChannelsProvider.future);
      final result = await tvEpgService.refreshSource(
        source: source,
        channels: channels,
      );
      ref.invalidate(epgSourcesProvider);
      ref.invalidate(epgProgrammeCountProvider);
      ref.invalidate(epgMappingCountProvider);
      ref.invalidate(tvNowNextProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'EPG refreshed: ${result.programmes} programmes, ${result.mappedChannels} mapped channels.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('EPG refresh failed: $error')));
    }
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

class _AddEpgSourceSheet extends StatefulWidget {
  final Future<void> Function(String name, String url) onSave;

  const _AddEpgSourceSheet({required this.onSave});

  @override
  State<_AddEpgSourceSheet> createState() => _AddEpgSourceSheetState();
}

class _AddEpgSourceSheetState extends State<_AddEpgSourceSheet> {
  final _name = TextEditingController(text: 'XMLTV Guide');
  final _url = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add XMLTV EPG source',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Source name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'XMLTV URL',
              hintText: 'https://example.com/guide.xml.gz',
            ),
            keyboardType: TextInputType.url,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: HCTheme.statusRed, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: const Text('Load EPG'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _error = 'Enter a valid XMLTV URL.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(name, url);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not load EPG: $error';
      });
    }
  }
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
