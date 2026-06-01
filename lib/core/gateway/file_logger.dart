/// Minimal file-based logger used when HONOR MagicOS filters logcat.
/// Appends lines to Documents/gateway.log which we pull via
/// `adb pull /storage/emulated/0/Android/data/com.nuburo.hermescommander/files/gateway.log`.
library;

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileLogger {
  FileLogger._();
  static final FileLogger instance = FileLogger._();

  File? _file;
  Future<void>? _init;
  final _queue = <String>[];

  Future<void> _ensureInit() {
    return _init ??= () async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        _file = File('${dir.path}/gateway.log');
        if (!_file!.existsSync()) await _file!.create(recursive: true);
        // Flush anything queued before init
        if (_queue.isNotEmpty) {
          await _file!.writeAsString(
            _queue.join('\n') + '\n',
            mode: FileMode.append,
            flush: true,
          );
          _queue.clear();
        }
      } catch (_) {
        _file = null;
      }
    }();
  }

  /// Fire-and-forget log append. Also prints to console for `flutter run`.
  void log(String tag, String message) {
    final ts = DateTime.now().toIso8601String();
    final line = '$ts $tag $message';
    // ignore: avoid_print
    print(line);
    if (_file == null) {
      _queue.add(line);
      unawaited(_ensureInit().then((_) => _flush()));
      return;
    }
    unawaited(_flush(line));
  }

  Future<void> _flush([String? extra]) async {
    if (_file == null) return;
    try {
      final out = StringBuffer();
      if (_queue.isNotEmpty) {
        out.writeAll(_queue, '\n');
        out.write('\n');
        _queue.clear();
      }
      if (extra != null) {
        out.write(extra);
        out.write('\n');
      }
      if (out.isNotEmpty) {
        await _file!.writeAsString(
          out.toString(),
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (_) {
      // swallow
    }
  }

  /// Absolute path of the log file (or null if not yet initialised).
  String? get path => _file?.path;
}
