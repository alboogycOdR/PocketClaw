/// Focus Sound scene + channel models loaded from assets/scenes.json.
library;

import 'package:flutter/material.dart';

class SoundChannel {
  final String id;
  final String label;

  /// Relative path under `assets/sounds/`. Null when the channel is
  /// procedurally generated (see [proceduralKind]).
  final String? assetFile;

  /// When non-null, the engine synthesises this kind of noise on-device
  /// at first play instead of loading a bundled asset. Valid values are
  /// in `NoiseGenerator.supportedNoiseKinds` — currently `white`,
  /// `pink`, `brown`, `low`, `mid`, `high`.
  final String? proceduralKind;

  final double defaultVolume;

  const SoundChannel({
    required this.id,
    required this.label,
    required this.defaultVolume,
    this.assetFile,
    this.proceduralKind,
  }) : assert(
          assetFile != null || proceduralKind != null,
          'SoundChannel needs either an assetFile or a proceduralKind',
        );

  bool get isProcedural => proceduralKind != null;

  factory SoundChannel.fromJson(Map<String, dynamic> json) => SoundChannel(
        id: json['id'] as String,
        label: json['label'] as String,
        assetFile: json['file'] as String?,
        proceduralKind: json['procedural'] as String?,
        defaultVolume: (json['defaultVolume'] as num).toDouble(),
      );
}

class SoundScene {
  final String id;
  final String displayName;
  final String emoji;
  final String description;
  final String category;
  final Color color;
  final List<SoundChannel> channels;

  const SoundScene({
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.description,
    required this.category,
    required this.color,
    required this.channels,
  });

  factory SoundScene.fromJson(Map<String, dynamic> json) {
    final colorHex = (json['color'] as String).replaceFirst('#', '');
    return SoundScene(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      emoji: json['emoji'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      color: Color(int.parse('FF$colorHex', radix: 16)),
      channels: (json['channels'] as List)
          .cast<Map<String, dynamic>>()
          .map(SoundChannel.fromJson)
          .toList(),
    );
  }
}
