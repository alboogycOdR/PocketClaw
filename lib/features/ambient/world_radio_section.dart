/// World Radio section — search Radio Garden's catalogue and stream
/// any station. Uses just_audio for the stream (already loaded for
/// Supertonic TTS).
///
/// Map view is deferred to a follow-up; v2.8.0 ships search +
/// place-browser + player.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/ambient/radio_garden_service.dart';
import '../../data/providers/ambient_providers.dart';
import 'models/radio_models.dart';

class WorldRadioSection extends ConsumerStatefulWidget {
  const WorldRadioSection({super.key});

  @override
  ConsumerState<WorldRadioSection> createState() => _WorldRadioSectionState();
}

class _WorldRadioSectionState extends ConsumerState<WorldRadioSection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(radioSearchQueryProvider);
    final activeChannel = ref.watch(activeRadioChannelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('World Radio',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
              const Spacer(),
              Text(
                'via radio.garden',
                style: TextStyle(
                  fontSize: 10,
                  color: PocketClawTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),

        // Search input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search cities, countries, stations…',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(radioSearchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
            ),
            onChanged: (v) =>
                ref.read(radioSearchQueryProvider.notifier).state = v,
          ),
        ),

        if (activeChannel != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _NowPlayingCard(channel: activeChannel),
          ),
        ],

        const SizedBox(height: 8),

        // Results / browse list
        if (query.trim().length >= 2)
          _SearchResults(query: query)
        else
          const _PopularPlaces(),
      ],
    );
  }
}

class _NowPlayingCard extends ConsumerWidget {
  final RadioChannel channel;
  const _NowPlayingCard({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(radioPlayerProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.radio, color: PocketClawTheme.electricTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${channel.placeTitle} · ${channel.country}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              color: PocketClawTheme.lobsterRed,
              onPressed: () {
                player.stop();
                ref.read(activeRadioChannelProvider.notifier).state = null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(radioSearchResultsProvider);
    return resultsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Search failed: $e',
          style:
              TextStyle(fontSize: 12, color: PocketClawTheme.lobsterRed),
        ),
      ),
      data: (hits) {
        if (hits.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No results',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          );
        }
        return Column(
          children: hits.take(40).map((h) => _SearchHitTile(hit: h)).toList(),
        );
      },
    );
  }
}

class _SearchHitTile extends ConsumerWidget {
  final RadioSearchHit hit;
  const _SearchHitTile({required this.hit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData icon;
    switch (hit.type) {
      case 'channel':
        icon = Icons.radio;
        break;
      case 'place':
        icon = Icons.location_city;
        break;
      case 'country':
        icon = Icons.public;
        break;
      default:
        icon = Icons.circle_outlined;
    }
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18),
      title: Text(hit.title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '${hit.type.toUpperCase()}${hit.subtitle.isEmpty ? '' : ' · ${hit.subtitle}'}',
        style: const TextStyle(fontSize: 10, color: Colors.white54),
      ),
      trailing: hit.type == 'channel'
          ? Icon(Icons.play_arrow, color: PocketClawTheme.electricTeal)
          : null,
      onTap: () async {
        if (hit.type == 'channel') {
          final channel = RadioChannel(
            id: hit.id,
            title: hit.title,
            country: '',
            placeTitle: hit.subtitle,
          );
          await _play(ref, channel);
        } else if (hit.type == 'place' && hit.id.isNotEmpty) {
          await _openPlace(context, hit.id, hit.title);
        }
      },
    );
  }

  Future<void> _play(WidgetRef ref, RadioChannel channel) async {
    final player = ref.read(radioPlayerProvider);
    ref.read(activeRadioChannelProvider.notifier).state = channel;
    try {
      await player.setUrl(channel.streamUrl);
      await player.play();
    } catch (_) {
      ref.read(activeRadioChannelProvider.notifier).state = null;
      rethrow;
    }
  }

  Future<void> _openPlace(
      BuildContext context, String placeId, String title) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => _PlaceChannelSheet(placeId: placeId, title: title),
    );
  }
}

class _PlaceChannelSheet extends ConsumerWidget {
  final String placeId;
  final String title;
  const _PlaceChannelSheet({required this.placeId, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<RadioChannel>>(
              future: radioGardenService.channelsForPlace(placeId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load: ${snap.error}',
                          style: TextStyle(
                              color: PocketClawTheme.lobsterRed,
                              fontSize: 12)),
                    ),
                  );
                }
                final channels = snap.data ?? const [];
                if (channels.isEmpty) {
                  return const Center(child: Text('No stations'));
                }
                return ListView.builder(
                  controller: controller,
                  itemCount: channels.length,
                  itemBuilder: (_, i) {
                    final ch = channels[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.radio, size: 18),
                      title: Text(ch.title,
                          style: const TextStyle(fontSize: 13)),
                      trailing: Icon(Icons.play_arrow,
                          color: PocketClawTheme.electricTeal),
                      onTap: () async {
                        final player = ref.read(radioPlayerProvider);
                        ref.read(activeRadioChannelProvider.notifier).state =
                            ch;
                        try {
                          await player.setUrl(ch.streamUrl);
                          await player.play();
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (_) {
                          ref
                              .read(activeRadioChannelProvider.notifier)
                              .state = null;
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularPlaces extends ConsumerWidget {
  const _PopularPlaces();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(radioPlacesProvider);
    return placesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Couldn\'t reach radio.garden: $e',
          style:
              TextStyle(fontSize: 12, color: PocketClawTheme.lobsterRed),
        ),
      ),
      data: (places) {
        // Sort by station count descending, take the top 50 so the
        // browse list isn't 30k entries on first open.
        final top = [...places]..sort((a, b) => b.size.compareTo(a.size));
        final shown = top.take(50).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Popular cities',
                style: TextStyle(
                    fontSize: 11,
                    color: PocketClawTheme.onSurfaceMuted,
                    letterSpacing: 0.5),
              ),
            ),
            for (final place in shown)
              ListTile(
                dense: true,
                leading: const Icon(Icons.location_city, size: 18),
                title: Text(place.title,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${place.country} · ${place.size} stations',
                  style:
                      const TextStyle(fontSize: 10, color: Colors.white54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,
                  builder: (_) => _PlaceChannelSheet(
                    placeId: place.id,
                    title: place.title,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
