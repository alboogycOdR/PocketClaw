/// Bytes → human-readable size string. Used by the storage screen
/// and the device-info screen.
library;

String formatBytes(int bytes, {int precision = 1}) {
  if (bytes < 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024.0;
  for (final unit in units) {
    if (value < 1024) return '${value.toStringAsFixed(precision)} $unit';
    value /= 1024;
  }
  return '${value.toStringAsFixed(precision)} PB';
}
