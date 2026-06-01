/// Office Sound Engine — plays 9 bundled looping audio channels
/// simultaneously using just_audio. Each channel has independent volume.
/// Volumes are persisted to SharedPreferences between sessions.
library;

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Channel descriptors ───────────────────────────────────────────────────────

class OfficeSoundChannel {
  final String id;
  final String label;
  final String assetPath; // full path as in pubspec assets

  const OfficeSoundChannel({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

// ── Channel list ──────────────────────────────────────────────────────────────

const officeSoundChannels = <OfficeSoundChannel>[
  OfficeSoundChannel(id: 'roomtone',  label: 'ROOM TONE',      assetPath: 'assets/sounds/office/ROOMTONE.mp3'),
  OfficeSoundChannel(id: 'coffee',    label: 'COFFEE MACHINE',  assetPath: 'assets/sounds/office/COFFEE.mp3'),
  OfficeSoundChannel(id: 'people',    label: 'PEOPLE',          assetPath: 'assets/sounds/office/PEOPLE.mp3'),
  OfficeSoundChannel(id: 'printer',   label: 'PRINTER',         assetPath: 'assets/sounds/office/PRINTER.mp3'),
  OfficeSoundChannel(id: 'window',    label: 'OPEN WINDOW',     assetPath: 'assets/sounds/office/OPEN_WINDOW.mp3'),
  OfficeSoundChannel(id: 'telephone', label: 'TELEPHONE',       assetPath: 'assets/sounds/office/TELEPHONE.mp3'),
  OfficeSoundChannel(id: 'dog',       label: 'THE OFFICE DOG',  assetPath: 'assets/sounds/office/THE_OFFICE_DOG.mp3'),
  OfficeSoundChannel(id: 'keyboard',  label: 'KEYBOARDS',       assetPath: 'assets/sounds/office/KEYBOARD.mp3'),
  OfficeSoundChannel(id: 'rain',      label: 'RAIN ON WINDOW',  assetPath: 'assets/sounds/office/RAIN_ON_WINDOW.mp3'),
];

// ── Engine state ──────────────────────────────────────────────────────────────

class OfficeSoundState {
  final bool isPlaying;
  final List<double> volumes;
  final bool isLoading;

  const OfficeSoundState({
    required this.isPlaying,
    required this.volumes,
    this.isLoading = false,
  });

  OfficeSoundState copyWith({
    bool? isPlaying,
    List<double>? volumes,
    bool? isLoading,
  }) => OfficeSoundState(
    isPlaying: isPlaying ?? this.isPlaying,
    volumes: volumes ?? this.volumes,
    isLoading: isLoading ?? this.isLoading,
  );
}

// ── Engine ────────────────────────────────────────────────────────────────────

class OfficeSoundEngine {
  final _players = List.generate(
    officeSoundChannels.length,
    (_) => AudioPlayer(),
  );
  final _volumes = List<double>.filled(officeSoundChannels.length, 0.5);
  bool _isPlaying = false;
  bool _initialized = false;
  bool _assetsLoaded = false;

  final _stateCtrl = StreamController<OfficeSoundState>.broadcast();
  Stream<OfficeSoundState> get stateStream => _stateCtrl.stream;

  bool get isPlaying => _isPlaying;
  List<double> get volumes => List.unmodifiable(_volumes);

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Load persisted volumes.
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < officeSoundChannels.length; i++) {
      _volumes[i] = prefs.getDouble('office_vol_${officeSoundChannels[i].id}') ?? 0.5;
    }

    // Configure audio session for concurrent mixing — critical on Android.
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
      debugPrint('OfficeSoundEngine: audio session config failed: $e');
    }

    // Pre-load all assets so play() is instant.
    await _loadAssets();
    _emit();
  }

  Future<void> _loadAssets() async {
    if (_assetsLoaded) return;
    await Future.wait(List.generate(officeSoundChannels.length, (i) async {
      try {
        await _players[i].setAudioSource(
          AudioSource.asset(officeSoundChannels[i].assetPath),
        );
        await _players[i].setLoopMode(LoopMode.one);
        await _players[i].setVolume(_volumes[i]);
      } catch (e) {
        debugPrint('OfficeSoundEngine: asset load failed for channel $i: $e');
      }
    }));
    _assetsLoaded = true;
  }

  // ── Play / stop ───────────────────────────────────────────────────────────

  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _emit(loading: true);

    if (!_assetsLoaded) await _loadAssets();

    // Start all players concurrently — no sequential awaiting so they
    // all kick off together and none steals focus from the next.
    await Future.wait(List.generate(officeSoundChannels.length, (i) async {
      try {
        await _players[i].setVolume(_volumes[i]);
        await _players[i].seek(Duration.zero);
        _players[i].play(); // intentionally not awaited — fire and forget
      } catch (e) {
        debugPrint('OfficeSoundEngine: play failed for channel $i: $e');
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

  // ── Volume ────────────────────────────────────────────────────────────────

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
      'office_vol_${officeSoundChannels[index].id}',
      _volumes[index],
    );
  }

  // ── Stream ────────────────────────────────────────────────────────────────

  void _emit({bool loading = false}) {
    _stateCtrl.add(OfficeSoundState(
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

final officeSoundEngine = OfficeSoundEngine();
