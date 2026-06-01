/// Backward-compatible entrypoint for generic remote file delivery.
///
/// Delegates to `scripts/release_remote.dart` semantics:
/// upload the file to Gofile.io and send a plain-text Telegram link.
library;

import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart scripts/send_file_remote.dart <file>');
    exit(2);
  }

  final result = await Process.start('dart', [
    'scripts/release_remote.dart',
    args.first,
  ], mode: ProcessStartMode.inheritStdio);
  final exitCode = await result.exitCode;
  exit(exitCode);
}
