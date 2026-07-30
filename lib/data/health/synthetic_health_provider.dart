import 'dart:math' as math;

import '../../core/util/iso_day.dart';
import '../../domain/entities/health/metric_key.dart';
import '../../features/health/telemetry_samples.dart';

/// Ported from `src/features/health/synthetic.provider.ts`.
///
/// Deterministic synthetic telemetry for the simulator, web and CI.
///
/// The series is *not* random noise: it encodes a plausible physiology so the
/// correlation engine has something real to find — a sub-clinical iron/
/// inflammation drift over the last three weeks that suppresses HRV, lifts
/// resting heart rate and fragments sleep. Screenshots and tests are therefore
/// reproducible frame-for-frame.
class SyntheticHealthProvider implements HealthProvider {
  const SyntheticHealthProvider();

  @override
  String get id => 'synthetic';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<HealthPermissionState> requestAuthorization() async =>
      HealthPermissionState.granted;

  @override
  Future<HealthPermissionState> getPermissionState() async =>
      HealthPermissionState.granted;

  @override
  Future<RawTelemetry> fetchRange(DateTime from, DateTime to) async {
    final hrv = <QuantitySample>[];
    final restingHeartRate = <QuantitySample>[];
    final sleep = <SleepSample>[];
    final activeEnergy = <QuantitySample>[];
    final steps = <QuantitySample>[];

    final today = startOfLocalDay(DateTime.now());
    var cursor = startOfLocalDay(from);
    final last = startOfLocalDay(to);

    while (!cursor.isAfter(last)) {
      final daysAgo = daysBetween(cursor, today);
      final profile = _profileForDay(cursor, daysAgo);

      // HRV is sampled several times a night, not once.
      for (var i = 0; i < 4; i += 1) {
        final jitter = _Mulberry32(_dayIndexSeed(cursor) + i).next();
        hrv.add(
          _quantity(cursor, profile.hrv * (0.9 + jitter * 0.2), 120 + i * 55),
        );
      }
      restingHeartRate.add(_quantity(cursor, profile.rhr, 420));
      activeEnergy.add(_quantity(cursor, profile.activeEnergy, 720));
      steps.add(_quantity(cursor, profile.steps, 720));
      sleep.addAll(_buildSleepSamples(cursor, profile));

      cursor = addDays(cursor, 1);
    }

    // Simulate native bridge latency so loading states are exercised in dev.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    return RawTelemetry(
      hrv: hrv,
      restingHeartRate: restingHeartRate,
      sleep: sleep,
      activeEnergy: activeEnergy,
      steps: steps,
    );
  }

  @override
  void Function() subscribe(void Function() onChange) => () {};
}

/// Mulberry32 — small, fast, and seeded so every run is identical.
///
/// The JavaScript original relies on `Math.imul` and `>>> 0` for 32-bit
/// semantics; Dart ints are 64-bit, so every step is masked back to 32 bits by
/// hand to keep the two implementations producing identical sequences.
class _Mulberry32 {
  _Mulberry32(int seed) : _a = seed & 0xFFFFFFFF;

  int _a;

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  double next() {
    _a = (_a + 0x6d2b79f5) & 0xFFFFFFFF;
    var t = _imul(_a ^ (_a >>> 15), 1 | _a);
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) ^ t) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }
}

int _dayIndexSeed(DateTime date) =>
    startOfLocalDay(date).millisecondsSinceEpoch ~/ 86400000;

double _clamp(double value, double min, double max) =>
    math.min(max, math.max(min, value));

class _DayProfile {
  const _DayProfile({
    required this.hrv,
    required this.rhr,
    required this.asleepMinutes,
    required this.awakeMinutes,
    required this.activeEnergy,
    required this.steps,
  });

  final double hrv;
  final double rhr;
  final double asleepMinutes;
  final double awakeMinutes;
  final double activeEnergy;
  final double steps;
}

_DayProfile _profileForDay(DateTime date, int daysAgo) {
  final rand = _Mulberry32(_dayIndexSeed(date) * 2654435761);
  // Dart's DateTime.weekday is 1 (Mon)–7 (Sun); JS getDay() is 0 (Sun)–6.
  final weekday = date.weekday == DateTime.sunday ? 0 : date.weekday;
  final isWeekend = weekday == 0 || weekday == 6;

  // Slow decline over the trailing 21 days, then a stable healthy plateau.
  final declinePhase = math.max(0.0, 1 - daysAgo / 21);
  final hrvDrift = -14 * declinePhase;
  final rhrDrift = 6 * declinePhase;

  // Weekly rhythm: worse recovery early in the week, best on Saturday.
  final circadian = math.sin(((weekday - 2) / 7) * math.pi * 2);

  return _DayProfile(
    hrv: _clamp(52 + hrvDrift + circadian * 4 + (rand.next() - 0.5) * 9, 14, 120),
    rhr: _clamp(56 + rhrDrift - circadian * 1.5 + (rand.next() - 0.5) * 4, 40, 95),
    asleepMinutes: _clamp(
      414 - 26 * declinePhase + (isWeekend ? 38 : 0) + (rand.next() - 0.5) * 55,
      210,
      620,
    ),
    awakeMinutes: _clamp(
      24 + 18 * declinePhase + (rand.next() - 0.5) * 14,
      4,
      90,
    ),
    activeEnergy: _clamp(
      (isWeekend ? 690 : 470) - 90 * declinePhase + (rand.next() - 0.5) * 260,
      60,
      1600,
    ),
    steps: _clamp(
      (isWeekend ? 11200 : 8300) -
          1400 * declinePhase +
          (rand.next() - 0.5) * 5200,
      500,
      26000,
    ).roundToDouble(),
  );
}

QuantitySample _quantity(DateTime day, double value, int offsetMinutes) {
  final start = DateTime(day.year, day.month, day.day, 0, offsetMinutes);
  final end = start.add(const Duration(minutes: 1));
  return QuantitySample(
    startDate: start.toIso8601String(),
    endDate: end.toIso8601String(),
    value: value,
    sourceName: 'Apple Watch',
  );
}

List<SleepSample> _buildSleepSamples(DateTime day, _DayProfile profile) {
  // Sleep is attributed to the *wake* day, matching Apple Health's convention.
  final bedtime = DateTime(day.year, day.month, day.day - 1, 23, 12);

  final deep = profile.asleepMinutes * 0.18;
  final rem = profile.asleepMinutes * 0.22;
  final core = profile.asleepMinutes - deep - rem;

  final segments = <({SleepStageValue stage, double minutes})>[
    (stage: SleepStageValue.core, minutes: core * 0.45),
    (stage: SleepStageValue.deep, minutes: deep),
    (stage: SleepStageValue.awake, minutes: profile.awakeMinutes),
    (stage: SleepStageValue.core, minutes: core * 0.55),
    (stage: SleepStageValue.rem, minutes: rem),
  ];

  final out = <SleepSample>[];
  var cursor = bedtime;
  for (final segment in segments) {
    final end = cursor.add(
      Duration(milliseconds: (segment.minutes * 60000).round()),
    );
    out.add(
      SleepSample(
        startDate: cursor.toIso8601String(),
        endDate: end.toIso8601String(),
        value: segment.stage,
        sourceName: 'Apple Watch',
      ),
    );
    cursor = end;
  }

  out.add(
    SleepSample(
      startDate: bedtime.toIso8601String(),
      endDate: cursor.toIso8601String(),
      value: SleepStageValue.inBed,
      sourceName: 'Apple Watch',
    ),
  );

  return out;
}
