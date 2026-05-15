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
  final String id;
  final String title;
  final String subtitle;
  final String? placeId;
  final String? channelHref;

  const RadioSearchHit({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.placeId,
    this.channelHref,
  });

  factory RadioSearchHit.fromJson(Map<String, dynamic> json) {
    final page = (json['page'] as Map?)?.cast<String, dynamic>() ?? const {};
    final href = (json['href'] as String?) ?? '';
    final id = href.isNotEmpty ? href.split('/').last : '';
    return RadioSearchHit(
      type: json['type'] as String? ?? '',
      id: id,
      title: json['title'] as String? ?? '',
      subtitle: page['title'] as String? ?? page['country'] as String? ?? '',
      placeId: page['place'] as String?,
      channelHref: href,
    );
  }
}
