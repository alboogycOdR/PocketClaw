library;

import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../app/app_flavor.dart';
import '../../app/hermes_commander_theme.dart';
import '../../app/theme.dart';
import '../../core/ambient/iptv_service.dart';
import '../../core/ambient/tv_epg_service.dart';
import '../../core/ambient/tv_database.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/iptv_providers.dart';
import 'models/tv_channel.dart';
import 'models/tv_epg.dart';

class FreeTvSection extends ConsumerWidget {
  const FreeTvSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showFavourites = ref.watch(iptvShowFavouritesProvider);
    final selectedGroup = ref.watch(iptvSelectedGroupProvider);
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final favouritesAsync = ref.watch(iptvFavouriteChannelsProvider);
    final groupsAsync = ref.watch(iptvGroupsProvider);
    final favouriteIds = ref.watch(iptvFavouriteIdsProvider).valueOrNull ?? {};
    final accent = kHermesOnlyMode
        ? HCTheme.gold
        : PocketClawTheme.electricTeal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.live_tv_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              const Text(
                'Free TV',
                style: TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Add custom channel',
                onPressed: () => _showAddChannelSheet(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.upload_file_outlined, size: 20),
                tooltip: 'Import M3U playlist',
                onPressed: () => _importPlaylist(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_view_week_outlined, size: 20),
                tooltip: 'TV guide',
                onPressed: () => context.push('/ambient/tv/guide'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                tooltip: 'Free TV settings',
                onPressed: () => context.push('/settings/tv'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh playlist',
                onPressed: () async {
                  final prefs = ref.read(sharedPrefsProvider);
                  await iptvService.invalidateCache(prefs);
                  ref.invalidate(iptvChannelsProvider);
                },
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: 'All',
                icon: Icons.public,
                selected: !showFavourites && selectedGroup == null,
                onTap: () {
                  ref.read(iptvShowFavouritesProvider.notifier).state = false;
                  ref.read(iptvSelectedGroupProvider.notifier).state = null;
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Favourites',
                icon: Icons.star_border,
                selected: showFavourites,
                onTap: () {
                  ref.read(iptvShowFavouritesProvider.notifier).state = true;
                  ref.read(iptvSelectedGroupProvider.notifier).state = null;
                },
              ),
              ...groupsAsync.when(
                data: (groups) => _prioritizedGroups(groups).map((group) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _FilterChip(
                      label: group,
                      selected: !showFavourites && selectedGroup == group,
                      onTap: () {
                        ref.read(iptvShowFavouritesProvider.notifier).state =
                            false;
                        ref.read(iptvSelectedGroupProvider.notifier).state =
                            group;
                      },
                    ),
                  );
                }).toList(),
                loading: () => const <Widget>[],
                error: (error, stackTrace) => const <Widget>[],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (showFavourites)
          _ChannelList(
            channelsAsync: favouritesAsync,
            favouriteIds: favouriteIds,
            emptyText:
                'No favourite TV channels yet. Long-press a channel to star it.',
          )
        else
          channelsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => _TvErrorState(error: error),
            data: (channels) {
              final visible = selectedGroup == null
                  ? channels
                  : iptvService.byGroup(channels, selectedGroup);
              return _ChannelList(
                channelsAsync: AsyncValue.data(visible),
                favouriteIds: favouriteIds,
                emptyText: 'No TV channels available for this filter.',
              );
            },
          ),
      ],
    );
  }

  List<String> _prioritizedGroups(List<String> groups) {
    const priority = ['Religion', 'Religious', 'Sport', 'Sports'];
    final available = groups.toSet();
    return [
      for (final group in priority)
        if (available.contains(group)) group,
      ...groups.where((group) => !priority.contains(group)),
    ];
  }

  void _showAddChannelSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddChannelSheet(),
    );
  }

  Future<void> _importPlaylist(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['m3u', 'm3u8', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    try {
      final file = result.files.single;
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Selected playlist is empty.');
      }

      final raw = utf8.decode(bytes, allowMalformed: true);
      final parsed = iptvService.parsePlaylist(raw, asCustom: true);
      if (parsed.isEmpty) {
        throw StateError('No channels found in this playlist.');
      }

      final currentChannels = await ref.read(iptvChannelsProvider.future);
      final existingUrls = currentChannels
          .map((channel) => channel.streamUrl.trim())
          .where((url) => url.isNotEmpty)
          .toSet();
      final uniqueUrls = <String>{};
      final importable = <TvChannel>[];

      for (final channel in parsed) {
        final url = channel.streamUrl.trim();
        if (url.isEmpty ||
            existingUrls.contains(url) ||
            uniqueUrls.contains(url)) {
          continue;
        }
        uniqueUrls.add(url);
        importable.add(channel);
      }

      final inserted = await tvDatabase.addCustomChannels(importable);
      final skipped = parsed.length - inserted;
      ref.invalidate(customChannelsProvider);
      ref.invalidate(iptvChannelsProvider);
      ref.invalidate(iptvGroupsProvider);
      final epgSources = await tvDatabase.getEpgSources();
      if (epgSources.isNotEmpty) {
        final updatedChannels = await ref.read(iptvChannelsProvider.future);
        await tvEpgService.autoMapChannels(updatedChannels);
        ref.invalidate(epgMappingCountProvider);
        ref.invalidate(tvNowNextProvider);
      }

      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported $inserted channels. Skipped $skipped duplicates.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Playlist import failed: $error')),
      );
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? HCTheme.gold : HCTheme.textSecondary;
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 14, color: color),
      selectedColor: HCTheme.goldBg,
      backgroundColor: HCTheme.bgSurface,
      checkmarkColor: HCTheme.gold,
      side: const BorderSide(color: HCTheme.border),
      labelStyle: TextStyle(
        fontFamily: 'GeistSans',
        fontSize: 12,
        color: color,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

class _ChannelList extends ConsumerWidget {
  final AsyncValue<List<TvChannel>> channelsAsync;
  final Set<String> favouriteIds;
  final String emptyText;

  const _ChannelList({
    required this.channelsAsync,
    required this.favouriteIds,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return channelsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => _TvErrorState(error: error),
      data: (channels) {
        if (channels.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Text(
              emptyText,
              style: const TextStyle(fontSize: 12, color: HCTheme.textMuted),
            ),
          );
        }
        return Column(
          children: channels.take(80).map((channel) {
            return _TvChannelTile(
              channel: channel,
              isFavourite: favouriteIds.contains(channel.id),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TvChannelTile extends ConsumerWidget {
  final TvChannel channel;
  final bool isFavourite;

  const _TvChannelTile({required this.channel, required this.isFavourite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowNext = ref.watch(tvNowNextProvider(channel)).valueOrNull;
    return ListTile(
      dense: true,
      leading: _ChannelLogo(channel: channel),
      title: Text(
        channel.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _subtitle(channel, nowNext),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: Colors.white54),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (channel.isGeoBlocked)
            const Icon(Icons.lock_outline, size: 16, color: HCTheme.textMuted),
          if (channel.isYouTube)
            const Icon(
              Icons.smart_display_outlined,
              size: 16,
              color: HCTheme.textMuted,
            ),
          Icon(
            isFavourite ? Icons.star : Icons.play_arrow,
            size: 18,
            color: isFavourite ? HCTheme.gold : HCTheme.statusGreen,
          ),
        ],
      ),
      onTap: () => context.push('/ambient/tv', extra: channel),
      onLongPress: () => _showChannelActions(context, ref),
    );
  }

  String _subtitle(TvChannel channel, TvNowNext? nowNext) {
    final current = nowNext?.current;
    if (current != null) {
      return 'Now: ${current.title} | ${_meta(channel)}';
    }
    final next = nowNext?.next;
    if (next != null) {
      return 'Next ${_time(next.start)}: ${next.title} | ${_meta(channel)}';
    }
    return _meta(channel);
  }

  String _meta(TvChannel channel) {
    final parts = <String>[
      channel.groupTitle,
      if (channel.isHD) 'HD' else 'SD',
      if (channel.channelNumber != null) '#${channel.channelNumber}',
      if (channel.isCustom) 'Custom',
      if (channel.isGeoBlocked) 'Geo-blocked',
      if (channel.isYouTube) 'YouTube',
    ];
    return parts.join(' | ');
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showChannelActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isFavourite ? Icons.star : Icons.star_border),
              title: Text(isFavourite ? 'Remove favourite' : 'Add favourite'),
              onTap: () async {
                if (isFavourite) {
                  await tvDatabase.removeFavourite(channel.id);
                } else {
                  await tvDatabase.addFavourite(channel);
                }
                ref.invalidate(iptvFavouriteIdsProvider);
                ref.invalidate(iptvFavouriteChannelsProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide broken channel'),
              onTap: () async {
                await tvDatabase.hideChannel(channel);
                ref.invalidate(iptvChannelsProvider);
                ref.invalidate(hiddenChannelsProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            if (channel.isCustom)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete custom channel'),
                onTap: () async {
                  await tvDatabase.deleteCustomChannel(channel.id);
                  ref.invalidate(customChannelsProvider);
                  ref.invalidate(iptvChannelsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy stream URL'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: channel.streamUrl));
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  final TvChannel channel;

  const _ChannelLogo({required this.channel});

  @override
  Widget build(BuildContext context) {
    final logoUrl = channel.logoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 42,
        color: HCTheme.bgSurface,
        child: logoUrl == null || logoUrl.isEmpty
            ? const Icon(Icons.live_tv_outlined, size: 20)
            : CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.contain,
                memCacheWidth: 84,
                memCacheHeight: 84,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (context, url) =>
                    const Icon(Icons.live_tv_outlined, size: 18),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.live_tv_outlined, size: 20),
              ),
      ),
    );
  }
}

class _TvErrorState extends ConsumerWidget {
  final Object error;

  const _TvErrorState({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.tv_off_outlined, color: HCTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            'Free TV playlist unavailable: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: HCTheme.textMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(iptvChannelsProvider),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _AddChannelSheet extends ConsumerStatefulWidget {
  const _AddChannelSheet();

  @override
  ConsumerState<_AddChannelSheet> createState() => _AddChannelSheetState();
}

class _AddChannelSheetState extends ConsumerState<_AddChannelSheet> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _group = TextEditingController(text: 'Custom');
  final _logo = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _group.dispose();
    _logo.dispose();
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
            'Add custom TV channel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Channel name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'HLS / M3U8 URL',
              hintText: 'https://example.com/channel.m3u8',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _group,
            decoration: const InputDecoration(labelText: 'Group'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _logo,
            decoration: const InputDecoration(labelText: 'Logo URL optional'),
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
                : const Icon(Icons.add),
            label: const Text('Add Channel'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    final group = _group.text.trim().isEmpty ? 'Custom' : _group.text.trim();
    final logo = _logo.text.trim();
    final uri = Uri.tryParse(url);

    if (name.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _error = 'Enter a channel name and a valid URL.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final exists = await tvDatabase.customChannelExists(url);
      if (exists) {
        setState(() {
          _saving = false;
          _error = 'That stream URL already exists.';
        });
        return;
      }

      await _probeUrl(uri);
      final channel = TvChannel(
        id: 'custom_${const Uuid().v4()}',
        name: name,
        groupTitle: group,
        streamUrl: url,
        logoUrl: logo.isEmpty ? null : logo,
        isCustom: true,
      );
      await tvDatabase.addCustomChannel(channel);
      ref.invalidate(customChannelsProvider);
      ref.invalidate(iptvChannelsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not verify stream: $error';
      });
    }
  }

  Future<void> _probeUrl(Uri uri) async {
    try {
      final response = await http.head(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 500) return;
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      if (!uri.path.toLowerCase().contains('.m3u8')) rethrow;
    }
  }
}
