library;

class EarthquakeEvent {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final double latitude;
  final double longitude;
  final double depth;

  const EarthquakeEvent({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.depth,
  });

  factory EarthquakeEvent.fromGeoJson(Map<String, dynamic> json) {
    final props = json['properties'] as Map<String, dynamic>? ?? {};
    final coords = json['geometry']?['coordinates'] as List? ?? const [0, 0, 0];
    final lon = coords.isNotEmpty ? (coords[0] as num?)?.toDouble() ?? 0 : 0.0;
    final lat = coords.length > 1 ? (coords[1] as num?)?.toDouble() ?? 0 : 0.0;
    final depth = coords.length > 2
        ? (coords[2] as num?)?.toDouble() ?? 0
        : 0.0;
    return EarthquakeEvent(
      id: json['id'] as String? ?? '',
      magnitude: (props['mag'] as num?)?.toDouble() ?? 0,
      place: props['place'] as String? ?? '',
      time: DateTime.fromMillisecondsSinceEpoch(
        (props['time'] as num?)?.toInt() ?? 0,
      ),
      latitude: lat,
      longitude: lon,
      depth: depth,
    );
  }

  factory EarthquakeEvent.fromOsirisJson(Map<String, dynamic> json) {
    return EarthquakeEvent(
      id: json['id'] as String? ?? '',
      magnitude: (json['magnitude'] as num?)?.toDouble() ?? 0,
      place: json['place'] as String? ?? '',
      time: DateTime.fromMillisecondsSinceEpoch(
        (json['time'] as num?)?.toInt() ?? 0,
      ),
      latitude: (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0,
      depth: (json['depth'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FlightState {
  final String icao24;
  final String? callsign;
  final String? country;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? velocity;
  final double? heading;
  final String? model;
  final String? registration;
  final String? squawk;
  final String? airlineCode;
  final String? aircraftCategory;
  final String? category;
  final bool onGround;

  const FlightState({
    required this.icao24,
    this.callsign,
    this.country,
    this.latitude,
    this.longitude,
    this.altitude,
    this.velocity,
    this.heading,
    this.model,
    this.registration,
    this.squawk,
    this.airlineCode,
    this.aircraftCategory,
    this.category,
    required this.onGround,
  });

  factory FlightState.fromOpenSky(List<dynamic> s) => FlightState(
    icao24: s[0] as String? ?? '',
    callsign: (s[1] as String?)?.trim(),
    country: s[2] as String?,
    latitude: (s[6] as num?)?.toDouble(),
    longitude: (s[5] as num?)?.toDouble(),
    altitude: (s[7] as num?)?.toDouble(),
    onGround: s[8] == true,
    velocity: (s[9] as num?)?.toDouble(),
    heading: (s[10] as num?)?.toDouble(),
  );

  factory FlightState.fromOsirisJson(Map<String, dynamic> json) => FlightState(
    icao24: json['icao24'] as String? ?? json['id'] as String? ?? '',
    callsign: (json['callsign'] as String?)?.trim(),
    country: json['country'] as String?,
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lng'] as num?)?.toDouble(),
    altitude: (json['altitude'] as num?)?.toDouble() ??
        (json['alt'] as num?)?.toDouble(),
    velocity: (json['velocity'] as num?)?.toDouble() ??
        (json['speed_knots'] as num?)?.toDouble(),
    heading: (json['heading'] as num?)?.toDouble(),
    model: json['model'] as String?,
    registration: json['registration'] as String?,
    squawk: json['squawk'] as String?,
    airlineCode: json['airline_code'] as String?,
    aircraftCategory: json['aircraft_category'] as String?,
    category: json['category'] as String?,
    onGround: json['onGround'] == true || json['on_ground'] == true,
  );
}

class FireHotspot {
  final double latitude;
  final double longitude;
  final double brightness;
  final double confidence;

  const FireHotspot({
    required this.latitude,
    required this.longitude,
    required this.brightness,
    required this.confidence,
  });

  factory FireHotspot.fromGeoJson(Map<String, dynamic> json) {
    final coords = json['geometry']?['coordinates'] as List? ?? const [0, 0];
    final props = json['properties'] as Map<String, dynamic>? ?? {};
    final lon = coords.isNotEmpty ? (coords[0] as num?)?.toDouble() ?? 0 : 0.0;
    final lat = coords.length > 1 ? (coords[1] as num?)?.toDouble() ?? 0 : 0.0;
    return FireHotspot(
      latitude: lat,
      longitude: lon,
      brightness: (props['brightness'] as num?)?.toDouble() ?? 0,
      confidence: (props['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  factory FireHotspot.fromOsirisJson(Map<String, dynamic> json) {
    return FireHotspot(
      latitude: (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NewsItem {
  final String id;
  final String title;
  final String source;
  final String? url;
  final String? streamUrl;
  final double? latitude;
  final double? longitude;

  const NewsItem({
    required this.id,
    required this.title,
    required this.source,
    this.url,
    this.streamUrl,
    this.latitude,
    this.longitude,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
    id: json['id'] as String? ?? json['source'] as String? ?? '',
    title: json['title'] as String? ?? '',
    source: json['source'] as String? ?? '',
    url: json['url'] as String?,
    streamUrl: json['stream_url'] as String?,
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lon'] as num?)?.toDouble(),
  );

  factory NewsItem.fromOsirisJson(Map<String, dynamic> json) => NewsItem(
    id: json['id'] as String? ?? json['source'] as String? ?? '',
    title: json['title'] as String? ?? '',
    source: json['source'] as String? ?? json['name'] as String? ?? '',
    url: json['url'] as String?,
    streamUrl: json['stream_url'] as String? ?? json['streamUrl'] as String?,
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lng'] as num?)?.toDouble() ??
        (json['lon'] as num?)?.toDouble(),
  );
}

class ConflictZone {
  final String name;
  final String severity;
  final double latitude;
  final double longitude;
  final String? description;

  const ConflictZone({
    required this.name,
    required this.severity,
    required this.latitude,
    required this.longitude,
    this.description,
  });

  factory ConflictZone.fromJson(Map<String, dynamic> json) => ConflictZone(
    name: json['name'] as String? ?? '',
    severity: json['severity'] as String? ?? 'elevated',
    latitude: (json['lat'] as num?)?.toDouble() ?? 0,
    longitude: (json['lon'] as num?)?.toDouble() ?? 0,
    description: json['description'] as String?,
  );

  factory ConflictZone.fromOsirisJson(Map<String, dynamic> json) =>
      ConflictZone(
        name: json['name'] as String? ?? '',
        severity: json['severity'] as String? ?? 'elevated',
        latitude: (json['lat'] as num?)?.toDouble() ?? 0,
        longitude: (json['lng'] as num?)?.toDouble() ??
            (json['lon'] as num?)?.toDouble() ??
            0,
        description: json['description'] as String?,
      );
}

class SatellitePosition {
  final String name;
  final int satId;
  final double latitude;
  final double longitude;
  final double altitude;
  final String? mission;
  final String? color;

  const SatellitePosition({
    required this.name,
    required this.satId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.mission,
    this.color,
  });

  factory SatellitePosition.fromJson(Map<String, dynamic> json) =>
      SatellitePosition(
        name: json['satname'] as String? ?? '',
        satId: (json['satid'] as num?)?.toInt() ?? 0,
        latitude: (json['satlat'] as num?)?.toDouble() ?? 0,
        longitude: (json['satlng'] as num?)?.toDouble() ?? 0,
        altitude: (json['satalt'] as num?)?.toDouble() ?? 0,
        mission: json['mission'] as String?,
        color: json['color'] as String?,
      );

  factory SatellitePosition.fromOsirisJson(Map<String, dynamic> json) =>
      SatellitePosition(
        name: json['name'] as String? ?? json['satname'] as String? ?? '',
        satId: (json['satId'] as num?)?.toInt() ??
            (json['satid'] as num?)?.toInt() ??
            0,
        latitude: (json['lat'] as num?)?.toDouble() ??
            (json['satlat'] as num?)?.toDouble() ??
            0,
        longitude: (json['lng'] as num?)?.toDouble() ??
            (json['lon'] as num?)?.toDouble() ??
            (json['satlng'] as num?)?.toDouble() ??
            0,
        altitude: (json['altitude'] as num?)?.toDouble() ??
            (json['satalt'] as num?)?.toDouble() ??
            0,
        mission: json['mission'] as String?,
        color: json['color'] as String?,
      );
}

class MaritimePort {
  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String type;
  final String? volume;
  final int? rank;
  final String? congestion;
  final String? dwellTime;

  const MaritimePort({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.volume,
    this.rank,
    this.congestion,
    this.dwellTime,
  });

  factory MaritimePort.fromOsirisJson(Map<String, dynamic> json) => MaritimePort(
    name: json['name'] as String? ?? '',
    country: json['country'] as String? ?? '',
    latitude: (json['lat'] as num?)?.toDouble() ?? 0,
    longitude: (json['lng'] as num?)?.toDouble() ?? 0,
    type: json['type'] as String? ?? 'port',
    volume: json['volume'] as String?,
    rank: (json['rank'] as num?)?.toInt(),
    congestion: json['congestion'] as String?,
    dwellTime: json['dwell_time'] as String?,
  );
}

class MaritimeChokepoint {
  final String name;
  final double latitude;
  final double longitude;
  final String? traffic;
  final String? risk;

  const MaritimeChokepoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.traffic,
    this.risk,
  });

  factory MaritimeChokepoint.fromOsirisJson(Map<String, dynamic> json) =>
      MaritimeChokepoint(
        name: json['name'] as String? ?? '',
        latitude: (json['lat'] as num?)?.toDouble() ?? 0,
        longitude: (json['lng'] as num?)?.toDouble() ?? 0,
        traffic: json['traffic'] as String?,
        risk: json['risk'] as String?,
      );
}

class WeatherEvent {
  final String id;
  final String title;
  final String category;
  final String type;
  final String? severity;
  final double latitude;
  final double longitude;
  final DateTime? date;
  final String? source;
  final String? provider;

  const WeatherEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    this.severity,
    required this.latitude,
    required this.longitude,
    this.date,
    this.source,
    this.provider,
  });

  factory WeatherEvent.fromOsirisJson(Map<String, dynamic> json) => WeatherEvent(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? '',
    type: json['type'] as String? ?? '',
    severity: json['severity'] as String?,
    latitude: (json['lat'] as num?)?.toDouble() ?? 0,
    longitude: (json['lng'] as num?)?.toDouble() ?? 0,
    date: json['date'] is String ? DateTime.tryParse(json['date'] as String) : null,
    source: json['source'] as String?,
    provider: json['provider'] as String?,
  );
}
