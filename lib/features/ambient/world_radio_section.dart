/// World Radio section — search Radio Garden's catalogue and stream
/// any station. Uses just_audio for the stream (already loaded for
/// Supertonic TTS).
///
/// Map view is deferred to a follow-up; v2.8.0 ships search +
/// place-browser + player.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/app_flavor.dart';
import '../../app/hermes_commander_theme.dart';
import '../../app/theme.dart';
import '../../core/ambient/radio_garden_service.dart';
import '../../data/providers/ambient_providers.dart';
import 'models/favorite_station.dart';
import 'models/radio_models.dart';

class WorldRadioSection extends ConsumerStatefulWidget {
  const WorldRadioSection({super.key});

  @override
  ConsumerState<WorldRadioSection> createState() => _WorldRadioSectionState();
}

class _WorldRadioSectionState extends ConsumerState<WorldRadioSection> {
  final _searchController = TextEditingController();
  StreamSubscription? _icySub;

  @override
  void dispose() {
    _searchController.dispose();
    _icySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(radioSearchQueryProvider);
    final activeChannel = ref.watch(activeRadioChannelProvider);

    // Subscribe to ICY metadata (artist/song info embedded in some
    // streams) whenever the active channel flips. Broadcasters either
    // send this every ~10s or not at all; the now-playing line on the
    // card just hides when nothing has arrived.
    ref.listen<RadioChannel?>(activeRadioChannelProvider, (prev, next) {
      _icySub?.cancel();
      _icySub = null;
      ref.read(radioNowPlayingProvider.notifier).state = null;
      if (next == null) return;
      final player = ref.read(radioPlayerProvider);
      _icySub = player.icyMetadataStream.listen((meta) {
        final title = meta?.info?.title;
        if (title == null || title.isEmpty) return;
        if (!mounted) return;
        ref.read(radioNowPlayingProvider.notifier).state = title;
      });
    });

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

        // Favorites — only renders when there's anything starred.
        const _FavoritesSection(),

        // Results / browse list
        if (query.trim().length >= 2)
          _SearchResults(query: query)
        else
          const _PopularPlaces(),
      ],
    );
  }
}

