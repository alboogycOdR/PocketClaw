library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../features/ambient/models/tv_channel.dart';
import '../../features/ambient/models/tv_epg.dart';
import 'tv_database.dart';

class TvEpgService {
  Future<TvEpgRefreshResult> addOrRefreshSource({
    required String name,
    required String url,
    required List<TvChannel> channels,
  }) async {
    await tvDatabase.ensureReady();
    final source = TvEpgSource(
      id: _sourceId(url),
      name: name.trim().isEmpty ? Uri.parse(url).host : name.trim(),
      url: url.trim(),
      lastRefresh: DateTime.now(),
    );
    return refreshSource(source: source, channels: channels);
  }

  Future<TvEpgRefreshResult> refreshSource({
    required TvEpgSource source,
    required List<TvChannel> channels,
  }) async {
    final response = await http
        .get(Uri.parse(source.url))
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('EPG source returned HTTP ${response.statusCode}.');
    }

    final parsed = parseBytes(response.bodyBytes, sourceId: source.id);
    final refreshedSource = TvEpgSource(
      id: source.id,
      name: source.name,
      url: source.url,
      enabled: source.enabled,
      lastRefresh: DateTime.now(),
    );
    await tvDatabase.replaceEpgData(
      source: refreshedSource,
      channels: parsed.channels,
      programmes: parsed.programmes,
    );
    final mapped = await autoMapChannels(channels);
    return TvEpgRefreshResult(
      source: refreshedSource,
      epgChannels: parsed.channels.length,
      programmes: parsed.programmes.length,
      mappedChannels: mapped,
    );
  }

  TvEpgParseResult parseBytes(List<int> bytes, {required String sourceId}) {
    List<int> decoded = bytes;
    try {
      decoded = gzip.decode(bytes);
    } catch (_) {
      decoded = bytes;
    }
    final xmlContent = utf8.decode(decoded, allowMalformed: true);
    return parseXml(xmlContent, sourceId: sourceId);
  }

  TvEpgParseResult parseXml(String xmlContent, {required String sourceId}) {
    final document = XmlDocument.parse(xmlContent);
    final tv = document.rootElement;
    final channels = <TvEpgChannel>[];
    final programmes = <TvEpgProgramme>[];

    for (final element in tv.findElements('channel')) {
      final channel = _parseChannel(element, sourceId);
      if (channel != null) channels.add(channel);
    }

    for (final element in tv.findElements('programme')) {
      final programme = _parseProgramme(element, sourceId);
      if (programme != null) programmes.add(programme);
    }

    return TvEpgParseResult(channels: channels, programmes: programmes);
  }

  Future<int> autoMapChannels(List<TvChannel> channels) async {
    await tvDatabase.ensureReady();
    final epgChannels = await tvDatabase.getEpgChannels();
    if (channels.isEmpty || epgChannels.isEmpty) return 0;

    final index = _EpgIndex.build(epgChannels);
    final mappings = <TvEpgMapping>[];

    for (final channel in channels) {
      final candidate = _bestCandidate(channel, epgChannels, index);
      if (candidate == null || candidate.confidence < 0.55) continue;
      mappings.add(
        TvEpgMapping(
          channelId: channel.id,
          epgChannelId: candidate.epgChannel.id,
          sourceId: candidate.epgChannel.sourceId,
          confidence: candidate.confidence,
          matchSource: candidate.reason,
          updatedAt: DateTime.now(),
        ),
      );
    }

    await tvDatabase.saveEpgMappings(mappings);
    return mappings.length;
  }

  TvEpgChannel? _parseChannel(XmlElement element, String sourceId) {
    final rawId = element.getAttribute('id');
    if (rawId == null || rawId.trim().isEmpty) return null;

    final displayNames = element
        .findElements('display-name')
        .map((node) => node.innerText.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final names = displayNames.isEmpty ? [rawId] : displayNames;
    final iconUrl = element
        .findElements('icon')
        .firstOrNull
        ?.getAttribute('src');
    final number = names.firstWhere(
      (name) => RegExp(r'^\d+$').hasMatch(name),
      orElse: () => '',
    );

    return TvEpgChannel(
      id: _epgChannelId(sourceId, rawId),
      sourceId: sourceId,
      channelId: rawId,
      displayNames: names,
      iconUrl: iconUrl,
      number: number.isEmpty ? null : number,
    );
  }

  TvEpgProgramme? _parseProgramme(XmlElement element, String sourceId) {
    final rawChannelId = element.getAttribute('channel');
    final startRaw = element.getAttribute('start');
    final stopRaw = element.getAttribute('stop');
    if (rawChannelId == null || startRaw == null || stopRaw == null) {
      return null;
    }

    final start = _parseXmltvDate(startRaw);
    final stop = _parseXmltvDate(stopRaw);
    if (start == null || stop == null || !stop.isAfter(start)) return null;

    final title = element.findElements('title').firstOrNull?.innerText.trim();
    if (title == null || title.isEmpty) return null;

    return TvEpgProgramme(
      epgChannelId: _epgChannelId(sourceId, rawChannelId),
      sourceId: sourceId,
      start: start,
      stop: stop,
      title: title,
      subtitle: element.findElements('sub-title').firstOrNull?.innerText.trim(),
      description: element.findElements('desc').firstOrNull?.innerText.trim(),
      category: element.findElements('category').firstOrNull?.innerText.trim(),
      iconUrl: element.findElements('icon').firstOrNull?.getAttribute('src'),
      episodeNum: element
          .findElements('episode-num')
          .firstOrNull
          ?.innerText
          .trim(),
    );
  }

  DateTime? _parseXmltvDate(String raw) {
    try {
      var value = raw.trim();
      var offset = Duration.zero;
      final tzMatch = RegExp(r'([+-]\d{4})$').firstMatch(value);
      if (tzMatch != null) {
        final tz = tzMatch.group(1)!;
        final sign = tz.startsWith('-') ? -1 : 1;
        final hours = int.parse(tz.substring(1, 3));
        final minutes = int.parse(tz.substring(3, 5));
        offset = Duration(hours: hours * sign, minutes: minutes * sign);
        value = value.substring(0, tzMatch.start).trim();
      }
      if (value.length < 14) value = value.padRight(14, '0');
      final year = int.parse(value.substring(0, 4));
      final month = int.parse(value.substring(4, 6));
      final day = int.parse(value.substring(6, 8));
      final hour = int.parse(value.substring(8, 10));
      final minute = int.parse(value.substring(10, 12));
      final second = int.parse(value.substring(12, 14));
      return DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
      ).subtract(offset).toLocal();
    } catch (error) {
      debugPrint('XMLTV date parse failed: $raw ($error)');
      return null;
    }
  }

  _MappingCandidate? _bestCandidate(
    TvChannel channel,
    List<TvEpgChannel> epgChannels,
    _EpgIndex index,
  ) {
    final candidates = <_MappingCandidate>[];

    final tvgId = channel.tvgId?.trim();
    if (tvgId != null && tvgId.isNotEmpty) {
      final exact = index.byRawId[tvgId] ?? index.byCompoundId[tvgId];
      if (exact != null) {
        candidates.add(_MappingCandidate(exact, 1.0, 'tvg-id'));
      }
      final normalized = _normalizeId(tvgId);
      final normalizedMatch = index.byNormalizedId[normalized];
      if (normalizedMatch != null) {
        candidates.add(_MappingCandidate(normalizedMatch, 0.94, 'tvg-id-norm'));
      }
    }

    if (candidates.any((candidate) => candidate.confidence >= 0.94)) {
      candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
      return candidates.first;
    }

    final number = channel.channelNumber?.toString();
    if (number != null) {
      final byNumber = index.byNumber[number];
      if (byNumber != null) {
        candidates.add(_MappingCandidate(byNumber, 0.52, 'channel-number'));
      }
    }

    final logoUrl = channel.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final byLogo = index.byIconUrl[logoUrl];
      if (byLogo != null) {
        candidates.add(_MappingCandidate(byLogo, 0.44, 'logo'));
      }
    }

    final cleaned = _cleanChannelName(channel.displayName);
    if (cleaned.isNotEmpty && !channel.displayName.contains('24/7')) {
      for (final epgChannel in epgChannels) {
        var best = 0.0;
        for (final name in epgChannel.displayNames) {
          final score = _nameScore(cleaned, _cleanChannelName(name));
          if (score > best) best = score;
        }
        if (best >= 0.55) {
          candidates.add(_MappingCandidate(epgChannel, best, 'name'));
        }
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.first;
  }

  String _sourceId(String url) => 'epg_${TvChannel.idFromUrl(url)}';

  String _epgChannelId(String sourceId, String channelId) =>
      '${sourceId}_${TvChannel.idFromUrl(channelId)}';

  String _normalizeId(String id) => id
      .toLowerCase()
      .replaceAll(RegExp(r'[._\-\s,()\[\]]'), '')
      .replaceAll(RegExp(r'(hd|fhd|uhd|4k|sd|hevc|h265|h264)$'), '');

  String _cleanChannelName(String name) {
    var cleaned = name.split(RegExp(r'\s*\|\s*')).last.trim();
    final callSign = RegExp(
      r'\(([WK][A-Z]{2,4})\)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (callSign != null) return callSign.group(1)!.toLowerCase();
    cleaned = cleaned
        .replaceAll(RegExp(r'^[A-Z]{2,3}\s*[:|/\-]\s*'), '')
        .replaceAll(
          RegExp(
            r'\b(HD|FHD|UHD|4K|SD|HEVC|H\.?265|H\.?264)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return cleaned;
  }

  double _nameScore(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 0.96;
    if (a.contains(b) || b.contains(a)) return 0.82;
    final aTokens = a.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();
    final bTokens = b.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    final intersection = aTokens.intersection(bTokens).length;
    final union = aTokens.union(bTokens).length;
    return union == 0 ? 0 : intersection / union;
  }
}

class TvEpgParseResult {
  final List<TvEpgChannel> channels;
  final List<TvEpgProgramme> programmes;

  const TvEpgParseResult({required this.channels, required this.programmes});
}

class TvEpgRefreshResult {
  final TvEpgSource source;
  final int epgChannels;
  final int programmes;
  final int mappedChannels;

  const TvEpgRefreshResult({
    required this.source,
    required this.epgChannels,
    required this.programmes,
    required this.mappedChannels,
  });
}

class _EpgIndex {
  final Map<String, TvEpgChannel> byRawId;
  final Map<String, TvEpgChannel> byCompoundId;
  final Map<String, TvEpgChannel> byNormalizedId;
  final Map<String, TvEpgChannel> byNumber;
  final Map<String, TvEpgChannel> byIconUrl;

  const _EpgIndex({
    required this.byRawId,
    required this.byCompoundId,
    required this.byNormalizedId,
    required this.byNumber,
    required this.byIconUrl,
  });

  factory _EpgIndex.build(List<TvEpgChannel> channels) {
    final byRawId = <String, TvEpgChannel>{};
    final byCompoundId = <String, TvEpgChannel>{};
    final byNormalizedId = <String, TvEpgChannel>{};
    final byNumber = <String, TvEpgChannel>{};
    final byIconUrl = <String, TvEpgChannel>{};
    final service = TvEpgService();
    for (final channel in channels) {
      byRawId[channel.channelId] = channel;
      byCompoundId[channel.id] = channel;
      byNormalizedId[service._normalizeId(channel.channelId)] = channel;
      for (final name in channel.displayNames) {
        byNormalizedId[service._normalizeId(name)] = channel;
      }
      final number = channel.number;
      if (number != null && number.isNotEmpty) byNumber[number] = channel;
      final icon = channel.iconUrl;
      if (icon != null && icon.isNotEmpty) byIconUrl[icon] = channel;
    }
    return _EpgIndex(
      byRawId: byRawId,
      byCompoundId: byCompoundId,
      byNormalizedId: byNormalizedId,
      byNumber: byNumber,
      byIconUrl: byIconUrl,
    );
  }
}

class _MappingCandidate {
  final TvEpgChannel epgChannel;
  final double confidence;
  final String reason;

  const _MappingCandidate(this.epgChannel, this.confidence, this.reason);
}

final tvEpgService = TvEpgService();
