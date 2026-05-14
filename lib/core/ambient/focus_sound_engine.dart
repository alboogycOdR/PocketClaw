/// Multi-channel Focus Sound engine — one AudioPlayer per channel, all
/// looping simultaneously. Volumes mix in real time without re-loading
/// the audio sources.
///
/// ⚠ Audio asset files are NOT bundled in v2.8.0 (the engine and UI
/// are wired but `assets/sounds/<scene_id>/*.mp3` files have to be
/// supplied separately). When a channel's asset is missing, the engine
/// logs and continues — the scene appears "playing" but is silent.
/// Drop matching files at the paths declared in `assets/scenes.json`
/// and add them under `flutter.assets` in pubspec.yaml to activate.
library;

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../features/ambient/models/sound_scene.dart';

class FocusSoundEngine {
  static const int kChannelCount = 10;

  SoundScene? _activeScene;
  final List<AudioPlayer> _players =
      List.generate(kChannelCount, (_) => AudioPlayer());
  final List<double> _volumes = List.filled(kChannelCount, 0.0);
  bool _isPlaying = false;
  double _masterVolume = 1.0;
  Timer? _sleepTimer;

  final _stateController = StreamController<FocusSoundState>.broadcast();
  Stream<FocusSoundState> get stateStream => _stateController.stream;

  bool get isPlaying => _isPlaying;
  SoundScene? get activeScene => _activeScene;
  List<double> get volumes => List.unmodifiable(_volumes);
  double get masterVolume => _masterVolume;

  Future<void> loadScene(SoundScene scene, {bool autoPlay = true}) async {
    if (_isPlaying) await stop();
    _activeScene = scene;
    for (var i = 0; i < kChannelCount; i++) {
      _volumes[i] =
          i < scene.channels.length ? scene.channels[i].defaultVolume : 0.0;
    }
    if (autoPlay) await play();
    _emit();
  }

  Future<void> play() async {
    final scene = _activeScene;
    if (scene == null) return;
    _isPlaying = true;
    for (var i = 0; i < scene.channels.length; i++) {
      final channel = scene.channels[i];
      final player = _players[i];
      try {
        await player.setVolume(_volumes[i] * _masterVolume);
        await player.setReleaseMode(ReleaseMode.loop);
        await player.play(AssetSource('sounds/${channel.assetFile}'));
      } catch (e) {
        // Missing audio asset is the v2.8.0 expected state — keep
        // the rest of the scene playing.
        debugPrint('FocusSoundEngine: channel $i (${channel.label}) failed: $e');
      }
    }
    _emit();
  }

  Future<void> pause() async {
    for (final p in _players) {
      await p.pause();
    }
    _isPlaying = false;
    _emit();
  }

  Future<void> resume() async {
    for (final p in _players) {
      await p.resume();
    }
    _isPlaying = true;
    _emit();
  }

  Future<void> stop() async {
    for (final p in _players) {
      await p.stop();
    }
    _isPlaying = false;
    _emit();
  }

  Future<void> setChannelVolume(int index, double volume) async {
    if (index < 0 || index >= kChannelCount) return;
    _volumes[index] = volume.clamp(0.0, 1.0);
    await _players[index].setVolume(_volumes[index] * _masterVolume);
    _emit();
  }

  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);
    for (var i = 0; i < kChannelCount; i++) {
      await _players[i].setVolume(_volumes[i] * _masterVolume);
    }
    _emit();
  }

  /// Push every channel toward equal volume — the "All In" preset.
  Future<void> allIn() async {
    for (var i = 0; i < kChannelCount; i++) {
      await setChannelVolume(i, 0.8);
    }
  }

  Future<void> resetToDefaults() async {
    final scene = _activeScene;
    if (scene == null) return;
    for (var i = 0; i < scene.channels.length; i++) {
      await setChannelVolume(i, scene.channels[i].defaultVolume);
    }
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () async {
      // 5-second fade.
      for (var step = 10; step >= 0; step--) {
        await setMasterVolume(step / 10);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await stop();
      _sleepTimer = null;
      _emit();
    });
    _emit();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _emit();
  }

  bool get hasSleepTimer => _sleepTimer != null && _sleepTimer!.isActive;

  static List<SoundScene>? _cachedScenes;

  static Future<List<SoundScene>> loadCatalogue() async {
    if (_cachedScenes != null) return _cachedScenes!;
    final raw = await rootBundle.loadString('assets/scenes.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _cachedScenes = (json['scenes'] as List)
        .cast<Map<String, dynamic>>()
        .map(SoundScene.fromJson)
        .toList();
    return _cachedScenes!;
  }

  void dispose() {
    _sleepTimer?.cancel();
    for (final p in _players) {
      p.dispose();
    }
    _stateController.close();
  }

  void _emit() {
    _stateController.add(FocusSoundState(
      isPlaying: _isPlaying,
      activeScene: _activeScene,
      volumes: List.of(_volumes),
      masterVolume: _masterVolume,
      hasSleepTimer: hasSleepTimer,
    ));
  }
}

class FocusSoundState {
  final bool isPlaying;
  final SoundScene? activeScene;
  final List<double> volumes;
  final double masterVolume;
  final bool hasSleepTimer;

  const FocusSoundState({
    required this.isPlaying,
    required this.activeScene,
    required this.volumes,
    required this.masterVolume,
    required this.hasSleepTimer,
  });
}

final focusSoundEngine = FocusSoundEngine();