class _FavoritesSection extends ConsumerWidget {
  const _FavoritesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(radioFavoritesProvider);
    if (favs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(Icons.star,
                  size: 14, color: (kHermesOnlyMode ? HCTheme.gold : PocketClawTheme.electricTeal)),
              const SizedBox(width: 6),
              Text(
                'Favorites',
                style: TextStyle(
                  fontSize: 11,
                  color: PocketClawTheme.onSurfaceMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        for (final fav in favs)
          ListTile(
            dense: true,
            leading: Icon(Icons.radio,
                size: 18, color: (kHermesOnlyMode ? HCTheme.gold : PocketClawTheme.electricTeal)),
            title: Text(fav.title,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              '${fav.placeTitle}${fav.country.isEmpty ? '' : ' · ${fav.country}'}',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.star, color: Colors.amber),
                  tooltip: 'Unfavorite',
                  onPressed: () => ref
                      .read(radioFavoritesProvider.notifier)
                      .remove(fav.channelId),
                ),
                Icon(Icons.play_arrow,
                    color: (kHermesOnlyMode ? HCTheme.gold : PocketClawTheme.electricTeal)),
              ],
            ),
            onTap: () async {
              final channel = RadioChannel(
                id: fav.channelId,
                title: fav.title,
                country: fav.country,
                placeTitle: fav.placeTitle,
              );
              final player = ref.read(radioPlayerProvider);
              ref.read(activeRadioChannelProvider.notifier).state = channel;
              try {
                await player.setUrl(channel.streamUrl);
                await player.play();
              } catch (_) {
                ref.read(activeRadioChannelProvider.notifier).state = null;
              }
            },
          ),
        const SizedBox(height: 4),
        const Divider(height: 1, indent: 16, endIndent: 16),
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
    final nowPlaying = ref.watch(radioNowPlayingProvider);
    final isFav =
        ref.watch(radioFavoritesProvider).any((f) => f.channelId == channel.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.radio, color: (kHermesOnlyMode ? HCTheme.gold : PocketClawTheme.electricTeal)),
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
                    channel.country.isEmpty
                        ? channel.placeTitle
                        : '${channel.placeTitle} · ${channel.country}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (nowPlaying != null && nowPlaying.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.music_note,
                            size: 11,
                            color: (kHermesOnlyMode ? HCTheme.gold : PocketClawTheme.electricTeal)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            nowPlaying,
                            style: TextStyle(
                              fontSize: 11,
                              color: (kHermesOnlyMode ? HCTheme.gold : PocketClawTheme.electricTeal),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(isFav ? Icons.star : Icons.star_border),
              color: isFav ? Colors.amber : Colors.white54,
              tooltip: isFav ? 'Unfavorite' : 'Add to favorites',
              onPressed: () =>
                  ref.read(radioFavoritesProvider.notifier).toggle(
                        FavoriteStation(
                          channelId: channel.id,
                          title: channel.title,
                          placeTitle: channel.placeTitle,
                          country: channel.country,
                          savedAt: DateTime.now(),
                        ),
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
          ? Icon(Icons.play_arrow, color: (kHermesOnlyMode ? HCTheme.gold : PocketClawTheme.electricTeal))
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
                    return _ChannelRow(channel: ch);
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

/// Channel row used inside the place-detail sheet. Tap the row to
/// play the station; tap the star to (un)favorite without dismissing
/// the sheet.
class _ChannelRow extends ConsumerWidget {
  final RadioChannel channel;
  const _ChannelRow({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref
        .watch(radioFavoritesProvider)
        .any((f) => f.channelId == channel.id);
    return ListTile(
      dense: true,
      leading: const Icon(Icons.radio, size: 18),
      title: Text(channel.title, style: const TextStyle(fontSize: 13)),
      subtitle: channel.country.isEmpty
          ? null
          : Text(channel.country,
              style: const TextStyle(fontSize: 10, color: Colors.white54)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            icon: Icon(isFav ? Icons.star : Icons.star_border),
            color: isFav ? Colors.amber : Colors.white54,
            tooltip: isFav ? 'Unfavorite' : 'Add to favorites',
            onPressed: () =>
                ref.read(radioFavoritesProvider.notifier).toggle(
                      FavoriteStation(
                        channelId: channel.id,
                        title: channel.title,
                        placeTitle: channel.placeTitle,
                        country: channel.country,
                        savedAt: DateTime.now(),
                      ),
                    ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.play_arrow, color: (kHermesOnlyMode ? HCTheme.gold : PocketClawTheme.electricTeal)),
        ],
      ),
      onTap: () async {
        final player = ref.read(radioPlayerProvider);
        ref.read(activeRadioChannelProvider.notifier).state = channel;
        try {
          await player.setUrl(channel.streamUrl);
          await player.play();
          if (context.mounted) Navigator.of(context).pop();
        } catch (_) {
          ref.read(activeRadioChannelProvider.notifier).state = null;
        }
      },
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
        // Top cities by station count for the quick-pick row, then
        // every country alphabetised below so anywhere off the global
        // top-N (South Africa, NZ, smaller-market countries) is still
        // one tap away.
        final byStations = [...places]..sort((a, b) => b.size.compareTo(a.size));
        final topCities = byStations.take(30).toList();

        final byCountry = <String, List<RadioPlace>>{};
        for (final p in places) {
          if (p.country.isEmpty) continue;
          byCountry.putIfAbsent(p.country, () => []).add(p);
        }
        final countries = byCountry.keys.toList()..sort();

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
            for (final place in topCities)
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
            const SizedBox(height: 8),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Browse by country',
                style: TextStyle(
                    fontSize: 11,
                    color: PocketClawTheme.onSurfaceMuted,
                    letterSpacing: 0.5),
              ),
            ),
            for (final country in countries)
              ListTile(
                dense: true,
                leading: const Icon(Icons.public, size: 18),
                title: Text(country,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${byCountry[country]!.length} cities · '
                  '${byCountry[country]!.fold<int>(0, (s, p) => s + p.size)} stations',
                  style:
                      const TextStyle(fontSize: 10, color: Colors.white54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (_) => _CountryCitySheet(
                    country: country,
                    cities: byCountry[country]!,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CountryCitySheet extends ConsumerWidget {
  final String country;
  final List<RadioPlace> cities;
  const _CountryCitySheet({required this.country, required this.cities});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = [...cities]..sort((a, b) => b.size.compareTo(a.size));
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
                const Icon(Icons.public, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(country,
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
            child: ListView.builder(
              controller: controller,
              itemCount: sorted.length,
              itemBuilder: (_, i) {
                final place = sorted[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_city, size: 18),
                  title: Text(place.title,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '${place.size} stations',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white54),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      useSafeArea: true,
                      builder: (_) => _PlaceChannelSheet(
                        placeId: place.id,
                        title: place.title,
                      ),
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
