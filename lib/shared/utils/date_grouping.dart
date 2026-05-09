/// Group items by relative-day buckets (Today / Yesterday / This Week /
/// Earlier). Keeps the original order within each bucket. Used by the
/// session list screens.
library;

enum DateBucket {
  today,
  yesterday,
  thisWeek,
  earlier,
  unknown,
}

extension DateBucketLabel on DateBucket {
  String get label => switch (this) {
        DateBucket.today => 'Today',
        DateBucket.yesterday => 'Yesterday',
        DateBucket.thisWeek => 'This Week',
        DateBucket.earlier => 'Earlier',
        DateBucket.unknown => 'Undated',
      };
}

DateBucket bucketFor(DateTime? when, {DateTime? now}) {
  if (when == null) return DateBucket.unknown;
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final ts = DateTime(when.year, when.month, when.day);

  final daysAgo = today.difference(ts).inDays;
  if (daysAgo <= 0) return DateBucket.today;
  if (daysAgo == 1) return DateBucket.yesterday;
  if (daysAgo <= 6) return DateBucket.thisWeek;
  return DateBucket.earlier;
}

/// Group [items] by the bucket of `dateOf(item)`. The returned map's
/// keys are in display order (Today → Earlier → Undated, skipping
/// empty buckets).
Map<DateBucket, List<T>> groupByDate<T>(
  Iterable<T> items,
  DateTime? Function(T) dateOf, {
  DateTime? now,
}) {
  final map = <DateBucket, List<T>>{};
  for (final item in items) {
    final b = bucketFor(dateOf(item), now: now);
    map.putIfAbsent(b, () => <T>[]).add(item);
  }
  // Re-build in canonical display order.
  final ordered = <DateBucket, List<T>>{};
  for (final b in [
    DateBucket.today,
    DateBucket.yesterday,
    DateBucket.thisWeek,
    DateBucket.earlier,
    DateBucket.unknown,
  ]) {
    final list = map[b];
    if (list != null && list.isNotEmpty) ordered[b] = list;
  }
  return ordered;
}
