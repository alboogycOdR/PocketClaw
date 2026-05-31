/// Radio Garden data models. The API root response wraps payloads in
/// `{apiVersion, version, data: {...}}` — parse callers unwrap the
/// outer envelope and hand the inner `data` map to the per-type
/// `fromJson` factories below.
library;

class RadioPlace {
  final String id;
  final String title;
  final String country;
  final double latitude;
  final double longitude;
  final int size;

  const RadioPlace({
    required this.id,
    required this.title,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.size,
  });

  /// Place JSON shape (verified live 2026-05-14):
  /// {size, title, geo: [lng, lat], url, country, id, boost}
  factory RadioPlace.fromJson(Map<String, dynamic> json) {
    final geo = (json['geo'] as List?) ?? const [0.0, 0.0];
    return RadioPlace(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      country: json['country'] as String? ?? '',
      // geo is [lng, lat] per GeoJSON convention.
      longitude: (geo.isNotEmpty ? geo[0] as num : 0).toDouble(),
      latitude: (geo.length > 1 ? geo[1] as num : 0).toDouble(),
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class RadioChannel {
  final String id;
  final String title;
  final String country;
  final String placeTitle;

  const RadioChannel({
    required this.id,
    required this.title,
    required this.country,
    required this.placeTitle,
  });

  /// `https://radio.garden/api/ara/content/listen/{id}/channel.mp3`
  /// redirects to the broadcaster's actual stream — `just_audio`
  /// follows redirects automatically so the URL can be passed in raw.
  String get streamUrl =>
      'https://radio.garden/api/ara/content/listen/$id/channel.mp3';

  /// Real channel shape (verified live 2026-05-15 against
  /// /api/ara/content/page/<placeId>/channels):
  ///   { page: { url: "/listen/<slug>/<id>", title, place:{id,title},
  ///             country:{id,title}, ... } }
  factory RadioChannel.fromJson(Map<String, dynamic> json) {
    final page = (json['page'] as Map?)?.cast<String, dynamic>() ?? const {};
    final url = page['url'] as String? ?? '';
    final id = url.isNotEmpty ? url.split('/').last : '';
    final placeMap =
        (page['place'] as Map?)?.cast<String, dynamic>() ?? const {};
    final countryMap =
        (page['country'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RadioChannel(
      id: id,
      title: page['title'] as String? ?? '',
      placeTitle: placeMap['title'] as String? ?? '',
      country: countryMap['title'] as String? ?? '',
    );
  }
}

class RadioSearchHit {
  /// Type of the search hit: 'channel' | 'place' | 'country'.
  final String type;

  /// For place results: the place ID (used to fetch channels).
  /// For channel results: the channel ID (used to stream).
  /// For country results: the country ID.
  final String id;

  final String title;
  final String subtitle;

  /// Channels only: the parent place ID, so a channel hit can jump
  /// either to "play this station" or "open this city".
  final String? placeId;

  const RadioSearchHit({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.placeId,
  });

  /// Search response item shape (verified live 2026-05-15 against
  /// /api/search?q=…):
  ///   _source: {
  ///     code, type, page: {
  ///       url, title, subtitle,
  ///       map,                              // for places: the place id
  ///       place: { id, title },             // for channels
  ///       country: { id, title },           // for channels
  ///     }
  ///   }
  factory RadioSearchHit.fromJson(Map<String, dynamic> source) {
    final type = source['type'] as String? ?? '';
    final page = (source['page'] as Map?)?.cast<String, dynamic>() ?? const {};
    final url = page['url'] as String? ?? '';
    final lastSegment = url.isNotEmpty ? url.split('/').last : '';

    String id;
    String? parentPlace;
    switch (type) {
      case 'place':
        // Place id lives on `page.map`, with the url path as a fallback.
        id = (page['map'] as String?) ??
            (lastSegment.isNotEmpty ? lastSegment : '');
        parentPlace = null;
        break;
      case 'channel':
        id = lastSegment;
        final placeMap =
            (page['place'] as Map?)?.cast<String, dynamic>() ?? const {};
        parentPlace = placeMap['id'] as String?;
        break;
      default:
        id = lastSegment;
        parentPlace = null;
    }

    return RadioSearchHit(
      type: type,
      id: id,
      title: page['title'] as String? ?? '',
      subtitle: page['subtitle'] as String? ?? '',
      placeId: parentPlace,
    );
  }
}
