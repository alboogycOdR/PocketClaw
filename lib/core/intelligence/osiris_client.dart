library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'intelligence_models.dart';

class OsirisClient {
  final String baseUrl;

  const OsirisClient({required this.baseUrl});

  Future<dynamic> _getJson(
    String path, {
    Map<String, String>? params,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Osiris $path returned ${response.statusCode}');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? params,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final body = await _getJson(path, params: params, timeout: timeout);
    if (body is Map<String, dynamic>) return body;
    return {'data': body};
  }

  List<dynamic> _extractList(dynamic body, List<String> preferredKeys) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      for (final key in preferredKeys) {
        final candidate = body[key];
        if (candidate is List) return candidate;
      }
      final features = body['features'];
      if (features is List) return features;
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  Future<List<EarthquakeEvent>> getEarthquakes() async {
    final body = await _getJson('/api/earthquakes');
    final items = _extractList(body, const ['earthquakes', 'items']);
    return items.whereType<Map<String, dynamic>>().map((item) {
      if (item.containsKey('geometry')) return EarthquakeEvent.fromGeoJson(item);
      return EarthquakeEvent.fromOsirisJson(item);
    }).toList();
  }

  Future<List<FlightState>> getFlights() async {
    final data = await _get('/api/flights');
    final states = data['states'];
    final flights = data['flights'];
    final commercial = data['commercial_flights'];
    final privateFlights = data['private_flights'];
    final privateJets = data['private_jets'];
    final military = data['military_flights'];
    final rawItems = states is List
        ? states
        : flights is List
        ? flights
        : [
            if (commercial is List) ...commercial,
            if (privateFlights is List) ...privateFlights,
            if (privateJets is List) ...privateJets,
            if (military is List) ...military,
          ];
    return rawItems.map((item) {
      if (item is List<dynamic>) return FlightState.fromOpenSky(item);
      if (item is Map<String, dynamic>) return FlightState.fromOsirisJson(item);
      return null;
    }).whereType<FlightState>()
        .where((flight) => flight.latitude != null && flight.longitude != null)
        .toList();
  }

  Future<List<FireHotspot>> getFires() async {
    final body = await _getJson('/api/fires');
    final items = _extractList(body, const ['fires', 'hotspots', 'items']);
    return items.whereType<Map<String, dynamic>>().map((item) {
      if (item.containsKey('geometry')) return FireHotspot.fromGeoJson(item);
      return FireHotspot.fromOsirisJson(item);
    }).toList();
  }

  Future<List<NewsItem>> getNews() async {
    final body = await _getJson('/api/news');
    final items = _extractList(body, const ['news', 'feeds', 'items']);
    return items.whereType<Map<String, dynamic>>().map((item) {
      if (item.containsKey('lon')) return NewsItem.fromJson(item);
      return NewsItem.fromOsirisJson(item);
    }).toList();
  }

  Future<List<ConflictZone>> getConflictZones() async {
    final body = await _getJson('/api/conflicts');
    final items = _extractList(body, const ['conflicts', 'zones', 'items']);
    return items.whereType<Map<String, dynamic>>().map((item) {
      if (item.containsKey('lon')) return ConflictZone.fromJson(item);
      return ConflictZone.fromOsirisJson(item);
    }).toList();
  }

  Future<List<SatellitePosition>> getSatellites() async {
    final body = await _getJson('/api/satellites');
    final items = _extractList(body, const ['satellites', 'items']);
    return items.whereType<Map<String, dynamic>>().map((item) {
      if (item.containsKey('satlng')) return SatellitePosition.fromJson(item);
      return SatellitePosition.fromOsirisJson(item);
    }).toList();
  }

  Future<List<MaritimePort>> getMaritimePorts() async {
    final body = await _getJson('/api/maritime');
    final items = _extractList(body, const ['ports']);
    return items.whereType<Map<String, dynamic>>()
        .map(MaritimePort.fromOsirisJson)
        .toList();
  }

  Future<List<MaritimeChokepoint>> getMaritimeChokepoints() async {
    final body = await _getJson('/api/maritime');
    final items = _extractList(body, const ['chokepoints']);
    return items.whereType<Map<String, dynamic>>()
        .map(MaritimeChokepoint.fromOsirisJson)
        .toList();
  }

  Future<List<WeatherEvent>> getWeatherEvents() async {
    final body = await _getJson('/api/weather');
    final items = _extractList(body, const ['events', 'weather']);
    return items.whereType<Map<String, dynamic>>()
        .map(WeatherEvent.fromOsirisJson)
        .toList();
  }

  Future<Map<String, dynamic>> dnsLookup(String domain) =>
      _get('/api/osint/dns', params: {'domain': domain});

  Future<Map<String, dynamic>> whoisLookup(String target) =>
      _get('/api/osint/whois', params: {'target': target});

  Future<Map<String, dynamic>> ipIntelligence(String ip) =>
      _get('/api/osint/ip', params: {'ip': ip});

  Future<Map<String, dynamic>> sslInspect(String domain) =>
      _get('/api/osint/ssl', params: {'domain': domain});

  Future<List<dynamic>> cveLookup(String keyword) async {
    final data = await _get('/api/osint/cve', params: {'q': keyword});
    return data['vulnerabilities'] as List? ?? const [];
  }

  Future<bool> isReachable() async {
    if (baseUrl.isEmpty) return false;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/earthquakes'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
