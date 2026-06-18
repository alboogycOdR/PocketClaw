library;

import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/hermes_commander_theme.dart';
import '../../core/ambient/tv_database.dart';
import '../../core/ambient/tv_stream_service.dart';
import '../../core/device/battery_optimization_service.dart';
import '../../data/providers/iptv_providers.dart';
import 'models/tv_channel.dart';

class TvPlayerScreen extends ConsumerStatefulWidget {
  final TvChannel channel;

  const TvPlayerScreen({super.key, required this.channel});

  @override
  ConsumerState<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends ConsumerState<TvPlayerScreen> {
  static const _tvChannel = MethodChannel('com.nuburo.hermescommander/tv');

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late TvChannel _playbackChannel;
  List<TvChannel> _alternatives = [];
  int _alternativeIndex = -1;
  bool _loading = true;
  bool _pipSupported = false;
  bool _failoverInProgress = false;
  DateTime? _bufferStartedAt;
  String? _error;
  String _status = 'Opening stream...';

  @override
  void initState() {
    super.initState();
    _playbackChannel = widget.channel;
    ref.read(activeTvChannelProvider.notifier).state = _playbackChannel;
    unawaited(_enableScreenAwake());
    unawaited(_enableAutoPip());
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeSuggestBatteryExemption());
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    unawaited(_setAutoPip(false));
    unawaited(_disableScreenAwake());
    super.dispose();
  }

  Future<void> _enableAutoPip() async {
    try {
      final supported = await _tvChannel.invokeMethod<bool>('isPipSupported');
      if (!mounted) return;
      setState(() => _pipSupported = supported ?? false);
      if (supported == true) {
        await _setAutoPip(true);
      }
    } catch (error) {
      debugPrint('TV PiP support check failed: $error');
    }
  }

  Future<void> _setAutoPip(bool enabled) async {
    try {
      await _tvChannel.invokeMethod<void>('setAutoPip', {'enabled': enabled});
    } catch (error) {
      debugPrint('TV auto PiP update failed: $error');
    }
  }

  Future<void> _enterPip() async {
    try {
      final value = _videoController?.value;
      final size = value?.size;
      final width = (size == null || size.width <= 0) ? 16 : size.width.round();
      final height = (size == null || size.height <= 0)
          ? 9
          : size.height.round();
      await _tvChannel.invokeMethod<bool>('enterPip', {
        'width': width,
        'height': height,
      });
    } catch (error) {
      debugPrint('TV enter PiP failed: $error');
    }
  }

  Future<void> _enableScreenAwake() async {
    try {
      await WakelockPlus.enable();
    } catch (error) {
      debugPrint('TV wakelock enable failed: $error');
    }
  }

  Future<void> _disableScreenAwake() async {
    try {
      await WakelockPlus.disable();
    } catch (error) {
      debugPrint('TV wakelock disable failed: $error');
    }
  }

