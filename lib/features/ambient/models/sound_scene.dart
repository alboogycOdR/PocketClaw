/// Focus Sound scene + channel models loaded from assets/scenes.json.
library;

import 'package:flutter/material.dart';

class SoundChannel {
  final String id;
  final String label;
  final String assetFile; // relative to assets/sounds/
  final double defaultVolume;

  const SoundChannel({
    required this.id,
    required this.label,
    required this.assetFile,
    required this.defaultVolume,
  });

  factory SoundChannel.fromJson(Map<String, dynamic> json) => SoundChannel(
        id: json['id'] as String,
        label: json['label'] as String,
        assetFile: json['file'] as String,
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
