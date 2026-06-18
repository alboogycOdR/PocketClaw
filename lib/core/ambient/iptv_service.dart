library;

import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/ambient/models/tv_channel.dart';
import 'tv_database.dart';

const _playlistUrl =
    'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8';
const _cacheKey = 'iptv_playlist_raw_v1';
const _cacheTimeKey = 'iptv_playlist_cached_at';
const _cacheMaxAgeHours = 12;
const _bundledImportAsset = 'assets/iptv/custom_import_playlist.m3u8';
const _bundledImportSeededKey = 'iptv_bundled_custom_import_seeded_v2';

class IptvService {
  Future<List<TvChannel>> getChannels(SharedPreferences prefs) async {
    await tvDatabase.ensureReady();

    final raw = await _fetchRaw(prefs);
    final hidden = await tvDatabase.getHiddenIds();
    final custom = await tvDatabase.getCustomChannels();

    final playlistChannels = raw == null
        ? <TvChannel>[]
        : parsePlaylist(
            raw,
          ).where((channel) => !hidden.contains(channel.id)).toList();
    final customVisible = custom
        .where((channel) => !hidden.contains(channel.id))
        .toList();
    final customUrls = customVisible
        .map((channel) => channel.streamUrl.trim())
        .toSet();
    final uniquePlaylistChannels = playlistChannels
        .where((channel) => !customUrls.contains(channel.streamUrl.trim()))
        .toList();

    return [...customVisible, ...uniquePlaylistChannels];
  }

  Future<int> seedBundledImport(SharedPreferences prefs) async {
    if (prefs.getBool(_bundledImportSeededKey) ?? false) return 0;

    await tvDatabase.ensureReady();
    final raw = await rootBundle.loadString(_bundledImportAsset);
    final channels = parsePlaylist(raw, asCustom: true);
    final inserted = await tvDatabase.addCustomChannels(channels);
    await prefs.setBool(_bundledImportSeededKey, true);
    return inserted;
  }

  List<String> getGroups(List<TvChannel> channels) {
    final groups =
        channels.map((channel) => channel.groupTitle).toSet().toList()
          ..sort((a, b) {
            if (a == 'Custom') return -1;
            if (b == 'Custom') return 1;
            return a.compareTo(b);
          });
    return groups;
  }

  List<TvChannel> byGroup(List<TvChannel> channels, String group) {
    return channels.where((channel) => channel.groupTitle == group).toList();
  }

  Future<void> invalidateCache(SharedPreferences prefs) async {
    await prefs.remove(_cacheTimeKey);
  }

  Future<String?> _fetchRaw(SharedPreferences prefs) async {
    final cachedAt = prefs.getInt(_cacheTimeKey) ?? 0;
    final ageHours =
        (DateTime.now().millisecondsSinceEpoch - cachedAt) / 3600000;

    if (ageHours < _cacheMaxAgeHours) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    try {
      final response = await http
          .get(Uri.parse(_playlistUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        await prefs.setString(_cacheKey, response.body);
        await prefs.setInt(
          _cacheTimeKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        return response.body;
      }
    } catch (_) {}

    return prefs.getString(_cacheKey);
  }

  List<TvChannel> parsePlaylist(String m3u8, {bool asCustom = false}) {
    final channels = <TvChannel>[];
    final lines = m3u8.split('\n');

    String? currentGroup;
    String? currentName;
    String? currentLogo;
    String? currentTvgId;
    String? currentTvgName;
    int? currentChannelNumber;
    var currentStreamType = TvStreamType.live;
    var isHD = true;
    var isGeo = false;
    var isYouTube = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('#EXTINF:')) {
        final attrs = _attrs(line);
        currentGroup = attrs['group-title'];
        currentLogo = attrs['tvg-logo'];
        currentTvgId = attrs['tvg-id'];
        currentTvgName = attrs['tvg-name'];
        currentChannelNumber = int.tryParse(attrs['tvg-chno'] ?? '');
        final comma = line.lastIndexOf(',');
        final rawName = comma >= 0 ? line.substring(comma + 1).trim() : '';
        final lowerName = rawName.toLowerCase();
        isHD = !rawName.contains('Ⓢ') && !lowerName.contains('480p');
        isGeo = rawName.contains('Ⓖ') || lowerName.contains('geo-blocked');
        isYouTube = rawName.contains('Ⓨ') || lowerName.contains('youtube');
        currentName = (rawName.isEmpty ? currentTvgName ?? '' : rawName)
            .replaceAll('Ⓢ', '')
            .replaceAll('Ⓖ', '')
            .replaceAll('Ⓨ', '')
            .replaceAll(RegExp(r'\s*\[Geo-blocked\]\s*'), ' ')
            .replaceAll(RegExp(r'\s*\[Not 24/7\]\s*'), ' ')
            .trim();
        currentStreamType = _streamType(currentGroup, '');
      } else if (line.isNotEmpty &&
          !line.startsWith('#') &&
          currentName != null) {
        final id = TvChannel.idFromUrl(line);
        channels.add(
          TvChannel(
            id: asCustom ? 'custom_$id' : id,
            name: currentName,
            groupTitle: currentGroup ?? 'International',
            streamUrl: line,
            logoUrl: currentLogo,
            tvgId: currentTvgId,
            tvgName: currentTvgName,
            channelNumber: currentChannelNumber,
            streamType: _streamType(currentGroup, line, currentStreamType),
            isHD: isHD,
            isGeoBlocked: isGeo,
            isYouTube: isYouTube,
            isCustom: asCustom,
          ),
        );
        currentGroup = null;
        currentName = null;
        currentLogo = null;
        currentTvgId = null;
        currentTvgName = null;
        currentChannelNumber = null;
        currentStreamType = TvStreamType.live;
        isHD = true;
        isGeo = false;
        isYouTube = false;
      }
    }

    return channels;
  }

  Map<String, String> _attrs(String line) {
    final attrs = <String, String>{};
    final regex = RegExp(r'([\w-]+)="([^"]*)"');
    for (final match in regex.allMatches(line)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }
    return attrs;
  }

  TvStreamType _streamType(
    String? group,
    String url, [
    TvStreamType fallback = TvStreamType.live,
  ]) {
    final groupLower = (group ?? '').toLowerCase();
    final urlLower = url.toLowerCase();
    if (groupLower.contains('series') || urlLower.contains('/series/')) {
      return TvStreamType.series;
    }
    if (groupLower.contains('movie') ||
        groupLower.contains('vod') ||
        urlLower.contains('/movie/')) {
      return TvStreamType.vod;
    }
    return fallback;
  }
}

final iptvService = IptvService();
