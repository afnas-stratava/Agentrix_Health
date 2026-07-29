import 'dart:math' as math;

import '../../core/util/iso_day.dart';
import '../../domain/entities/health/daily_snapshot.dart';
import 'telemetry_samples.dart';

/// Ported from `src/features/health/aggregate.ts`.

/// Sleep that crosses midnight belongs to the day the user *woke up*, which is
/// how Apple Health presents it. A session ending after 18:00 is treated as a
/// pre-midnight bedtime for the following day rather than an evening nap.
const int _eveningCutoffHour = 18;

/// Higher wins when two sources describe the same minute differently.
const Map<SleepStageValue, int> _stagePriority = {
  SleepStageValue.deep: 5,
  SleepStageValue.rem: 4,
  SleepStageValue.core: 3,
  SleepStageValue.asleep: 2,
  SleepStageValue.unspecified: 2,
  SleepStageValue.awake: 1,
  SleepStageValue.inBed: 0,
};

const List<String> _wearableHints = ['watch', 'oura', 'whoop', 'ultrahuman'];

bool _isWearable(String? sourceName) {
  if (sourceName == null || sourceName.isEmpty) return false;
  final lower = sourceName.toLowerCase();
  return _wearableHints.any(lower.contains);
}

double? _meanOrNull(List<double> values) {
  if (values.isEmpty) return null;
  return values.fold<double>(0, (sum, v) => sum + v) / values.length;
}

double? _sumOrNull(List<double> values) {
  if (values.isEmpty) return null;
  return values.fold<double>(0, (total, v) => total + v);
}

Map<IsoDay, List<QuantitySample>> _bucketByDay(List<QuantitySample> samples) {
  final map = <IsoDay, List<QuantitySample>>{};
  for (final sample in samples) {
    final day = toIsoDay(DateTime.parse(sample.startDate).toLocal());
    map.putIfAbsent(day, () => <QuantitySample>[]).add(sample);
  }
  return map;
}

IsoDay _sleepDayFor(SleepSample sample) {
  final end = DateTime.parse(sample.endDate).toLocal();
  if (end.hour >= _eveningCutoffHour) {
    return toIsoDay(DateTime(end.year, end.month, end.day + 1));
  }
  return toIsoDay(end);
}

class _ResolvedInterval {
  _ResolvedInterval({required this.start, required this.end, required this.stage});

  final int start;
  int end;
  final SleepStageValue stage;
}

class _Span {
  const _Span({required this.start, required this.end, required this.stage});

  final int start;
  final int end;
  final SleepStageValue stage;
}

/// Overlapping sleep samples are the norm — the iPhone writes `INBED` while the
/// Watch writes staged sleep, and a third-party ring may write its own take on
/// the same night. Summing raw durations would report 14 hours of sleep.
///
/// This does an interval sweep: every distinct boundary becomes an elementary
/// segment, and each segment is credited to the single highest-priority stage
/// covering it. Total minutes can therefore never exceed wall-clock time.
List<_ResolvedInterval> _resolveTimeline(List<SleepSample> samples) {
  final staged = samples.where((s) => s.value != SleepStageValue.inBed).toList();
  if (staged.isEmpty) return [];

  final boundaries = <int>{};
  final spans = staged
      .map((s) => _Span(
            start: DateTime.parse(s.startDate).millisecondsSinceEpoch,
            end: DateTime.parse(s.endDate).millisecondsSinceEpoch,
            stage: s.value,
          ))
      .toList();

  for (final span in spans) {
    if (span.end <= span.start) continue;
    boundaries.add(span.start);
    boundaries.add(span.end);
  }

  final points = boundaries.toList()..sort();
  final resolved = <_ResolvedInterval>[];

  for (var i = 0; i < points.length - 1; i += 1) {
    final start = points[i];
    final end = points[i + 1];
    if (end <= start) continue;

    SleepStageValue? winner;
    for (final span in spans) {
      if (span.start <= start && span.end >= end) {
        if (winner == null || _stagePriority[span.stage]! > _stagePriority[winner]!) {
          winner = span.stage;
        }
      }
    }

    if (winner == null) continue;

    final previous = resolved.isEmpty ? null : resolved.last;
    if (previous != null && previous.stage == winner && previous.end == start) {
      previous.end = end;
    } else {
      resolved.add(_ResolvedInterval(start: start, end: end, stage: winner));
    }
  }

  return resolved;
}

/// Total wall-clock minutes covered by the union of the given samples, so
/// overlapping in-bed records from two devices are not double-counted.
double _unionMinutes(List<SleepSample> samples) {
  final spans = samples
      .map((s) => (
            start: DateTime.parse(s.startDate).millisecondsSinceEpoch,
            end: DateTime.parse(s.endDate).millisecondsSinceEpoch,
          ))
      .where((s) => s.end > s.start)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  var total = 0;
  var cursorStart = -1;
  var cursorEnd = -1;

  for (final span in spans) {
    if (cursorEnd < span.start) {
      if (cursorEnd > cursorStart) total += cursorEnd - cursorStart;
      cursorStart = span.start;
      cursorEnd = span.end;
    } else {
      cursorEnd = math.max(cursorEnd, span.end);
    }
  }
  if (cursorEnd > cursorStart) total += cursorEnd - cursorStart;

  return total / 60000;
}

