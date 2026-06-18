library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/hermes_commander_theme.dart';
import '../../core/ambient/tv_database.dart';
import '../../data/providers/iptv_providers.dart';
import 'models/tv_channel.dart';
import 'models/tv_epg.dart';

class TvGuideScreen extends ConsumerStatefulWidget {
  const TvGuideScreen({super.key});

  @override
  ConsumerState<TvGuideScreen> createState() => _TvGuideScreenState();
}

class _TvGuideScreenState extends ConsumerState<TvGuideScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final sourceCount = ref.watch(epgSourcesProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Free TV Guide')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search guide channels',
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          if (sourceCount == 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _GuideStatus(
                icon: Icons.event_busy_outlined,
                text:
                    'Add an XMLTV source in Free TV settings to show programme listings.',
              ),
            ),
          Expanded(
            child: channelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Guide unavailable: $error')),
              data: (channels) {
                final visible = _filtered(channels).take(180).toList();
                if (visible.isEmpty) {
                  return const Center(child: Text('No matching channels'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _GuideChannelTile(channel: visible[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TvChannel> _filtered(List<TvChannel> channels) {
    if (_query.isEmpty) return channels;
    final query = _query.toLowerCase();
    return channels
        .where(
          (channel) =>
              channel.displayName.toLowerCase().contains(query) ||
              channel.groupTitle.toLowerCase().contains(query),
        )
        .toList();
  }
}

class _GuideChannelTile extends StatelessWidget {
  final TvChannel channel;

  const _GuideChannelTile({required this.channel});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.now().subtract(const Duration(minutes: 30));
    final end = DateTime.now().add(const Duration(hours: 8));
    return FutureBuilder<List<TvEpgProgramme>>(
      future: tvDatabase.getProgrammesForChannel(
        channelId: channel.id,
        start: start,
        end: end,
      ),
      builder: (context, snapshot) {
        final programmes = snapshot.data ?? const <TvEpgProgramme>[];
        final nowNext = _nowNext(programmes);
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideLogo(channel: channel),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        channel.groupTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: HCTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const LinearProgressIndicator(minHeight: 2)
                      else if (!nowNext.hasData)
                        const Text(
                          'No EPG data',
                          style: TextStyle(
                            fontSize: 12,
                            color: HCTheme.textMuted,
                          ),
                        )
                      else ...[
                        if (nowNext.current != null)
                          _ProgrammeLine(
                            label: 'Now',
                            programme: nowNext.current!,
                          ),
                        if (nowNext.next != null) ...[
                          const SizedBox(height: 8),
                          _ProgrammeLine(
                            label: 'Next',
                            programme: nowNext.next!,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  TvNowNext _nowNext(List<TvEpgProgramme> programmes) {
    final now = DateTime.now();
    TvEpgProgramme? current;
    TvEpgProgramme? next;
    for (final programme in programmes) {
      if (!programme.start.isAfter(now) && programme.stop.isAfter(now)) {
        current = programme;
      } else if (programme.start.isAfter(now) && next == null) {
        next = programme;
      }
      if (current != null && next != null) break;
    }
    return TvNowNext(current: current, next: next);
  }
}

class _ProgrammeLine extends StatelessWidget {
  final String label;
  final TvEpgProgramme programme;

  const _ProgrammeLine({required this.label, required this.programme});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: HCTheme.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                programme.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_time(programme.start)} - ${_time(programme.stop)}',
                style: const TextStyle(fontSize: 11, color: HCTheme.textMuted),
              ),
              if (programme.description?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  programme.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: HCTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _GuideLogo extends StatelessWidget {
  final TvChannel channel;

  const _GuideLogo({required this.channel});

  @override
  Widget build(BuildContext context) {
    final logo = channel.logoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        color: HCTheme.bgSurface,
        child: logo == null || logo.isEmpty
            ? const Icon(Icons.live_tv_outlined, size: 20)
            : CachedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.contain,
                memCacheWidth: 88,
                memCacheHeight: 88,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.live_tv_outlined, size: 20),
              ),
      ),
    );
  }
}

class _GuideStatus extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GuideStatus({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: HCTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: HCTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
