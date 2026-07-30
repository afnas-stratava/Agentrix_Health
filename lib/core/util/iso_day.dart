import 'package:intl/intl.dart';

/// ISO-8601 calendar day in the device's local timezone: `2026-07-28`.
///
/// Ported from `src/lib/date.ts`. Kept as a bare `String` alias rather than a
/// wrapper class so these values stay trivially usable as `Map` keys and
/// Firestore field values, exactly as they were in the TypeScript original.
typedef IsoDay = String;

final RegExp _isoDayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

bool isValidIsoDay(String value) => _isoDayPattern.hasMatch(value);

/// All day-bucketing happens in the device's local timezone, matching how
/// HealthKit and the Health app present daily totals. Using UTC here would
/// shift every metric by the user's offset and silently corrupt correlations.
IsoDay toIsoDay(DateTime date) {
  final local = date.isUtc ? date.toLocal() : date;
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-$month-$day';
}

/// Local midnight for the given day. `DateTime(y, m, d)` is already local in
/// Dart, which is what makes this a faithful port of the JS `new Date(y, m-1, d)`.
DateTime fromIsoDay(IsoDay day) {
  final parts = day.split('-');
  if (parts.length != 3) {
    throw FormatException('Expected an ISO calendar day (YYYY-MM-DD)', day);
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

DateTime startOfLocalDay(DateTime date) {
  final local = date.isUtc ? date.toLocal() : date;
  return DateTime(local.year, local.month, local.day);
}

DateTime endOfLocalDay(DateTime date) {
  final local = date.isUtc ? date.toLocal() : date;
  return DateTime(local.year, local.month, local.day, 23, 59, 59, 999);
}

/// Calendar-day arithmetic, not 24-hour arithmetic. Going through the
/// `DateTime` constructor lets Dart normalise overflow (day 32 → the 1st) and
/// keeps the wall-clock time stable across a DST boundary, which
/// `add(Duration(days: n))` would not.
DateTime addDays(DateTime date, int days) {
  final local = date.isUtc ? date.toLocal() : date;
  return DateTime(
    local.year,
    local.month,
    local.day + days,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
  );
}

/// Whole calendar days between two instants, measured midnight-to-midnight.
///
/// The rounding is load-bearing: on a DST transition the gap between two local
/// midnights is 23 or 25 hours, and truncating would report the wrong number
/// of days twice a year.
int daysBetween(DateTime a, DateTime b) {
  final ms =
      startOfLocalDay(b).millisecondsSinceEpoch -
      startOfLocalDay(a).millisecondsSinceEpoch;
  return (ms / 86400000).round();
}

/// Inclusive list of ISO days spanning `from`…`to`.
List<IsoDay> enumerateDays(DateTime from, DateTime to) {
  final out = <IsoDay>[];
  var cursor = startOfLocalDay(from);
  final last = startOfLocalDay(to);
  while (!cursor.isAfter(last)) {
    out.add(toIsoDay(cursor));
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return out;
}

enum DayFormatStyle { short, long }

String formatDay(IsoDay day, [DayFormatStyle style = DayFormatStyle.short]) {
  final date = fromIsoDay(day);
  final pattern = style == DayFormatStyle.long ? 'MMMM d, y' : 'MMM d';
  return DateFormat(pattern).format(date);
}

String formatRelativeDay(IsoDay day, {DateTime? now}) {
  final diff = daysBetween(fromIsoDay(day), now ?? DateTime.now());
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';
  return formatDay(day);
}

String formatDuration(double hours) {
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// UTC ISO-8601 with a `Z` suffix, matching JavaScript's `toISOString()` so
/// timestamps written by the React Native build and this one stay comparable.
String nowIso([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().toIso8601String();
