/// A station the user has starred. Stored snapshotted (id + display
/// fields) so the favorites list renders offline / between Radio
/// Garden hits without re-fetching catalogue data.
library;

import 'dart:convert';

class FavoriteStation {
  final String channelId;
  final String title;
  final String placeTitle;
  final String country;
  final DateTime savedAt;

  const FavoriteStation({
    required this.channelId,
    required this.title,
    required this.placeTitle,
    required this.country,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'title': title,
        'placeTitle': placeTitle,
        'country': country,
        'savedAt': savedAt.toIso8601String(),
      };

  factory FavoriteStation.fromJson(Map<String, dynamic> json) =>
      FavoriteStation(
        channelId: json['channelId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        placeTitle: json['placeTitle'] as String? ?? '',
        country: json['country'] as String? ?? '',
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  static String encode(List<FavoriteStation> list) =>
      jsonEncode(list.map((f) => f.toJson()).toList());

  static List<FavoriteStation> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FavoriteStation.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
