library;

class TvEpgSource {
  final String id;
  final String name;
  final String url;
  final DateTime? lastRefresh;
  final bool enabled;

  const TvEpgSource({
    required this.id,
    required this.name,
    required this.url,
    this.lastRefresh,
    this.enabled = true,
  });

  factory TvEpgSource.fromMap(Map<String, dynamic> map) => TvEpgSource(
    id: map['id'] as String,
    name: map['name'] as String,
    url: map['url'] as String,
    lastRefresh: (map['last_refresh'] as int?) == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['last_refresh'] as int),
    enabled: (map['enabled'] as int? ?? 1) == 1,
  );
}

class TvEpgChannel {
  final String id;
  final String sourceId;
  final String channelId;
  final List<String> displayNames;
  final String? iconUrl;
  final String? number;

  const TvEpgChannel({
    required this.id,
    required this.sourceId,
    required this.channelId,
    required this.displayNames,
    this.iconUrl,
    this.number,
  });

  String get primaryName =>
      displayNames.isEmpty ? channelId : displayNames.first;
}

class TvEpgProgramme {
  final int? id;
  final String epgChannelId;
  final String sourceId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? subtitle;
  final String? description;
  final String? category;
  final String? iconUrl;
  final String? episodeNum;

  const TvEpgProgramme({
    this.id,
    required this.epgChannelId,
    required this.sourceId,
    required this.start,
    required this.stop,
    required this.title,
    this.subtitle,
    this.description,
    this.category,
    this.iconUrl,
    this.episodeNum,
  });

  factory TvEpgProgramme.fromMap(Map<String, dynamic> map) => TvEpgProgramme(
    id: map['id'] as int?,
    epgChannelId: map['epg_channel_id'] as String,
    sourceId: map['source_id'] as String,
    start: DateTime.fromMillisecondsSinceEpoch(map['start_ms'] as int),
    stop: DateTime.fromMillisecondsSinceEpoch(map['stop_ms'] as int),
    title: map['title'] as String,
    subtitle: map['subtitle'] as String?,
    description: map['description'] as String?,
    category: map['category'] as String?,
    iconUrl: map['icon_url'] as String?,
    episodeNum: map['episode_num'] as String?,
  );
}

class TvEpgMapping {
  final String channelId;
  final String epgChannelId;
  final String sourceId;
  final double confidence;
  final String matchSource;
  final DateTime updatedAt;

  const TvEpgMapping({
    required this.channelId,
    required this.epgChannelId,
    required this.sourceId,
    required this.confidence,
    required this.matchSource,
    required this.updatedAt,
  });

  factory TvEpgMapping.fromMap(Map<String, dynamic> map) => TvEpgMapping(
    channelId: map['channel_id'] as String,
    epgChannelId: map['epg_channel_id'] as String,
    sourceId: map['source_id'] as String,
    confidence: (map['confidence'] as num? ?? 0).toDouble(),
    matchSource: map['match_source'] as String? ?? 'auto',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
  );
}

class TvNowNext {
  final TvEpgProgramme? current;
  final TvEpgProgramme? next;

  const TvNowNext({this.current, this.next});

  bool get hasData => current != null || next != null;
}
