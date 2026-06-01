/// Nature & Ambience sound engine — 3 bundled looping channels played
/// concurrently via just_audio. Independent volume per channel,
/// persisted to SharedPreferences.
library;

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Channel descriptors ───────────────────────────────────────────────────────

class NatureSoundChannel {
  final String id;
  final String label;
  final String assetPath;
  final String emoji;

  const NatureSoundChannel({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.emoji,
  });
}

const natureSoundChannels = <NatureSoundChannel>[
  NatureSoundChannel(
    id: 'farm',
    label: 'DAYTIME FARM',
    assetPath: 'assets/sounds/nature/DAYTIME_FARM.mp3',
    emoji: '🌾',
  ),
  NatureSoundChannel(
    id: 'night',
    label: 'NIGHT AMBIENCE',
    assetPath: 'assets/sounds/nature/NIGHT_AMBIENCE.mp3',
    emoji: '🌙',
  ),
  NatureSoundChannel(
    id: 'sea',
    label: 'DEEP SEA',
    assetPath: 'assets/sounds/nature/DEEP_SEA.mp3',
    emoji: '🌊',
  ),
];

// ── State ─────────────────────────────────────────────────────────────────────

class NatureSoundState {
  final bool isPlaying;
  final List<double> volumes;
  final bool isLoading;

  const NatureSoundState({
    required this.isPlaying,
    required this.volumes,
    this.isLoading = false,
  });
}

// ── Engine ────────────────────────────────────────────────────────────────────

class NatureSoundEngine {
  final _players = List.generate(
    natureSoundChannels.length,
    (_) => AudioPlayer(),
  );
  final _volumes = List<double>.filled(natureSoundChannels.length, 0.6);
  bool _isPlaying = false;
  bool _initialized = false;
  bool _assetsLoaded = false;

  final _stateCtrl = StreamController<NatureSoundState>.broadcast();
  Stream<NatureSoundState> get stateStream => _stateCtrl.stream;

  bool get isPlaying => _isPlaying;
  List<double> get volumes => List.unmodifiable(_volumes);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < natureSoundChannels.length; i++) {
      _volumes[i] = prefs.getDouble('nature_vol_${natureSoundChannels[i].id}') ?? 0.6;
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));
    } catch (e) {
      debugPrint('NatureSoundEngine: audio session config failed: $e');
    }
    await _loadAssets();
    _emit();
  }

  Future<void> _loadAssets() async {
    if (_assetsLoaded) return;
    await Future.wait(List.generate(natureSoundChannels.length, (i) async {
      try {
        await _players[i].setAudioSource(
          AudioSource.asset(natureSoundChannels[i].assetPath),
        );
        await _players[i].setLoopMode(LoopMode.one);
        await _players[i].setVolume(_volumes[i]);
      } catch (e) {
        debugPrint('NatureSoundEngine: load failed for channel $i: $e');
      }
    }));
    _assetsLoaded = true;
  }

  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _emit(loading: true);
    if (!_assetsLoaded) await _loadAssets();
    await Future.wait(List.generate(natureSoundChannels.length, (i) async {
      try {
        await _players[i].setVolume(_volumes[i]);
        await _players[i].seek(Duration.zero);
        _players[i].play();
      } catch (e) {
        debugPrint('NatureSoundEngine: play failed for channel $i: $e');
      }
    }));
    _emit();
  }

  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    await Future.wait(_players.map((p) async {
      try { await p.stop(); } catch (_) {}
    }));
    _emit();
  }

  Future<void> toggle() async =>
      _isPlaying ? stop() : play();

  Future<void> setChannelVolume(int index, double volume) async {
    if (index < 0 || index >= _volumes.length) return;
    _volumes[index] = volume.clamp(0.0, 1.0);
    try { await _players[index].setVolume(_volumes[index]); } catch (_) {}
    _persistVolume(index);
    _emit();
  }

  Future<void> nudgeVolume(int index, double delta) async =>
      setChannelVolume(index, _volumes[index] + delta);

  void _persistVolume(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      'nature_vol_${natureSoundChannels[index].id}',
      _volumes[index],
    );
  }

  void _emit({bool loading = false}) {
    _stateCtrl.add(NatureSoundState(
      isPlaying: _isPlaying,
      volumes: List.unmodifiable(_volumes),
      isLoading: loading,
    ));
  }

  Future<void> dispose() async {
    await stop();
    for (final p in _players) { await p.dispose(); }
    await _stateCtrl.close();
  }
}

final natureSoundEngine = NatureSoundEngine();