SleepSummary? _summariseSleep(List<SleepSample> samples) {
  if (samples.isEmpty) return null;

  final timeline = _resolveTimeline(samples);
  var deep = 0.0;
  var rem = 0.0;
  var core = 0.0;
  var awake = 0.0;
  var unspecified = 0.0;

  for (final interval in timeline) {
    final duration = (interval.end - interval.start) / 60000;
    switch (interval.stage) {
      case SleepStageValue.deep:
        deep += duration;
      case SleepStageValue.rem:
        rem += duration;
      case SleepStageValue.core:
        core += duration;
      case SleepStageValue.awake:
        awake += duration;
      case SleepStageValue.asleep:
      case SleepStageValue.unspecified:
      case SleepStageValue.inBed:
        unspecified += duration;
    }
  }

  final asleepMinutes = deep + rem + core + unspecified;
  if (asleepMinutes <= 0) return null;

  final inBedSamples =
      samples.where((s) => s.value == SleepStageValue.inBed).toList();
  final inBedMinutes = inBedSamples.isNotEmpty
      ? math.max(_unionMinutes(inBedSamples), asleepMinutes)
      : asleepMinutes + awake;

  final asleepIntervals =
      timeline.where((i) => i.stage != SleepStageValue.awake).toList();
  final bedtime = asleepIntervals.isNotEmpty
      ? DateTime.fromMillisecondsSinceEpoch(asleepIntervals.first.start)
      : null;
  final wakeTime = asleepIntervals.isNotEmpty
      ? DateTime.fromMillisecondsSinceEpoch(asleepIntervals.last.end)
      : null;

  return SleepSummary(
    deepMinutes: _round1(deep),
    remMinutes: _round1(rem),
    coreMinutes: _round1(core),
    awakeMinutes: _round1(awake),
    unspecifiedMinutes: _round1(unspecified),
    asleepMinutes: _round1(asleepMinutes),
    inBedMinutes: _round1(inBedMinutes),
    efficiency: inBedMinutes > 0 ? _clamp01(asleepMinutes / inBedMinutes) : null,
    bedtime: bedtime?.toUtc().toIso8601String(),
    wakeTime: wakeTime?.toUtc().toIso8601String(),
  );
}

double _round1(double value) => (value * 10).round() / 10;

double _clamp01(double value) => math.min(1.0, math.max(0.0, value));

/// Collapses raw HealthKit samples into one snapshot per calendar day across
/// the whole requested window — including days with no samples at all, which
/// are emitted with `null` metrics so gaps stay visible instead of being
/// silently closed by the chart.
List<DailySnapshot> aggregateDailySnapshots(
  RawTelemetry raw,
  DateTime from,
  DateTime to,
) {
  final hrvByDay = _bucketByDay(raw.hrv);
  final rhrByDay = _bucketByDay(raw.restingHeartRate);
  final energyByDay = _bucketByDay(raw.activeEnergy);
  final stepsByDay = _bucketByDay(raw.steps);

  final sleepByDay = <IsoDay, List<SleepSample>>{};
  for (final sample in raw.sleep) {
    sleepByDay.putIfAbsent(_sleepDayFor(sample), () => <SleepSample>[]).add(sample);
  }

  return enumerateDays(from, to).map((day) {
    final hrvSamples = hrvByDay[day] ?? const <QuantitySample>[];
    final rhrSamples = rhrByDay[day] ?? const <QuantitySample>[];
    final energySamples = energyByDay[day] ?? const <QuantitySample>[];
    final stepSamples = stepsByDay[day] ?? const <QuantitySample>[];
    final sleepSamples = sleepByDay[day] ?? const <SleepSample>[];

    final allSources = [...hrvSamples, ...rhrSamples, ...energySamples];

    return DailySnapshot(
      day: day,
      // Apple reports a daily *average* SDNN; taking the max would flatter
      // recovery on nights with one good reading.
      hrv: _roundOrNull(_meanOrNull(hrvSamples.map((s) => s.value).toList()), 1),
      // Resting HR is already a daily derived value; averaging duplicates from
      // multiple sources is the correct reconciliation.
      restingHeartRate:
          _roundOrNull(_meanOrNull(rhrSamples.map((s) => s.value).toList()), 0),
      sleep: _summariseSleep(sleepSamples),
      activeEnergy:
          _roundOrNull(_sumOrNull(energySamples.map((s) => s.value).toList()), 0),
      steps: _roundOrNull(_sumOrNull(stepSamples.map((s) => s.value).toList()), 0),
      hasWearableSource: allSources.any((s) => _isWearable(s.sourceName)) ||
          sleepSamples.any((s) => _isWearable(s.sourceName)),
    );
  }).toList();
}

double? _roundOrNull(double? value, int decimals) {
  if (value == null || !value.isFinite) return null;
  final factor = math.pow(10, decimals);
  return (value * factor).round() / factor;
}
