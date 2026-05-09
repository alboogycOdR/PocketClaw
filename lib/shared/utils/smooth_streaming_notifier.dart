/// Progressively reveals a target string at ~60 fps so streamed
/// assistant text feels smooth instead of arriving in chunks.
///
/// Adaptive step keeps the cursor close to the target without making
/// the catch-up obvious:
///   - far behind (>60 chars remaining): jump remaining/8 chars
///   - medium     (20–60 remaining)   : jump 3 chars
///   - close      (<20 remaining)     : 1 char per tick
///
/// If the target shrinks or changes non-additively (error reset, a new
/// session being loaded), snap to the new target immediately.
///
/// Ported from hermes-workspace `use-smooth-streaming-text.ts`.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

class SmoothStreamingNotifier extends ChangeNotifier {
  String _target = '';
  String _rendered = '';
  Timer? _ticker;

  String get rendered => _rendered;

  bool get isCaughtUp => _rendered == _target;

  /// Update the target string. Starts ticking if not already running.
  void setTarget(String text) {
    if (text == _target) return;

    if (_rendered.length > text.length || !text.startsWith(_rendered)) {
      _rendered = '';
    }

    _target = text;

    if (_rendered == _target) {
      _ticker?.cancel();
      _ticker = null;
      notifyListeners();
      return;
    }

    _ticker ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tick(),
    );
  }

  /// Snap to the final value immediately (e.g. when streaming ends).
  void snapToTarget() {
    _rendered = _target;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void _tick() {
    if (_rendered == _target) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    final remaining = _target.length - _rendered.length;
    final step = remaining > 60
        ? (remaining / 8).ceil()
        : remaining > 20
            ? 3
            : 1;

    final nextLen = (_rendered.length + step).clamp(0, _target.length);
    _rendered = _target.substring(0, nextLen);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