  Future<void> _maybeSuggestBatteryExemption() async {
    final exempt =
        await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    if (!mounted || exempt == true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Allow unrestricted battery use for TV playback'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => unawaited(_openBatterySettings()),
        ),
      ),
    );
  }

  Future<void> _openBatterySettings() async {
    await BatteryOptimizationService.requestExemption();
    await BatteryOptimizationService.markAsked();
  }

  Future<void> _start({TvChannel? channel, bool allowFailover = true}) async {
    if (channel != null) {
      _playbackChannel = channel;
      ref.read(activeTvChannelProvider.notifier).state = channel;
    }
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Checking stream...';
    });

    try {
      final uri = Uri.parse(_playbackChannel.streamUrl);
      await _probeStream(uri);
      if (!mounted) return;
      setState(() => _status = 'Starting player...');
      final controller = await _createControllerWithRetry(
        uri,
        _playbackChannel,
      );
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _videoController = controller;
      _chewieController = _buildChewieController(controller);
      _attachBufferMonitor(controller);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      await tvDatabase.recordStreamFailure(_playbackChannel.streamUrl);
      if (allowFailover) {
        final alternative = await _nextAlternative();
        if (alternative != null) {
          await _disposeControllers();
          await _start(channel: alternative, allowFailover: true);
          return;
        }
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _probeStream(Uri uri) async {
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw StateError('Invalid stream URL.');
    }

    try {
      final response = await http
          .get(uri, headers: const {'Range': 'bytes=0-2048'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 400) return;
      throw StateError('HTTP ${response.statusCode}');
    } catch (error) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.m3u8') || path.contains('.m3u8')) {
        debugPrint('TV stream probe deferred to player: $error');
        return;
      }
      rethrow;
    }
  }

  Future<VideoPlayerController> _createControllerWithRetry(
    Uri uri,
    TvChannel channel,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      final controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: const {
          'User-Agent': 'HermesCommander/FreeTV',
          'Accept': '*/*',
        },
      );
      try {
        final stopwatch = Stopwatch()..start();
        if (mounted) {
          setState(() {
            _status = attempt == 1
                ? 'Buffering stream...'
                : 'Retrying stream...';
          });
        }
        await controller.initialize().timeout(const Duration(seconds: 18));
        stopwatch.stop();
        unawaited(
          tvDatabase.recordStreamSuccess(
            channel.streamUrl,
            stopwatch.elapsedMilliseconds,
          ),
        );
        return controller;
      } catch (error) {
        lastError = error;
        await controller.dispose();
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
    }

    throw StateError('Playback failed: $lastError');
  }

  void _attachBufferMonitor(VideoPlayerController controller) {
    controller.addListener(() {
      if (!mounted || _videoController != controller) return;
      final value = controller.value;
      if (!value.isInitialized) return;
      if (value.isBuffering) {
        _bufferStartedAt ??= DateTime.now();
        final stalled =
            DateTime.now().difference(_bufferStartedAt!) >
            const Duration(seconds: 5);
        if (stalled && !_failoverInProgress) {
          unawaited(_switchToAlternative('Stream stalled'));
        }
      } else {
        _bufferStartedAt = null;
      }
    });
  }

  ChewieController _buildChewieController(VideoPlayerController controller) {
    return ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowedScreenSleep: false,
      allowPlaybackSpeedChanging: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: HCTheme.gold,
        handleColor: HCTheme.goldLight,
        bufferedColor: HCTheme.goldBg,
      ),
      errorBuilder: (context, message) =>
          _PlayerError(message: message, onRetry: _restart),
    );
  }

  Future<void> _restart() async {
    await _disposeControllers();
    await _start();
  }

  Future<void> _disposeControllers() async {
    _chewieController?.dispose();
    final controller = _videoController;
    _chewieController = null;
    _videoController = null;
    _bufferStartedAt = null;
    await controller?.dispose();
  }

  Future<void> _switchToAlternative(String reason) async {
    _failoverInProgress = true;
    try {
      await tvDatabase.recordStreamStall(_playbackChannel.streamUrl);
      final alternative = await _nextAlternative();
      if (alternative == null || !mounted) return;
      setState(() {
        _loading = true;
        _error = null;
        _status = '$reason. Switching backup...';
      });
      await _disposeControllers();
      await _start(channel: alternative, allowFailover: true);
    } finally {
      _failoverInProgress = false;
    }
  }

  Future<TvChannel?> _nextAlternative() async {
    if (_alternatives.isEmpty) {
      final allChannels = await ref.read(iptvChannelsProvider.future);
      _alternatives = await tvStreamService.findAlternatives(
        channel: _playbackChannel,
        allChannels: allChannels,
      );
      _alternativeIndex = -1;
    }
    if (_alternatives.isEmpty) return null;
    _alternativeIndex++;
    if (_alternativeIndex >= _alternatives.length) return null;
    return _alternatives[_alternativeIndex];
  }

  @override
  Widget build(BuildContext context) {
    final favouriteIds = ref.watch(iptvFavouriteIdsProvider).valueOrNull ?? {};
    final isFavourite = favouriteIds.contains(_playbackChannel.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _playbackChannel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _playbackChannel.groupTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          if (_pipSupported)
            IconButton(
              icon: const Icon(Icons.picture_in_picture_alt_outlined),
              color: Colors.white54,
              tooltip: 'Picture in picture',
              onPressed: () => unawaited(_enterPip()),
            ),
          IconButton(
            icon: const Icon(Icons.battery_saver_outlined),
            color: Colors.white54,
            tooltip: 'Battery settings',
            onPressed: () => unawaited(_openBatterySettings()),
          ),
          IconButton(
            icon: Icon(isFavourite ? Icons.star : Icons.star_border),
            color: isFavourite ? HCTheme.gold : Colors.white54,
            tooltip: isFavourite ? 'Remove favourite' : 'Add favourite',
            onPressed: () async {
              if (isFavourite) {
                await tvDatabase.removeFavourite(_playbackChannel.id);
              } else {
                await tvDatabase.addFavourite(_playbackChannel);
              }
              ref.invalidate(iptvFavouriteIdsProvider);
              ref.invalidate(iptvFavouriteChannelsProvider);
            },
          ),
        ],
      ),
      body: _loading
          ? _PlayerLoading(status: _status)
          : _error != null || _chewieController == null
          ? _PlayerError(
              message: _error ?? 'Playback failed',
              onRetry: _restart,
            )
          : Chewie(controller: _chewieController!),
    );
  }
}

class _PlayerLoading extends StatelessWidget {
  final String status;

  const _PlayerLoading({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: HCTheme.gold),
          const SizedBox(height: 14),
          Text(
            status,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PlayerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PlayerError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tv_off_outlined, color: Colors.white38, size: 44),
            const SizedBox(height: 14),
            const Text(
              'Channel unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
