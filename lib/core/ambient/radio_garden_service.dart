/// Radio Garden HTTP client (unofficial reverse-engineered API).
///
/// Base: `https://radio.garden/api/ara/content`. All responses wrap the
/// payload in `{apiVersion, version, data: <T>}`. Callers get the
/// inner `data` — the envelope is stripped here.
///
/// ⚠ No SLA — the API isn't officially published and can break without
/// notice. Each call surfaces a clean exception so the UI can render an
/// empty state instead of a stack trace.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/ambient/models/radio_models.dart';

class RadioGardenService {
  static const _base = 'https://radio.garden/api';

  /// Browser-like headers. The site's edge (Cloudflare) returns HTTP
  /// 403 to the bare `Dart/<version>` User-Agent the http package
  /// sends by default. Mimicking a real Chrome on Android + sending
  /// the matching Referer gets through. If they crack down further
  /// we may need to rotate UAs or move to a proxy.
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; ClawCommander) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://radio.garden/',
  };

  final http.Client _http;
  List<RadioPlace>? _placesCache;
  DateTime? _placesCacheAt;

  RadioGardenService({http.Client? client}) : _http = client ?? http.Client();

  /// All cities globally that have at least one station. Cached
  /// in-memory for 24 hours — the list is ~1.4 MB and changes rarely.
  Future<List<RadioPlace>> listPlaces({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _placesCache != null &&
        _placesCacheAt != null &&
        DateTime.now().difference(_placesCacheAt!) < const Duration(hours: 24)) {
      return _placesCache!;
    }
    final res = await _http.get(
      Uri.parse('$_base/ara/content/places'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Radio Garden: HTTP ${res.statusCode} on /places');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final list = (data?['list'] as List?) ?? const [];
    final places = list
        .cast<Map<String, dynamic>>()
        .map(RadioPlace.fromJson)
        .toList(growable: false);
    _placesCache = places;
    _placesCacheAt = DateTime.now();
    return places;
  }

  /// Channels (stations) broadcasting from a specific place.
  Future<List<RadioChannel>> channelsForPlace(String placeId) async {
    final res = await _http.get(
      Uri.parse('$_base/ara/content/page/$placeId/channels'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception(
          'Radio Garden: HTTP ${res.statusCode} on /page/$placeId/channels');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final content = (data?['content'] as List?) ?? const [];
    // Real shape: data.content is a list of sections; each section has
    // `itemsType: "channel"` and `items: [{page: {url, title, place,
    // country, …}}, …]`. Take items from any channel-typed section.
    final channels = <RadioChannel>[];
    for (final section in content) {
      if (section is! Map) continue;
      if (section['itemsType'] != 'channel') continue;
      final items = (section['items'] as List?) ?? const [];
      for (final item in items) {
        if (item is! Map) continue;
        channels.add(RadioChannel.fromJson(item.cast<String, dynamic>()));
      }
    }
    return channels;
  }

  /// Free-text search across countries, places, and channels.
  Future<List<RadioSearchHit>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final res = await _http.get(
      Uri.parse('$_base/search?q=${Uri.encodeQueryComponent(trimmed)}'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Radio Garden: HTTP ${res.statusCode} on /search');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final hits = ((body['hits'] as Map?)?['hits'] as List?) ?? const [];
    final results = <RadioSearchHit>[];
    for (final hit in hits) {
      if (hit is! Map) continue;
      final source = (hit['_source'] as Map?)?.cast<String, dynamic>();
      if (source == null) continue;
      results.add(RadioSearchHit.fromJson(source));
    }
    return results;
  }

  void dispose() => _http.close();
}

final radioGardenService = RadioGardenService();
