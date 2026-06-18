library;

enum TvStreamType { live, vod, series }

class TvChannel {
  final String id;
  final String name;
  final String groupTitle;
  final String streamUrl;
  final String? logoUrl;
  final String? tvgId;
  final String? tvgName;
  final int? channelNumber;
  final TvStreamType streamType;
  final bool isHD;
  final bool isGeoBlocked;
  final bool isYouTube;
  final bool isCustom;

  const TvChannel({
    required this.id,
    required this.name,
    required this.groupTitle,
    required this.streamUrl,
    this.logoUrl,
    this.tvgId,
    this.tvgName,
    this.channelNumber,
    this.streamType = TvStreamType.live,
    this.isHD = true,
    this.isGeoBlocked = false,
    this.isYouTube = false,
    this.isCustom = false,
  });

  String get displayName =>
      tvgName?.trim().isNotEmpty == true ? tvgName!.trim() : name;

  static String idFromUrl(String url) {
    var hash = 0;
    for (final codeUnit in url.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return 'ch_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'group_title': groupTitle,
    'stream_url': streamUrl,
    'logo_url': logoUrl,
    'tvg_id': tvgId,
    'tvg_name': tvgName,
    'channel_number': channelNumber,
    'stream_type': streamType.name,
    'is_hd': isHD ? 1 : 0,
    'is_geo': isGeoBlocked ? 1 : 0,
    'is_youtube': isYouTube ? 1 : 0,
    'is_custom': isCustom ? 1 : 0,
  };

  factory TvChannel.fromMap(Map<String, dynamic> map) => TvChannel(
    id: map['id'] as String,
    name: map['name'] as String,
    groupTitle: map['group_title'] as String? ?? 'Custom',
    streamUrl: map['stream_url'] as String,
    logoUrl: map['logo_url'] as String?,
    tvgId: map['tvg_id'] as String?,
    tvgName: map['tvg_name'] as String?,
    channelNumber: map['channel_number'] as int?,
    streamType: TvStreamType.values.firstWhere(
      (type) => type.name == (map['stream_type'] as String? ?? 'live'),
      orElse: () => TvStreamType.live,
    ),
    isHD: (map['is_hd'] as int? ?? 1) == 1,
    isGeoBlocked: (map['is_geo'] as int? ?? 0) == 1,
    isYouTube: (map['is_youtube'] as int? ?? 0) == 1,
    isCustom: (map['is_custom'] as int? ?? 0) == 1,
  );
}
