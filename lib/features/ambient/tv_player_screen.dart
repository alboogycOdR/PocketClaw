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
  bool _loading = true;
  bool _pipSupported = false;
  String? _error;
  String _status = 'Opening stream...';

  @override
  void initState() {
    super.initState();
    ref.read(activeTvChannelProvider.notifier).state = widget.channel;
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

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Checking stream...';
    });

    try {
      await _probeStream(Uri.parse(widget.channel.streamUrl));
      if (!mounted) return;
      setState(() => _status = 'Starting player...');
      final controller = await _createControllerWithRetry(
        Uri.parse(widget.channel.streamUrl),
      );
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _videoController = controller;
      _chewieController = _buildChewieController(controller);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
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

  Future<VideoPlayerController> _createControllerWithRetry(Uri uri) async {
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
        if (mounted) {
          setState(() {
            _status = attempt == 1
                ? 'Buffering stream...'
                : 'Retrying stream...';
          });
        }
        await controller.initialize().timeout(const Duration(seconds: 18));
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
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final favouriteIds = ref.watch(iptvFavouriteIdsProvider).valueOrNull ?? {};
    final isFavourite = favouriteIds.contains(widget.channel.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.channel.groupTitle,
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
                await tvDatabase.removeFavourite(widget.channel.id);
              } else {
                await tvDatabase.addFavourite(widget.channel);
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
